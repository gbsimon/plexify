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
        let episodes: [Episode]?
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

        var episodes: [Episode]? = nil

        if mediaType == .tvShow {
            let episodeResult = scanEpisodes(in: folderURL)
            episodes = episodeResult.episodes
            mediaFiles = episodeResult.mediaFiles
            excludedItems.append(contentsOf: episodeResult.excluded)
            warnings.append(contentsOf: episodeResult.warnings)
        }

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
            warnings: warnings,
            episodes: episodes
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

    private func scanEpisodes(in folderURL: URL) -> (episodes: [Episode], mediaFiles: [URL], excluded: [URL], warnings: [String]) {
        let fileManager = FileManager.default
        var episodes: [Episode] = []
        var mediaFiles: [URL] = []
        var excludedItems: [URL] = []
        var warnings: [String] = []

        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return (episodes, mediaFiles, excludedItems, warnings)
        }

        var unparsedFiles = 0

        for case let itemURL as URL in enumerator {
            let name = itemURL.lastPathComponent.lowercased()

            if FolderScanner.excludedFolderNames.contains(name) {
                excludedItems.append(itemURL)
                enumerator.skipDescendants()
                continue
            }

            if FolderScanner.excludedFilePatterns.contains(where: { name.contains($0) }) {
                excludedItems.append(itemURL)
                if (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    enumerator.skipDescendants()
                }
                continue
            }

            let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            if resourceValues?.isDirectory == true {
                continue
            }

            let fileExtension = itemURL.pathExtension.lowercased()
            if !FolderScanner.videoExtensions.contains(fileExtension) {
                continue
            }

            mediaFiles.append(itemURL)

            let fileName = itemURL.deletingPathExtension().lastPathComponent
            if fileName.lowercased().contains("sample"),
               let fileSize = resourceValues?.fileSize,
               fileSize < 300 * 1024 * 1024 {
                excludedItems.append(itemURL)
                continue
            }

            if fileName.lowercased().contains("trailer") {
                excludedItems.append(itemURL)
                continue
            }

            let seasonFromPath = parseSeasonNumber(from: itemURL, root: folderURL)
            if let episodeInfo = parseSeasonEpisode(from: fileName) {
                let season = episodeInfo.season ?? seasonFromPath ?? 1
                let episode = episodeInfo.episode
                let episodeTitle = episodeInfo.title

                episodes.append(Episode(
                    season: season,
                    episode: episode,
                    title: episodeTitle,
                    originalURL: itemURL,
                    airDate: nil
                ))
                continue
            }

            if let airInfo = parseAirDate(from: fileName) {
                let season = seasonFromPath ?? 1
                episodes.append(Episode(
                    season: season,
                    episode: 0,
                    title: airInfo.title,
                    originalURL: itemURL,
                    airDate: airInfo.date
                ))
                continue
            }

            unparsedFiles += 1
        }

        if episodes.isEmpty {
            warnings.append("Episode information is required for TV shows")
        } else if unparsedFiles > 0 {
            warnings.append("Some episode files could not be parsed (\(unparsedFiles))")
        }

        return (episodes, mediaFiles, excludedItems, warnings)
    }

    private func parseSeasonNumber(from url: URL, root: URL) -> Int? {
        let relativeComponents = url.path.replacingOccurrences(of: root.path, with: "")
            .split(separator: "/")
            .map { String($0) }

        for component in relativeComponents {
            let lower = component.lowercased()
            if lower == "specials" {
                return 0
            }
            let pattern = #"season\s*(\d{1,2})"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: component, range: NSRange(component.startIndex..., in: component)),
               let range = Range(match.range(at: 1), in: component),
               let season = Int(component[range]) {
                return season
            }
        }

        return nil
    }

    private func parseSeasonEpisode(from fileName: String) -> (season: Int?, episode: Int, title: String?)? {
        let pattern = #"(?i)s(\d{1,2})e(\d{1,2})"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: fileName, range: NSRange(fileName.startIndex..., in: fileName)),
           let seasonRange = Range(match.range(at: 1), in: fileName),
           let episodeRange = Range(match.range(at: 2), in: fileName),
           let season = Int(fileName[seasonRange]),
           let episode = Int(fileName[episodeRange]) {
            let suffixStart = match.range.upperBound
            let startIndex = fileName.index(fileName.startIndex, offsetBy: suffixStart)
            let suffix = String(fileName[startIndex...])
            let title = sanitizeEpisodeTitle(suffix)
            return (season, episode, title)
        }

        // Fallback: numeric episode filenames like "01", "01 - Title", "01.Title"
        let numericPattern = #"^\s*(\d{1,3})(?:\D+(.*))?$"#
        if let regex = try? NSRegularExpression(pattern: numericPattern),
           let match = regex.firstMatch(in: fileName, range: NSRange(fileName.startIndex..., in: fileName)),
           let episodeRange = Range(match.range(at: 1), in: fileName),
           let episode = Int(fileName[episodeRange]) {
            let title: String?
            if let titleRange = Range(match.range(at: 2), in: fileName) {
                title = sanitizeEpisodeTitle(String(fileName[titleRange]))
            } else {
                title = nil
            }
            return (nil, episode, title)
        }

        return nil
    }

    private func parseAirDate(from fileName: String) -> (date: Date, title: String?)? {
        let pattern = #"(19\d{2}|20\d{2})[.\- ](\d{2})[.\- ](\d{2})"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: fileName, range: NSRange(fileName.startIndex..., in: fileName)),
           let yearRange = Range(match.range(at: 1), in: fileName),
           let monthRange = Range(match.range(at: 2), in: fileName),
           let dayRange = Range(match.range(at: 3), in: fileName),
           let year = Int(fileName[yearRange]),
           let month = Int(fileName[monthRange]),
           let day = Int(fileName[dayRange]) {
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            guard let date = Calendar.current.date(from: components) else {
                return nil
            }

            let suffixStart = match.range.upperBound
            let startIndex = fileName.index(fileName.startIndex, offsetBy: suffixStart)
            let suffix = String(fileName[startIndex...])
            let title = sanitizeEpisodeTitle(suffix)
            return (date, title)
        }

        return nil
    }

    private func sanitizeEpisodeTitle(_ raw: String) -> String? {
        var cleaned = raw
        cleaned = cleaned.replacingOccurrences(of: " - ", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "-", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "_", with: " ")
        cleaned = cleaned.replacingOccurrences(of: ".", with: " ")
        cleaned = cleaned.replacingOccurrences(of: #"\[[^\]]+\]"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\([^\)]+\)"#, with: "", options: .regularExpression)

        let removeTokens = [
            "1080p", "2160p", "720p", "4k", "uhd", "hdr", "dv",
            "webrip", "web-dl", "bluray", "remux", "x264", "x265",
            "h264", "h265", "hevc", "aac", "ddp", "atmos"
        ]
        for token in removeTokens {
            cleaned = cleaned.replacingOccurrences(
                of: "\\b\(NSRegularExpression.escapedPattern(for: token))\\b",
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        cleaned = cleaned.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? nil : cleaned
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
