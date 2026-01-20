import Foundation

struct Episode {
    let season: Int
    let episode: Int
    let title: String?
    let originalURL: URL
    let airDate: Date? // For date-based TV shows (YYYY-MM-DD format)
    
    init(
        season: Int,
        episode: Int,
        title: String? = nil,
        originalURL: URL,
        airDate: Date? = nil
    ) {
        self.season = season
        self.episode = episode
        self.title = title
        self.originalURL = originalURL
        self.airDate = airDate
    }
}
