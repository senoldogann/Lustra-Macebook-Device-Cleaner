import Foundation

/// Storage category for sidebar display
struct StorageCategory: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let path: URL
    var size: Int64 = 0
    var isScanning: Bool = false
    var items: [StorageItem] = []
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
