import Foundation

struct FolderRenamer {
    func buildPlan(for media: MediaItem, fileURLs: [URL]) -> RenamePlan {
        let imdbSuffix = media.imdbID.map { "{imdb-\($0)}" } ?? ""
        let yearSuffix = media.year.map { " (\($0))" } ?? ""
        let baseName = "\(media.title)\(yearSuffix) \(imdbSuffix)"
        let sanitizedBase = PathSanitizer.sanitize(baseName)

        let fileRenames = fileURLs.map { url in
            RenamePlan.FileRename(
                originalURL: url,
                targetName: "\(sanitizedBase)\(url.pathExtension.isEmpty ? "" : ".\(url.pathExtension)")"
            )
        }

        return RenamePlan(
            originalFolderURL: media.originalFolderURL,
            targetFolderName: sanitizedBase,
            fileRenames: fileRenames
        )
    }

    func apply(plan: RenamePlan) throws {
        let fileManager = FileManager.default
        let parentURL = plan.originalFolderURL.deletingLastPathComponent()
        let targetFolderURL = parentURL.appendingPathComponent(plan.targetFolderName)

        try fileManager.moveItem(at: plan.originalFolderURL, to: targetFolderURL)

        for rename in plan.fileRenames {
            let targetURL = targetFolderURL.appendingPathComponent(rename.targetName)
            let originalInNewFolder = targetFolderURL.appendingPathComponent(rename.originalURL.lastPathComponent)
            try fileManager.moveItem(at: originalInNewFolder, to: targetURL)
        }
    }
}
