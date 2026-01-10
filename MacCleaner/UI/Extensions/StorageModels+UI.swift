import Foundation

extension StorageItem {
    // Color is now a stored property in the model, assigned by DiskScanner
}

extension AnalysisStatus {
    var color: String {
        switch self {
        case .safe: return "green"
        case .review: return "orange"
        case .notAnalyzed, .analyzing, .unknown: return "gray"
        }
    }
}
