import SwiftUI
import Combine
import os

/// ViewModel responsible for disk scanning operations
/// Extracted from MainViewModel for Single Responsibility Principle
@MainActor
final class ScannerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var scanProgress: Double = 0.0
    @Published var isScanning: Bool = false
    @Published var currentlyScanningCategory: String?
    @Published var categories: [StorageCategory] = []
    @Published var largestFiles: [StorageItem] = []
    
    // Disk Info
    @Published var totalDiskSize: Int64 = 0
    @Published var usedDiskSize: Int64 = 0
    
    // Cache state
    @Published var lastScanDate: Date?
    @Published var isBackgroundRefreshing: Bool = false
    
    private let scanner = DiskScanner.shared
    
    // MARK: - Computed Properties
    
    var hasValidCache: Bool {
        let hasData = categories.contains { $0.size > 0 }
        if let lastScan = lastScanDate {
            let hoursSinceLastScan = Date().timeIntervalSince(lastScan) / 3600
            return hasData && hoursSinceLastScan < 168 // 7 days
        }
        return hasData
    }
    
    // MARK: - Initialization
    
    init() {
        self.categories = scanner.getCategories()
        loadCachedData()
        loadDiskInfo()
    }
    
    // MARK: - Public Methods
    
    func startFullScan() async {
        scanProgress = 0.0
        currentlyScanningCategory = "Initializing..."
        isScanning = true
        
        // Disk Space Info
        loadDiskInfo()
        
        // Parallel Scan using TaskGroup
        await withTaskGroup(of: (Int, Int64, [StorageItem]).self) { group in
            for i in 0..<categories.count {
                let index = i
                let categoryPath = categories[index].path
                let categoryId = categories[index].id
                let categoryName = categories[index].name
                
                group.addTask { [self] in
                    print("DEBUG: [SCAN] Background task started for: \(categoryName)")
                    let items = await scanner.getItems(in: categoryPath, color: CategoryPresenter.hexColor(for: categoryId))
                    let totalSize = items.reduce(0) { $0 + $1.size }
                    return (index, totalSize, items)
                }
            }
            
            var completedCount = 0
            for await (index, size, items) in group {
                completedCount += 1
                let progress = Double(completedCount) / Double(categories.count)
                
                categories[index].size = size
                categories[index].items = items
                categories[index].isScanning = false
                scanProgress = progress
                print("DEBUG: [SCAN] Category '\(categories[index].name)' finished. Size: \(size)")
            }
        }
        
        print("DEBUG: All parallel scans finished")
        
        // Artificial delay for UX transitions
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        saveCachedData()
        
        // Load largest files
        currentlyScanningCategory = "Finding Largest Files..."
        largestFiles = await scanner.getLargestFiles()
        
        isScanning = false
        currentlyScanningCategory = nil
    }
    
    func getItems(for category: StorageCategory) async -> [StorageItem] {
        await scanner.getItems(in: category.path, color: CategoryPresenter.hexColor(for: category.id))
    }
    
    // MARK: - Disk Info
    
    func loadDiskInfo() {
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()) {
            totalDiskSize = (attrs[.systemSize] as? Int64) ?? 0
            let freeSize = (attrs[.systemFreeSize] as? Int64) ?? 0
            usedDiskSize = totalDiskSize - freeSize
        }
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
    
    func saveCachedData() {
        do {
            let data = try JSONEncoder().encode(categories)
            try data.write(to: cacheURL)
            
            let dateString = ISO8601DateFormatter().string(from: Date())
            try dateString.write(to: scanDateURL, atomically: true, encoding: .utf8)
            lastScanDate = Date()
            
            print("DEBUG: Cache saved with \(categories.count) categories")
        } catch {
            Logger.fileSystem.error("Failed to save cache: \(error.localizedDescription)")
        }
    }
    
    @discardableResult
    func loadCachedData() -> Bool {
        do {
            guard FileManager.default.fileExists(atPath: cacheURL.path) else { return false }
            let data = try Data(contentsOf: cacheURL)
            let cachedCats = try JSONDecoder().decode([StorageCategory].self, from: data)
            
            for i in 0..<categories.count {
                if let cached = cachedCats.first(where: { $0.id == categories[i].id }) {
                    categories[i].size = cached.size
                    categories[i].items = cached.items
                }
            }
            
            if FileManager.default.fileExists(atPath: scanDateURL.path) {
                let dateString = try String(contentsOf: scanDateURL, encoding: .utf8)
                lastScanDate = ISO8601DateFormatter().date(from: dateString)
            }
            
            print("DEBUG: Cache loaded successfully. Last scan: \(lastScanDate?.description ?? "unknown")")
            return true
        } catch {
            Logger.fileSystem.warning("Failed to load cache: \(error.localizedDescription)")
            return false
        }
    }
}
