import Foundation

final class SecurityScopedBookmarkStore {
    static let shared = SecurityScopedBookmarkStore()

    private let bookmarkKey = "plexify.libraryRootBookmark"

    private init() {}

    func saveBookmark(for url: URL) throws {
        let data = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: bookmarkKey)
    }

    func resolveBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return nil
        }

        var isStale = false
        let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        if isStale, let resolvedURL = url {
            do {
                try saveBookmark(for: resolvedURL)
            } catch {
                print("⚠️ Failed to refresh stale bookmark: \(error.localizedDescription)")
            }
        }

        return url
    }

    func clearBookmark() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
    }
}
