import Foundation

/// Protocol for IMDb ID lookup services
protocol ImdbLookupClientProtocol {
    func fetchImdbResult(for title: String, year: Int?, mediaType: MediaType) async throws -> ImdbLookupResult
    func fetchEpisodeTitle(tvID: Int, season: Int, episode: Int) async throws -> String?
    func fetchTmdbIDFromImdbID(_ imdbID: String, mediaType: MediaType) async throws -> Int?
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
    
    func fetchImdbResult(for title: String, year: Int?, mediaType: MediaType) async throws -> ImdbLookupResult {
        // Check cache first
        let cacheKey = CacheKey(title: title, year: year, mediaType: mediaType)
        let cachedID = cache.get(key: cacheKey)
        if let cachedID, year != nil {
            return ImdbLookupResult(imdbID: cachedID, year: year, tmdbID: nil)
        }
        
        // Fetch from API
        let apiKey = try resolveApiKey()
        let searchPath = mediaType == .movie ? "search/movie" : "search/tv"
        let sanitizedTitle = sanitizeTitleForSearch(title, year: year)
        let searchURL = baseURL.appendingPathComponent(searchPath)

        var searchComponents = URLComponents(url: searchURL, resolvingAgainstBaseURL: false)
        var searchItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: sanitizedTitle),
        ]
        if let year {
            let yearParam = mediaType == .movie ? "year" : "first_air_date_year"
            searchItems.append(URLQueryItem(name: yearParam, value: String(year)))
        }
        searchComponents?.queryItems = searchItems

        guard let resolvedSearchURL = searchComponents?.url else {
            throw ImdbLookupError.invalidResponse
        }

        let (searchData, searchHTTPResponse) = try await URLSession.shared.data(from: resolvedSearchURL)
        if let http = searchHTTPResponse as? HTTPURLResponse {
            print("🌐 TMDb search status: \(http.statusCode)")
        }
        let decodedSearchResponse = try JSONDecoder().decode(SearchResponse.self, from: searchData)

        guard let firstResult = decodedSearchResponse.results.first else {
            print("⚠️ TMDb search returned 0 results for: \(sanitizedTitle) (\(year.map(String.init) ?? "no year"))")
            if let cachedID {
                return ImdbLookupResult(imdbID: cachedID, year: year, tmdbID: nil)
            }
            throw ImdbLookupError.noResults
        }

        let imdbID: String?
        let tvYear: Int?
        switch mediaType {
        case .movie:
            tvYear = nil
            imdbID = try await fetchMovieImdbID(apiKey: apiKey, tmdbID: firstResult.id)
        case .tvShow:
            imdbID = try await fetchTvImdbID(apiKey: apiKey, tmdbID: firstResult.id)
            tvYear = try await fetchTvFirstAirYear(apiKey: apiKey, tmdbID: firstResult.id)
        }

        guard let imdbID else {
            if let cachedID {
                return ImdbLookupResult(imdbID: cachedID, year: year, tmdbID: nil)
            }
            throw ImdbLookupError.missingImdbID
        }
        
        // Store in cache
        cache.set(key: cacheKey, imdbID: imdbID)
        
        let suggestedYear = mediaType == .movie
            ? firstResult.releaseYear
            : (firstResult.firstAirYear ?? tvYear)
        return ImdbLookupResult(imdbID: imdbID, year: suggestedYear ?? year, tmdbID: firstResult.id)
    }

    private func resolveApiKey() throws -> String {
        if let key = KeychainStore.shared.readString(service: "Plexify.TMDB", account: "apiKey"),
           !key.isEmpty {
            return key
        }
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

        let (data, httpResponse) = try await URLSession.shared.data(from: url)
        if let http = httpResponse as? HTTPURLResponse {
            print("🌐 TMDb movie details status: \(http.statusCode)")
        }
        let decodedResponse = try JSONDecoder().decode(MovieDetailsResponse.self, from: data)
        if decodedResponse.imdb_id == nil {
            print("⚠️ TMDb movie details missing imdb_id for tmdbID: \(tmdbID)")
        }
        return decodedResponse.imdb_id
    }

    private func fetchTvImdbID(apiKey: String, tmdbID: Int) async throws -> String? {
        let detailsURL = baseURL.appendingPathComponent("tv/\(tmdbID)/external_ids")
        var components = URLComponents(url: detailsURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        guard let url = components?.url else {
            throw ImdbLookupError.invalidResponse
        }

        let (data, httpResponse) = try await URLSession.shared.data(from: url)
        if let http = httpResponse as? HTTPURLResponse {
            print("🌐 TMDb TV external_ids status: \(http.statusCode)")
        }
        let decodedResponse = try JSONDecoder().decode(TvExternalIDsResponse.self, from: data)
        if decodedResponse.imdb_id == nil {
            print("⚠️ TMDb TV external_ids missing imdb_id for tmdbID: \(tmdbID)")
        }
        return decodedResponse.imdb_id
    }

    private func fetchTvFirstAirYear(apiKey: String, tmdbID: Int) async throws -> Int? {
        let detailsURL = baseURL.appendingPathComponent("tv/\(tmdbID)")
        var components = URLComponents(url: detailsURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        guard let url = components?.url else {
            throw ImdbLookupError.invalidResponse
        }

        let (data, httpResponse) = try await URLSession.shared.data(from: url)
        if let http = httpResponse as? HTTPURLResponse {
            print("🌐 TMDb TV details status: \(http.statusCode)")
        }
        let decodedResponse = try JSONDecoder().decode(TvDetailsResponse.self, from: data)
        guard let firstAirDate = decodedResponse.first_air_date else {
            return nil
        }
        return Int(firstAirDate.prefix(4))
    }

    func fetchEpisodeTitle(tvID: Int, season: Int, episode: Int) async throws -> String? {
        let apiKey = try resolveApiKey()
        let detailsURL = baseURL.appendingPathComponent("tv/\(tvID)/season/\(season)/episode/\(episode)")
        var components = URLComponents(url: detailsURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        guard let url = components?.url else {
            throw ImdbLookupError.invalidResponse
        }

        let (data, httpResponse) = try await URLSession.shared.data(from: url)
        if let http = httpResponse as? HTTPURLResponse {
            print("🌐 TMDb episode details status: \(http.statusCode) for s\(season)e\(episode)")
        }
        let decodedResponse = try JSONDecoder().decode(TvEpisodeDetailsResponse.self, from: data)
        return decodedResponse.name
    }

    func fetchTmdbIDFromImdbID(_ imdbID: String, mediaType: MediaType) async throws -> Int? {
        let apiKey = try resolveApiKey()
        let normalizedImdbID = imdbID.hasPrefix("tt") ? imdbID : "tt\(imdbID)"
        let detailsURL = baseURL.appendingPathComponent("find/\(normalizedImdbID)")
        var components = URLComponents(url: detailsURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "external_source", value: "imdb_id"),
        ]
        guard let url = components?.url else {
            throw ImdbLookupError.invalidResponse
        }

        let (data, httpResponse) = try await URLSession.shared.data(from: url)
        if let http = httpResponse as? HTTPURLResponse {
            print("🌐 TMDb find status: \(http.statusCode)")
        }
        let decodedResponse = try JSONDecoder().decode(FindResponse.self, from: data)

        switch mediaType {
        case .movie:
            return decodedResponse.movie_results.first?.id
        case .tvShow:
            return decodedResponse.tv_results.first?.id
        }
    }

    private func sanitizeTitleForSearch(_ title: String, year: Int?) -> String {
        var cleaned = title

        if let year {
            let yearToken = " \(year)"
            if cleaned.hasSuffix(yearToken) {
                cleaned = String(cleaned.dropLast(yearToken.count))
            }
        }

        cleaned = cleaned.replacingOccurrences(of: #"\(\d{4}\)$"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\b(19\d{2}|20\d{2})\b$"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Stub implementation for testing
struct StubImdbLookupClient: ImdbLookupClientProtocol {
    let stubResults: [String: ImdbLookupResult] // [cacheKey: result]
    let stubEpisodeTitles: [String: String] // [tvID|season|episode: title]
    let stubFindResults: [String: Int] // [imdbID: tmdbID]
    
    init(
        stubResults: [String: ImdbLookupResult] = [:],
        stubEpisodeTitles: [String: String] = [:],
        stubFindResults: [String: Int] = [:]
    ) {
        self.stubResults = stubResults
        self.stubEpisodeTitles = stubEpisodeTitles
        self.stubFindResults = stubFindResults
    }
    
    func fetchImdbResult(for title: String, year: Int?, mediaType: MediaType) async throws -> ImdbLookupResult {
        let key = "\(title)|\(year ?? 0)|\(mediaType)"
        if let result = stubResults[key] {
            return result
        }
        throw ImdbLookupError.noResults
    }

    func fetchEpisodeTitle(tvID: Int, season: Int, episode: Int) async throws -> String? {
        let key = "\(tvID)|\(season)|\(episode)"
        return stubEpisodeTitles[key]
    }

    func fetchTmdbIDFromImdbID(_ imdbID: String, mediaType: MediaType) async throws -> Int? {
        return stubFindResults[imdbID]
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

struct ImdbLookupResult {
    let imdbID: String
    let year: Int?
    let tmdbID: Int?
}

private struct SearchResult: Decodable {
    let id: Int
    let release_date: String?
    let first_air_date: String?

    var releaseYear: Int? {
        guard let release_date else { return nil }
        return Int(release_date.prefix(4))
    }

    var firstAirYear: Int? {
        guard let first_air_date else { return nil }
        return Int(first_air_date.prefix(4))
    }
}

private struct MovieDetailsResponse: Decodable {
    let imdb_id: String?
}

private struct TvExternalIDsResponse: Decodable {
    let imdb_id: String?
}

private struct TvDetailsResponse: Decodable {
    let first_air_date: String?
}

private struct TvEpisodeDetailsResponse: Decodable {
    let name: String?
}

private struct FindResponse: Decodable {
    let movie_results: [FindResult]
    let tv_results: [FindResult]
}

private struct FindResult: Decodable {
    let id: Int
}
