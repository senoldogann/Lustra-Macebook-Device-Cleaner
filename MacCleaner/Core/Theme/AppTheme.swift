import SwiftUI

struct AppTheme {
    // FAF9F6 , 1F1E1D , 4D4C48 , 30302E , D97757
    
    static let cream = Color(hex: "FAF9F6")
    static let almostBlack = Color(hex: "1F1E1D")
    static let darkGray = Color(hex: "4D4C48")
    static let darkerGray = Color(hex: "30302E")
    static let terracotta = Color(hex: "D97757")
    
    // Semantic Roles
    static let background = almostBlack
    static let sidebarBackground = almostBlack
    
    static let primaryText = cream
    static let secondaryText = cream.opacity(0.6)
    
    static let accent = terracotta
    static let cardBackground = darkerGray
    static let rowHover = Color.white.opacity(0.1)
    
    // Status Colors (Matching reference style but using our tones)
    static let safe = Color(hex: "4CAF50") // Vibrant green
    static let review = Color(hex: "FF9800") // Vibrant orange
    
    // Treemap Palette - Colorful but harmonious with the dark theme
    static let treemapPalette: [Color] = [
        Color(hex: "D97457"), // Terracotta
        Color(hex: "4A90E2"), // Blue
        Color(hex: "7ED321"), // Light Green
        Color(hex: "F5A623"), // Orange
        Color(hex: "BD10E0"), // Purple
        Color(hex: "50E3C2"), // Teal
        Color(hex: "F8E71C"), // Yellow
        Color(hex: "D0021B")  // Red
    ]
    
    // Strict Palette Array
    static let palette: [Color] = [cream, almostBlack, darkGray, darkerGray, terracotta]
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
