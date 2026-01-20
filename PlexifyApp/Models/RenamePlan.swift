import Foundation

struct RenamePlan {
    let originalFolderURL: URL
    let targetFolderName: String
    let fileRenames: [FileRename]

    struct FileRename {
        let originalURL: URL
        let targetName: String
    }
}
