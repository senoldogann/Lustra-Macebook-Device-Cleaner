import SwiftUI

// MARK: - Main View

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var hasAppeared = false
    
    var body: some View {
        Group {
            switch viewModel.appState {
            case .welcome, .scanning:
                WelcomeView(viewModel: viewModel)
            case .results:
                HStack(spacing: 0) {
                    PremiumSidebarView(viewModel: viewModel)
                        .frame(width: 280)
                    
                    Rectangle()
                        .fill(AppTheme.darkerGray.opacity(0.5))
                        .frame(width: 1)
                    
                    PremiumContentAreaView(viewModel: viewModel)
                }
                .frame(minWidth: 1000, minHeight: 700)
                .ignoresSafeArea()
            }
        }
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
        .confirmationDialog(
            Text(NSLocalizedString("are_you_sure_title", comment: "")),
            isPresented: $viewModel.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("delete_action", comment: ""), role: .destructive) {
                viewModel.deleteSelectedItems()
            }
            Button(NSLocalizedString("cancel_action", comment: ""), role: .cancel) {
                viewModel.itemToDelete = nil
            }
        }
        .alert(item: $viewModel.itemToDelete) { item in
            Alert(
                title: Text("are_you_sure_title"),
                message: Text(String(format: NSLocalizedString("delete_item_confirmation", comment: ""), item.name)),
                primaryButton: .destructive(Text("delete_action")) {
                    viewModel.deleteItem(item)
                },
                secondaryButton: .cancel(Text("cancel_action"))
            )
        }
        .alert(item: $viewModel.alertItem) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $viewModel.showAPIKeySheet) {
            APIKeyInputView(viewModel: viewModel)
        }
        }
    }

// MARK: - Premium Sidebar

struct PremiumSidebarView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var hoveredCategoryId: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Premium Header with Glassmorphism
            VStack(spacing: 8) {
                HStack {
                    // App Logo/Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.accent, AppTheme.accent.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Text("Lustra")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.primaryText)
                    
                    Spacer()
                    
                    if viewModel.isScanning {
                        ProgressView()
                            .controlSize(.small)
                            .tint(AppTheme.accent)
                    }
                }
                
                // Disk Usage Mini Indicator
                if viewModel.totalDiskSize > 0 {
                    DiskUsageMiniView(
                        used: viewModel.usedDiskSize,
                        total: viewModel.totalDiskSize
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 50)
            .padding(.bottom, 16)
            .background(
                LinearGradient(
                    colors: [AppTheme.darkerGray.opacity(0.8), AppTheme.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Category List
            ScrollView(showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(viewModel.categories, id: \.id) { category in
                        PremiumCategoryRow(
                            category: category,
                            isSelected: viewModel.selectedCategory?.id == category.id,
                            isHovered: hoveredCategoryId == category.id
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.selectCategory(category)
                            }
                        }
                        .onHover { isHovering in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                hoveredCategoryId = isHovering ? category.id : nil
                            }
                            if isHovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
            
            Spacer()
            
            // Premium Discard Section
            PremiumDiscardSection(viewModel: viewModel)
        }
        .frame(maxHeight: .infinity)
        .background(AppTheme.sidebarBackground)
    }
}

struct DiskUsageMiniView: View {
    let used: Int64
    let total: Int64
    
    private var usagePercentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total)
    }
    
    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.darkGray.opacity(0.5))
                    
                    // Used portion
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent, AppTheme.accent.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * usagePercentage)
                }
            }
            .frame(height: 6)
            
            HStack {
                Text("\(ByteCountFormatter.string(fromByteCount: used, countStyle: .file)) \(NSLocalizedString("disk_used_suffix", comment: ""))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.secondaryText)
                
                Spacer()
                
                Text("\(ByteCountFormatter.string(fromByteCount: total - used, countStyle: .file)) \(NSLocalizedString("disk_free_suffix", comment: ""))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.secondaryText.opacity(0.7))
            }
        }
    }
}

struct PremiumCategoryRow: View {
    let category: StorageCategory
    let isSelected: Bool
    let isHovered: Bool
    
    var body: some View {
        HStack(spacing: 14) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(isSelected ? AppTheme.accent : Color.clear)
                .frame(width: 4)
                .animation(.spring(response: 0.3), value: isSelected)
            
            // Icon with background
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isSelected
                            ? AppTheme.accent.opacity(0.2)
                            : (isHovered ? AppTheme.darkGray.opacity(0.5) : Color.clear)
                    )
                    .frame(width: 36, height: 36)
                
                Image(systemName: CategoryPresenter.icon(for: category.id))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.secondaryText)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? AppTheme.primaryText : AppTheme.secondaryText)
                
                if category.size > 0 {
                    Text(category.formattedSize)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(isSelected ? AppTheme.accent : AppTheme.secondaryText.opacity(0.6))
                }
            }
            
            Spacer()
            
            if category.isScanning {
                ProgressView()
                    .controlSize(.small)
                    .tint(AppTheme.accent)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isSelected
                        ? AppTheme.darkerGray
                        : (isHovered ? AppTheme.darkerGray.opacity(0.5) : Color.clear)
                )
        )
        .contentShape(Rectangle())
    }
}

struct PremiumDiscardSection: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Divider
            Rectangle()
                .fill(AppTheme.darkerGray)
                .frame(height: 1)
            
            VStack(spacing: 12) {
                // Header
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.isDiscardSectionExpanded.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 14))
                            .foregroundColor(viewModel.selectedItems.isEmpty ? AppTheme.secondaryText : AppTheme.accent)
                        
                        Text(NSLocalizedString("discard_section_title", comment: ""))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.primaryText)
                            .lineLimit(1)
                            .layoutPriority(1)
                        
                        if viewModel.selectedItemsCount > 0 {
                            Spacer()
                            
                            Text(String(format: NSLocalizedString("selected_count", comment: ""), viewModel.selectedItemsCount))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.accent.opacity(0.1))
                                .cornerRadius(4)
                                .lineLimit(1)
                        } else {
                            Spacer()
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppTheme.secondaryText)
                            .rotationEffect(.degrees(viewModel.isDiscardSectionExpanded ? 90 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                
                // Expanded Content
                if viewModel.isDiscardSectionExpanded {
                    VStack(spacing: 12) {
                        if viewModel.selectedItems.isEmpty {
                            HStack {
                                Text(String(format: NSLocalizedString("disk_used", comment: ""), ByteCountFormatter.string(fromByteCount: viewModel.usedDiskSize, countStyle: .file)))
                                .font(.caption2)
                                .foregroundColor(AppTheme.secondaryText)
                            Spacer()
                            Text(String(format: NSLocalizedString("disk_free", comment: ""), ByteCountFormatter.string(fromByteCount: viewModel.totalDiskSize - viewModel.usedDiskSize, countStyle: .file)))
                                .font(.caption2)
                                .foregroundColor(AppTheme.secondaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        } else {
                            // Selected items preview
                            VStack(spacing: 8) {
                                ForEach(viewModel.allSelectedItems.prefix(3)) { item in
                                    HStack(spacing: 10) {
                                        Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(hex: item.color))
                                        
                                        Text(item.name)
                                            .font(.system(size: 12))
                                            .lineLimit(1)
                                            .foregroundColor(AppTheme.secondaryText)
                                        
                                        Spacer()
                                        
                                        Text(item.formattedSize)
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .foregroundColor(AppTheme.secondaryText.opacity(0.7))
                                    }
                                }
                                
                                if viewModel.allSelectedItems.count > 3 {
                                    Text("+\(viewModel.allSelectedItems.count - 3) more")
                                        .font(.system(size: 10))
                                        .foregroundColor(AppTheme.secondaryText.opacity(0.6))
                                }
                            }
                            
                            // Actions Row: Smart Check, Clear, Delete
                            HStack(spacing: 8) {
                                // Smart Check (Auto-Select Safe)
                                Button(action: { viewModel.autoSelectSafeItems() }) {
                                    Image(systemName: "wand.and.stars")
                                        .font(.system(size: 16))
                                        .foregroundColor(AppTheme.accent)
                                        .frame(width: 32, height: 32)
                                        .background(AppTheme.background.opacity(0.5))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help(NSLocalizedString("smart_check", comment: ""))
                                
                                // Clear Selection
                                Button(action: { viewModel.clearSelection() }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(AppTheme.secondaryText)
                                }
                                .buttonStyle(.plain)
                                .help(NSLocalizedString("clear_selection", comment: ""))
                                
                                // Delete Button
                                Button(action: { viewModel.confirmDelete() }) {
                                    HStack {
                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 12))
                                        Text(String(format: NSLocalizedString("delete_count_items", comment: ""), viewModel.selectedItemsCount))
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
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
                                }
                                .buttonStyle(.plain)
                                .onHover { inside in
                                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                }
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(16)
            .background(AppTheme.darkerGray.opacity(0.3))
        }
    }
}

// MARK: - Premium Content Area

struct PremiumContentAreaView: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Premium Header
            PremiumHeaderView(viewModel: viewModel)
            
            // Category Info Card
            if let category = viewModel.selectedCategory {
                PremiumCategoryInfoCard(category: category, viewModel: viewModel)
            }
            
            // Items List
            PremiumItemsListView(viewModel: viewModel)
            
            // Bottom Panel
            PremiumBottomPanelView(viewModel: viewModel)
        }
        .background(AppTheme.background)
    }
}

struct PremiumHeaderView: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        HStack {
            // Breadcrumb
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.secondaryText.opacity(0.5))
                HStack(spacing: 6) {
                    Text("home_breadcrumb")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.secondaryText)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppTheme.darkGray)
                    
                    Text(viewModel.selectedCategory?.name ?? "Home")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.primaryText)
            }
            
            Spacer()
            
            // Selection Toolbar
            if !viewModel.selectedItems.isEmpty {
                HStack(spacing: 12) {
                    Text(String(format: NSLocalizedString("selected_count", comment: ""), viewModel.selectedItemsCount))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.secondaryText)
                    
                    // Smart Check Button
                    // Logic: If analysis is needed (any selected item not safe/review/unknown), trigger analysis.
                    // If all selected items have been analyzed, just re-select safe ones?
                    // "Smart Check" generally implies "Do the Magic".
                    // The best UX: Always try to analyze if not analyzed. 
                    // If already analyzed, it acts as "Select Safe".
                    Button(action: { 
                        // If any item is not analyzed, we treat this as "Run Analysis"
                        let needsAnalysis = viewModel.currentItems.filter { viewModel.selectedItems.contains($0.id) }
                            .contains { $0.analysisStatus == .unknown }
                        
                        if needsAnalysis {
                            viewModel.analyzeSelectedItems()
                        } else {
                            // If already analyzed, just refine selection to safe ones?
                            // Or re-analyze? Let's assume re-analyze is safer/clearer "Check" action.
                            viewModel.analyzeSelectedItems()
                        }
                    }) {
                        HStack(spacing: 6) {
                            if viewModel.isAnalyzing {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11))
                            }
                            Text(NSLocalizedString("smart_check", comment: ""))
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(AppTheme.primaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(AppTheme.darkerGray)
                                .overlay(
                                    Capsule()
                                        .strokeBorder(AppTheme.darkGray, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isAnalyzing)
                    .onHover { inside in
                        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                    
                    // Delete Button
                    Button(action: { viewModel.confirmDelete() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 11))
                            Text(NSLocalizedString("delete_action", comment: ""))
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(AppTheme.accent) // Removed overlay/stroke for cleaner look as per user pref for "button"
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { inside in
                        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                    
                    // Clear Selection
                    Button(action: { viewModel.backToWelcome() }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(AppTheme.darkerGray))
                    .buttonStyle(.plain)
                    .onHover { inside in
                        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(AppTheme.cardBackground.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(AppTheme.darkGray.opacity(0.5), lineWidth: 1)
                        )
                )
            }
        }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .padding(.top, 30) // Account for traffic lights
        .background(AppTheme.background)
    }
}

struct PremiumCategoryInfoCard: View {
    let category: StorageCategory
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(category.name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.primaryText)
                
                Text(getCategoryDescription(category.id))
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.secondaryText)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // New Scan Button
            Button(action: { viewModel.startFullScan() }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                    Text(NSLocalizedString("new_scan", comment: ""))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.accent)
                )
            }
            .buttonStyle(.plain)
            .onHover { inside in
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    private func getCategoryDescription(_ id: String) -> String {
        switch id {
        case "system_junk":
            return NSLocalizedString("cat_desc_system_junk", comment: "")
        case "user_library":
            return NSLocalizedString("cat_desc_user_library", comment: "")
        case "downloads":
            return NSLocalizedString("cat_desc_downloads", comment: "")
        case "desktop":
            return NSLocalizedString("cat_desc_desktop", comment: "")
        case "documents":
            return NSLocalizedString("cat_desc_documents", comment: "")
        case "applications":
            return NSLocalizedString("cat_desc_applications", comment: "")
        case "other":
            return NSLocalizedString("cat_desc_other", comment: "")
        case "system":
            return NSLocalizedString("cat_desc_system", comment: "")
        default:
            return NSLocalizedString("cat_desc_default", comment: "")
        }
    }
}

struct PremiumItemsListView: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        ZStack {
            if viewModel.isLoadingItems {
                // Loading State
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(AppTheme.accent)
                    
                    Text("Loading files...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.currentItems.isEmpty {
                // Empty State
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.darkerGray)
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 32))
                            .foregroundColor(AppTheme.secondaryText.opacity(0.5))
                    }
                    
                    Text(NSLocalizedString("no_items_found", comment: ""))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.secondaryText)
                    
                    Text(NSLocalizedString("empty_category_message", comment: ""))
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.secondaryText.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Content
                VStack(spacing: 0) {
                    // List Header
                    HStack(spacing: 0) {
                        // Select All Checkbox
                        Button(action: { viewModel.toggleSelectAll() }) {
                            ZStack {
                                Circle()
                                    .strokeBorder(
                                        viewModel.areAllItemsSelected ? AppTheme.accent : AppTheme.darkGray,
                                        lineWidth: 2
                                    )
                                    .frame(width: 22, height: 22)
                                
                                if viewModel.areAllItemsSelected {
                                    Circle()
                                        .fill(AppTheme.accent)
                                        .frame(width: 14, height: 14)
                                }
                            }
                            .padding(8) // Increase tap area
                            .contentShape(Circle())
                            .background(Color.black.opacity(0.001)) // Make transparent area clickable
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 24)
                        .onHover { inside in
                            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                        
                        Text(NSLocalizedString("col_name", comment: ""))
                            .padding(.leading, 16)
                        
                        Spacer()
                        
                        Text(NSLocalizedString("col_status", comment: ""))
                            .frame(width: 160, alignment: .leading)
                        
                        Text(NSLocalizedString("col_modified", comment: ""))
                            .frame(width: 90, alignment: .trailing)
                        
                        Text(NSLocalizedString("col_size", comment: ""))
                            .frame(width: 70, alignment: .trailing)
                            .padding(.trailing, 24)
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.secondaryText.opacity(0.7))
                    .textCase(.uppercase)
                    .padding(.vertical, 12)
                    .background(AppTheme.background)
                    
                    Rectangle()
                        .fill(AppTheme.darkerGray.opacity(0.5))
                        .frame(height: 1)
                    
                    // Permission Banner (if needed)
                    if let category = viewModel.selectedCategory,
                       ["user_library", "documents", "system"].contains(category.id),
                       !viewModel.hasFullDiskAccess {
                        PremiumFullDiskAccessBanner(viewModel: viewModel)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                    }
                    
                    // Items ScrollView
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.currentItems.enumerated()), id: \.element.id) { index, item in
                                PremiumItemRow(
                                    viewModel: viewModel,
                                    item: item,
                                    isEven: index % 2 == 0
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

struct PremiumItemRow: View {
    @ObservedObject var viewModel: MainViewModel
    let item: StorageItem
    let isEven: Bool
    
    @State private var isHovering = false
    
    private var isSelected: Bool {
        viewModel.selectedItems.contains(item.id)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Checkbox
            Button(action: { viewModel.toggleItemSelection(item) }) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? AppTheme.accent : AppTheme.darkGray,
                            lineWidth: 2
                        )
                        .frame(width: 22, height: 22)
                    
                    if isSelected {
                        Circle()
                            .fill(AppTheme.accent)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.leading, 24)
            .onHover { inside in
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: item.color).opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: item.color))
            }
            .padding(.leading, 12)
            
            // Name
            Text(item.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.primaryText)
                .lineLimit(1)
                .padding(.leading, 12)
            
            Spacer()
            
            // Hover Actions
            if isHovering {
                HStack(spacing: 8) {
                    // Smart Check
                    Button(action: { viewModel.analyzeItem(item) }) {
                        Text("Smart Check")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.primaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(AppTheme.darkerGray)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(item.analysisStatus == .analyzing)
                    .onHover { inside in
                        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                    
                    // Reveal in Finder
                    Button(action: { viewModel.revealInFinder(item: item) }) {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .onHover { inside in
                        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                    
                    // Delete
                    Button(action: { viewModel.confirmDeleteItem(item) }) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                    .onHover { inside in
                        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }
                .padding(.trailing, 12)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            
            // Analysis Status
            PremiumAnalysisBadge(item: item)
                .frame(width: 160, alignment: .leading)
            
            // Date
            Text(item.formattedDate)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.secondaryText)
                .frame(width: 90, alignment: .trailing)
            
            // Size
            Text(item.formattedSize)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.primaryText)
                .frame(width: 70, alignment: .trailing)
                .padding(.trailing, 24)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isHovering
                        ? AppTheme.darkerGray.opacity(0.5)
                        : (isEven ? Color.clear : AppTheme.darkerGray.opacity(0.2))
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                viewModel.toggleItemSelection(item)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}


struct PremiumAnalysisBadge: View {
    let item: StorageItem
    @State private var showDetails = false
    
    var body: some View {
        HStack(spacing: 8) {
            switch item.analysisStatus {
            case .notAnalyzed:
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.secondaryText.opacity(0.5))
                Text("status_not_analyzed")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.secondaryText.opacity(0.5))
                
            case .analyzing:
                ProgressView()
                    .controlSize(.small)
                    .tint(AppTheme.accent)
                Text("status_analyzing")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.accent)
                
            case .safe:
                BadgeButton(title: NSLocalizedString("status_safe", comment: ""), icon: "checkmark.shield.fill", color: AppTheme.safe) {
                    showDetails.toggle()
                }
                
            case .review:
                BadgeButton(title: NSLocalizedString("status_review", comment: ""), icon: "exclamationmark.shield.fill", color: AppTheme.review) {
                    showDetails.toggle()
                }
                
            case .unknown:
                Image(systemName: "circle.slash")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.secondaryText.opacity(0.5))
                Text("status_unknown")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.secondaryText.opacity(0.5))
            }
        }
        .popover(isPresented: $showDetails, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: item.analysisStatus == .safe ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .foregroundColor(item.analysisStatus == .safe ? AppTheme.safe : AppTheme.review)
                    Text("smart_check_results")
                        .font(.headline)
                }
                
                Divider()
                
                Divider()
                
                Text(item.analysisDescription.isEmpty ? NSLocalizedString("no_feedback", comment: "") : item.analysisDescription)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                
                if !item.analysisConsequences.isEmpty {
                    Text("label_consequences")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.secondaryText)
                    
                    Text(item.analysisConsequences)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.terracotta.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                HStack {
                    Text("label_safe_to_delete")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.secondaryText)
                    
                    Text(item.safeToDelete ? NSLocalizedString("yes", comment: "") : NSLocalizedString("no", comment: ""))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(item.safeToDelete ? AppTheme.safe : AppTheme.review)
                }
                
                if item.analysisStatus == .review {
                    Text("recommendation_manual")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.terracotta)
                }
            }
            .frame(width: 300) // Fixed width for compact layout
            .padding(16)
            .background(AppTheme.darkerGray)
        }
    }
}

struct BadgeButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color)
                    .shadow(color: color.opacity(isHovering ? 0.6 : 0.3), radius: isHovering ? 8 : 4)
            )
            .scaleEffect(isHovering ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { inside in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = inside
            }
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

struct PremiumFullDiskAccessBanner: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.accent)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("fda_required_title")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.primaryText)
                
                Text("fda_required_desc")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.secondaryText)
            }
            
            Spacer()
            
            Button(action: { viewModel.requestFullDiskAccess() }) {
                Text("open_settings")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppTheme.accent)
                    )
            }
            .buttonStyle(.plain)
            .onHover { inside in
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.darkerGray.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(AppTheme.accent.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Premium Bottom Panel

struct PremiumBottomPanelView: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppTheme.darkerGray.opacity(0.5))
                .frame(height: 1)
            
            GeometryReader { geometry in
                let panelWidth = (geometry.size.width - 48) / 2
                
                HStack(spacing: 16) {
                    // Left Panel - Treemap
                    VStack(alignment: .leading, spacing: 0) {
                        // Segmented Tab Control
                        HStack(spacing: 0) {
                            PremiumTabButton(
                                title: NSLocalizedString("tab_treemap", comment: ""),
                                icon: "square.grid.2x2",
                                isActive: viewModel.selectedBottomTab == .treemap
                            ) {
                                viewModel.selectedBottomTab = .treemap
                            }
                            
                            PremiumTabButton(
                                title: NSLocalizedString("tab_sunburst", comment: ""),
                                icon: "chart.pie",
                                isActive: viewModel.selectedBottomTab == .sunburst
                            ) {
                                viewModel.selectedBottomTab = .sunburst
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        
                            Group {
                                if viewModel.selectedBottomTab == .treemap {
                                    let topItems = viewModel.currentItems.sorted { $0.size > $1.size }.prefix(15)
                                    PremiumTreemapView(viewModel: viewModel, items: Array(topItems))
                                        .padding(16)
                                } else {
                                    let topItems = viewModel.currentItems.sorted { $0.size > $1.size }.prefix(8)
                                    PremiumSunburstView(viewModel: viewModel, items: Array(topItems))
                                        .padding(20)
                                }
                            }
                        }
                        .frame(maxHeight: .infinity)
                        .frame(width: panelWidth)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(AppTheme.darkerGray.opacity(0.4))
                        )
                    
                    // Right Panel - Largest Files
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.accent)
                            
                            Text("tab_largest_files")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.primaryText)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 12)
                        
                        ScrollView(showsIndicators: false) {
                            let sortedItems = viewModel.currentItems.sorted { $0.size > $1.size }
                            VStack(spacing: 10) {
                                ForEach(Array(sortedItems.prefix(5).enumerated()), id: \.element.id) { index, file in
                                    PremiumLargestFileRow(file: file, rank: index + 1)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }
                    }
                    .frame(width: panelWidth)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppTheme.darkerGray.opacity(0.4))
                    )
                }
                .padding(16)
            }
        }
        .frame(height: 260)
        .background(AppTheme.background)
    }
}

struct PremiumTabButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 12, weight: isActive ? .semibold : .medium))
            }
            .foregroundColor(isActive ? AppTheme.primaryText : AppTheme.secondaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? AppTheme.darkerGray : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { inside in
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

struct PremiumLargestFileRow: View {
    let file: StorageItem
    let rank: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank Badge
            Text("\(rank)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(rank <= 3 ? .white : AppTheme.secondaryText)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(rank <= 3 ? AppTheme.accent : AppTheme.darkGray)
                )
            
            // Icon
            Image(systemName: file.isDirectory ? "folder.fill" : "doc.fill")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: file.color))
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.primaryText)
                    .lineLimit(1)
                
                Text(file.formattedSize)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.accent)
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

struct PremiumSunburstView: View {
    @ObservedObject var viewModel: MainViewModel
    let items: [StorageItem]
    
    // Geometry constant for hit testing
    private let innerRadius: CGFloat = 50
    private let outerRadius: CGFloat = 100
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                // Chart Content
                ZStack {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        let startAngle = angleForIndex(index)
                        let endAngle = angleForIndex(index + 1)
                        let color = AppTheme.treemapPalette[index % AppTheme.treemapPalette.count]
                        
                        SunburstSlice(
                            startAngle: startAngle,
                            endAngle: endAngle,
                            innerRadius: innerRadius,
                            outerRadius: outerRadius
                        )
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .black.opacity(0.2), radius: 2)
                    }
                }
                // Add a transparent overlay to capture all hover/mouse events continuously
                .background(Color.black.opacity(0.001))
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        // Calculate hit test manually for perfect precision
                        let vector = CGVector(dx: location.x - center.x, dy: location.y - center.y)
                        let distance = sqrt(vector.dx * vector.dx + vector.dy * vector.dy)
                        
                        // Check if inside ring
                        if distance >= innerRadius && distance <= outerRadius {
                            // Calculate angle (-180 to 180) -> converted to match chart angles
                            let angle = atan2(vector.dy, vector.dx) * 180 / .pi
                            
                            // Let's normalize everything to 0-360 starting from -90 (Top)
                            let normalizedAngle = (angle + 90).truncatingRemainder(dividingBy: 360)
                            let finalAngle = normalizedAngle < 0 ? normalizedAngle + 360 : normalizedAngle
                            
                            // Find item that spans this angle
                            let total = items.reduce(0) { $0 + $1.size }
                            if total > 0 {
                                var currentAngle: Double = 0
                                
                                for item in items {
                                    let ratio = Double(item.size) / Double(total)
                                    let sweep = ratio * 360
                                    
                                    if finalAngle >= currentAngle && finalAngle < (currentAngle + sweep) {
                                        viewModel.hoveredItem = item
                                        viewModel.tooltipPosition = location
                                        NSCursor.pointingHand.push()
                                        return
                                    }
                                    currentAngle += sweep
                                }
                            }
                        }
                        
                        // If we fall through here, we are not hovering a valid item
                        if viewModel.hoveredItem != nil {
                            viewModel.hoveredItem = nil
                            NSCursor.pop()
                        }
                        
                    case .ended:
                        viewModel.hoveredItem = nil
                        NSCursor.pop()
                    }
                }
                
                // Tooltip (Not Clipped)
                if let hovered = viewModel.hoveredItem, items.contains(where: { $0.id == hovered.id }) {
                    PremiumChartTooltip(item: hovered)
                        .fixedSize() // Prevent truncation
                        .position(x: viewModel.tooltipPosition.x, y: viewModel.tooltipPosition.y - 30)
                        .zIndex(100)
                        .allowsHitTesting(false)
                }
                
                VStack(spacing: 2) {
                    Text("\(items.count)")
                        .font(.system(size: 18, weight: .bold))
                    Text("label_items")
                        .font(.system(size: 9))
                        .foregroundColor(AppTheme.secondaryText)
                }
            }
        }
    }
    func angleForIndex(_ index: Int) -> Angle {
        let total = items.reduce(0) { $0 + $1.size }
        guard total > 0 else { return .degrees(0) }
        
        let subtotal = items.prefix(index).reduce(0) { $0 + $1.size }
        return .degrees(Double(subtotal) / Double(total) * 360 - 90)
    }
}

struct SunburstSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        
        path.addArc(center: center, radius: outerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
        
        return path
    }
}

struct PremiumTreemapView: View {
    @ObservedObject var viewModel: MainViewModel
    let items: [StorageItem]
    
    var body: some View {
        GeometryReader { geometry in
            let rects = calculateTreemap(items: items, in: CGRect(origin: .zero, size: geometry.size))
            
            ZStack {
                // Chart Content (Clipped)
                ZStack {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        if index < rects.count {
                            let rect = rects[index]
                            if rect.width > 3 && rect.height > 3 {
                                let color = AppTheme.treemapPalette[index % AppTheme.treemapPalette.count]
                                
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [color, color.opacity(0.7)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: max(rect.width - 2, 0), height: max(rect.height - 2, 0))
                                    .onHover { inside in
                                        if inside {
                                            viewModel.hoveredItem = item
                                            viewModel.tooltipPosition = CGPoint(x: rect.midX, y: rect.minY)
                                            NSCursor.pointingHand.push()
                                        } else {
                                            viewModel.hoveredItem = nil
                                            NSCursor.pop()
                                        }
                                    }
                                    .position(x: rect.midX, y: rect.midY)
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12)) // Clip ONLY the chart
                
                // Tooltip (Not Clipped)
                if let hovered = viewModel.hoveredItem, items.contains(where: { $0.id == hovered.id }) {
                    PremiumChartTooltip(item: hovered)
                        .fixedSize() // Prevent truncation
                        .position(x: viewModel.tooltipPosition.x, y: viewModel.tooltipPosition.y - 20)
                        .zIndex(100)
                        .allowsHitTesting(false)
                }
            }
        }
    }
    
    private func calculateTreemap(items: [StorageItem], in bounds: CGRect) -> [CGRect] {
        guard !items.isEmpty else { return [] }
        
        let totalSize = items.reduce(0) { $0 + $1.size }
        guard totalSize > 0 else { return [] }
        
        var rects: [CGRect] = []
        var remaining = bounds
        
        let sorted = items.sorted { $0.size > $1.size }
        
        for (index, item) in sorted.enumerated() {
            let rest = sorted[index...].reduce(0) { $0 + $1.size }
            let ratio = CGFloat(item.size) / CGFloat(rest)
            
            var rect: CGRect
            if remaining.width > remaining.height {
                let w = remaining.width * ratio
                rect = CGRect(x: remaining.minX, y: remaining.minY, width: w, height: remaining.height)
                remaining = CGRect(x: remaining.minX + w, y: remaining.minY, width: remaining.width - w, height: remaining.height)
            } else {
                let h = remaining.height * ratio
                rect = CGRect(x: remaining.minX, y: remaining.minY, width: remaining.width, height: h)
                remaining = CGRect(x: remaining.minX, y: remaining.minY + h, width: remaining.width, height: remaining.height - h)
            }
            rects.append(rect)
        }
        
        return rects
    }
}

// MARK: - Preview

// #Preview {
//     MainView()
// }

struct PremiumChartTooltip: View {
    let item: StorageItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.name)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true) // Allow wrapping if needed
                .layoutPriority(1)
            Text(item.formattedSize)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.8))
                .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.8))
                
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            }
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.9)), removal: .opacity))
    }
}


