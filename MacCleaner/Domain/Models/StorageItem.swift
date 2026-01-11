import Foundation

/// Individual file/folder item
struct StorageItem: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let url: URL
    let name: String
    let size: Int64
    let modificationDate: Date?
    let isDirectory: Bool
    var color: String = "4D4C48" // Default hex color
    var isSelected: Bool = false
    
    // AI Analysis
    var analysisStatus: AnalysisStatus = .notAnalyzed
    var analysisDescription: String = ""
    var analysisConsequences: String = "" // Added for detailed AI consequences
    var safeToDelete: Bool = false
    
    init(url: URL, name: String, size: Int64, modificationDate: Date?, isDirectory: Bool) {
        self.id = UUID()
        self.url = url
        self.name = name
        self.size = size
        self.modificationDate = modificationDate
        self.isDirectory = isDirectory
    }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = .current // Ensure it uses current locale
        return formatter
    }()
    
    var formattedDate: String {
        guard let date = modificationDate else { return "-" }
        return Self.dateFormatter.string(from: date)
    }
    
}
