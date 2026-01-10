import SwiftUI
import Combine

struct SettingsView: View {
    @StateObject private var permissionManager = PermissionManager.shared
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            WhitelistSettingsView(permissionManager: permissionManager)
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }
        }
        .padding()
        .frame(minWidth: 450, minHeight: 350)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("playSounds") private var playSounds = true
    @AppStorage("showNotifications") private var showNotifications = true
    @State private var apiKey: String = ""
    @State private var showSuccess: Bool = false
    
    var body: some View {
        Form {
            Section {
                Toggle("Play completion sound", isOn: $playSounds)
                Toggle("Show notifications", isOn: $showNotifications)
            }
            
            Section(header: Text("AI Configuration")) {
                SecureField("Ollama API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                
                HStack {
                    if showSuccess {
                        Text("Saved!")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    Button("Update Key") {
                        Task {
                            await OllamaService.shared.updateAPIKey(apiKey)
                            showSuccess = true
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            showSuccess = false
                        }
                    }
                    .disabled(apiKey.isEmpty)
                }
            }
        }
        .padding()
        .onAppear {
            if let savedKey = UserDefaults.standard.string(forKey: "OllamaAPIKey_UserOverride") {
                apiKey = savedKey
            }
        }
    }
}

struct WhitelistSettingsView: View {
    @ObservedObject var permissionManager: PermissionManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Full Disk Access")
                .font(.headline)
            
            HStack {
                Image(systemName: permissionManager.hasFullDiskAccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(permissionManager.hasFullDiskAccess ? .green : .red)
                
                Text(permissionManager.hasFullDiskAccess ? "Granted" : "Not Granted")
                
                Spacer()
                
                if !permissionManager.hasFullDiskAccess {
                    Button("Grant Access") {
                        Task {
                            _ = await permissionManager.requestAccess()
                        }
                    }
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            Text("Lustra needs access to your Home folder to identify junk files. We use Apple's secure Sandbox technology to ensure we only touch what is necessary.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
