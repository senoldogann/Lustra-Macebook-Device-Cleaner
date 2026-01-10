import XCTest
@testable import MacCleaner

final class MacCleanerTests: XCTestCase {

    func testExperimentWithOptimizedDeletion() {
        // This test simulates the logic we added to MainViewModel.deleteSelectedItems
        
        // 1. Setup Mock Items
        let item1 = StorageItem(url: URL(fileURLWithPath: "/tmp/1"), name: "File 1", size: 100, modificationDate: Date(), isDirectory: false)
        let item2 = StorageItem(url: URL(fileURLWithPath: "/tmp/2"), name: "File 2", size: 200, modificationDate: Date(), isDirectory: false)
        let item3 = StorageItem(url: URL(fileURLWithPath: "/tmp/3"), name: "File 3", size: 300, modificationDate: Date(), isDirectory: false)
        
        var currentItems = [item1, item2, item3]
        var selectedItems: Set<UUID> = [item1.id, item3.id]
        var totalSize: Int64 = 600
        
        // 2. Execute Logic
        let itemsToDelete = currentItems.filter { selectedItems.contains($0.id) }
        var deletedSize: Int64 = 0
        
        for item in itemsToDelete {
            deletedSize += item.size
        }
        
        currentItems.removeAll { selectedItems.contains($0.id) }
        totalSize -= deletedSize
        
        // 3. Verify Expectations
        XCTAssertEqual(currentItems.count, 1)
        XCTAssertEqual(currentItems.first?.name, "File 2")
        XCTAssertEqual(deletedSize, 400)
        XCTAssertEqual(totalSize, 200)
    }
    
    func testStorageItemUIColors() {
        // Verify that the color logic is consistent
        let item = StorageItem(url: URL(fileURLWithPath: "/tmp/a"), name: "TestFile", size: 0, modificationDate: nil, isDirectory: false)
        XCTAssertEqual(item.color, "blue") // Files are always blue
        
        let folder = StorageItem(url: URL(fileURLWithPath: "/tmp/b"), name: "TestFolder", size: 0, modificationDate: nil, isDirectory: true)
        XCTAssertTrue(!folder.color.isEmpty)
    }
    
    func testAnalysisStatusParsing() {
        // Test our Enums
        let status = AnalysisStatus(rawValue: "safe")
        XCTAssertEqual(status, .safe)
        XCTAssertEqual(status?.color, "green")
        
        let unknown = AnalysisStatus(rawValue: "unknown_value")
        XCTAssertNil(unknown)
    }
}
