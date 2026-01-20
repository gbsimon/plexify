import Foundation

struct MediaItem {
    let originalFolderURL: URL
    let title: String
    let year: Int?
    let imdbID: String?
    let mediaType: MediaType
    let edition: String? // For movies: "Director's Cut", "Extended Edition", etc.
    
    // For TV shows
    let episodes: [Episode]?
    
    init(
        originalFolderURL: URL,
        title: String,
        year: Int? = nil,
        imdbID: String? = nil,
        mediaType: MediaType,
        edition: String? = nil,
        episodes: [Episode]? = nil
    ) {
        self.originalFolderURL = originalFolderURL
        self.title = title
        self.year = year
        self.imdbID = imdbID
        self.mediaType = mediaType
        self.edition = edition
        self.episodes = episodes
    }
}
