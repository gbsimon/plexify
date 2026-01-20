import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @Binding var statusText: String

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
            .frame(height: 140)
            .overlay(
                Text(statusText)
                    .multilineTextAlignment(.center)
                    .padding(12)
            )
            .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
                guard let provider = providers.first else {
                    return false
                }
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url = url else { return }
                    DispatchQueue.main.async {
                        statusText = url.path
                    }
                }
                return true
            }
    }
}
