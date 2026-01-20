import Foundation

struct FolderRenamer {
    func buildPlan(for media: MediaItem, fileURLs: [URL]) -> RenamePlan {
        switch media.mediaType {
        case .movie:
            return buildMoviePlan(for: media, fileURLs: fileURLs)
        case .tvShow:
            return buildTVShowPlan(for: media, fileURLs: fileURLs)
        }
    }
    
    private func buildMoviePlan(for media: MediaItem, fileURLs: [URL]) -> RenamePlan {
        let folderName = PlexNameFormatter.formatMovieName(
            title: media.title,
            year: media.year,
            imdbID: media.imdbID,
            edition: media.edition
        )
        
        let fileRenames = fileURLs.map { url in
            let fileName = PlexNameFormatter.formatMovieName(
                title: media.title,
                year: media.year,
                imdbID: media.imdbID,
                edition: media.edition
            )
            let fileExtension = url.pathExtension
            let fullFileName = fileExtension.isEmpty ? fileName : "\(fileName).\(fileExtension)"
            
            return RenamePlan.FileRename(
                originalURL: url,
                targetName: fullFileName,
                seasonNumber: nil
            )
        }
        
        return RenamePlan(
            originalFolderURL: media.originalFolderURL,
            targetFolderName: folderName,
            fileRenames: fileRenames,
            seasonFolders: nil
        )
    }
    
    private func buildTVShowPlan(for media: MediaItem, fileURLs: [URL]) -> RenamePlan {
        let folderName = PlexNameFormatter.formatTVShowFolderName(
            title: media.title,
            year: media.year,
            imdbID: media.imdbID
        )
        
        // Group episodes by season
        var seasonFolders: [Int: RenamePlan.SeasonFolder] = [:]
        var fileRenames: [RenamePlan.FileRename] = []
        
        if let episodes = media.episodes {
            // Use episode data if available
            for episode in episodes {
                let season = episode.season
                
                // Create season folder if needed
                if seasonFolders[season] == nil {
                    let seasonFolderName = PlexNameFormatter.formatSeasonFolderName(seasonNumber: season)
                    seasonFolders[season] = RenamePlan.SeasonFolder(
                        seasonNumber: season,
                        targetName: seasonFolderName
                    )
                }
                
                // Format episode filename
                let fileName: String
                if let airDate = episode.airDate {
                    // Date-based episode
                    let fileExtension = episode.originalURL.pathExtension
                    fileName = PlexNameFormatter.formatTVEpisodeNameDateBased(
                        showTitle: media.title,
                        year: media.year,
                        airDate: airDate,
                        episodeTitle: episode.title,
                        fileExtension: fileExtension
                    )
                } else {
                    // Season-based episode
                    let fileExtension = episode.originalURL.pathExtension
                    fileName = PlexNameFormatter.formatTVEpisodeName(
                        showTitle: media.title,
                        year: media.year,
                        season: episode.season,
                        episode: episode.episode,
                        episodeTitle: episode.title,
                        fileExtension: fileExtension
                    )
                }
                
                fileRenames.append(RenamePlan.FileRename(
                    originalURL: episode.originalURL,
                    targetName: fileName,
                    seasonNumber: season
                ))
            }
        } else {
            // Fallback: if no episode data, treat as simple file rename
            // This is a basic fallback - in practice, episodes should be provided
            for url in fileURLs {
                let fileExtension = url.pathExtension
                let fileName = fileExtension.isEmpty ? url.deletingPathExtension().lastPathComponent : "\(url.deletingPathExtension().lastPathComponent).\(fileExtension)"
                fileRenames.append(RenamePlan.FileRename(
                    originalURL: url,
                    targetName: fileName,
                    seasonNumber: nil
                ))
            }
        }
        
        let sortedSeasonFolders = seasonFolders.values.sorted { $0.seasonNumber < $1.seasonNumber }
        
        return RenamePlan(
            originalFolderURL: media.originalFolderURL,
            targetFolderName: folderName,
            fileRenames: fileRenames,
            seasonFolders: sortedSeasonFolders.isEmpty ? nil : sortedSeasonFolders
        )
    }

    func apply(plan: RenamePlan) throws {
        let fileManager = FileManager.default
        let parentURL = plan.originalFolderURL.deletingLastPathComponent()
        let targetFolderURL = parentURL.appendingPathComponent(plan.targetFolderName)

        // Create target folder if it doesn't exist
        if !fileManager.fileExists(atPath: targetFolderURL.path) {
            try fileManager.createDirectory(at: targetFolderURL, withIntermediateDirectories: true)
        }
        
        // Move folder if it's different
        if plan.originalFolderURL.lastPathComponent != plan.targetFolderName {
            try fileManager.moveItem(at: plan.originalFolderURL, to: targetFolderURL)
        }

        // Create season folders for TV shows
        if let seasonFolders = plan.seasonFolders {
            for seasonFolder in seasonFolders {
                let seasonURL = targetFolderURL.appendingPathComponent(seasonFolder.targetName)
                if !fileManager.fileExists(atPath: seasonURL.path) {
                    try fileManager.createDirectory(at: seasonURL, withIntermediateDirectories: true)
                }
            }
        }

        // Rename files
        for rename in plan.fileRenames {
            let originalInNewFolder = targetFolderURL.appendingPathComponent(rename.originalURL.lastPathComponent)
            
            // Determine target location (season folder for TV shows, root for movies)
            let targetLocation: URL
            if let seasonNumber = rename.seasonNumber,
               let seasonFolder = plan.seasonFolders?.first(where: { $0.seasonNumber == seasonNumber }) {
                targetLocation = targetFolderURL.appendingPathComponent(seasonFolder.targetName)
            } else {
                targetLocation = targetFolderURL
            }
            
            let targetURL = targetLocation.appendingPathComponent(rename.targetName)
            
            // Only move if the name or location changed
            if originalInNewFolder.path != targetURL.path {
                try fileManager.moveItem(at: originalInNewFolder, to: targetURL)
            }
        }
    }
}
