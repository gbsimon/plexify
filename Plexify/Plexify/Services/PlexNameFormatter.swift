import Foundation

struct PlexNameFormatter {
    /// Formats a movie name according to Plex conventions
    /// Format: `Title (Year) {imdb-ttXXXXXXX}` with optional `{edition-...}`
    static func formatMovieName(
        title: String,
        year: Int?,
        imdbID: String?,
        edition: String? = nil
    ) -> String {
        var components: [String] = []
        
        // Title
        let sanitizedTitle = PathSanitizer.sanitize(sanitizeMovieTitle(title))
        components.append(sanitizedTitle)
        
        // Year in parentheses
        if let year = year {
            components.append("(\(year))")
        }
        
        // Edition tag (optional)
        if let edition = edition, !edition.isEmpty {
            let sanitizedEdition = PathSanitizer.sanitize(edition)
            components.append("{edition-\(sanitizedEdition)}")
        }
        
        // IMDb ID tag (optional)
        if let imdbID = imdbID, !imdbID.isEmpty {
            components.append("{imdb-\(imdbID)}")
        }
        
        return components.joined(separator: " ")
    }
    
    /// Formats a TV show folder name according to Plex conventions
    /// Format: `Show (Year) {imdb-ttXXXXXXX}`
    static func formatTVShowFolderName(
        title: String,
        year: Int?,
        imdbID: String?
    ) -> String {
        var components: [String] = []
        
        // Title
        let sanitizedTitle = PathSanitizer.sanitize(sanitizeShowTitle(title))
        components.append(sanitizedTitle)
        
        // Year in parentheses
        if let year = year {
            components.append("(\(year))")
        }
        
        // IMDb ID tag (optional)
        if let imdbID = imdbID, !imdbID.isEmpty {
            components.append("{imdb-\(imdbID)}")
        }
        
        return components.joined(separator: " ")
    }
    
    /// Formats a season folder name
    /// Format: `Season 01`, `Season 02`, etc. (always zero-padded to 2 digits)
    static func formatSeasonFolderName(seasonNumber: Int) -> String {
        return String(format: "Season %02d", seasonNumber)
    }
    
    /// Formats a TV episode filename for season-based shows
    /// Format: `Show (Year) - s01e01 - Title.ext`
    static func formatTVEpisodeName(
        showTitle: String,
        year: Int?,
        season: Int,
        episode: Int,
        episodeTitle: String?,
        fileExtension: String
    ) -> String {
        var components: [String] = []
        
        // Show title
        let sanitizedShowTitle = PathSanitizer.sanitize(sanitizeShowTitle(showTitle))
        components.append(sanitizedShowTitle)
        
        // Year in parentheses
        if let year = year {
            components.append("(\(year))")
        }
        
        // Season/episode number: s01e01 format
        let seasonEpisode = String(format: "s%02de%02d", season, episode)
        components.append("-")
        components.append(seasonEpisode)
        
        // Episode title (optional)
        if let episodeTitle = episodeTitle, !episodeTitle.isEmpty {
            let sanitizedEpisodeTitle = PathSanitizer.sanitize(episodeTitle)
            components.append("-")
            components.append(sanitizedEpisodeTitle)
        }
        
        let baseName = components.joined(separator: " ")
        return fileExtension.isEmpty ? baseName : "\(baseName).\(fileExtension)"
    }
    
    /// Formats a TV episode filename for date-based shows
    /// Format: `Show (Year) - YYYY-MM-DD - Title.ext`
    static func formatTVEpisodeNameDateBased(
        showTitle: String,
        year: Int?,
        airDate: Date,
        episodeTitle: String?,
        fileExtension: String
    ) -> String {
        var components: [String] = []
        
        // Show title
        let sanitizedShowTitle = PathSanitizer.sanitize(sanitizeShowTitle(showTitle))
        components.append(sanitizedShowTitle)
        
        // Year in parentheses
        if let year = year {
            components.append("(\(year))")
        }
        
        // Air date in YYYY-MM-DD format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: airDate)
        components.append("-")
        components.append(dateString)
        
        // Episode title (optional)
        if let episodeTitle = episodeTitle, !episodeTitle.isEmpty {
            let sanitizedEpisodeTitle = PathSanitizer.sanitize(episodeTitle)
            components.append("-")
            components.append(sanitizedEpisodeTitle)
        }
        
        let baseName = components.joined(separator: " ")
        return fileExtension.isEmpty ? baseName : "\(baseName).\(fileExtension)"
    }

    private static func sanitizeShowTitle(_ title: String) -> String {
        var cleaned = title
        if let braceIndex = cleaned.firstIndex(of: "{") {
            cleaned = String(cleaned[..<braceIndex])
        }
        cleaned = cleaned.replacingOccurrences(of: #"\((\d{4})\)"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\s(19\d{2}|20\d{2})$"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func sanitizeMovieTitle(_ title: String) -> String {
        var cleaned = title
        if let braceIndex = cleaned.firstIndex(of: "{") {
            cleaned = String(cleaned[..<braceIndex])
        }
        cleaned = cleaned.replacingOccurrences(of: #"\((\d{4})\)"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\s(19\d{2}|20\d{2})$"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
