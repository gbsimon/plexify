import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @Binding var statusText: String
    @Binding var errorMessage: String?
    var onFolderDropped: (URL) -> Void
    
    @State private var isTargeted = false

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.plexDarkSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isTargeted ? Color.plexOrange : (errorMessage != nil ? Color.red : Color.plexDarkTertiary),
                        style: StrokeStyle(lineWidth: isTargeted ? 3 : 2, dash: [8, 4])
                    )
            )
            .frame(height: 180)
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: isTargeted ? "folder.badge.plus" : "folder.fill")
                        .font(.system(size: 48))
                        .foregroundColor(isTargeted ? .plexOrange : .plexTextTertiary)
                        .symbolEffect(.bounce, value: isTargeted)
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    } else {
                        Text(statusText)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.plexTextSecondary)
                            .font(.subheadline)
                            .padding(.horizontal)
                    }
                }
                .padding(20)
            )
            .onDrop(of: [.directory], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else {
            return false
        }
        
        _ = provider.loadObject(ofClass: URL.self) { url, error in
            guard let url = url else {
                DispatchQueue.main.async {
                    errorMessage = "Failed to load folder"
                }
                return
            }
            
            // Verify it's actually a directory
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                DispatchQueue.main.async {
                    errorMessage = "Please drop a folder, not a file"
                }
                return
            }
            
            DispatchQueue.main.async {
                errorMessage = nil
                statusText = "Scanning: \(url.lastPathComponent)..."
                onFolderDropped(url)
            }
        }
        
        return true
    }
}
