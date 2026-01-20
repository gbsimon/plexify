import Foundation
import AppKit

/// Helper to request file access permissions for network volumes
class PermissionRequestHelper {
    /// Request permission to access a folder (especially useful for network volumes)
    /// Returns the granted URL if permission is given, nil otherwise
    static func requestFolderAccess(startingAt url: URL? = nil) -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Select Folder to Rename"
        panel.prompt = "Select"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        
        // If a URL is provided, set it as the starting directory
        if let url = url {
            panel.directoryURL = url
        }
        
        let response = panel.runModal()
        
        if response == .OK, let selectedURL = panel.url {
            // The file picker automatically grants security-scoped access
            return selectedURL
        }
        
        return nil
    }

    static func requestLibraryRootAccess() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Grant Plexify Access"
        panel.message = "Select your media root folder (e.g., /Volumes/Medias).\nPlexify will remember this location so you only grant access once."
        panel.prompt = "Grant Access"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false

        let response = panel.runModal()
        if response == .OK, let selectedURL = panel.url {
            return selectedURL
        }

        return nil
    }
}
