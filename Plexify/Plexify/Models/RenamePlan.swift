import Foundation

struct RenamePlan {
    let originalFolderURL: URL
    let targetFolderName: String
    let fileRenames: [FileRename]
    let seasonFolders: [SeasonFolder]? // For TV shows
    let warnings: [String] // Warnings about the rename plan
    
    struct FileRename {
        let originalURL: URL
        let targetName: String
        let seasonNumber: Int? // For TV shows: which season folder this file belongs to
    }
    
    struct SeasonFolder {
        let seasonNumber: Int
        let targetName: String // e.g., "Season 01"
    }
    
    init(
        originalFolderURL: URL,
        targetFolderName: String,
        fileRenames: [FileRename],
        seasonFolders: [SeasonFolder]? = nil,
        warnings: [String] = []
    ) {
        self.originalFolderURL = originalFolderURL
        self.targetFolderName = targetFolderName
        self.fileRenames = fileRenames
        self.seasonFolders = seasonFolders
        self.warnings = warnings
    }
}
