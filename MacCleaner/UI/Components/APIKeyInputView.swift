import SwiftUI

struct APIKeyInputView: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.1))
                    .frame(width: 70, height: 70)
                
                Image(systemName: "key.fill")
                    .font(.system(size: 30))
                    .foregroundColor(AppTheme.accent)
            }
            .padding(.top, 10)
            
            VStack(spacing: 8) {
                Text(NSLocalizedString("api_key_required_title", value: "API Configuration Required", comment: ""))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.primaryText)
                
                Text(NSLocalizedString("api_key_required_message", value: "To use Smart CheckAI features, please enter your Ollama API Key below.", comment: ""))
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            SecureField("sk-...", text: $viewModel.apiKeyInput)
                .textFieldStyle(.plain)
                .padding(10)
                .background(AppTheme.darkGray)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.darkerGray, lineWidth: 1)
                )
                .frame(width: 320)
                .foregroundColor(AppTheme.primaryText)
            
            HStack(spacing: 16) {
                Button(action: {
                    viewModel.showAPIKeySheet = false
                }) {
                    Text(NSLocalizedString("cancel_action", comment: ""))
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .foregroundColor(AppTheme.secondaryText)
                
                Button(action: {
                    Task {
                        await viewModel.saveAPIKey()
                    }
                }) {
                    Text(NSLocalizedString("save_action", value: "Save Key", comment: ""))
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(AppTheme.accent)
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.apiKeyInput.isEmpty)
                .opacity(viewModel.apiKeyInput.isEmpty ? 0.6 : 1)
            }
            .padding(.bottom, 10)
        }
        .padding(30)
        .frame(width: 420)
        .background(AppTheme.background)
    }
}
