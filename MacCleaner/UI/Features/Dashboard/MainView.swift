import SwiftUI

/// Main window with FreeUpMyMac-style layout
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
                    SidebarView(viewModel: viewModel)
                        .frame(width: 260) // Fixed width for sidebar
                    
                    Divider()
                        .background(AppTheme.darkerGray)
                    
                    ContentAreaView(viewModel: viewModel)
                }
                .frame(minWidth: 900, minHeight: 600)
                .ignoresSafeArea() // Critical for edge-to-edge layout
            }
        }
        .background(AppTheme.background)
        .preferredColorScheme(.dark) // Force dark mode
        .confirmationDialog(
            "Are you sure?",
            isPresented: $viewModel.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                viewModel.deleteSelectedItems()
            }
            Button("Cancel", role: .cancel) {
                viewModel.itemToDelete = nil
            }
        } message: {
            if let item = viewModel.itemToDelete {
                Text("Are you sure you want to move '\(item.name)' to the Trash?")
            } else {
                Text("This will move \(viewModel.selectedItemsCount) items (\(viewModel.formattedSelectedSize)) to the Trash. You can restore them from the Trash if needed.")
            }
        }
        .alert(item: $viewModel.alertItem) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .overlay(alignment: .topLeading) {
            if let item = viewModel.hoveredItem {
                TechExpertTooltip(item: item)
                    .position(x: viewModel.tooltipPosition.x + 150, y: viewModel.tooltipPosition.y) // Adjusting for tooltip center width
            }
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Lustra")
                    .font(.headline)
                    .foregroundColor(AppTheme.secondaryText)
                Spacer()
                if viewModel.isScanning {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(.horizontal)
            .padding(.top, 45) // Pushing down to clear traffic lights
            .padding(.bottom, 10)
            
            // Category List
            List(viewModel.categories, id: \.id, selection: Binding(
                get: { viewModel.selectedCategory?.id },
                set: { newId in
                    if let id = newId, let cat = viewModel.categories.first(where: { $0.id == id }) {
                        viewModel.selectCategory(cat)
                    }
                }
            )) { category in
                CategoryRow(category: category, isSelected: viewModel.selectedCategory?.id == category.id)
                    .tag(category.id)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            
            Divider()
            
            // Discard Section
            DiscardSectionView(viewModel: viewModel)
        }
        .frame(maxHeight: .infinity)
        .background(AppTheme.sidebarBackground)
        .ignoresSafeArea()
    }
}

struct CategoryRow: View {
    let category: StorageCategory
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? AppTheme.primaryText : AppTheme.accent)
                    .frame(width: 24)
            
            Text(category.name)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            
            Spacer()
            
            if category.isScanning {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 12, height: 12)
                    .padding(.trailing, 4)
            }
            
            if category.size > 0 {
                Text(category.formattedSize)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.9) : AppTheme.secondaryText)
            } else if !category.isScanning {
                // Only show empty state if not scanning and size is 0
                Text("--")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.secondaryText)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .cornerRadius(6)
        .onHover { inside in
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

struct DiscardSectionView: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.isDiscardSectionExpanded.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                        .foregroundColor(viewModel.selectedItems.isEmpty ? .secondary : AppTheme.accent)
                    
                    Text("Discard")
                        .font(.system(size: 14, weight: .semibold))
                    
                    if !viewModel.selectedItems.isEmpty {
                        Text("\(viewModel.selectedItemsCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.8))
                            .clipShape(Capsule())
                        
                        Spacer()
                        
                        Text(viewModel.formattedSelectedSize)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Spacer()
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(viewModel.isDiscardSectionExpanded ? 90 : 0))
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { inside in
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            
            if viewModel.isDiscardSectionExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    if viewModel.selectedItems.isEmpty {
                        Text("No items selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 10)
                    } else {
                        // Scrollable list of items to discard
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(viewModel.allSelectedItems.prefix(5)) { item in
                                HStack(spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: item.color).opacity(0.2))
                                            .frame(width: 28, height: 28)
                                        Image(systemName: "folder.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(hex: item.color))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.system(size: 12, weight: .medium))
                                            .lineLimit(1)
                                        Text(item.formattedSize)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                            
                            if viewModel.allSelectedItems.count > 5 {
                                Text("+\(viewModel.allSelectedItems.count - 5) more items")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                            }
                        }
                        
                        // Large Delete button
                        Button(action: {
                            viewModel.confirmDelete()
                        }) {
                            Text("Delete \(viewModel.selectedItemsCount) items")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(AppTheme.accent)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        .padding(.top, 4)
                        .onHover { inside in
                            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                    }
                }
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Content Area

struct ContentAreaView: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with breadcrumb and action bar
            HeaderView(viewModel: viewModel)
            
            // Category Title
            if let category = viewModel.selectedCategory {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(category.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.startFullScan()
                        }) {
                            Label("New Scan", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                        .onHover { inside in
                            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                    }
                    
                    Text(getCategoryDescription(category.id))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            // Items List Header
            HStack {
                Text("Name")
                    .frame(width: 200, alignment: .leading)
                    .padding(.leading, 20) // Match ItemRow padding
                Text("Smart Check")
                    .frame(width: 200, alignment: .leading)
                Spacer()
                Text("Modified")
                    .frame(width: 100, alignment: .trailing)
                Text("Size")
                    .frame(width: 80, alignment: .trailing)
                    .padding(.trailing, 20) // Added padding to header
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(AppTheme.background)
            
            // Items List
            ItemsListView(viewModel: viewModel)
            
            Divider()
            
            // Bottom Section: Treemap + Largest Files
            BottomPanelView(viewModel: viewModel)
        }
    }
    
    private func getCategoryDescription(_ id: String) -> String {
        switch id {
        case "system_junk":
            return "System Data is often full of confusing cache files. We've identified these as safe to remove to reclaim free space."
        case "user_library":
            return "Contains app data and settings. Use Smart Check to translate technical names into plain English before deciding."
        case "downloads":
            return "Files downloaded from the internet. Great place to find forgotten giants taking up space."
        case "desktop":
            return "Files on your Desktop. Rapidly access and organize your workspace."
        case "documents":
            return "Your personal documents. Review carefully."
        default:
            return "Files and folders in this location."
        }
    }
}

struct HeaderView: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        HStack {
            // Breadcrumb
            Image(systemName: "chevron.left")
                .foregroundColor(.secondary)
            Image(systemName: "house.fill")
                .foregroundColor(.secondary)
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
            Text(viewModel.selectedCategory?.name ?? "Home")
                .font(.headline)
            
            Spacer()
            
            // Selection toolbar
            if !viewModel.selectedItems.isEmpty {
                HStack(spacing: 12) {
                    Text("\(viewModel.selectedItemsCount) items selected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        viewModel.analyzeSelectedItems()
                    }) {
                        HStack(spacing: 4) {
                            if viewModel.isAnalyzing {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text("Smart Check")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isAnalyzing)
                    
                    Button(action: {
                        viewModel.confirmDelete()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash.fill")
                            Text("Delete")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                    
                    Button(action: {
                        viewModel.clearSelection()
                    }) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                    .onHover { inside in
                        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.cardBackground)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(AppTheme.background)
    }
}

struct ItemsListView: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        ZStack {
            // Loading state
            if viewModel.isLoadingItems {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accent))
                    
                    Text("Loading files...")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.currentItems.isEmpty && viewModel.selectedCategory != nil {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.secondaryText.opacity(0.5))
                    
                    Text("No items found")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Content
                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 12) {
                        Button(action: { viewModel.toggleSelectAll() }) {
                            Image(systemName: viewModel.areAllItemsSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(viewModel.areAllItemsSelected ? AppTheme.accent : AppTheme.secondaryText)
                                .font(.system(size: 18))
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 20)
                        .help(viewModel.areAllItemsSelected ? "Deselect All" : "Select All")
                        
                        Text("Name")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("Date")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 100, alignment: .trailing)
                        
                        Text("Size")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .trailing)
                            .padding(.trailing, 20)
                    }
                    .padding(.vertical, 10)
                    .background(AppTheme.background)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(AppTheme.secondaryText.opacity(0.1)),
                        alignment: .bottom
                    )
                    
                    ScrollView {
                    LazyVStack(spacing: 0) {
                        if let category = viewModel.selectedCategory,
                           ["user_library", "documents", "system"].contains(category.id),
                           !viewModel.hasFullDiskAccess {
                            FullDiskAccessBanner(viewModel: viewModel)
                                .padding()
                        }
                        
                        ForEach(viewModel.currentItems) { item in
                            ItemRow(
                                viewModel: viewModel,
                                item: item
                            )
                            Divider() 
                        }
                    }
                }
                }
            }
        }
    }
}

struct ItemRow: View {
    @ObservedObject var viewModel: MainViewModel
    let item: StorageItem
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: { viewModel.toggleItemSelection(item) }) {
                let isSelected = viewModel.selectedItems.contains(item.id)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.secondaryText)
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
            .padding(.leading, 20) // Shift to the right
            .onHover { inside in
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            
            // Icon
            Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundColor(Color(hex: item.color)) // Use consistent color
                .font(.system(size: 20))
            
            // Name
            Text(item.name)
                .font(.system(size: 13))
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)
            
            // Analysis Status Badge
            AnalysisBadge(item: item)
                .frame(width: 200, alignment: .leading)
            
            Spacer()
            
            // Hover actions
            if isHovering {
                HStack(spacing: 8) {
                    Button(action: { viewModel.analyzeItem(item) }) {
                        Text("Smart Check")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .disabled(item.analysisStatus == .analyzing)
                    .onHover { inside in
                        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                    
                    Button(action: { viewModel.revealInFinder(item: item) }) {
                        Image(systemName: "arrow.up.forward.square")
                    }
                    .buttonStyle(.borderless)
                    .onHover { inside in
                        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                    
                    Button(action: {
                        viewModel.confirmDeleteItem(item)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(AppTheme.accent)
                    }
                    .buttonStyle(.borderless)
                    .onHover { inside in
                        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }
            }
            
            // Date
            Text(item.formattedDate)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .trailing)
            
            // Size
            Text(item.formattedSize)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 80, alignment: .trailing)
                .padding(.trailing, 20)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(
            GeometryReader { geo in
                Color.clear
                    .onChange(of: isHovering) { hovering in
                        if hovering {
                            let frame = geo.frame(in: .global)
                            // Position the tooltip slightly to the right and down from the row
                            viewModel.tooltipPosition = CGPoint(x: frame.minX + 40, y: frame.minY + 30)
                            viewModel.hoveredItem = item
                        } else {
                            if viewModel.hoveredItem?.id == item.id {
                                viewModel.hoveredItem = nil
                            }
                        }
                    }
            }
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .zIndex(isHovering ? 10 : 0)
    }
}

// Tech Expert Tooltip Component
struct TechExpertTooltip: View {
    let item: StorageItem
    
    var body: some View {
        if item.analysisStatus == .notAnalyzed {
             EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(item.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(item.analysisDescription)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                
                Divider().background(Color.white.opacity(0.3))
                
                HStack(alignment: .top, spacing: 4) {
                    Text("If deleted:")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text(item.analysisStatus == .safe ? "Safe to remove." : "May affect apps.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(16)
            .frame(width: 300)
            .background(Color(red: 0.1, green: 0.1, blue: 0.1)) // Solid dark gray, NOT theme
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.accent, lineWidth: 2)
            )
            .shadow(color: .black, radius: 15, x: 0, y: 8)
            .allowsHitTesting(false) // Bypass mouse events
            .drawingGroup() // CRITICAL: Forces Metal rendering as a single opaque bitmap
        }
    }
}

struct FullDiskAccessBanner: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.title2)
                    .foregroundColor(AppTheme.accent)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Full Disk Access Required")
                        .font(.headline)
                    Text("To scan some system and user folders (Library, Documents), macOS requires you to grant this app Full Disk Access in System Settings.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                }
                
                Spacer()
                
                Button("Open Settings") {
                    viewModel.requestFullDiskAccess()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }
            .padding()
            .background(AppTheme.cardBackground.opacity(0.5))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.accent.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct AnalysisBadge: View {
    let item: StorageItem
    
    var body: some View {
        HStack(spacing: 8) {
            // Fixed width icon container for perfect alignment
            ZStack {
                switch item.analysisStatus {
                case .notAnalyzed:
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.secondary)
                    
                case .analyzing:
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.6)
                    
                case .safe:
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12))
                    
                case .review:
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 12))
                    
                case .unknown:
                    Image(systemName: "circle.slash")
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 20, alignment: .center)
            
            HStack(spacing: 6) {
                switch item.analysisStatus {
                case .notAnalyzed:
                    Text("Not analyzed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                case .analyzing:
                    Text("Analyzing...")
                        .font(.caption)
                        .foregroundColor(AppTheme.accent)
                    
                case .safe:
                    HStack(spacing: 8) {
                        Text("safe")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(AppTheme.safe)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        if !item.analysisDescription.isEmpty {
                            Text(item.analysisDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                case .review:
                    HStack(spacing: 8) {
                        Text("review")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(AppTheme.review)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        if !item.analysisDescription.isEmpty {
                            Text(item.analysisDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                case .unknown:
                    Text("unknown")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct BottomPanelView: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        GeometryReader { geometry in
            let panelWidth = (geometry.size.width - 16) / 2 // Equal width with 16px gap
            
            HStack(spacing: 16) {
                // Left Panel: Treemap/Sunburst
                VStack(alignment: .leading, spacing: 0) {
                    // Tab Bar
                    HStack(spacing: 24) {
                        TabButton(title: "Treemap", isActive: viewModel.selectedBottomTab == .treemap) {
                            viewModel.selectedBottomTab = .treemap
                        }
                        
                        TabButton(title: "Sunburst", isActive: viewModel.selectedBottomTab == .sunburst) {
                            viewModel.selectedBottomTab = .sunburst
                        }
                        
                        Spacer()
                    }
                    .padding(.leading, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    
                    // Treemap visualization
                    Group {
                        if viewModel.selectedBottomTab == .treemap {
                            let topItems = viewModel.currentItems.sorted(by: { $0.size > $1.size }).prefix(20)
                            TreemapView(items: Array(topItems))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                        } else {
                            VStack {
                                Spacer()
                                Image(systemName: "chart.pie.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary.opacity(0.3))
                                Text("Sunburst View Coming Soon")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(width: panelWidth)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(white: 0.15))
                )
                
                // Right Panel: Largest Files
                VStack(alignment: .leading, spacing: 0) {
                    Text("Largest Files")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.primaryText)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 16)
                    
                    ScrollView(showsIndicators: false) {
                        let sortedItems = viewModel.currentItems.sorted(by: { $0.size > $1.size })
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(sortedItems.prefix(5)) { file in
                                HStack(spacing: 14) {
                                    Image(systemName: file.isDirectory ? "folder.fill" : "doc.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(AppTheme.secondaryText.opacity(0.6))
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(file.name)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(AppTheme.primaryText)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        
                                        Text(file.formattedSize)
                                            .font(.system(size: 12))
                                            .foregroundColor(AppTheme.secondaryText.opacity(0.7))
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.bottom, 16)
                    }
                }
                .frame(width: panelWidth)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(white: 0.15))
                )
            }
        }
        .frame(height: 240)
    }
}

// MARK: - Treemap

struct TabButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: isActive ? .bold : .medium))
                    .foregroundColor(isActive ? .primary : .secondary)
                
                if isActive {
                    Rectangle()
                        .fill(AppTheme.accent)
                        .frame(width: 20, height: 2)
                        .cornerRadius(1)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 20, height: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { inside in
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

struct TreemapView: View {
    let items: [StorageItem]
    
    var body: some View {
        GeometryReader { geometry in
            let rects = calculateTreemap(items: items, in: CGRect(origin: .zero, size: geometry.size))
            
            ZStack {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    let rect = rects[index]
                    if rect.width > 2 && rect.height > 2 {
                        let color = AppTheme.treemapPalette[index % AppTheme.treemapPalette.count]
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color.opacity(0.85))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                            )
                            .frame(width: max(rect.width - 1, 0), height: max(rect.height - 1, 0))
                            .position(x: rect.midX, y: rect.midY)
                            .help("\(item.name): \(item.formattedSize)")
                    }
                }
            }
        }
    }
    
    private func calculateTreemap(items: [StorageItem], in bounds: CGRect) -> [CGRect] {
        guard !items.isEmpty else { return [] }
        
        let totalDisplaySize = items.reduce(0) { $0 + $1.size }
        guard totalDisplaySize > 0 else { return [] }
        
        var rects: [CGRect] = []
        var remainingRect = bounds
        
        let sortedItems = items.sorted(by: { $0.size > $1.size })
        
        for (index, item) in sortedItems.enumerated() {
            let totalRemaining = sortedItems[index...].reduce(0) { $0 + $1.size }
            let ratio = CGFloat(item.size) / CGFloat(totalRemaining)
            
            var currentRect: CGRect
            if remainingRect.width > remainingRect.height {
                let width = remainingRect.width * ratio
                currentRect = CGRect(x: remainingRect.minX, y: remainingRect.minY, width: width, height: remainingRect.height)
                remainingRect = CGRect(x: remainingRect.minX + width, y: remainingRect.minY, width: remainingRect.width - width, height: remainingRect.height)
            } else {
                let height = remainingRect.height * ratio
                currentRect = CGRect(x: remainingRect.minX, y: remainingRect.minY, width: remainingRect.width, height: height)
                remainingRect = CGRect(x: remainingRect.minX, y: remainingRect.minY + height, width: remainingRect.width, height: remainingRect.height - height)
            }
            rects.append(currentRect)
        }
        
        return rects
    }
}

#Preview {
    MainView()
}
