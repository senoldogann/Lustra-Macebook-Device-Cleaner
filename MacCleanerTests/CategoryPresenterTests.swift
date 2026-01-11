import XCTest
@testable import MacCleaner

/// Unit tests for CategoryPresenter UI mapping
final class CategoryPresenterTests: XCTestCase {
    
    // MARK: - Color Tests
    
    func testColorMappingForAllCategories() {
        // Given
        let categoryIds = [
            "system_junk",
            "user_library",
            "downloads",
            "containers",
            "desktop",
            "media",
            "documents",
            "applications"
        ]
        
        // When/Then
        for id in categoryIds {
            let hexColor = CategoryPresenter.hexColor(for: id)
            XCTAssertFalse(hexColor.isEmpty, "Category \(id) should have a hex color")
            XCTAssertEqual(hexColor.count, 6, "Hex color should be 6 characters")
        }
    }
    
    func testDefaultColorForUnknownCategory() {
        // Given
        let unknownId = "unknown_category_123"
        
        // When
        let hexColor = CategoryPresenter.hexColor(for: unknownId)
        
        // Then
        XCTAssertEqual(hexColor, "4D4C48", "Unknown category should return default gray color")
    }
    
    // MARK: - Icon Tests
    
    func testIconMappingForAllCategories() {
        // Given
        let categoryIds = [
            "system_junk",
            "user_library",
            "downloads",
            "containers",
            "desktop",
            "media",
            "documents",
            "applications"
        ]
        
        // When/Then
        for id in categoryIds {
            let icon = CategoryPresenter.icon(for: id)
            XCTAssertFalse(icon.isEmpty, "Category \(id) should have an icon")
        }
    }
    
    func testDefaultIconForUnknownCategory() {
        // Given
        let unknownId = "unknown_category_456"
        
        // When
        let icon = CategoryPresenter.icon(for: unknownId)
        
        // Then
        XCTAssertEqual(icon, "folder", "Unknown category should return default folder icon")
    }
    
    // MARK: - Specific Category Tests
    
    func testSystemJunkMapping() {
        XCTAssertEqual(CategoryPresenter.hexColor(for: "system_junk"), "D97757")
        XCTAssertEqual(CategoryPresenter.icon(for: "system_junk"), "gearshape.2.fill")
    }
    
    func testDownloadsMapping() {
        XCTAssertEqual(CategoryPresenter.hexColor(for: "downloads"), "7ED321")
        XCTAssertEqual(CategoryPresenter.icon(for: "downloads"), "arrow.down.circle.fill")
    }
}
