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
        var warnings: [String] = []
        
        // Check for missing IMDb ID
        if media.imdbID == nil {
            warnings.append("Missing IMDb ID - matching may be less accurate")
        }
        
        // Check for missing year
        if media.year == nil {
            warnings.append("Missing year - recommended for better matching")
        }
        
        // Check for multiple files (might indicate multiple editions)
        if fileURLs.count > 1 {
            warnings.append("Multiple files detected - ensure all files belong to the same movie")
        }
        
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
            seasonFolders: nil,
            warnings: warnings
        )
    }
    
    private func buildTVShowPlan(for media: MediaItem, fileURLs: [URL]) -> RenamePlan {
        var warnings: [String] = []
        
        // Check for missing IMDb ID
        if media.imdbID == nil {
            warnings.append("Missing IMDb ID - matching may be less accurate")
        }
        
        // Check for missing year
        if media.year == nil {
            warnings.append("Missing year - recommended for Plex TV Series agent")
        }
        
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
            warnings.append("No episode data provided - files will not be properly organized into seasons")
            warnings.append("Episode information is required for TV shows")
            
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
            seasonFolders: sortedSeasonFolders.isEmpty ? nil : sortedSeasonFolders,
            warnings: warnings
        )
    }

    func apply(plan: RenamePlan) throws {
        let fileManager = FileManager.default
        
        // Ensure we have access to the original folder AND parent directory (important for network volumes)
        let originalAccessing = plan.originalFolderURL.startAccessingSecurityScopedResource()
        let parentURL = plan.originalFolderURL.deletingLastPathComponent()
        let parentAccessing = parentURL.startAccessingSecurityScopedResource()
        
        if originalAccessing {
            print("🔐 Started accessing original folder for rename operation")
        }
        if parentAccessing {
            print("🔐 Started accessing parent directory for rename operation")
        }
        
        defer {
            if originalAccessing {
                plan.originalFolderURL.stopAccessingSecurityScopedResource()
            }
            if parentAccessing {
                parentURL.stopAccessingSecurityScopedResource()
            }
        }
        
        let targetFolderURL = parentURL.appendingPathComponent(plan.targetFolderName)
        
        // Track operations for rollback
        var operations: [RenameOperation] = []
        var folderMoved = false
        
        do {
            // Verify original folder is accessible
            guard fileManager.fileExists(atPath: plan.originalFolderURL.path) else {
                throw RenameError.applyFailed("Original folder not found or not accessible. Please ensure you have permission to access this folder.")
            }
            
            // Check if target folder already exists
            let targetExists = fileManager.fileExists(atPath: targetFolderURL.path)
            
            // Check if source and target are the same (already renamed)
            let sourceAndTargetSame = plan.originalFolderURL.path == targetFolderURL.path
            
            if sourceAndTargetSame {
                // Source and target are the same path - folder already has target name
                print("ℹ️ Folder already has the target name, skipping folder rename")
                folderMoved = false
            } else if targetExists {
                // Target exists but is different folder - check if it's the same folder (resolved path)
                var isSameFolder = false
                if let sourceResourceValues = try? plan.originalFolderURL.resourceValues(forKeys: [.fileResourceIdentifierKey]),
                   let targetResourceValues = try? targetFolderURL.resourceValues(forKeys: [.fileResourceIdentifierKey]),
                   let sourceID = sourceResourceValues.fileResourceIdentifier,
                   let targetID = targetResourceValues.fileResourceIdentifier {
                    isSameFolder = sourceID.isEqual(targetID)
                }
                
                if isSameFolder {
                    print("ℹ️ Target folder is the same as source (resolved path), skipping folder rename")
                    folderMoved = false
                } else {
                    // Different folder with same name - error
                    throw RenameError.applyFailed("A folder named \"\(plan.targetFolderName)\" already exists in \"\(parentURL.lastPathComponent)\". Please rename or remove the existing folder first.")
                }
            } else {
                // Target doesn't exist, proceed with rename
                if plan.originalFolderURL.lastPathComponent != plan.targetFolderName {
                    print("📦 Moving folder: \(plan.originalFolderURL.lastPathComponent) → \(plan.targetFolderName)")
                    try fileManager.moveItem(at: plan.originalFolderURL, to: targetFolderURL)
                    operations.append(.movedFolder(from: plan.originalFolderURL, to: targetFolderURL))
                    folderMoved = true
                }
            }
            
            // Use the correct folder URL for file operations (target if moved, original if not)
            let workingFolderURL = folderMoved ? targetFolderURL : plan.originalFolderURL

            // Create season folders for TV shows
            if let seasonFolders = plan.seasonFolders {
                for seasonFolder in seasonFolders {
                    let seasonURL = workingFolderURL.appendingPathComponent(seasonFolder.targetName)
                    if !fileManager.fileExists(atPath: seasonURL.path) {
                        try fileManager.createDirectory(at: seasonURL, withIntermediateDirectories: true)
                        operations.append(.createdDirectory(seasonURL))
                    }
                }
            }

            // Rename files
            for rename in plan.fileRenames {
                // Find the original file location (in the working folder)
                let originalFileURL = workingFolderURL.appendingPathComponent(rename.originalURL.lastPathComponent)
                
                // Determine target location (season folder for TV shows, root for movies)
                let targetLocation: URL
                if let seasonNumber = rename.seasonNumber,
                   let seasonFolder = plan.seasonFolders?.first(where: { $0.seasonNumber == seasonNumber }) {
                    targetLocation = workingFolderURL.appendingPathComponent(seasonFolder.targetName)
                } else {
                    targetLocation = workingFolderURL
                }
                
                let targetURL = targetLocation.appendingPathComponent(rename.targetName)
                
                // Only rename if the name or location changed
                if originalFileURL.path != targetURL.path {
                    // Check if target file already exists
                    if fileManager.fileExists(atPath: targetURL.path) {
                        print("⚠️ Target file already exists: \(rename.targetName), skipping...")
                        continue
                    }
                    
                    print("📝 Renaming file: \(rename.originalURL.lastPathComponent) → \(rename.targetName)")
                    try fileManager.moveItem(at: originalFileURL, to: targetURL)
                    operations.append(.movedFile(from: originalFileURL, to: targetURL))
                } else {
                    print("ℹ️ File already has target name, skipping: \(rename.targetName)")
                }
            }
        } catch {
            // Rollback on error
            try rollback(operations: operations, folderMoved: folderMoved, originalFolderURL: plan.originalFolderURL, targetFolderURL: targetFolderURL)
            throw RenameError.applyFailed(error.localizedDescription)
        }
    }
    
    private enum RenameOperation {
        case createdDirectory(URL)
        case movedFolder(from: URL, to: URL)
        case movedFile(from: URL, to: URL)
    }
    
    private func rollback(
        operations: [RenameOperation],
        folderMoved: Bool,
        originalFolderURL: URL,
        targetFolderURL: URL
    ) throws {
        let fileManager = FileManager.default
        
        // Rollback in reverse order
        for operation in operations.reversed() {
            switch operation {
            case .movedFile(let from, let to):
                // Restore file to original location
                if fileManager.fileExists(atPath: to.path) {
                    try? fileManager.moveItem(at: to, to: from)
                }
            case .movedFolder(let from, let to):
                // Restore folder to original location
                if fileManager.fileExists(atPath: to.path) {
                    try? fileManager.moveItem(at: to, to: from)
                }
            case .createdDirectory(let url):
                // Remove created directory
                if fileManager.fileExists(atPath: url.path) {
                    try? fileManager.removeItem(at: url)
                }
            }
        }
        
        // If folder was moved, ensure original folder exists
        if folderMoved && !fileManager.fileExists(atPath: originalFolderURL.path) {
            // Try to restore from target if it still exists
            if fileManager.fileExists(atPath: targetFolderURL.path) {
                try? fileManager.moveItem(at: targetFolderURL, to: originalFolderURL)
            }
        }
    }
}

enum RenameError: LocalizedError {
    case applyFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .applyFailed(let message):
            return "Failed to apply rename plan: \(message)"
        }
    }
}

