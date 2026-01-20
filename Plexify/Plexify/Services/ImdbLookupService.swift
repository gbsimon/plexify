import Foundation

/// Service that handles IMDb ID lookup with support for manual override, cache, and API lookup
struct ImdbLookupService {
    let lookupClient: ImdbLookupClientProtocol
    
    init(lookupClient: ImdbLookupClientProtocol = ImdbLookupClient()) {
        self.lookupClient = lookupClient
    }
    
    /// Resolves IMDb metadata for a media item, respecting manual override
    /// - Returns: IMDb result if found, nil if not available
    func resolveImdbResult(for mediaItem: MediaItem) async throws -> ImdbLookupResult? {
        // If manual IMDb ID is set, use it (manual override)
        if mediaItem.isManualImdbID, let manualID = mediaItem.imdbID {
            return ImdbLookupResult(imdbID: manualID, year: mediaItem.year, tmdbID: mediaItem.tmdbID)
        }
        
        // If IMDb ID already exists (from cache or previous lookup), return it
        if let existingID = mediaItem.imdbID {
            return ImdbLookupResult(imdbID: existingID, year: mediaItem.year, tmdbID: mediaItem.tmdbID)
        }
        
        // Otherwise, perform API lookup
        do {
            return try await lookupClient.fetchImdbResult(
                for: mediaItem.title,
                year: mediaItem.year,
                mediaType: mediaItem.mediaType
            )
        } catch {
            // Return nil if lookup fails (allows user to manually enter later)
            return nil
        }
    }

    /// Resolves IMDb ID only
    func resolveImdbID(for mediaItem: MediaItem) async throws -> String? {
        return try await resolveImdbResult(for: mediaItem)?.imdbID
    }

    func enrichEpisodesForTVShow(tmdbID: Int, episodes: [Episode]) async -> [Episode] {
        var enriched: [Episode] = []
        enriched.reserveCapacity(episodes.count)

        for episode in episodes {
            guard episode.episode > 0 else {
                enriched.append(episode)
                continue
            }

            let title = try? await lookupClient.fetchEpisodeTitle(
                tvID: tmdbID,
                season: episode.season,
                episode: episode.episode
            )

            let updated = Episode(
                season: episode.season,
                episode: episode.episode,
                title: title ?? episode.title,
                originalURL: episode.originalURL,
                airDate: episode.airDate
            )
            enriched.append(updated)
        }

        return enriched
    }

    func resolveTmdbID(from imdbID: String, mediaType: MediaType) async -> Int? {
        return try? await lookupClient.fetchTmdbIDFromImdbID(imdbID, mediaType: mediaType)
    }
}
