import Foundation
import os

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.maccleaner.app"

    /// Logs related to the scanning engine
    static let scan = Logger(subsystem: subsystem, category: "scan")
    
    /// Logs related to user interface
    static let ui = Logger(subsystem: subsystem, category: "ui")
    
    /// Logs related to file system operations (read/delete)
    static let fileSystem = Logger(subsystem: subsystem, category: "fileSystem")
    
    /// Logs related to app lifecycle and permissions
    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
}
