import XCTest
@testable import MacCleaner

/// Unit tests for DiskScanner functionality
final class DiskScannerTests: XCTestCase {
    
    // MARK: - Category Tests
    
    func testGetCategoriesReturnsExpectedCount() async {
        // Given
        let scanner = DiskScanner.shared
        
        // When
        let categories = scanner.getCategories()
        
        // Then
        XCTAssertEqual(categories.count, 8, "Should return 8 storage categories")
    }
    
    func testCategoriesHaveValidIds() {
        // Given
        let scanner = DiskScanner.shared
        let expectedIds = [
            "system_junk",
            "user_library", 
            "downloads",
            "containers",
            "desktop",
            "media",
            "documents",
            "applications"
        ]
        
        // When
        let categories = scanner.getCategories()
        let actualIds = categories.map { $0.id }
        
        // Then
        XCTAssertEqual(Set(actualIds), Set(expectedIds), "Category IDs should match expected values")
    }
    
    func testCategoriesHaveValidPaths() {
        // Given
        let scanner = DiskScanner.shared
        
        // When
        let categories = scanner.getCategories()
        
        // Then
        for category in categories {
            XCTAssertFalse(category.path.path.isEmpty, "Category \(category.id) should have a valid path")
        }
    }
    
    func testCategoriesHaveNames() {
        // Given
        let scanner = DiskScanner.shared
        
        // When
        let categories = scanner.getCategories()
        
        // Then
        for category in categories {
            XCTAssertFalse(category.name.isEmpty, "Category \(category.id) should have a name")
        }
    }
    
    // MARK: - Size Calculation Tests
    
    func testCalculateDirectorySizeForInvalidPath() async {
        // Given
        let scanner = DiskScanner.shared
        let invalidURL = URL(fileURLWithPath: "/nonexistent/path/that/does/not/exist")
        
        // When
        let size = await scanner.calculateDirectorySize(at: invalidURL)
        
        // Then
        XCTAssertEqual(size, 0, "Size of nonexistent directory should be 0")
    }
    
    func testCalculateDirectorySizeForTempDirectory() async {
        // Given
        let scanner = DiskScanner.shared
        let tempURL = FileManager.default.temporaryDirectory
        
        // When
        let size = await scanner.calculateDirectorySize(at: tempURL)
        
        // Then
        // Temp directory should exist and have some size (or 0 if empty)
        XCTAssertGreaterThanOrEqual(size, 0, "Size should be non-negative")
    }
}
