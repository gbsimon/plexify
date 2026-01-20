import Foundation

struct FolderScanner {
    // Common video file extensions
    private static let videoExtensions: Set<String> = [
        "mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v",
        "mpg", "mpeg", "3gp", "ogv", "ts", "m2ts", "vob"
    ]
    
    // Folders to exclude (Plex conventions)
    private static let excludedFolderNames: Set<String> = [
        "extras", "samples", "bonus", "bonus disc", "featurettes",
        "trailers", "behind the scenes", "deleted scenes", "scenes",
        "VIDEO_TS", "BDMV", "AUDIO_TS"
    ]
    
    // Files/folders to exclude
    private static let excludedFilePatterns: [String] = [
        "sample", "trailer"
    ]
    
    struct ScanResult {
        let folderURL: URL
        let mediaType: MediaType
        let mediaFiles: [URL]
        let excludedItems: [URL]
        let warnings: [String]
    }
    
    /// Scans a folder and detects media files, classifying as movie or TV show
    func scan(folderURL: URL) throws -> ScanResult {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: folderURL.path) else {
            throw ScanError.folderNotFound
        }
        
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ScanError.notADirectory
        }
        
        var mediaFiles: [URL] = []
        var excludedItems: [URL] = []
        var warnings: [String] = []
        
        // Get all items in the folder
        let contents = try fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        
        // Filter out excluded folders
        let includedItems = contents.filter { url in
            let name = url.lastPathComponent.lowercased()
            
            // Check if it's an excluded folder
            if FolderScanner.excludedFolderNames.contains(name) {
                excludedItems.append(url)
                return false
            }
            
            // Check if folder name contains excluded patterns
            for pattern in FolderScanner.excludedFilePatterns {
                if name.contains(pattern) {
                    excludedItems.append(url)
                    return false
                }
            }
            
            return true
        }
        
        // Separate files and directories
        var files: [URL] = []
        var subdirectories: [URL] = []
        
        for item in includedItems {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: item.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    subdirectories.append(item)
                } else {
                    files.append(item)
                }
            }
        }
        
        // Filter media files
        for file in files {
            let fileExtension = file.pathExtension.lowercased()
            
            // Skip sample files
            let fileName = file.lastPathComponent.lowercased()
            if fileName.contains("sample") {
                // Check file size (samples are typically < 300MB)
                if let fileSize = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                   fileSize < 300 * 1024 * 1024 {
                    excludedItems.append(file)
                    continue
                }
            }
            
            // Skip trailer files
            if fileName.contains("trailer") {
                excludedItems.append(file)
                continue
            }
            
            // Check if it's a video file
            if FolderScanner.videoExtensions.contains(fileExtension) {
                mediaFiles.append(file)
            }
        }
        
        // Classify as movie or TV show
        let mediaType = classifyMediaType(
            folderURL: folderURL,
            files: mediaFiles,
            subdirectories: subdirectories
        )
        
        // Collect warnings
        if mediaFiles.isEmpty {
            warnings.append("No media files found in folder")
        }
        
        if mediaType == .tvShow && subdirectories.isEmpty {
            warnings.append("TV show detected but no season folders found")
        }
        
        return ScanResult(
            folderURL: folderURL,
            mediaType: mediaType,
            mediaFiles: mediaFiles,
            excludedItems: excludedItems,
            warnings: warnings
        )
    }
    
    /// Classifies the media type based on folder structure and file patterns
    private func classifyMediaType(
        folderURL: URL,
        files: [URL],
        subdirectories: [URL]
    ) -> MediaType {
        // Check for TV show indicators
        // 1. Season folders (Season 01, Season 1, Season 02, etc.)
        let hasSeasonFolders = subdirectories.contains { url in
            let name = url.lastPathComponent.lowercased()
            return name.hasPrefix("season") || name == "specials"
        }
        
        // 2. Episode patterns in filenames (s01e01, s1e1, etc.)
        let hasEpisodePatterns = files.contains { url in
            let fileName = url.lastPathComponent.lowercased()
            return fileName.range(of: #"s\d+e\d+"#, options: .regularExpression) != nil ||
                   fileName.range(of: #"season\s*\d+\s*episode\s*\d+"#, options: .regularExpression) != nil
        }
        
        // 3. Date-based patterns (YYYY-MM-DD)
        let hasDatePatterns = files.contains { url in
            let fileName = url.lastPathComponent
            return fileName.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression) != nil
        }
        
        if hasSeasonFolders || hasEpisodePatterns || hasDatePatterns {
            return .tvShow
        }
        
        // Default to movie if no TV indicators found
        return .movie
    }
}

enum ScanError: LocalizedError {
    case folderNotFound
    case notADirectory
    case scanFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .folderNotFound:
            return "Folder not found"
        case .notADirectory:
            return "Path is not a directory"
        case .scanFailed(let message):
            return "Scan failed: \(message)"
        }
    }
}
