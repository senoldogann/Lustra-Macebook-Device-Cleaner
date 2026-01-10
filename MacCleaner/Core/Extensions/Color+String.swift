import SwiftUI

extension Color {
    static func from(string: String) -> Color {
        switch string.lowercased() {
        // High attention / Accent
        case "pink", "red", "orange", "yellow", "primary":
            return AppTheme.terracotta
            
        // Darker Tones
        case "blue", "indigo", "purple", "black":
            return AppTheme.darkerGray
            
        // Lighter/Neutral Tones
        case "green", "mint", "teal", "cyan", "gray", "secondary":
            return AppTheme.darkGray
            
        case "white":
            return AppTheme.cream
            
        default:
            return AppTheme.terracotta
        }
    }
}
