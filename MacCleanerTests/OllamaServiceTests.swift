import XCTest
@testable import MacCleaner

/// Unit tests for OllamaService functionality
final class OllamaServiceTests: XCTestCase {
    
    // MARK: - FileAnalysis Model Tests
    
    func testFileAnalysisDecoding() throws {
        // Given
        let json = """
        {
            "status": "safe",
            "description": "Test description",
            "consequences": "No consequences",
            "safeToDelete": true
        }
        """
        let data = json.data(using: .utf8)!
        
        // When
        let analysis = try JSONDecoder().decode(FileAnalysis.self, from: data)
        
        // Then
        XCTAssertEqual(analysis.status, .safe)
        XCTAssertEqual(analysis.description, "Test description")
        XCTAssertEqual(analysis.consequences, "No consequences")
        XCTAssertTrue(analysis.safeToDelete)
    }
    
    func testFileAnalysisDecodingWithReviewStatus() throws {
        // Given
        let json = """
        {
            "status": "review",
            "description": "System file",
            "consequences": "App may crash",
            "safeToDelete": false
        }
        """
        let data = json.data(using: .utf8)!
        
        // When
        let analysis = try JSONDecoder().decode(FileAnalysis.self, from: data)
        
        // Then
        XCTAssertEqual(analysis.status, .review)
        XCTAssertFalse(analysis.safeToDelete)
    }
    
    // MARK: - AnalysisStatus Tests
    
    func testAnalysisStatusEquality() {
        // Given
        let safe1 = AnalysisStatus.safe
        let safe2 = AnalysisStatus.safe
        let review = AnalysisStatus.review
        
        // Then
        XCTAssertEqual(safe1, safe2, "Same status should be equal")
        XCTAssertNotEqual(safe1, review, "Different statuses should not be equal")
    }
    
    func testAnalysisStatusCases() {
        // Verify all expected cases exist
        let cases: [AnalysisStatus] = [.notAnalyzed, .analyzing, .safe, .review, .unknown]
        XCTAssertEqual(cases.count, 5, "Should have 5 analysis status cases")
    }
}
