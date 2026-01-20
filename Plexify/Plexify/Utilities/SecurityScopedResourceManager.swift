import Foundation

/// Manages security-scoped resource access for sandboxed file operations
class SecurityScopedResourceManager {
    private var accessedURLs: Set<URL> = []
    
    /// Start accessing a security-scoped resource
    /// Returns true if access was granted, false otherwise
    @discardableResult
    func startAccessing(url: URL) -> Bool {
        // Check if we're already accessing this URL
        if accessedURLs.contains(url) {
            return true
        }
        
        // Try to start accessing
        let success = url.startAccessingSecurityScopedResource()
        if success {
            accessedURLs.insert(url)
            print("🔐 Started accessing security-scoped resource: \(url.lastPathComponent)")
        } else {
            print("⚠️ Failed to access security-scoped resource: \(url.lastPathComponent)")
        }
        return success
    }
    
    /// Stop accessing a security-scoped resource
    func stopAccessing(url: URL) {
        if accessedURLs.contains(url) {
            url.stopAccessingSecurityScopedResource()
            accessedURLs.remove(url)
            print("🔒 Stopped accessing security-scoped resource: \(url.lastPathComponent)")
        }
    }
    
    /// Ensure we have access to a URL and all its parent directories (for network volumes)
    func ensureAccess(to url: URL) -> Bool {
        var currentURL = url
        
        // Start from the root and work down to ensure all parent directories are accessible
        var urlsToAccess: [URL] = []
        
        // Collect all parent URLs
        while currentURL.path != "/" {
            urlsToAccess.append(currentURL)
            currentURL = currentURL.deletingLastPathComponent()
        }
        
        // Access from root to target (reverse order)
        var allSucceeded = true
        for urlToAccess in urlsToAccess.reversed() {
            if !startAccessing(url: urlToAccess) {
                allSucceeded = false
            }
        }
        
        return allSucceeded
    }
    
    /// Stop accessing all resources
    func stopAccessingAll() {
        let urls = Array(accessedURLs)
        for url in urls {
            stopAccessing(url: url)
        }
    }
    
    deinit {
        stopAccessingAll()
    }
}
