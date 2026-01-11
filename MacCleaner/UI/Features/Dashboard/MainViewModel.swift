import SwiftUI
import Combine
import os

/// Main ViewModel for the FreeUpMyMac-style interface
@MainActor
final class MainViewModel: ObservableObject {
    
    enum AppState {
        case welcome
        case scanning
        case results
    }
    
    // MARK: - Published Properties
    @Published var appState: AppState = .welcome
    @Published var categories: [StorageCategory] = []
    @Published var selectedCategory: StorageCategory?
    @Published var currentItems: [StorageItem] = []
    @Published var largestFiles: [StorageItem] = []
    @Published var scanProgress: Double = 0.0
    @Published var currentlyScanningCategory: String? // To show what's being scanned
    @Published var isScanning: Bool = false
    @Published var isAnalyzing: Bool = false
    @Published var isLoadingItems: Bool = false // Loading items for selected category
    @Published var totalDiskSize: Int64 = 0
    @Published var usedDiskSize: Int64 = 0
    @Published var selectedItems: Set<UUID> = []
    
    @Published var showDeleteConfirmation: Bool = false
    
    // Error Handling
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    struct AlertItem: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }
    
    @Published var alertItem: AlertItem?
    
    // Tooltip & UX State
    @Published var hoveredItem: StorageItem?
    @Published var tooltipPosition: CGPoint = .zero
    @Published var itemToDelete: StorageItem? // For single item deletion confirmation
    @Published var isDiscardSectionExpanded: Bool = true
    
    enum BottomTab {
        case treemap
        case sunburst
    }
    @Published var selectedBottomTab: BottomTab = .treemap
    
    // Permission state
    @Published var hasFullDiskAccess: Bool = false
    
    // Smart Cache state
    @Published var lastScanDate: Date?
    @Published var isBackgroundRefreshing: Bool = false
    
    private let scanner = DiskScanner.shared
    private let ollamaService = OllamaService.shared
    private let updateService = UpdateService.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var updateAvailable: AppVersion?
    
    // MARK: - Initialization
    init() {
        // Initialize categories
        self.categories = scanner.getCategories()
        
        // Smart Cache: Load previous scan data
        let hasCachedData = loadCachedData()
        
        // If we have valid cached data, skip directly to results!
        // If we have valid cached data, we still load it to be ready,
        // BUT we do NOT skip to results. User wants to see Welcome screen always.
        if hasCachedData && hasValidCache() {
            print("DEBUG: Valid cache found from \(lastScanDate?.description ?? "unknown"). Loading data but staying on Welcome.")
            // Load disk info
            loadDiskInfo()
            // Auto-select first category in background
            if let first = categories.first {
                selectedCategory = first
                currentItems = first.items
            }
            // DISABLED: Do not auto-skip
            // appState = .results
        }
        
        // Observe permission changes
        PermissionManager.shared.$hasFullDiskAccess
            .receive(on: RunLoop.main)
            .sink { [weak self] hasAccess in
                self?.hasFullDiskAccess = hasAccess
            }
            .store(in: &cancellables)
        
        // Initial permission check
        self.hasFullDiskAccess = PermissionManager.shared.hasFullDiskAccess
        
        // Listen for updates
        updateService.$latestVersion
            .receive(on: RunLoop.main)
            .assign(to: \.updateAvailable, on: self)
            .store(in: &cancellables)
    }
    
    private func hasValidCache() -> Bool {
        // Cache is valid if:
        // 1. We have categories with sizes > 0
        // 2. Last scan was within 24 hours (optional, can be adjusted)
        let hasData = categories.contains { $0.size > 0 }
        
        if let lastScan = lastScanDate {
            let hoursSinceLastScan = Date().timeIntervalSince(lastScan) / 3600
            // Consider cache valid for 7 days
            return hasData && hoursSinceLastScan < 168
        }
        
        return hasData
    }
    
    private func loadDiskInfo() {
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()) {
            self.totalDiskSize = (attrs[.systemSize] as? Int64) ?? 0
            let freeSize = (attrs[.systemFreeSize] as? Int64) ?? 0
            self.usedDiskSize = self.totalDiskSize - freeSize
        }
    }
    
    // MARK: - Computed Properties
    
    var selectedItemsCount: Int {
        selectedItems.count
    }
    
    var totalSelectedSize: Int64 {
        allSelectedItems.reduce(0) { $0 + $1.size }
    }
    
    var allSelectedItems: [StorageItem] {
        // We need to look through all categories to find the items that are selected
        categories.flatMap { $0.items }.filter { selectedItems.contains($0.id) }
    }
    
    var formattedSelectedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file)
    }
    
    // MARK: - Persistence
    
    private var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("categories_cache.json")
    }
    
    private var scanDateURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("last_scan_date.txt")
    }
    
    private func saveCachedData() {
        do {
            let data = try JSONEncoder().encode(categories)
            try data.write(to: cacheURL)
            
            // Save scan date
            let dateString = ISO8601DateFormatter().string(from: Date())
            try dateString.write(to: scanDateURL, atomically: true, encoding: .utf8)
            self.lastScanDate = Date()
            
            print("DEBUG: Cache saved with \(categories.count) categories")
        } catch {
            Logger.fileSystem.error("Failed to save cache: \(error.localizedDescription)")
        }
    }
    
    /// Returns true if cache was successfully loaded
    @discardableResult
    private func loadCachedData() -> Bool {
        do {
            guard FileManager.default.fileExists(atPath: cacheURL.path) else { return false }
            let data = try Data(contentsOf: cacheURL)
            let cachedCats = try JSONDecoder().decode([StorageCategory].self, from: data)
            
            // Merge cache with current categories (to keep paths valid but restore sizes and items)
            for i in 0..<categories.count {
                if let cached = cachedCats.first(where: { $0.id == categories[i].id }) {
                    categories[i].size = cached.size
                    categories[i].items = cached.items
                }
            }
            
            // Load last scan date
            if FileManager.default.fileExists(atPath: scanDateURL.path) {
                let dateString = try String(contentsOf: scanDateURL, encoding: .utf8)
                self.lastScanDate = ISO8601DateFormatter().date(from: dateString)
            }
            
            print("DEBUG: Cache loaded successfully. Last scan: \(lastScanDate?.description ?? "unknown")")
            return true
        } catch {
            Logger.fileSystem.warning("Failed to load cache: \(error.localizedDescription)")
            return false
        }
    }
    
    private var loadTask: Task<Void, Never>?
    
    func requestFullDiskAccess() {
        PermissionManager.shared.openSystemSettings()
    }
    
    // MARK: - Public Methods
    
    func selectCategory(_ category: StorageCategory) {
        // Cancel previous loading task prevents piling up requests
        loadTask?.cancel()
        loadTask = nil
        
        print("DEBUG: MainViewModel selecting category: \(category.name) (\(category.id)) path: \(category.path.path)")
        
        // Immediate visual feedback
        Task { [weak self] in
            guard let self = self else { return }
            self.selectedCategory = category
            
            // CACHE HIT: If we already have items, show them immediately
            if !category.items.isEmpty {
                print("DEBUG: Cache hit for \(category.name)")
                self.currentItems = category.items
                self.isLoadingItems = false
                return
            }
            
            // CACHE MISS: Clear items and show loading
            self.currentItems = []
            self.isLoadingItems = true
            
            // Start new task
            self.loadTask = Task { [weak self] in
                await self?.loadItemsForSelectedCategory()
                await MainActor.run {
                    self?.isLoadingItems = false
                }
            }
        }
    }

    func startFullScan() {
        // Transition to scanning state (shows dashboard with progress)
        self.appState = .scanning
        self.scanProgress = 0.0
        self.currentlyScanningCategory = "Initializing..."
        
        Task { [weak self] in
            guard let self = self else { return }
            print("DEBUG: Starting full scan")
            
            // Setup initial categories if empty
            if self.categories.isEmpty {
                self.categories = self.scanner.getCategories()
            }
            
            // Select first if needed
            if self.selectedCategory == nil, let first = self.categories.first {
                self.selectCategory(first)
            }
            
            // Disk Space Info
            if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()) {
                self.totalDiskSize = (attrs[.systemSize] as? Int64) ?? 0
                let freeSize = (attrs[.systemFreeSize] as? Int64) ?? 0
                self.usedDiskSize = self.totalDiskSize - freeSize
            }
            
            self.isScanning = true
            
            // Parallel Scan using TaskGroup
            await withTaskGroup(of: (Int, Int64, [StorageItem]).self) { group in
                for i in 0..<self.categories.count {
                    let index = i
                    let categoryPath = self.categories[index].path
                    let categoryId = self.categories[index].id
                    let categoryName = self.categories[index].name
                    
                    group.addTask {
                        print("DEBUG: [SCAN] Background task started for: \(categoryName)")
                        // Get items and total size in one go
                        let items = await self.scanner.getItems(in: categoryPath, color: CategoryPresenter.hexColor(for: categoryId))
                        let totalSize = items.reduce(0) { $0 + $1.size }
                        return (index, totalSize, items)
                    }
                }
                
                var completedCount = 0
                for await (index, size, items) in group {
                    completedCount += 1
                    let progress = Double(completedCount) / Double(self.categories.count)
                    
                    await MainActor.run {
                        self.categories[index].size = size
                        self.categories[index].items = items
                        self.categories[index].isScanning = false
                        self.scanProgress = progress
                        print("DEBUG: [SCAN] Category '\(self.categories[index].name)' finished. Size: \(size)")
                        
                        // If this was the selected category, update it
                        if self.selectedCategory?.id == self.categories[index].id {
                            self.selectedCategory?.size = size
                            self.selectedCategory?.items = items
                            self.currentItems = items
                        }
                    }
                }
            }
            
            print("DEBUG: All parallel scans finished")
            
            // Artificial delay for UX transitions
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            self.saveCachedData()
            
            // Load largest files (with timeout)
            self.currentlyScanningCategory = "Finding Largest Files..."
            let files = await withTaskGroup(of: [StorageItem]?.self) { group in
                group.addTask { await self.scanner.getLargestFiles() }
                group.addTask {
                    try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                    return nil
                }
                
                // First to finish wins
                if let res = await group.next() { 
                    group.cancelAll()
                    return res ?? [] 
                }
                group.cancelAll()
                return []
            } 
            self.largestFiles = files
            print("DEBUG: Largest files loaded: \(files.count)")
            
            await MainActor.run {
                self.isScanning = false
                self.currentlyScanningCategory = nil
                self.appState = .results
                print("DEBUG: State set to .results")
            }
        }
    }
    
    func loadItemsForSelectedCategory() async {
        guard let category = selectedCategory else {
            print("DEBUG: No category selected")
            return
        }
        
        print("DEBUG: Loading items for category: \(category.name)")
        
        if Task.isCancelled { return }
        
        let items = await scanner.getItems(in: category.path, color: CategoryPresenter.hexColor(for: category.id))
        
        if Task.isCancelled { return }
        
        print("DEBUG: Loaded \(items.count) items for \(category.name)")
        self.currentItems = items
        
        // Save to in-memory cache AND persist to disk
        if let index = self.categories.firstIndex(where: { $0.id == category.id }) {
            self.categories[index].items = items
            if self.selectedCategory?.id == category.id {
                self.selectedCategory?.items = items
            }
            // Persist to disk cache so items are available on next launch
            self.saveCachedData()
        }
    }
    
    func toggleItemSelection(_ item: StorageItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }
    
    func clearSelection() {
        selectedItems.removeAll()
    }
    
    func toggleSelectAll() {
        if areAllItemsSelected {
            // Deselect all items in the CURRENT list
            for item in currentItems {
                selectedItems.remove(item.id)
            }
        } else {
            // Select all items in the CURRENT list
            for item in currentItems {
                selectedItems.insert(item.id)
            }
        }
    }
    
    var areAllItemsSelected: Bool {
        guard !currentItems.isEmpty else { return false }
        // All items in the current view must be in the selection set
        return currentItems.allSatisfy { selectedItems.contains($0.id) }
    }
    
    // MARK: - AI Analysis
    
    func analyzeItem(_ item: StorageItem) {
        Task {
            guard let index = self.currentItems.firstIndex(where: { $0.id == item.id }) else { return }
            
            self.currentItems[index].analysisStatus = .analyzing
            
            // Offload work to background, but file analysis is async anyway
            let analysis = await ollamaService.analyzeFile(
                name: item.name,
                path: item.url.path,
                size: item.size,
                isDirectory: item.isDirectory
            )
            
            // Re-fetch index in case items changed during await
            guard let validIndex = self.currentItems.firstIndex(where: { $0.id == item.id }) else { return }
            
            // Explicitly map the status from Service to Domain Model
            // Since we unified them, we can assign directly if types match, 
            // OR use the rawValue if they are distinct types.
            // OllamaService.FileAnalysis now uses the nested status or the Domain one? 
            // We removed the nested one. So it should be the SAME type.
            self.currentItems[validIndex].analysisStatus = analysis.status
            self.currentItems[validIndex].analysisDescription = analysis.description
            self.currentItems[validIndex].analysisConsequences = analysis.consequences // Map consequences
            self.currentItems[validIndex].safeToDelete = analysis.safeToDelete
        }
    }
    
    func analyzeSelectedItems() {
        isAnalyzing = true
        
        Task {
            let itemsToAnalyze = self.currentItems.filter { self.selectedItems.contains($0.id) }
            
            for item in itemsToAnalyze {
                guard let index = currentItems.firstIndex(where: { $0.id == item.id }) else { continue }
                currentItems[index].analysisStatus = .analyzing
                
                let analysis = await ollamaService.analyzeFile(
                    name: item.name,
                    path: item.url.path,
                    size: item.size,
                    isDirectory: item.isDirectory
                )
                
                if let validIndex = self.currentItems.firstIndex(where: { $0.id == item.id }) {
                    self.currentItems[validIndex].analysisStatus = analysis.status
                    self.currentItems[validIndex].analysisDescription = analysis.description
                    self.currentItems[validIndex].analysisConsequences = analysis.consequences // Map consequences
                    self.currentItems[validIndex].safeToDelete = analysis.safeToDelete
                }
            }
            
            isAnalyzing = false
        }
    }
    
    // MARK: - Delete Operations
    
    func confirmDelete() {
        showDeleteConfirmation = true
    }
    
    func confirmDeleteItem(_ item: StorageItem) {
        self.itemToDelete = item
        self.showDeleteConfirmation = true
    }
    
    func revealInFinder(item: StorageItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }
    
    func deleteSelectedItems() {
        if let singleItem = itemToDelete {
            deleteItem(singleItem)
            itemToDelete = nil
            showDeleteConfirmation = false
            return
        }
        
        let itemsToDelete = currentItems.filter { selectedItems.contains($0.id) }
        var deletedSize: Int64 = 0
        
        for item in itemsToDelete {
            do {
                try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
                Logger.fileSystem.info("Moved to Trash: \(item.url.path)")
                deletedSize += item.size
            } catch {
                Logger.fileSystem.error("Failed to delete: \(error.localizedDescription)")
                self.alertItem = AlertItem(title: "Delete Failed", message: "Could not delete \(item.name): \(error.localizedDescription)")
            }
        }
        
        // Optimistic UI Update (Locally remove items)
        withAnimation {
            self.currentItems.removeAll { selectedItems.contains($0.id) }
            
            // Update Category Size
            if let catID = selectedCategory?.id,
               let index = categories.firstIndex(where: { $0.id == catID }) {
                categories[index].items = currentItems
                categories[index].size -= deletedSize
                // Also update the selectedCategory reference
                selectedCategory?.size -= deletedSize
            }
            
            // Update Totals
            self.usedDiskSize -= deletedSize
        }
        
        // Clear selection
        selectedItems.removeAll()
        showDeleteConfirmation = false
    }
    
    func deleteItem(_ item: StorageItem) {
        do {
            try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
            Logger.fileSystem.info("Moved to Trash: \(item.url.path)")
            
            // Remove from list
            withAnimation {
                currentItems.removeAll { $0.id == item.id }
                selectedItems.remove(item.id)
                
                // Update Category Size
                if let catID = selectedCategory?.id,
                   let index = categories.firstIndex(where: { $0.id == catID }) {
                    categories[index].size -= item.size
                    selectedCategory?.size -= item.size
                }
                
                // Update Totals
                self.usedDiskSize -= item.size
            }
        } catch {
            Logger.fileSystem.error("Failed to delete: \(error.localizedDescription)")
        }
    }
    func backToWelcome() {
        withAnimation {
            appState = .welcome
            currentItems = []
            selectedItems = []
            selectedCategory = nil
            isScanning = false
            scanProgress = 0
            currentlyScanningCategory = nil
        }
    }
    
    func autoSelectSafeItems() {
        withAnimation {
            let safeItems = currentItems.filter { $0.analysisStatus == .safe }
            selectedItems = Set(safeItems.map { $0.id })
        }
    }
}
