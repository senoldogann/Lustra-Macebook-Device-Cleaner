import Foundation

/// Analysis status for a file
enum AnalysisStatus: String, Equatable, Codable, Sendable {
    case notAnalyzed = "Not analyzed"
    case analyzing = "Analyzing..."
    case safe = "safe"
    case review = "review"
    case unknown = "unknown"
}
