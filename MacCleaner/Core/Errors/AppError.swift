import Foundation

enum AppError: LocalizedError, Equatable, Identifiable {
    case permissionDenied(path: String)
    case fileLocked(path: String)
    case scanFailed(reason: String)
    case diskAccessRequired
    case unknown(String)
    
    var id: String {
        switch self {
        case .permissionDenied(let path): return "permissionDenied_\(path)"
        case .fileLocked(let path): return "fileLocked_\(path)"
        case .scanFailed(let reason): return "scanFailed_\(reason)"
        case .diskAccessRequired: return "diskAccessRequired"
        case .unknown(let msg): return "unknown_\(msg)"
        }
    }

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let path):
            return "Permission denied for: \(path)"
        case .fileLocked(let path):
             return "File is locked or in use: \(path)"
        case .scanFailed(let reason):
            return "Scan failed: \(reason)"
        case .diskAccessRequired:
            return "Full Disk Access is required to scan this location."
        case .unknown(let msg):
            return "An unknown error occurred: \(msg)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied, .diskAccessRequired:
            return "Please grant access in System Settings."
        default:
            return "Try again later."
        }
    }
}
