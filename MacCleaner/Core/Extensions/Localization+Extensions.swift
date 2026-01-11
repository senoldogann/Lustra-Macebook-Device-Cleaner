import Foundation

/// String extension for easy localization
extension String {
    /// Returns the localized version of the string
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
    
    /// Returns the localized version with format arguments
    func localized(with arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}

/// Type-safe localization keys
enum L10n {
    // MARK: - General
    static let appName = "app.name".localized
    static let appTagline = "app.tagline".localized
    
    // MARK: - Welcome
    enum Welcome {
        static let title = "welcome.title".localized
        static let subtitle = "welcome.subtitle".localized
        static let startScan = "welcome.startScan".localized
        static let scanDescription = "welcome.scanDescription".localized
    }
    
    // MARK: - Scanning
    enum Scan {
        static let initializing = "scan.initializing".localized
        static let findingLargestFiles = "scan.findingLargestFiles".localized
        static let complete = "scan.complete".localized
    }
    
    // MARK: - Smart Check
    enum SmartCheck {
        static let title = "smartCheck.title".localized
        static let notAnalyzed = "smartCheck.notAnalyzed".localized
        static let analyzing = "smartCheck.analyzing".localized
        static let safe = "smartCheck.safe".localized
        static let review = "smartCheck.review".localized
        static let unknown = "smartCheck.unknown".localized
        static let consequences = "smartCheck.consequences".localized
        static let safeToDelete = "smartCheck.safeToDelete".localized
        static let yes = "smartCheck.yes".localized
        static let no = "smartCheck.no".localized
        static let recommendation = "smartCheck.recommendation".localized
        static let noFeedback = "smartCheck.noFeedback".localized
    }
    
    // MARK: - Actions
    enum Action {
        static let delete = "action.delete".localized
        static let cancel = "action.cancel".localized
        static let selectAll = "action.selectAll".localized
        static let deselectAll = "action.deselectAll".localized
        static let analyze = "action.analyze".localized
        static let refresh = "action.refresh".localized
    }
    
    // MARK: - Confirmation
    enum Confirm {
        static let deleteTitle = "confirm.deleteTitle".localized
        
        static func deleteSingle(name: String) -> String {
            "confirm.deleteSingle".localized(with: name)
        }
        
        static func deleteMultiple(count: Int, size: String) -> String {
            "confirm.deleteMultiple".localized(with: count, size)
        }
    }
}
