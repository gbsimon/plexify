import SwiftUI

struct ProcessingProgressView: View {
    @ObservedObject var viewModel: PlexifyViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            ProgressView(value: viewModel.progress)
                .progressViewStyle(.linear)
                .tint(.plexOrange)
                .scaleEffect(x: 1, y: 2, anchor: .center)
            
            VStack(spacing: 8) {
                Text("Processing...")
                    .font(.headline)
                    .foregroundColor(.plexTextPrimary)
                
                Text("\(Int(viewModel.progress * 100))%")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.plexOrange)
            }
        }
        .padding(32)
        .frame(maxWidth: 400)
        .background(Color.plexDarkSecondary)
        .cornerRadius(16)
    }
}

struct ResultView: View {
    @ObservedObject var viewModel: PlexifyViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: viewModel.currentState == .success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(viewModel.currentState == .success ? .plexOrange : .red)
                .symbolEffect(.bounce, value: viewModel.currentState)
            
            VStack(spacing: 12) {
                Text(viewModel.currentState == .success ? "Success!" : "Error")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.plexTextPrimary)
                
                if let message = viewModel.resultMessage {
                    Text(message)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.plexTextSecondary)
                        .font(.subheadline)
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.red)
                        .font(.subheadline)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            
            Button("Done") {
                viewModel.cancel()
            }
            .buttonStyle(.borderedProminent)
            .tint(.plexOrange)
            .controlSize(.large)
        }
        .padding(32)
        .frame(maxWidth: 450)
        .background(Color.plexDarkSecondary)
        .cornerRadius(16)
    }
}
