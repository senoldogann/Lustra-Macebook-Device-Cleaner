import Foundation
import os

// Models are now in Domain/Models

/// Main scanner that works with REAL home directory (not sandboxed container)
actor DiskScanner {
    
    static let shared = DiskScanner()
    
    private let fileManager = FileManager.default
    
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
                name: "System Junk",
                icon: "gearshape.2.fill",
                path: home.appendingPathComponent("Library/Caches"),
                color: "D97757" // Terracotta
            ),
            StorageCategory(
                id: "user_library",
                name: "User Library",
                icon: "folder.fill",
                path: home.appendingPathComponent("Library"),
                color: "4A90E2" // Blue
            ),
            StorageCategory(
                id: "downloads",
                name: "Downloads",
                icon: "arrow.down.circle.fill",
                path: home.appendingPathComponent("Downloads"),
                color: "7ED321" // Green
            ),
            StorageCategory(
                id: "desktop",
                name: "Desktop",
                icon: "desktopcomputer",
                path: home.appendingPathComponent("Desktop"),
                color: "BD10E0" // Purple
            ),
            StorageCategory(
                id: "documents",
                name: "Documents",
                icon: "doc.fill",
                path: home.appendingPathComponent("Documents"),
                color: "F5A623" // Orange
            ),
            StorageCategory(
                id: "applications",
                name: "Applications",
                icon: "app.fill",
                path: URL(fileURLWithPath: "/Applications"),
                color: "50E3C2" // Teal
            ),
            StorageCategory(
                id: "other",
                name: "Other",
                icon: "questionmark.folder.fill",
                path: home,
                color: "4D4C48" // Gray
            ),
            StorageCategory(
                id: "system",
                name: "System",
                icon: "internaldrive.fill",
                path: URL(fileURLWithPath: "/System"),
                color: "D0021B" // Red
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
    
    /// Serial scan for subdirectories (recursive via enumerator)
    private nonisolated func serialCalculateSize(at url: URL) -> Int64 {
        var totalSize: Int64 = 0
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isDirectoryKey]
        
        guard let enumerator = fileManager.enumerator(
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
    
    /// Get top-level items in a directory with their sizes
    nonisolated func getItems(in url: URL, color: String = "4D4C48", limit: Int = 100) async -> [StorageItem] {
        print("DEBUG: Getting items for \(url.path)")
        
        guard fileManager.isReadableFile(atPath: url.path) else {
            print("DEBUG: Path not readable: \(url.path)")
            return []
        }
        
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey]
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles]
            )
            
            print("DEBUG: Found \(contents.count) items in raw scan")
            let limitedContents = Array(contents.prefix(limit))
            
            return await withTaskGroup(of: StorageItem?.self) { group in
                for itemURL in limitedContents {
                    group.addTask {
                        if Task.isCancelled { return nil }
                        
                        // Yield occasionally to prevent blocking the thread pool
                        await Task.yield()
                        
                        do {
                            let values = try itemURL.resourceValues(forKeys: keys)
                            let isDir = values.isDirectory ?? false
                            
                            var size: Int64 = 0
                            if isDir {
                                // For directories, calculate total size concurrently
                                size = await self.calculateDirectorySize(at: itemURL)
                            } else {
                                size = Int64(values.fileSize ?? 0)
                            }
                            
                            var item = StorageItem(
                                url: itemURL,
                                name: itemURL.lastPathComponent,
                                size: size,
                                modificationDate: values.contentModificationDate,
                                isDirectory: isDir
                            )
                            item.color = color
                            return item
                        } catch {
                            // print("DEBUG: Failed to get attributes for \(itemURL.lastPathComponent): \(error)")
                            return nil
                        }
                    }
                }
                
                var items: [StorageItem] = []
                for await item in group {
                    if let item = item {
                        items.append(item)
                    }
                }
                
                return items.sorted { $0.size > $1.size }
            }
        } catch {
            print("DEBUG: Failed to list directory contents: \(error)")
            Logger.scan.error("Failed to list directory: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Get largest files across common directories
    nonisolated func getLargestFiles(limit: Int = 20) async -> [StorageItem] {
        var allFiles: [StorageItem] = []
        let home = realHomeDirectory
        
        let searchPaths = [
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Movies"),
            home.appendingPathComponent("Music")
        ]
        
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey]
        let threshold: Int64 = 50 * 1024 * 1024 // 50 MB
        
        for searchPath in searchPaths {
            guard fileManager.isReadableFile(atPath: searchPath.path) else { continue }
            
            guard let enumerator = fileManager.enumerator(
                at: searchPath,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            
            for case let fileURL as URL in enumerator {
                if Task.isCancelled { break }
                
                do {
                    let values = try fileURL.resourceValues(forKeys: keys)
                    let isDir = values.isDirectory ?? false
                    let size = Int64(values.fileSize ?? 0)
                    
                    if !isDir && size > threshold {
                        let item = StorageItem(
                            url: fileURL,
                            name: fileURL.lastPathComponent,
                            size: size,
                            modificationDate: values.contentModificationDate,
                            isDirectory: false
                        )
                        allFiles.append(item)
                    }
                } catch {
                    // Skip
                }
            }
        }
        
        // Sort by size and return top N
        return Array(allFiles.sorted { $0.size > $1.size }.prefix(limit))
    }
}
