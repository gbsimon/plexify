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
    
    private let scanner = FolderScanner()
    private let renamer = FolderRenamer()
    private let lookupService = ImdbLookupService()
    
    enum AppState {
        case idle
        case scanning
        case preview
        case processing
        case success
        case error
    }
    
    func handleFolderDrop(_ url: URL) {
        Task {
            await scanFolder(url: url)
        }
    }
    
    private func scanFolder(url: URL) async {
        currentState = .scanning
        errorMessage = nil
        
        do {
            let result = try scanner.scan(folderURL: url)
            scanResult = result
            
            // Extract title from folder name (basic implementation)
            let folderName = url.lastPathComponent
            let title = extractTitle(from: folderName)
            let year = extractYear(from: folderName)
            
            // Create media item
            var mediaItem = MediaItem(
                originalFolderURL: url,
                title: title,
                year: year,
                imdbID: nil,
                mediaType: result.mediaType
            )
            
            // Try to lookup IMDb ID
            if let imdbID = try? await lookupService.resolveImdbID(for: mediaItem) {
                mediaItem = MediaItem(
                    originalFolderURL: url,
                    title: title,
                    year: year,
                    imdbID: imdbID,
                    mediaType: result.mediaType,
                    episodes: nil,
                    isManualImdbID: false
                )
            }
            
            // Build rename plan
            let plan = renamer.buildPlan(for: mediaItem, fileURLs: result.mediaFiles)
            renamePlan = plan
            
            currentState = .preview
        } catch {
            errorMessage = error.localizedDescription
            currentState = .error
        }
    }
    
    func applyRename() {
        guard let plan = renamePlan else { return }
        
        Task {
            currentState = .processing
            progress = 0.0
            
            do {
                progress = 0.5
                try renamer.apply(plan: plan)
                progress = 1.0
                
                resultMessage = "Successfully renamed \(plan.fileRenames.count) file(s)"
                currentState = .success
            } catch {
                errorMessage = "Failed to rename: \(error.localizedDescription)"
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
        // Remove year pattern (YYYY) and clean up
        let cleaned = folderName
            .replacingOccurrences(of: #"\(\d{4}\)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? folderName : cleaned
    }
    
    private func extractYear(from folderName: String) -> Int? {
        let pattern = #"\((\d{4})\)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: folderName, range: NSRange(folderName.startIndex..., in: folderName)),
           let yearRange = Range(match.range(at: 1), in: folderName) {
            return Int(folderName[yearRange])
        }
        return nil
    }
}
