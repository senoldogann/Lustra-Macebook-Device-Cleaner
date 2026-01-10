import Foundation

/// Storage category for sidebar display
struct StorageCategory: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let icon: String // SF Symbol name - debatable if UI or Data, but usually Icon name is data in modern apps.
    let path: URL
    let color: String // Hex color string
    var size: Int64 = 0
    var isScanning: Bool = false
    var items: [StorageItem] = []
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
