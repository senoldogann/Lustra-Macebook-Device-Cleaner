import Foundation
import AppKit
import Combine
import os

final class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    private let bookmarksKey = "securityScopedBookmarks"
    
    @Published var hasFullDiskAccess: Bool = false
    @Published var homeDirectory: URL?
    
    init() {
        restoreBookmarks()
    }
    
    /// Checks if we can read the user's home directory and sensitive folders
    func checkHomeAccess() -> Bool {
        let home = homeDirectory ?? FileManager.default.homeDirectoryForCurrentUser
        let isReadable = FileManager.default.isReadableFile(atPath: home.path)
        
        // Check for Full Disk Access indicator
        self.hasFullDiskAccess = checkFullDiskAccess()
        
        Logger.lifecycle.info("Home directory access check: \(isReadable), FDA: \(self.hasFullDiskAccess)")
        
        if isReadable {
            self.homeDirectory = home
        }
        return isReadable
    }
    
    /// Checks if the app has Full Disk Access by trying to read a protected directory
    func checkFullDiskAccess() -> Bool {
        let home = homeDirectory ?? FileManager.default.homeDirectoryForCurrentUser
        
        // Standard protected directories that are unreadable in sandbox without FDA or specific bookmarks
        let library = home.appendingPathComponent("Library")
        
        // In a sandboxed app, even with home directory permission, some subfolders stay restricted
        // unless FDA is granted.
        let isLibraryReadable = FileManager.default.isReadableFile(atPath: library.path)
        
        return isLibraryReadable
    }
    
    func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
    
    /// Requests access to a folder via Open Panel
    @MainActor
    func requestAccess(initialDirectory: URL? = nil) async -> Bool {
        let openPanel = NSOpenPanel()
        openPanel.message = "Please grant access to your Home folder to scan for junk."
        openPanel.prompt = "Grant Access"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = false
        openPanel.allowsMultipleSelection = false
        if let initialDirectory = initialDirectory {
            openPanel.directoryURL = initialDirectory
        }
        
        let response = await openPanel.begin()
        
        if response == .OK, let url = openPanel.url {
            saveBookmark(for: url)
            return checkHomeAccess()
        }
        return false
    }
    
    // MARK: - Bookmark Handling
    
    private func saveBookmark(for url: URL) {
        do {
            let data = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: bookmarksKey)
            Logger.lifecycle.info("Saved security scoped bookmark for \(url.path)")
            // Immediately start accessing
            startAccessing(url: url)
        } catch {
            Logger.lifecycle.error("Failed to save bookmark: \(error.localizedDescription)")
        }
    }
    
    private func restoreBookmarks() {
        guard let data = UserDefaults.standard.data(forKey: bookmarksKey) else { return }
        
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                Logger.lifecycle.warning("Bookmark is stale, need to save again")
                saveBookmark(for: url)
            }
            
            startAccessing(url: url)
            _ = checkHomeAccess()
            
        } catch {
            Logger.lifecycle.error("Failed to resolve bookmark: \(error.localizedDescription)")
        }
    }
    
    private func startAccessing(url: URL) {
        let success = url.startAccessingSecurityScopedResource()
        if success {
            Logger.lifecycle.info("Successfully started accessing security scoped resource: \(url.path)")
            self.homeDirectory = url
        } else {
            Logger.lifecycle.error("Failed to start accessing security scoped resource: \(url.path)")
        }
    }
    
    deinit {
        homeDirectory?.stopAccessingSecurityScopedResource()
    }
}
