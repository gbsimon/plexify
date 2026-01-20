import Foundation

/// Service that handles IMDb ID lookup with support for manual override, cache, and API lookup
struct ImdbLookupService {
    let lookupClient: ImdbLookupClientProtocol
    
    init(lookupClient: ImdbLookupClientProtocol = ImdbLookupClient()) {
        self.lookupClient = lookupClient
    }
    
    /// Resolves IMDb ID for a media item, respecting manual override
    /// - Returns: IMDb ID if found, nil if not available
    func resolveImdbID(for mediaItem: MediaItem) async throws -> String? {
        // If manual IMDb ID is set, use it (manual override)
        if mediaItem.isManualImdbID, let manualID = mediaItem.imdbID {
            return manualID
        }
        
        // If IMDb ID already exists (from cache or previous lookup), return it
        if let existingID = mediaItem.imdbID {
            return existingID
        }
        
        // Otherwise, perform API lookup
        do {
            return try await lookupClient.fetchImdbID(
                for: mediaItem.title,
                year: mediaItem.year,
                mediaType: mediaItem.mediaType
            )
        } catch {
            // Return nil if lookup fails (allows user to manually enter later)
            return nil
        }
    }
}
