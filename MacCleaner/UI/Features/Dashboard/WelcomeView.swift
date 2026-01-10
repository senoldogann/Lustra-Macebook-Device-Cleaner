import SwiftUI
import Combine

struct WelcomeView: View {
    @ObservedObject var viewModel: MainViewModel
    @ObservedObject private var permissionManager = PermissionManager.shared
    
    // Animation states
    @State private var progressGlow = false
    @State private var shimmerOffset: CGFloat = -200
    @State private var currentTipIndex = 0
    
    // Scanning tips that rotate (icon, text)
    private let scanningTips: [(icon: String, text: String)] = [
        ("magnifyingglass", "Analyzing every folder and file..."),
        ("internaldrive", "Scan speed varies based on disk size"),
        ("chart.bar.doc.horizontal", "Deep scanning for accurate results"),
        ("trash", "Finding junk files and caches..."),
        ("bolt.fill", "Larger disks may take longer")
    ]
    
    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 40) {
            // Header
            Text("Lustra")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.secondaryText)
                .padding(.top, 20)
            
            Spacer()
            
            // Main Card
            VStack(spacing: 0) {
                // Top section - Disk info
                HStack(alignment: .top) {
                    // Disk Icon
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.accent)
                        .frame(width: 64, height: 64)
                        .background(AppTheme.background)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Macintosh HD")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AppTheme.primaryText)
                        
                        Text(getDiskSpaceString())
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    
                    Spacer()
                    
                    // Button or Progress
                    if viewModel.appState == .scanning {
                        VStack(alignment: .trailing, spacing: 6) {
                            // Progress bar
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppTheme.cardBackground)
                                    .frame(width: 160, height: 8)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.terracotta, AppTheme.terracotta.opacity(0.7)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(8, 160 * viewModel.scanProgress), height: 8)
                                    .shadow(color: AppTheme.terracotta.opacity(progressGlow ? 0.8 : 0.4), radius: progressGlow ? 8 : 4)
                                
                                // Shimmer
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [.clear, .white.opacity(0.3), .clear],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 50, height: 8)
                                    .offset(x: shimmerOffset)
                                    .mask(
                                        RoundedRectangle(cornerRadius: 4)
                                            .frame(width: max(8, 160 * viewModel.scanProgress), height: 8)
                                    )
                            }
                            .frame(width: 160, height: 8)
                            .onAppear {
                                withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                    progressGlow = true
                                }
                                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                    shimmerOffset = 160
                                }
                            }
                            
                            HStack(spacing: 6) {
                                Text("\(Int(viewModel.scanProgress * 100))%")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(AppTheme.terracotta)
                                
                                if let scanningCat = viewModel.currentlyScanningCategory {
                                    Text("•")
                                        .foregroundColor(AppTheme.secondaryText.opacity(0.5))
                                    
                                    Text(scanningCat)
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.secondaryText)
                                        .lineLimit(1)
                                }
                            }
                            .animation(.easeInOut(duration: 0.3), value: viewModel.currentlyScanningCategory)
                        }
                        .frame(height: 44)
                    } else {
                        if permissionManager.hasFullDiskAccess {
                            AnimatedScanButton {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    viewModel.startFullScan()
                                }
                            }
                        } else {
                            Button(action: {
                                Task {
                                    _ = await PermissionManager.shared.requestAccess()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "lock.open.fill")
                                        .font(.system(size: 14))
                                    Text("Grant Access")
                                }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 160, height: 42)
                                .background(
                                    LinearGradient(
                                        colors: [AppTheme.terracotta, AppTheme.terracotta.opacity(0.85)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .cornerRadius(10)
                                .shadow(color: AppTheme.terracotta.opacity(0.4), radius: 8, x: 0, y: 4)
                            }
                            .buttonStyle(.plain)
                            .help("Grant access to Home folder to scan personal files.")
                        }
                    }
                }
                .padding(28)
                
                // Bottom section - Animated tips (only during scanning)
                if viewModel.appState == .scanning {
                    Divider()
                        .background(AppTheme.secondaryText.opacity(0.1))
                    
                    HStack(spacing: 10) {
                        Image(systemName: scanningTips[currentTipIndex].icon)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.accent)
                            .frame(width: 20)
                        
                        Text(scanningTips[currentTipIndex].text)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.secondaryText)
                            .animation(.easeInOut(duration: 0.5), value: currentTipIndex)
                            .id(currentTipIndex)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .onReceive(timer) { _ in
                        withAnimation(.easeInOut(duration: 0.5)) {
                            currentTipIndex = (currentTipIndex + 1) % scanningTips.count
                        }
                    }
                }
            }
            .frame(width: 540)
            .background(
                ZStack {
                    AppTheme.cardBackground
                    
                    LinearGradient(
                        colors: [AppTheme.accent.opacity(0.03), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.4), radius: 30, x: 0, y: 15)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [AppTheme.secondaryText.opacity(0.15), AppTheme.secondaryText.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.appState)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }
    
    private func getDiskSpaceString() -> String {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let total = attrs[.systemSize] as? Int64,
              let free = attrs[.systemFreeSize] as? Int64 else {
            return "Unknown storage"
        }
        
        let totalStr = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
        let freeStr = ByteCountFormatter.string(fromByteCount: free, countStyle: .file)
        
        return "\(freeStr) available of \(totalStr)"
    }
}

// MARK: - Animated Scan Button
struct AnimatedScanButton: View {
    let action: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var pulseAnimation = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Pulse ring
                Circle()
                    .stroke(AppTheme.terracotta.opacity(pulseAnimation ? 0 : 0.5), lineWidth: 2)
                    .frame(width: pulseAnimation ? 120 : 100, height: pulseAnimation ? 120 : 100)
                    .scaleEffect(isHovered ? 1.1 : 1.0)
                
                // Main button
                Text("Scan")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 110, height: 44)
                    .background(
                        ZStack {
                            LinearGradient(
                                colors: [AppTheme.terracotta, AppTheme.terracotta.opacity(0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            
                            if isHovered {
                                LinearGradient(
                                    colors: [.white.opacity(0.2), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            }
                        }
                    )
                    .cornerRadius(10)
                    .shadow(color: AppTheme.terracotta.opacity(isHovered ? 0.6 : 0.4), radius: isHovered ? 12 : 8, x: 0, y: isHovered ? 6 : 4)
                    .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.02 : 1.0))
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
                }
        )
        .onAppear {
            withAnimation(Animation.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                pulseAnimation = true
            }
        }
    }
}

#Preview {
    WelcomeView(viewModel: MainViewModel())
}
