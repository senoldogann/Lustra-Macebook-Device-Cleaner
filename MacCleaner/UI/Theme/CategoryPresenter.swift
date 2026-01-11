import SwiftUI

/// UI Presenter for StorageCategory styling
/// This separates UI concerns (colors, icons) from the Data layer
enum CategoryPresenter {
    
    /// Returns the Color for a given category ID
    static func color(for categoryId: String) -> Color {
        switch categoryId {
        case "system_junk":
            return Color(hex: "D97757") // Terracotta
        case "user_library":
            return Color(hex: "4A90E2") // Blue
        case "downloads":
            return Color(hex: "7ED321") // Green
        case "containers":
            return Color(hex: "9B59B6") // Amethyst Purple
        case "desktop":
            return Color(hex: "AAB7B8") // Silver/Gray
        case "media":
            return Color(hex: "BD10E0") // Purple
        case "documents":
            return Color(hex: "F5A623") // Orange
        case "applications":
            return Color(hex: "50E3C2") // Teal
        default:
            return Color(hex: "4D4C48") // Default gray
        }
    }
    
    /// Returns the hex color string for a given category ID
    static func hexColor(for categoryId: String) -> String {
        switch categoryId {
        case "system_junk": return "D97757"
        case "user_library": return "4A90E2"
        case "downloads": return "7ED321"
        case "containers": return "9B59B6"
        case "desktop": return "AAB7B8"
        case "media": return "BD10E0"
        case "documents": return "F5A623"
        case "applications": return "50E3C2"
        default: return "4D4C48"
        }
    }
    
    /// Returns the SF Symbol icon name for a given category ID
    static func icon(for categoryId: String) -> String {
        switch categoryId {
        case "system_junk": return "gearshape.2.fill"
        case "user_library": return "folder.fill"
        case "downloads": return "arrow.down.circle.fill"
        case "containers": return "archivebox.fill"
        case "desktop": return "desktopcomputer"
        case "media": return "film.fill"
        case "documents": return "doc.fill"
        case "applications": return "app.fill"
        default: return "folder"
        }
    }
}
