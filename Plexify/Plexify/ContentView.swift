import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PlexifyViewModel()
    @State private var statusText = "Drop a folder to begin."

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Plexify")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.plexTextPrimary)
                Text("Rename media folders for Plex")
                    .font(.subheadline)
                    .foregroundColor(.plexTextSecondary)
            }
            .padding(.top, 8)
            
            // Main content
            switch viewModel.currentState {
            case .idle:
                if !viewModel.hasLibraryAccess {
                    VStack(spacing: 12) {
                        Text("Grant access to your media root folder to continue.")
                            .foregroundColor(.plexTextSecondary)
                        if let message = viewModel.libraryAccessMessage {
                            Text(message)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        Button("Grant Access") {
                            viewModel.requestLibraryAccess()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.plexOrange)
                    }
                }
                DropZoneView(
                    statusText: $statusText,
                    errorMessage: $viewModel.errorMessage,
                    onFolderDropped: { url in
                        viewModel.handleFolderDrop(url)
                    }
                )
                
            case .scanning:
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.plexOrange)
                    Text("Scanning folder...")
                        .font(.headline)
                        .foregroundColor(.plexTextSecondary)
                }
                .frame(height: 140)
                .frame(maxWidth: .infinity)
                .background(Color.plexDarkSecondary)
                .cornerRadius(12)
                
            case .preview:
                if viewModel.renamePlan != nil {
                    ScrollView {
                        PreviewView(viewModel: viewModel)
                    }
                }
                
            case .processing:
                ProcessingProgressView(viewModel: viewModel)
                
            case .success, .error:
                ResultView(viewModel: viewModel)
            }
        }
        .padding(32)
        .frame(minWidth: 600, minHeight: 500)
        .background(Color.plexDark)
        .onAppear {
            viewModel.ensureLibraryAccess()
        }
        .onChange(of: viewModel.hasLibraryAccess) { hasAccess in
            statusText = hasAccess ? "Drop a folder to begin." : "Grant access to your media folder to continue."
        }
    }
}

#Preview {
    ContentView()
}
