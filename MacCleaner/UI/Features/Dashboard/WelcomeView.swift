import SwiftUI
import Combine

struct WelcomeView: View {
    @ObservedObject var viewModel: MainViewModel
    @ObservedObject private var permissionManager = PermissionManager.shared
    
    @State private var meshAnimate = false
    @State private var currentTipIndex = 0
    @State private var isHoveringScan = false
    private let timer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()
    
    private let scanningTips: [(icon: String, text: LocalizedStringKey)] = [
        ("magnifyingglass", "tip_analyzing"),
        ("internaldrive", "tip_speed"),
        ("chart.bar.doc.horizontal", "tip_deep"),
        ("trash", "tip_junk"),
        ("bolt.fill", "tip_large")
    ]
    
    var body: some View {
        ZStack {
            // 1. Background Layer
            AppTheme.background.ignoresSafeArea()
            
            // Animated Mesh Gradient for depth
            AnimatedMeshBackground()
                .opacity(0.4)
                .ignoresSafeArea()
            
            // 2. Main Content
            HStack(spacing: 0) {
                // Left Panel: Controls & Info
                VStack(alignment: .leading, spacing: 0) {
                    // Logo Header
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.terracotta)
                            .shadow(color: AppTheme.terracotta.opacity(0.5), radius: 10)
                        
                        Text("Lustra")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppTheme.primaryText)
                    }
                    .padding(.top, 40)
                    .padding(.leading, 180)
                    
                    Spacer()
                    
                    // Center Info Area
                    VStack(alignment: .leading, spacing: 32) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("professional_mac_care")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.terracotta)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(AppTheme.terracotta.opacity(0.1))
                                .cornerRadius(20)
                            
                            Text("hero_title")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(AppTheme.primaryText)
                                .lineSpacing(-2)
                            
                            Text("hero_subtitle")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.secondaryText)
                                .frame(maxWidth: 400)
                        }
                        
                        // Disk Status Card
                        HStack(spacing: 20) {
                            StorageMiniChart()
                                .frame(width: 50, height: 50)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Macintosh HD")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppTheme.primaryText)
                                
                                Text(getDiskSpaceString())
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.secondaryText)
                            }
                        }
                        .padding(20)
                        .background(AppTheme.cardBackground.opacity(0.5))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                        
                        // Action Button
                        if viewModel.appState == .scanning {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("scanning_system")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(AppTheme.terracotta)
                                    
                                    Spacer()
                                    
                                    Text("\(Int(viewModel.scanProgress * 100))%")
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundColor(AppTheme.terracotta)
                                }
                                .frame(width: 320)
                                
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(AppTheme.cardBackground)
                                        .frame(width: 320, height: 6)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(AppTheme.terracotta)
                                        .frame(width: 320 * viewModel.scanProgress, height: 6)
                                        .shadow(color: AppTheme.terracotta.opacity(0.5), radius: 10)
                                }
                                
                                if let scanningCat = viewModel.currentlyScanningCategory {
                                    Text(viewModel.scanProgress > 0 ? String(format: NSLocalizedString("analyzing_category", comment: ""), scanningCat) : "")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.secondaryText)
                                        .transition(.opacity)
                                }
                            }
                        } else {
                            if permissionManager.hasFullDiskAccess {
                                Button(action: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        viewModel.startFullScan()
                                    }
                                }) {
                                    Text("start_full_scan")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 200, height: 50)
                                        .background(
                                            ZStack {
                                                AppTheme.terracotta
                                                if isHoveringScan {
                                                    Color.white.opacity(0.1)
                                                }
                                            }
                                        )
                                        .cornerRadius(25)
                                        .shadow(color: AppTheme.terracotta.opacity(isHoveringScan ? 0.5 : 0.3), radius: isHoveringScan ? 20 : 15, x: 0, y: isHoveringScan ? 12 : 10)
                                        .scaleEffect(isHoveringScan ? 1.05 : 1.0)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .onHover { hovering in
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        isHoveringScan = hovering
                                    }
                                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                }
                            } else {
                                Button(action: {
                                    Task {
                                        _ = await PermissionManager.shared.requestAccess()
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "key.fill")
                                        Text("grant_full_disk_access")
                                    }
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 240, height: 50)
                                    .background(AppTheme.darkGray)
                                    .cornerRadius(25)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    .padding(.leading, 180)
                    
                    Spacer()
                    
                    // Bottom rotating tips
                    if viewModel.appState == .scanning {
                        HStack(spacing: 12) {
                            Image(systemName: scanningTips[currentTipIndex].icon)
                                .foregroundColor(AppTheme.terracotta)
                                .font(.system(size: 14))
                            
                            Text(scanningTips[currentTipIndex].text)
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.secondaryText)
                                .id(currentTipIndex)
                                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity)))
                        }
                        .padding(.leading, 180)
                        .padding(.bottom, 60)
                        .onReceive(timer) { _ in
                            withAnimation(.easeInOut(duration: 0.8)) {
                                currentTipIndex = (currentTipIndex + 1) % scanningTips.count
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Right Panel: Visual Animation + Feature Cards
                VStack(spacing: 32) {
                    Spacer()
                    
                    // Main Animation
                    ScanningAnimation(isScanning: viewModel.appState == .scanning)
                        .frame(width: 280, height: 280)
                    
                    // Feature Cards Grid (only show when not scanning)
                    if viewModel.appState != .scanning {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            FeatureCard(
                                icon: "trash.fill",
                                title: "feat_smart_cleanup",
                                description: "feat_smart_cleanup_desc",
                                color: AppTheme.terracotta
                            )
                            FeatureCard(
                                icon: "bolt.fill",
                                title: "feat_fast_scan",
                                description: "feat_fast_scan_desc",
                                color: Color(hex: "7ED321")
                            )
                            FeatureCard(
                                icon: "shield.checkered",
                                title: "feat_safe_delete",
                                description: "feat_safe_delete_desc",
                                color: Color(hex: "4A90E2")
                            )
                            FeatureCard(
                                icon: "chart.pie.fill",
                                title: "feat_visual_analysis",
                                description: "feat_visual_analysis_desc",
                                color: Color(hex: "9B59B6")
                            )
                        }
                        .padding(.horizontal, 40)
                        .frame(maxWidth: 420)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(
                    RadialGradient(
                        colors: [AppTheme.terracotta.opacity(0.05), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 300
                    )
                )
            }
            .overlay(alignment: .top) {
                if let update = viewModel.updateAvailable {
                    UpdateBanner(version: update)
                        .padding(.top, 40)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: viewModel.updateAvailable != nil)
                }
            }
        }
    }
    
    private func getDiskSpaceString() -> String {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let total = attrs[.systemSize] as? Int64,
              let free = attrs[.systemFreeSize] as? Int64 else {
            return "Unknown storage"
        }
        
        let totalStr = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
        let freeStr = ByteCountFormatter.string(fromByteCount: free, countStyle: .file)
        
        // Ensure "disk_capacity_format" is in Localizable.strings as "%@ available of %@"
        return String(format: NSLocalizedString("disk_capacity_format", comment: ""), freeStr, totalStr)
    }
}

// MARK: - Subcomponents

struct StorageMiniChart: View {
    @State private var animate = false
    @State private var isHovering = false
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.secondaryText.opacity(0.1), lineWidth: 4)
            
            Circle()
                .trim(from: 0, to: animate ? 0.75 : 0)
                .stroke(isHovering ? AppTheme.accent : AppTheme.terracotta, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: AppTheme.terracotta.opacity(isHovering ? 0.6 : 0), radius: 5)
        }
        .onAppear {
            withAnimation(.spring(response: 1.5, dampingFraction: 0.8).delay(0.5)) {
                animate = true
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

struct AnimatedMeshBackground: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.terracotta.opacity(0.1))
                .frame(width: 600, height: 600)
                .blur(radius: 100)
                .offset(x: animate ? 100 : -100, y: animate ? -50 : 50)
            
            Circle()
                .fill(Color.blue.opacity(0.05)) // Subtle secondary color for depth
                .frame(width: 500, height: 500)
                .blur(radius: 80)
                .offset(x: animate ? -150 : 150, y: animate ? 100 : -100)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}

// MARK: - Feature Card Component
struct FeatureCard: View {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let color: Color
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppTheme.primaryText)
            
            Text(description)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.secondaryText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.cardBackground.opacity(isHovered ? 0.8 : 0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(isHovered ? 0.3 : 0.1), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .shadow(color: color.opacity(isHovered ? 0.2 : 0), radius: 10)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

struct UpdateBanner: View {
    let version: AppVersion
    @State private var showChangelog = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with Glow
            ZStack {
                Circle()
                    .fill(AppTheme.terracotta.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "arrow.down")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.terracotta)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("new_version_available")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.primaryText)
                    
                    Text("v\(version.version)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.terracotta)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.terracotta.opacity(0.1))
                        .cornerRadius(6)
                }
                
                Button(action: { showChangelog.toggle() }) {
                    HStack(spacing: 4) {
                        Text("see_whats_new")
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(AppTheme.terracotta)
                }
                .buttonStyle(PlainButtonStyle())
                .popover(isPresented: $showChangelog, arrowEdge: .bottom) {
                    ChangelogPopover(version: version)
                }
            }
            
            Spacer()
            
            Button(action: {
                UpdateService.shared.downloadAndInstall()
            }) {
                Text("update_now")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [AppTheme.terracotta, AppTheme.terracotta.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: AppTheme.terracotta.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(
            ZStack {
                AppTheme.cardBackground
                    .opacity(0.95)
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                    .opacity(0.2)
            }
        )
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [AppTheme.terracotta.opacity(0.5), .clear]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        .frame(width: 480)
    }
}

struct ChangelogPopover: View {
    let version: AppVersion
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(format: NSLocalizedString("whats_new_version", comment: ""), version.version))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.primaryText)
                Spacer()
            }
            .padding(.bottom, 4)
            
            ScrollView {
                Text(version.notes)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.secondaryText)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(width: 300, height: 200)
        .background(AppTheme.cardBackground)
    }
}

// Helper for blur effect (if not already present, though typically standard View modifiers are preferred in pure SwiftUI, 
// keeping it simple with colors is safer if VisualEffectBlur isn't defined. 
// I'll stick to pure SwiftUI colors for safety as I don't recall seeing a VisualEffectBlur struct in the viewed files.)


#Preview {
    WelcomeView(viewModel: MainViewModel())
}
