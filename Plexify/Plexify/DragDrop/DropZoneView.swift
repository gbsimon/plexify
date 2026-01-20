import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @Binding var statusText: String
    @Binding var errorMessage: String?
    var onFolderDropped: (URL) -> Void
    
    @State private var isTargeted = false
    @State private var showFilePicker = false

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
                        
                        if error.contains("Failed to load") || error.contains("Cannot load") {
                            Text("Tip: Use 'Grant Access' to select your media root first")
                                .font(.caption)
                                .foregroundColor(.plexTextTertiary)
                                .padding(.top, 4)
                        }
                    } else {
                        Text(statusText)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.plexTextSecondary)
                            .font(.subheadline)
                            .padding(.horizontal)
                    }
                    
                    // Browse button for file picker
                    Button(action: {
                        showFilePicker = true
                    }) {
                        Label("Browse...", systemImage: "folder")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .tint(.plexOrange)
                    .controlSize(.small)
                    .padding(.top, 8)
                }
                .padding(20)
            )
            .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        handleSelectedFolder(url: url)
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        errorMessage = "Failed to select folder: \(error.localizedDescription)"
                    }
                    print("❌ File picker error: \(error.localizedDescription)")
                }
            }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else {
            DispatchQueue.main.async {
                errorMessage = "No folder provided"
            }
            return false
        }
        
        guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else {
            DispatchQueue.main.async {
                errorMessage = "Cannot load folder. Please try dragging a folder from Finder."
            }
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            if let error = error {
                DispatchQueue.main.async {
                    errorMessage = "Error loading folder: \(error.localizedDescription)"
                }
                print("❌ DropZoneView Error: \(error.localizedDescription)")
                return
            }

            let url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                url = item as? URL
            }

            guard let url = url else {
                DispatchQueue.main.async {
                    errorMessage = "Failed to load folder URL"
                }
                print("❌ DropZoneView Error: URL is nil")
                return
            }
            
            print("📁 Dropped URL: \(url)")
            print("   Path: \(url.path)")
            print("   Is file URL: \(url.isFileURL)")
            
            // Verify it exists (file or directory)
            var isDirectory: ObjCBool = false
            let fileManager = FileManager.default
            let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
            
            print("   File exists: \(exists)")
            print("   Is directory: \(isDirectory.boolValue)")
            
            guard exists else {
                DispatchQueue.main.async {
                    errorMessage = "Item not found at path: \(url.path)"
                }
                return
            }

            let droppedType = isDirectory.boolValue ? "folder" : "file"
            print("✅ Valid \(droppedType) dropped: \(url.lastPathComponent)")

            DispatchQueue.main.async {
                errorMessage = nil
                statusText = "Scanning: \(url.lastPathComponent)..."
                onFolderDropped(url)
            }
        }
        
        return true
    }
    
    private func handleSelectedFolder(url: URL) {
        print("📁 Selected folder via file picker: \(url)")
        print("   Path: \(url.path)")
        print("   Is file URL: \(url.isFileURL)")
        verifyAndProceed(url: url)
    }
    
    private func verifyAndProceed(url: URL) {
        // Verify it's actually a directory
        var isDirectory: ObjCBool = false
        let fileManager = FileManager.default
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        
        print("   File exists: \(exists)")
        print("   Is directory: \(isDirectory.boolValue)")
        
        guard exists else {
            errorMessage = "Folder not found at path: \(url.path)"
            return
        }
        
        if isDirectory.boolValue {
            print("✅ Valid folder selected: \(url.lastPathComponent)")
        } else {
            print("✅ Valid file selected: \(url.lastPathComponent)")
        }
        
        DispatchQueue.main.async {
            errorMessage = nil
            statusText = "Scanning: \(url.lastPathComponent)..."
            onFolderDropped(url)
        }
    }

}
