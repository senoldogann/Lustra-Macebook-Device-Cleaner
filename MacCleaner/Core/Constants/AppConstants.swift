import Foundation

enum AppConstants {
    enum Paths {
        static let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        static let logs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("Logs")
    }
    
    enum Scan {
        /// Large file threshold (100 MB)
        static let largeFileThreshold: Int64 = 100 * 1024 * 1024
    }
    
    enum AI {
        /// Default Ollama Model
        static let defaultModel = "llama3"
        /// Default Ollama Base URL
        static let defaultBaseURL = "http://localhost:11434/api/generate"
        /// Default Timeout
        static let timeout: TimeInterval = 60
    }
}
