import Foundation

/// Protocol for IMDb ID lookup services
protocol ImdbLookupClientProtocol {
    func fetchImdbID(for title: String, year: Int?, mediaType: MediaType) async throws -> String
}

enum ImdbLookupError: Error {
    case missingApiKey
    case noResults
    case missingImdbID
    case invalidResponse
    case cacheError(String)
}

/// TMDb-based IMDb lookup client with caching support
struct ImdbLookupClient: ImdbLookupClientProtocol {
    private let baseURL = URL(string: "https://api.themoviedb.org/3")!
    private let cache: ImdbLookupCache
    
    init(cache: ImdbLookupCache = ImdbLookupCache()) {
        self.cache = cache
    }
    
    func fetchImdbID(for title: String, year: Int?, mediaType: MediaType) async throws -> String {
        // Check cache first
        let cacheKey = CacheKey(title: title, year: year, mediaType: mediaType)
        if let cachedID = cache.get(key: cacheKey) {
            return cachedID
        }
        
        // Fetch from API
        let apiKey = try resolveApiKey()
        let searchPath = mediaType == .movie ? "search/movie" : "search/tv"
        let searchURL = baseURL.appendingPathComponent(searchPath)

        var searchComponents = URLComponents(url: searchURL, resolvingAgainstBaseURL: false)
        var searchItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: title),
        ]
        if let year {
            let yearParam = mediaType == .movie ? "year" : "first_air_date_year"
            searchItems.append(URLQueryItem(name: yearParam, value: String(year)))
        }
        searchComponents?.queryItems = searchItems

        guard let resolvedSearchURL = searchComponents?.url else {
            throw ImdbLookupError.invalidResponse
        }

        let (searchData, _) = try await URLSession.shared.data(from: resolvedSearchURL)
        let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: searchData)

        guard let firstResult = searchResponse.results.first else {
            throw ImdbLookupError.noResults
        }

        let imdbID: String?
        switch mediaType {
        case .movie:
            imdbID = try await fetchMovieImdbID(apiKey: apiKey, tmdbID: firstResult.id)
        case .tvShow:
            imdbID = try await fetchTvImdbID(apiKey: apiKey, tmdbID: firstResult.id)
        }

        guard let imdbID else {
            throw ImdbLookupError.missingImdbID
        }
        
        // Store in cache
        cache.set(key: cacheKey, imdbID: imdbID)
        
        return imdbID
    }

    private func resolveApiKey() throws -> String {
        if let key = ProcessInfo.processInfo.environment["TMDB_API_KEY"], !key.isEmpty {
            return key
        }
        throw ImdbLookupError.missingApiKey
    }

    private func fetchMovieImdbID(apiKey: String, tmdbID: Int) async throws -> String? {
        let detailsURL = baseURL.appendingPathComponent("movie/\(tmdbID)")
        var components = URLComponents(url: detailsURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        guard let url = components?.url else {
            throw ImdbLookupError.invalidResponse
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(MovieDetailsResponse.self, from: data)
        return response.imdb_id
    }

    private func fetchTvImdbID(apiKey: String, tmdbID: Int) async throws -> String? {
        let detailsURL = baseURL.appendingPathComponent("tv/\(tmdbID)/external_ids")
        var components = URLComponents(url: detailsURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        guard let url = components?.url else {
            throw ImdbLookupError.invalidResponse
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TvExternalIDsResponse.self, from: data)
        return response.imdb_id
    }
}

/// Stub implementation for testing
struct StubImdbLookupClient: ImdbLookupClientProtocol {
    let stubResults: [String: String] // [cacheKey: imdbID]
    
    init(stubResults: [String: String] = [:]) {
        self.stubResults = stubResults
    }
    
    func fetchImdbID(for title: String, year: Int?, mediaType: MediaType) async throws -> String {
        let key = "\(title)|\(year ?? 0)|\(mediaType)"
        if let result = stubResults[key] {
            return result
        }
        throw ImdbLookupError.noResults
    }
}

// MARK: - Cache Support

struct CacheKey: Hashable {
    let title: String
    let year: Int?
    let mediaType: MediaType
}

/// Cache for IMDb lookups using JSON file storage
class ImdbLookupCache {
    private let cacheFileURL: URL
    private var cache: [String: String] = [:] // [cacheKeyString: imdbID]
    
    init(cacheFileURL: URL? = nil) {
        if let url = cacheFileURL {
            self.cacheFileURL = url
        } else {
            // Default to Application Support directory
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appFolder = appSupport.appendingPathComponent("Plexify", isDirectory: true)
            try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
            self.cacheFileURL = appFolder.appendingPathComponent("imdb_cache.json")
        }
        loadCache()
    }
    
    func get(key: CacheKey) -> String? {
        let keyString = makeKeyString(key)
        return cache[keyString]
    }
    
    func set(key: CacheKey, imdbID: String) {
        let keyString = makeKeyString(key)
        cache[keyString] = imdbID
        saveCache()
    }
    
    func clear() {
        cache.removeAll()
        saveCache()
    }
    
    private func makeKeyString(_ key: CacheKey) -> String {
        return "\(key.title.lowercased())|\(key.year ?? 0)|\(key.mediaType)"
    }
    
    private func loadCache() {
        guard FileManager.default.fileExists(atPath: cacheFileURL.path),
              let data = try? Data(contentsOf: cacheFileURL),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }
        cache = decoded
    }
    
    private func saveCache() {
        guard let data = try? JSONEncoder().encode(cache) else {
            return
        }
        try? data.write(to: cacheFileURL)
    }
}

// MARK: - Response Models

private struct SearchResponse: Decodable {
    let results: [SearchResult]
}

private struct SearchResult: Decodable {
    let id: Int
}

private struct MovieDetailsResponse: Decodable {
    let imdb_id: String?
}

private struct TvExternalIDsResponse: Decodable {
    let imdb_id: String?
}
