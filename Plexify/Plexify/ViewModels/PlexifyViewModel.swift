import Foundation
import SwiftUI
import Combine

@MainActor
class PlexifyViewModel: ObservableObject {
    @Published var currentState: AppState = .idle
    @Published var errorMessage: String?
    @Published var scanResult: FolderScanner.ScanResult?
    @Published var renamePlan: RenamePlan?
    @Published var progress: Double = 0.0
    @Published var resultMessage: String?
    @Published var hasLibraryAccess: Bool = false
    @Published var libraryAccessMessage: String?
    
    private let scanner = FolderScanner()
    private let renamer = FolderRenamer()
    private let lookupService = ImdbLookupService()
    private let securityManager = SecurityScopedResourceManager()
    private var currentFolderURL: URL?
    private var parentFolderURL: URL?
    private var libraryRootURL: URL?
    
    enum AppState {
        case idle
        case scanning
        case preview
        case processing
        case success
        case error
    }

    func ensureLibraryAccess() {
        if let url = SecurityScopedBookmarkStore.shared.resolveBookmark() {
            libraryRootURL = url
            hasLibraryAccess = securityManager.startAccessing(url: url)
            if hasLibraryAccess {
                libraryAccessMessage = nil
                return
            }
        }

        requestLibraryAccess()
    }

    func requestLibraryAccess() {
        if let url = PermissionRequestHelper.requestLibraryRootAccess() {
            do {
                try SecurityScopedBookmarkStore.shared.saveBookmark(for: url)
                libraryRootURL = url
                hasLibraryAccess = securityManager.startAccessing(url: url)
                libraryAccessMessage = nil
            } catch {
                hasLibraryAccess = false
                libraryAccessMessage = "Failed to save access. Please try again."
            }
        } else {
            hasLibraryAccess = false
            libraryAccessMessage = "Access required to rename media. Use the Grant Access button."
        }
    }
    
    func handleFolderDrop(_ url: URL) {
        guard hasLibraryAccess else {
            errorMessage = "Please grant access to your media folder before dropping."
            return
        }

        Task {
            // Store folder and parent URLs
            currentFolderURL = url
            parentFolderURL = url.deletingLastPathComponent()
            
            // Ensure we have security-scoped access to both folder and parent
            let hasFolderAccess = securityManager.startAccessing(url: url)
            let hasParentAccess = securityManager.startAccessing(url: parentFolderURL!)
            
            if !hasFolderAccess {
                print("⚠️ Warning: Could not access folder security-scoped resource")
            }
            if !hasParentAccess {
                print("⚠️ Warning: Could not access parent directory security-scoped resource")
            }
            
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            guard exists else {
                errorMessage = "Dropped item not found."
                currentState = .error
                return
            }

            if isDirectory.boolValue {
                await scanFolder(url: url)
            } else {
                await scanSingleFile(url: url)
            }
        }
    }

    private func scanFolder(url: URL) async {
        currentState = .scanning
        errorMessage = nil
        
        print("🔍 Starting scan for: \(url.path)")
        
        do {
            let result = try scanner.scan(folderURL: url)
            scanResult = result
            print("✅ Scan completed: \(result.mediaFiles.count) media files found")
            print("   Media type: \(result.mediaType)")
            print("   Warnings: \(result.warnings.count)")
            
            // Extract title from folder name (basic implementation)
            let folderName = url.lastPathComponent
            let existingImdbID = extractImdbID(from: folderName)
            let title = extractTitle(from: folderName)
            var year = extractYear(from: folderName)
            
            print("📝 Extracted metadata:")
            print("   Title: \(title)")
            print("   Year: \(year ?? 0)")
            
            // Create media item
            var mediaItem = MediaItem(
                originalFolderURL: url,
                title: title,
                year: year,
                imdbID: existingImdbID,
                mediaType: result.mediaType,
                tmdbID: nil,
                episodes: result.episodes
            )

            // Try to lookup IMDb ID if not already present
            if existingImdbID == nil {
                print("🔍 Looking up IMDb ID via TMDb API...")
                do {
                    if let result = try await lookupService.resolveImdbResult(for: mediaItem) {
                        print("✅ Found IMDb ID: \(result.imdbID)")
                        if year == nil, let suggestedYear = result.year {
                            year = suggestedYear
                        }
                        var episodes = mediaItem.episodes
                        if mediaItem.mediaType == .tvShow,
                           let tmdbID = result.tmdbID,
                           let currentEpisodes = episodes {
                            episodes = await lookupService.enrichEpisodesForTVShow(
                                tmdbID: tmdbID,
                                episodes: currentEpisodes
                            )
                        }
                        mediaItem = MediaItem(
                            originalFolderURL: url,
                            title: title,
                            year: year,
                            imdbID: result.imdbID,
                            mediaType: mediaItem.mediaType,
                            tmdbID: result.tmdbID,
                            episodes: episodes,
                            isManualImdbID: false
                        )
                    } else {
                        print("⚠️ No IMDb ID found - user can manually enter one")
                    }
                } catch {
                    print("❌ IMDb lookup failed: \(error.localizedDescription)")
                    if let lookupError = error as? ImdbLookupError {
                        switch lookupError {
                        case .missingApiKey:
                            print("   ⚠️ TMDb API key is missing - check environment variable TMDB_API_KEY")
                        case .noResults:
                            print("   ⚠️ No results found for '\(title)' (\(year.map { String($0) } ?? "no year"))")
                        case .missingImdbID:
                            print("   ⚠️ TMDb result found but no IMDb ID available")
                        default:
                            print("   Error: \(lookupError.localizedDescription)")
                        }
                    }
                }
            } else {
                print("✅ Using existing IMDb ID from folder name: \(existingImdbID ?? "")")
                if year == nil {
                    let lookupItem = MediaItem(
                        originalFolderURL: url,
                        title: title,
                        year: nil,
                        imdbID: nil,
                        mediaType: result.mediaType
                    )
                    if let lookupResult = try? await lookupService.resolveImdbResult(for: lookupItem),
                       let suggestedYear = lookupResult.year {
                        year = suggestedYear
                        var episodes = mediaItem.episodes
                        if mediaItem.mediaType == .tvShow,
                           let tmdbID = lookupResult.tmdbID,
                           let currentEpisodes = episodes {
                            episodes = await lookupService.enrichEpisodesForTVShow(
                                tmdbID: tmdbID,
                                episodes: currentEpisodes
                            )
                        }
                        mediaItem = MediaItem(
                            originalFolderURL: url,
                            title: title,
                            year: year,
                            imdbID: existingImdbID,
                            mediaType: result.mediaType,
                            tmdbID: lookupResult.tmdbID,
                            episodes: episodes,
                            isManualImdbID: false
                        )
                        print("✅ Added missing year from TMDb: \(suggestedYear)")
                    }
                }

                if mediaItem.mediaType == .tvShow, mediaItem.tmdbID == nil, let imdbID = existingImdbID {
                    if let tmdbID = await lookupService.resolveTmdbID(from: imdbID, mediaType: .tvShow) {
                        print("✅ Resolved TMDb ID from IMDb: \(tmdbID)")
                        if let episodes = mediaItem.episodes {
                            let enriched = await lookupService.enrichEpisodesForTVShow(
                                tmdbID: tmdbID,
                                episodes: episodes
                            )
                            mediaItem = MediaItem(
                                originalFolderURL: url,
                                title: title,
                                year: year,
                                imdbID: imdbID,
                                mediaType: mediaItem.mediaType,
                                tmdbID: tmdbID,
                                episodes: enriched,
                                isManualImdbID: false
                            )
                        }
                    }
                }
            }
            
            // Build rename plan
            let plan = renamer.buildPlan(for: mediaItem, fileURLs: result.mediaFiles)
            renamePlan = plan
            
            currentState = .preview
        } catch {
            let errorDescription: String
            if let scanError = error as? ScanError {
                errorDescription = scanError.localizedDescription
            } else {
                errorDescription = "\(error.localizedDescription)\n\nError details: \(error)"
            }
            
            print("❌ Scan failed: \(errorDescription)")
            if let nsError = error as NSError? {
                print("   Domain: \(nsError.domain)")
                print("   Code: \(nsError.code)")
                print("   UserInfo: \(nsError.userInfo)")
            }
            
            errorMessage = errorDescription
            currentState = .error
        }
    }

    private func scanSingleFile(url: URL) async {
        currentState = .scanning
        errorMessage = nil

        print("🔍 Starting scan for file: \(url.path)")

        let fileName = url.deletingPathExtension().lastPathComponent
        let title = extractTitle(from: fileName)
        var year = extractYear(from: fileName)
        let mediaType: MediaType = .movie

        let scanResult = FolderScanner.ScanResult(
            folderURL: url,
            mediaType: mediaType,
            mediaFiles: [url],
            excludedItems: [],
            warnings: [],
            episodes: nil
        )

        self.scanResult = scanResult

        var mediaItem = MediaItem(
            originalFolderURL: url,
            title: title,
            year: year,
            imdbID: nil,
            mediaType: mediaType
        )

        print("📝 Extracted metadata:")
        print("   Title: \(title)")
        print("   Year: \(year ?? 0)")

        print("🔍 Looking up IMDb ID via TMDb API...")
        if let result = try? await lookupService.resolveImdbResult(for: mediaItem) {
            print("✅ Found IMDb ID: \(result.imdbID)")
            if year == nil, let suggestedYear = result.year {
                year = suggestedYear
            }
            mediaItem = MediaItem(
                originalFolderURL: url,
                title: title,
                year: year,
                imdbID: result.imdbID,
                mediaType: mediaType,
                tmdbID: result.tmdbID
            )
        } else {
            print("⚠️ No IMDb ID found - user can manually enter one")
        }

        let plan = renamer.buildPlan(for: mediaItem, fileURLs: [url])
        renamePlan = plan
        currentState = .preview
    }
    
    func applyRename() {
        guard let plan = renamePlan else { return }
        
        Task {
            currentState = .processing
            progress = 0.0
            
            // Ensure we still have security-scoped access before renaming
            // We need access to both the folder and its parent directory
            if let folderURL = currentFolderURL {
                let hasFolderAccess = securityManager.startAccessing(url: folderURL)
                print("🔐 Folder access: \(hasFolderAccess ? "granted" : "denied")")
            }
            
            if let parentURL = parentFolderURL {
                let hasParentAccess = securityManager.startAccessing(url: parentURL)
                print("🔐 Parent directory access: \(hasParentAccess ? "granted" : "denied")")
                
                if !hasParentAccess {
                    // For network volumes, we might need to request parent directory access
                    print("⚠️ Warning: Parent directory access denied - this may cause rename to fail")
                }
            }
            
            do {
                progress = 0.5
                try renamer.apply(plan: plan)
                progress = 1.0
                
                resultMessage = "Successfully renamed \(plan.fileRenames.count) file(s)"
                currentState = .success
            } catch {
                let nsError = error as NSError
                var errorMsg = "Failed to rename: \(error.localizedDescription)"
                
                // Check for permission errors
                if nsError.domain == NSCocoaErrorDomain {
                    switch nsError.code {
                    case 513: // NSFileWriteFileExistsError or permission error
                        errorMsg = "Permission denied. Please ensure the app has access to the folder.\n\nTry using the 'Browse' button instead of drag-and-drop for network volumes."
                    case 260: // NSFileReadNoSuchFileError
                        errorMsg = "File not found. The folder may have been moved or deleted."
                    default:
                        break
                    }
                }
                
                print("❌ Rename failed: \(error)")
                print("   Error domain: \(nsError.domain)")
                print("   Error code: \(nsError.code)")
                print("   User info: \(nsError.userInfo)")
                
                errorMessage = errorMsg
                currentState = .error
            }
        }
    }
    
    func cancel() {
        currentState = .idle
        scanResult = nil
        renamePlan = nil
        errorMessage = nil
        resultMessage = nil
        progress = 0.0
        
        // Clean up security-scoped resources
        if let folderURL = currentFolderURL {
            securityManager.stopAccessing(url: folderURL)
        }
        if let parentURL = parentFolderURL {
            securityManager.stopAccessing(url: parentURL)
        }
        currentFolderURL = nil
        parentFolderURL = nil
    }
    
    func setManualImdbID(_ imdbID: String) {
        guard let scanResult = scanResult,
              renamePlan != nil else { return }
        
        // Create new media item with manual IMDb ID
        let folderURL = scanResult.folderURL
        let newMediaItem = MediaItem(
            originalFolderURL: folderURL,
            title: extractTitle(from: folderURL.lastPathComponent),
            year: extractYear(from: folderURL.lastPathComponent),
            imdbID: imdbID,
            mediaType: scanResult.mediaType,
            episodes: nil,
            isManualImdbID: true
        )
        
        // Rebuild plan with new IMDb ID
        let newPlan = renamer.buildPlan(for: newMediaItem, fileURLs: scanResult.mediaFiles)
        renamePlan = newPlan
    }
    
    // MARK: - Helper Methods
    
    private func extractTitle(from folderName: String) -> String {
        // Strategy: Find where technical metadata starts and extract everything before it
        // Technical metadata indicators (in order of priority - earliest wins):
        let technicalIndicators = [
            #"\.\d{4}\."#,              // .2025. (year with dots)
            #"\.\d{4}p"#,               // .2160p (resolution)
            #"\.\d{4}\s"#,              // .2025 (year followed by space)
            #"\d{4}p"#,                 // 2160p (resolution at word boundary)
            #"\b(2160p|1080p|720p|480p)\b"#,
            #"\bWEB[- ]?DL\b"#,
            #"\bWEBRIP\b"#,
            #"\bBLURAY\b"#,
            #"\bREMUX\b"#,
            #"\bHDR\b"#,
            #"\bHEVC\b"#,
            #"\bX265\b"#,
            #"\bX264\b"#,
            #"\bH265\b"#,
            #"\bH264\b"#,
            #"\bTRUEHD\b"#,
            #"\bDTS\b"#,
            #"\.UHD\."#,
            #"\.BluRay"#,
            #"\.REMUX"#,
            #"\.Remux"#,
            #"\.DV\."#,
            #"\.HDR"#,
            #"\.P7"#,
            #"\.TrueHD"#,
            #"\.Atmos"#,
            #"\.HEVC"#,
            #"\.H265"#,
            #"\.H264"#,
            #"\.x264"#,
            #"\.x265"#,
            #"\.7\.1"#,                 // Audio channels
            #"\.5\.1"#,
            #"\.ENG\."#,                // Language codes
            #"\.LATINO"#,
            #"\.FRENCH"#,
            #"\.ITALIAN"#,
            #"\.GERMAN"#,
            #"\.RUSSIAN"#,
            #"\.UKRAINIAN"#,
            #"\.MULTi"#,
            #"\["#,                      // Release group bracket start
            #"-\w"#,                     // Release group dash (like -BEN or -FraMeSToR)
        ]
        
        var title = folderName
        var earliestStop: String.Index?
        
        // Find the earliest technical indicator
        for pattern in technicalIndicators {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
               let range = Range(match.range, in: title) {
                if earliestStop == nil || range.lowerBound < earliestStop! {
                    earliestStop = range.lowerBound
                }
            }
        }
        
        // Truncate at the earliest technical indicator
        if let stopIndex = earliestStop {
            title = String(title[..<stopIndex])
        }
        
        // Remove embedded tags or any dangling brace fragments
        if let braceIndex = title.firstIndex(of: "{") {
            title = String(title[..<braceIndex])
        }
        title = title.replacingOccurrences(of: #"\{imdb-[^}]+\}"#, with: "", options: .regularExpression)
        title = title.replacingOccurrences(of: #"\{tmdb-[^}]+\}"#, with: "", options: .regularExpression)
        title = title.replacingOccurrences(of: #"\{tvdb-[^}]+\}"#, with: "", options: .regularExpression)
        title = title.replacingOccurrences(of: #"\{edition-[^}]+\}"#, with: "", options: .regularExpression)

        // Remove year tokens if still present (handle .2025 or (2025) formats)
        title = title.replacingOccurrences(of: #"\.(\d{4})$"#, with: "", options: .regularExpression)
        title = title.replacingOccurrences(of: #"\((\d{4})\)"#, with: "", options: .regularExpression)
        title = title.replacingOccurrences(of: #"\s(19\d{2}|20\d{2})$"#, with: "", options: .regularExpression)
        
        // Clean up trailing dots/spaces
        title = title.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        
        // Replace dots with spaces for readability (common in release names)
        if title.contains(".") {
            title = title.replacingOccurrences(of: ".", with: " ")
        }
        
        // Clean up multiple spaces
        title = title.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        title = title.trimmingCharacters(in: .whitespaces)
        
        // Validate: should have reasonable length and be shorter than original
        if title.count > 2 && title.count < folderName.count {
            return title
        }
        
        // Fallback: return original if extraction seems wrong
        return folderName
    }
    
    private func extractYear(from folderName: String) -> Int? {
        // Try (2025) format first
        let parenPattern = #"\((\d{4})\)"#
        if let regex = try? NSRegularExpression(pattern: parenPattern),
           let match = regex.firstMatch(in: folderName, range: NSRange(folderName.startIndex..., in: folderName)),
           let yearRange = Range(match.range(at: 1), in: folderName),
           let year = Int(folderName[yearRange]),
           year >= 1900 && year <= 2100 {
            return year
        }
        
        // Try .2025. format (common in release names)
        let dotPattern = #"\.(\d{4})\."#
        if let regex = try? NSRegularExpression(pattern: dotPattern),
           let match = regex.firstMatch(in: folderName, range: NSRange(folderName.startIndex..., in: folderName)),
           let yearRange = Range(match.range(at: 1), in: folderName),
           let year = Int(folderName[yearRange]),
           year >= 1900 && year <= 2100 {
            return year
        }
        
        // Try 2025 format (standalone, not in parentheses or dots)
        // But only if it's early in the filename (likely to be year)
        let standalonePattern = #"\b(19\d{2}|20\d{2})\b"#
        if let regex = try? NSRegularExpression(pattern: standalonePattern),
           let match = regex.firstMatch(in: folderName, range: NSRange(folderName.startIndex..., in: folderName)),
           let yearRange = Range(match.range, in: folderName),
           let year = Int(folderName[yearRange]),
           year >= 1900 && year <= 2100 {
            // Only use if it appears in first 50 characters (likely to be release year)
            if yearRange.lowerBound.utf16Offset(in: folderName) < 50 {
                return year
            }
        }
        
        return nil
    }

    private func extractImdbID(from folderName: String) -> String? {
        let pattern = #"\{imdb-(tt\d+)\}"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: folderName, range: NSRange(folderName.startIndex..., in: folderName)),
           let idRange = Range(match.range(at: 1), in: folderName) {
            return String(folderName[idRange])
        }
        return nil
    }
}
