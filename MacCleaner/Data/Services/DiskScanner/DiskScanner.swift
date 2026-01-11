import Foundation
import os

// Models are now in Domain/Models

/// Main scanner that works with REAL home directory (not sandboxed container)
actor DiskScanner {
    
    static let shared = DiskScanner()
    
    /// Get the REAL user home directory (not sandbox container)
    nonisolated var realHomeDirectory: URL {
        // If we have a bookmark-resolved URL from PermissionManager, use it.
        // This is crucial for sandboxed apps.
        if let authorizedHome = PermissionManager.shared.homeDirectory {
            return authorizedHome
        }
        // Fallback (works in non-sandboxed or if TCC allows default home)
        return FileManager.default.homeDirectoryForCurrentUser
    }
    
    /// Get all storage categories with their paths
    nonisolated func getCategories() -> [StorageCategory] {
        let home = realHomeDirectory
        
        return [
            StorageCategory(
                id: "system_junk",
                name: NSLocalizedString("category_system_junk", comment: ""),
                path: home.appendingPathComponent("Library/Caches")
            ),
            StorageCategory(
                id: "user_library",
                name: NSLocalizedString("category_user_library", comment: ""),
                path: home.appendingPathComponent("Library/Application Support")
            ),
            StorageCategory(
                id: "downloads",
                name: NSLocalizedString("category_downloads", comment: ""),
                path: home.appendingPathComponent("Downloads")
            ),
            StorageCategory(
                id: "containers",
                name: NSLocalizedString("category_containers", comment: ""),
                path: home.appendingPathComponent("Library/Containers")
            ),
            StorageCategory(
                id: "desktop",
                name: NSLocalizedString("category_desktop", comment: ""),
                path: home.appendingPathComponent("Desktop")
            ),
            StorageCategory(
                id: "media",
                name: NSLocalizedString("category_media", comment: ""),
                path: home.appendingPathComponent("Movies")
            ),
            StorageCategory(
                id: "documents",
                name: NSLocalizedString("category_documents", comment: ""),
                path: home.appendingPathComponent("Documents")
            ),
            StorageCategory(
                id: "applications",
                name: NSLocalizedString("category_applications", comment: ""),
                path: URL(fileURLWithPath: "/Applications")
            )
        ]
    }

    
    /// Calculate size of a directory - FAST method using 'du' command
    /// This is significantly faster than FileManager for large directories like ~/Library
    nonisolated func calculateDirectorySize(at url: URL, depth: Int = 0) async -> Int64 {
        // Use 'du' for top-level categories (fastest method)
        if depth == 0 {
            return await calculateSizeUsingDu(at: url)
        }
        
        // For deeper recursion, use serial method
        return serialCalculateSize(at: url)
    }
    
    /// Use 'du -sk' command for ultra-fast directory size calculation
    /// 'du' is a highly optimized C program that outperforms FileManager significantly
    private nonisolated func calculateSizeUsingDu(at url: URL) async -> Int64 {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()
                
                process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
                // -s = summarize (total only), -k = kilobytes
                process.arguments = ["-sk", url.path]
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        // Output format: "12345\t/path/to/folder"
                        let components = output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\t")
                        if let sizeInKB = Int64(components.first ?? "0") {
                            let sizeInBytes = sizeInKB * 1024
                            continuation.resume(returning: sizeInBytes)
                            return
                        }
                    }
                    continuation.resume(returning: 0)
                } catch {
                    // Fallback: If 'du' fails, return 0 (or could use serial method)
                    print("DEBUG: du command failed: \(error)")
                    continuation.resume(returning: 0)
                }
            }
        }
    }
    
    /// Use 'du -sk' for multiple URLs in a single process (Massive speedup for directory listings)
    private nonisolated func calculateSizesUsingDu(for urls: [URL]) async -> [URL: Int64] {
        if urls.isEmpty { return [:] }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()
                
                process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
                process.arguments = ["-sk"] + urls.map { $0.path }
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice
                
                var results: [URL: Int64] = [:]
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        let lines = output.components(separatedBy: .newlines)
                        for line in lines {
                            let components = line.components(separatedBy: "\t")
                            if components.count >= 2,
                               let sizeInKB = Int64(components[0]) {
                                let path = components[1]
                                let url = URL(fileURLWithPath: path)
                                results[url] = sizeInKB * 1024
                            }
                        }
                    }
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(returning: [:])
                }
            }
        }
    }
    
    /// Serial scan for subdirectories (recursive via enumerator)
    private nonisolated func serialCalculateSize(at url: URL) -> Int64 {
        var totalSize: Int64 = 0
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isDirectoryKey]
        
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }
        
        for case let fileURL as URL in enumerator {
            if Task.isCancelled { break }
            
            do {
                let values = try fileURL.resourceValues(forKeys: keys)
                if !(values.isDirectory ?? false) {
                    totalSize += Int64(values.fileSize ?? 0)
                }
            } catch {
                continue
            }
        }
        return totalSize
    }
    
    /// Restricted folders that should NEVER be scanned or deleted
    /// These are typically SIP-protected or system-critical caches that cause permission errors
    private let restrictedCaches: Set<String> = [
        "com.apple.findmy.fmipcore",
        "com.apple.HomeKit",
        "com.apple.CloudKit",
        "com.apple.ap.adprivacyd",
        "com.apple.homed",
        "com.apple.Music", // Often causes issues if Music is open
        "FamilyCircle" // System protected folder
    ]

    /// Get top-level items in a directory with their sizes
    nonisolated func getItems(in url: URL, color: String = "4D4C48", limit: Int = 100) async -> [StorageItem] {
        print("DEBUG: Getting items for \(url.path)")
        
        guard FileManager.default.isReadableFile(atPath: url.path) else { return [] }
        
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey]
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles]
            )
            
            // Filter out restricted caches if we are in Library/Caches
            let isCacheFolder = url.path.hasSuffix("Library/Caches")
            let filteredContents = contents.filter { url in
                if isCacheFolder {
                    return !restrictedCaches.contains(url.lastPathComponent)
                }
                return true
            }
            
            let sortedContents = filteredContents.prefix(limit)
            let directoryURLs = sortedContents.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false }
            
            // Batch calculate directory sizes
            let dirSizes = await calculateSizesUsingDu(for: Array(directoryURLs))
            
            var items: [StorageItem] = []
            for itemURL in sortedContents {
                do {
                    let values = try itemURL.resourceValues(forKeys: keys)
                    let isDir = values.isDirectory ?? false
                    let size = isDir ? (dirSizes[itemURL] ?? 0) : Int64(values.fileSize ?? 0)
                    
                    var item = StorageItem(
                        url: itemURL,
                        name: itemURL.lastPathComponent,
                        size: size,
                        modificationDate: values.contentModificationDate,
                        isDirectory: isDir
                    )
                    item.color = color
                    items.append(item)
                } catch { continue }
            }
            
            return items.sorted { $0.size > $1.size }
        } catch {
            return []
        }
    }
    
    /// Get largest files across common directories
    nonisolated func getLargestFiles(limit: Int = 20) async -> [StorageItem] {
        let home = realHomeDirectory
        
        let searchPaths = [
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Movies"),
            home.appendingPathComponent("Music"),
            home.appendingPathComponent("Library/Application Support")
        ]
        
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey]
        let threshold: Int64 = 100 * 1024 * 1024 // Increased to 100 MB for "Largest Files"
        
        return await withTaskGroup(of: [StorageItem].self) { group in
            for searchPath in searchPaths {
                group.addTask {
                    var files: [StorageItem] = []
                    let fileManager = FileManager.default
                    guard fileManager.isReadableFile(atPath: searchPath.path) else { return [] }
                    
                    guard let enumerator = fileManager.enumerator(
                        at: searchPath,
                        includingPropertiesForKeys: Array(keys),
                        options: [.skipsHiddenFiles, .skipsPackageDescendants]
                    ) else { return [] }
                    
                    for case let fileURL as URL in enumerator {
                        if Task.isCancelled { break }
                        
                        do {
                            let values = try fileURL.resourceValues(forKeys: keys)
                            let isDir = values.isDirectory ?? false
                            let size = Int64(values.fileSize ?? 0)
                            
                            if !isDir && size > threshold {
                                files.append(StorageItem(
                                    url: fileURL,
                                    name: fileURL.lastPathComponent,
                                    size: size,
                                    modificationDate: values.contentModificationDate,
                                    isDirectory: false
                                ))
                            }
                        } catch { continue }
                    }
                    return files
                }
            }
            
            var allFiles: [StorageItem] = []
            for await files in group {
                allFiles.append(contentsOf: files)
            }
            
            return Array(allFiles.sorted { $0.size > $1.size }.prefix(limit))
        }
    }
}
