import SwiftUI

struct PreviewView: View {
    @ObservedObject var viewModel: PlexifyViewModel
    @State private var manualImdbID: String = ""
    @State private var showManualInput = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Rename Preview")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.plexTextPrimary)
            
            if let plan = viewModel.renamePlan {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Folder rename
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Folder")
                                .font(.headline)
                                .foregroundColor(.plexTextSecondary)
                            HStack(spacing: 12) {
                                Text(plan.originalFolderURL.lastPathComponent)
                                    .foregroundColor(.plexTextTertiary)
                                    .lineLimit(1)
                                Image(systemName: "arrow.right")
                                    .foregroundColor(.plexOrange)
                                    .font(.caption)
                                Text(plan.targetFolderName)
                                    .foregroundColor(.plexTextPrimary)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                            }
                        }
                        .padding(16)
                        .background(Color.plexDarkSecondary)
                        .cornerRadius(12)
                        
                        // Warnings
                        if !plan.warnings.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.plexOrange)
                                    Text("Warnings")
                                        .font(.headline)
                                        .foregroundColor(.plexOrange)
                                }
                                ForEach(plan.warnings, id: \.self) { warning in
                                    Text("• \(warning)")
                                        .font(.subheadline)
                                        .foregroundColor(.plexTextSecondary)
                                }
                            }
                            .padding(16)
                            .background(Color.plexOrange.opacity(0.15))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.plexOrange.opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        // Manual IMDb ID input
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("IMDb ID")
                                    .font(.headline)
                                    .foregroundColor(.plexTextSecondary)
                                Spacer()
                                Button(showManualInput ? "Cancel" : "Edit") {
                                    showManualInput.toggle()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .tint(.plexOrange)
                            }
                            
                            if showManualInput {
                                HStack(spacing: 8) {
                                    TextField("tt1234567", text: $manualImdbID)
                                        .textFieldStyle(.plain)
                                        .padding(10)
                                        .background(Color.plexDarkTertiary)
                                        .foregroundColor(.plexTextPrimary)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .strokeBorder(Color.plexOrange.opacity(0.5), lineWidth: 1)
                                        )
                                    Button("Apply") {
                                        if !manualImdbID.isEmpty {
                                            viewModel.setManualImdbID(manualImdbID)
                                            showManualInput = false
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    .tint(.plexOrange)
                                }
                            } else {
                                Text(plan.targetFolderName.contains("{imdb-") ? 
                                     extractImdbID(from: plan.targetFolderName) ?? "Not set" : 
                                     "Not set")
                                    .foregroundColor(plan.targetFolderName.contains("{imdb-") ? .plexOrange : .plexTextTertiary)
                                    .font(.subheadline)
                            }
                        }
                        .padding(16)
                        .background(Color.plexDarkSecondary)
                        .cornerRadius(12)
                        
                        // File renames
                        if !plan.fileRenames.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Files (\(plan.fileRenames.count))")
                                    .font(.headline)
                                    .foregroundColor(.plexTextSecondary)
                                
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(Array(plan.fileRenames.enumerated()), id: \.offset) { index, rename in
                                            HStack(spacing: 12) {
                                                Text(rename.originalURL.lastPathComponent)
                                                    .foregroundColor(.plexTextTertiary)
                                                    .lineLimit(1)
                                                    .font(.system(.caption, design: .monospaced))
                                                Image(systemName: "arrow.right")
                                                    .foregroundColor(.plexOrange.opacity(0.6))
                                                    .font(.caption2)
                                                Text(rename.targetName)
                                                    .foregroundColor(.plexTextPrimary)
                                                    .fontWeight(.medium)
                                                    .lineLimit(1)
                                                    .font(.system(.caption, design: .monospaced))
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    }
                                }
                                .frame(maxHeight: 200)
                            }
                            .padding(16)
                            .background(Color.plexDarkSecondary)
                            .cornerRadius(12)
                        }
                        
                        // Action buttons
                        HStack {
                            Button("Cancel") {
                                viewModel.cancel()
                            }
                            .buttonStyle(.bordered)
                            .tint(.plexTextSecondary)
                            
                            Spacer()
                            
                            Button("Apply Rename") {
                                viewModel.applyRename()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.plexOrange)
                            .controlSize(.large)
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
        .padding(24)
    }
    
    private func extractImdbID(from text: String) -> String? {
        let pattern = #"\{imdb-(tt\d+)\}"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let idRange = Range(match.range(at: 1), in: text) {
            return String(text[idRange])
        }
        return nil
    }
}
