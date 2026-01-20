import Foundation

struct MediaItem {
    let originalFolderURL: URL
    let title: String
    let year: Int?
    let imdbID: String?
    let mediaType: MediaType
    let edition: String? // For movies: "Director's Cut", "Extended Edition", etc.
    let isManualImdbID: Bool // True if IMDb ID was manually entered (overrides API lookup)
    
    // For TV shows
    let episodes: [Episode]?
    
    init(
        originalFolderURL: URL,
        title: String,
        year: Int? = nil,
        imdbID: String? = nil,
        mediaType: MediaType,
        edition: String? = nil,
        episodes: [Episode]? = nil,
        isManualImdbID: Bool = false
    ) {
        self.originalFolderURL = originalFolderURL
        self.title = title
        self.year = year
        self.imdbID = imdbID
        self.mediaType = mediaType
        self.edition = edition
        self.episodes = episodes
        self.isManualImdbID = isManualImdbID
    }
    
    /// Creates a new MediaItem with a manually entered IMDb ID
    func withManualImdbID(_ imdbID: String) -> MediaItem {
        return MediaItem(
            originalFolderURL: originalFolderURL,
            title: title,
            year: year,
            imdbID: imdbID,
            mediaType: mediaType,
            edition: edition,
            episodes: episodes,
            isManualImdbID: true
        )
    }
}
