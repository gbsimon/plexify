import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""
    @State private var lastSavedKey: String = ""
    @State private var statusMessage: String?

    private let service = "Plexify.TMDB"
    private let account = "apiKey"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.title2)
                .bold()

            VStack(alignment: .leading, spacing: 8) {
                Text("TMDb API Key")
                    .font(.headline)
                SecureField("Enter TMDb API key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                Text("Stored securely in your Keychain.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let message = statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.plexOrange)
            }

            HStack {
                Button("Save") {
                    persistKey()
                }
                .buttonStyle(.borderedProminent)
                .tint(.plexOrange)

                Button("Clear") {
                    let success = KeychainStore.shared.delete(service: service, account: account)
                    if success {
                        apiKey = ""
                        statusMessage = "Cleared."
                    } else {
                        statusMessage = "Failed to clear."
                    }
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Close") {
                    dismiss()
                }
            }
        }
        .padding(24)
        .frame(minWidth: 420)
        .onAppear {
            apiKey = KeychainStore.shared.readString(service: service, account: account) ?? ""
            lastSavedKey = apiKey
        }
        .onDisappear {
            if apiKey != lastSavedKey {
                persistKey()
            }
        }
    }

    private func persistKey() {
        let success = KeychainStore.shared.saveString(apiKey, service: service, account: account)
        if success {
            let savedValue = KeychainStore.shared.readString(service: service, account: account) ?? ""
            apiKey = savedValue
            lastSavedKey = savedValue
            statusMessage = savedValue.isEmpty ? "Cleared." : "Saved."
        } else {
            statusMessage = "Failed to save."
        }
    }
}

#Preview {
    SettingsView()
}
