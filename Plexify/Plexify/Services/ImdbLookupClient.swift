import Foundation

struct ImdbLookupClient {
    enum LookupError: Error {
        case missingApiKey
        case noResults
        case missingImdbID
        case invalidResponse
    }

    private let baseURL = URL(string: "https://api.themoviedb.org/3")!

    func fetchImdbID(for title: String, year: Int?, mediaType: MediaType) async throws -> String {
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
            throw LookupError.invalidResponse
        }

        let (searchData, _) = try await URLSession.shared.data(from: resolvedSearchURL)
        let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: searchData)

        guard let firstResult = searchResponse.results.first else {
            throw LookupError.noResults
        }

        let imdbID: String?
        switch mediaType {
        case .movie:
            imdbID = try await fetchMovieImdbID(apiKey: apiKey, tmdbID: firstResult.id)
        case .tvShow:
            imdbID = try await fetchTvImdbID(apiKey: apiKey, tmdbID: firstResult.id)
        }

        guard let imdbID else {
            throw LookupError.missingImdbID
        }

        return imdbID
    }

    private func resolveApiKey() throws -> String {
        if let key = ProcessInfo.processInfo.environment["TMDB_API_KEY"], !key.isEmpty {
            return key
        }
        throw LookupError.missingApiKey
    }

    private func fetchMovieImdbID(apiKey: String, tmdbID: Int) async throws -> String? {
        let detailsURL = baseURL.appendingPathComponent("movie/\(tmdbID)")
        var components = URLComponents(url: detailsURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        guard let url = components?.url else {
            throw LookupError.invalidResponse
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
            throw LookupError.invalidResponse
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TvExternalIDsResponse.self, from: data)
        return response.imdb_id
    }
}

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
