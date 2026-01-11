import SwiftUI

struct MenubarView: View {
    @StateObject private var monitor = SystemMonitor.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var isCleaning = false
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text(NSLocalizedString("app_name", comment: ""))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                    Text("v1.3.0")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 4)
                
                Divider().background(Color.white.opacity(0.1))
                
                // Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatBox(
                        icon: "cpu",
                        title: NSLocalizedString("cpu_load", comment: ""),
                        value: String(format: "%.1f%%", monitor.cpuUsage),
                        color: monitor.cpuUsage > 80 ? .red : .blue
                    )
                    
                    StatBox(
                        icon: "memorychip",
                        title: NSLocalizedString("ram_usage", comment: ""),
                        value: monitor.usedRAM,
                        subtitle: String(format: NSLocalizedString("of_total_ram", comment: ""), monitor.totalRAM),
                        color: monitor.ramUsage > 85 ? .orange : .green
                    )
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                // Actions
                Button(action: {
                    Task {
                        isCleaning = true
                        try? await MemoryCleaner.shared.cleanMemory()
                        isCleaning = false
                        monitor.startMonitoring()
                    }
                }) {
                    HStack {
                        if isCleaning {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white)
                        } else {
                            Image(systemName: "bolt.fill")
                        }
                        Text(isCleaning ? NSLocalizedString("optimizing", comment: "") : NSLocalizedString("clean_ram", comment: ""))
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.accent, AppTheme.accent.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .shadow(color: AppTheme.accent.opacity(0.3), radius: 5, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(isCleaning)
                
                Button(NSLocalizedString("quit_app", comment: "")) {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)
                .foregroundColor(.white.opacity(0.8))
            }
            .padding()
        }
        .frame(width: 280)
    }
}

// Helper View for Stats
// Helper View for Stats
struct StatBox: View {
    let icon: String
    let title: String
    let value: String
    var subtitle: String? = nil
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}


