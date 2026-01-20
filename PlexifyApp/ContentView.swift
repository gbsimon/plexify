import SwiftUI

struct ContentView: View {
    @State private var statusText = "Drop a folder to begin."

    var body: some View {
        VStack(spacing: 16) {
            Text("Plexify")
                .font(.largeTitle)
            Text("Rename media folders for Plex")
                .foregroundColor(.secondary)
            DropZoneView(statusText: $statusText)
        }
        .padding(32)
        .frame(minWidth: 420, minHeight: 260)
    }
}

#Preview {
    ContentView()
}
