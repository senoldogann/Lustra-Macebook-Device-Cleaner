import Foundation
import Combine
import AppKit
import OSLog

struct AppVersion: Codable {
    let version: String
    let title: String
    let notes: String
    let downloadURL: String
}

class UpdateService: ObservableObject {
    static let shared = UpdateService()
    
    @Published var latestVersion: AppVersion?
    @Published var isUpdateAvailable: Bool = false
    
    // GitHub clean raw content URL (Open Source)
    private let updateURL = URL(string: "https://raw.githubusercontent.com/senoldogann/Lustra-Macebook-Device-Cleaner/main/appcast.json")!
    
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MacCleaner", category: "UpdateService")
    
    private init() {
        checkForUpdates()
    }
    
    func checkForUpdates() {
        logger.info("Checking for updates at \(self.updateURL.absoluteString)")
        
        URLSession.shared.dataTask(with: updateURL) { data, response, error in
            if let error = error {
                self.logger.error("Network error: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                self.logger.error("No data received")
                return
            }
            
            do {
                let versionInfo = try JSONDecoder().decode(AppVersion.self, from: data)
                DispatchQueue.main.async {
                    self.validateVersion(versionInfo)
                }
            } catch {
                self.logger.error("JSON Decode Error: \(error.localizedDescription)")
                if let rawString = String(data: data, encoding: .utf8) {
                    self.logger.debug("Raw response: \(rawString)")
                }
            }
        }.resume()
    }
    
    private func validateVersion(_ remoteVersion: AppVersion) {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        logger.info("Comparing versions - Remote: \(remoteVersion.version), Local: \(currentVersion)")
        
        if remoteVersion.version.compare(currentVersion, options: .numeric) == .orderedDescending {
            logger.notice("New update available: \(remoteVersion.version)")
            self.latestVersion = remoteVersion
            self.isUpdateAvailable = true
        } else {
            logger.info("App is up to date.")
        }
    }
    
    func downloadAndInstall() {
        guard let urlString = latestVersion?.downloadURL, let url = URL(string: urlString) else { return }
        logger.notice("Starting seamless update download from \(urlString)")
        
        // 1. Download to temporary file
        let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
            guard let localURL = localURL, error == nil else {
                self.logger.error("Download failed: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            do {
                let tempDir = FileManager.default.temporaryDirectory
                let targetURL = tempDir.appendingPathComponent("LustraUpdate.dmg")
                
                // Remove existing file if present
                try? FileManager.default.removeItem(at: targetURL)
                try FileManager.default.moveItem(at: localURL, to: targetURL)
                
                self.logger.info("Downloaded update to \(targetURL.path)")
                
                // 2. Execute Shell Script
                try self.runUpdaterScript(dmgPath: targetURL.path)
                
            } catch {
                self.logger.error("Update installation failed: \(error.localizedDescription)")
            }
        }
        task.resume()
    }
    
    private func runUpdaterScript(dmgPath: String) throws {
        // 1. Write Embedded Script to Temp Directory
        let tempDir = FileManager.default.temporaryDirectory
        let scriptPath = tempDir.appendingPathComponent("UpdaterScript.sh")
        
        do {
            try updaterScript.write(to: scriptPath, atomically: true, encoding: .utf8)
            // Make executable
            try FileManager.default.setAttributes([.posixPermissions: 0o777], ofItemAtPath: scriptPath.path)
        } catch {
            logger.error("Failed to write updater script: \(error.localizedDescription)")
            throw error
        }
        
        let oldPID = Int32(ProcessInfo.processInfo.processIdentifier)
        let appName = "Lustra" // Must match the .app name
        let destPath = "/Applications"
        
        logger.info("Launching updater script: \(scriptPath.path)")
        
        // 2. Run Script in Background
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath.path, String(oldPID), dmgPath, appName, destPath]
        
        // Detach header: The script must survive app termination
        // Swift Process usually kills children on exit, BUT since we exec bash which waits
        // we hope for the best. To be robust, use 'nohup' or similar if needed.
        // Actually, 'open' or 'nohup' might be better, but let's try direct spawn first.
        // For truly detached process, we might need 'setsid' or simply spawn and ignore.
        
        try process.run()
        
        // 3. Terminate Self
        print("DEBUG: Terminating self to allow update...")
        DispatchQueue.main.async {
            NSApplication.shared.terminate(nil)
        }
    }
    
    // MARK: - Embedded Shell Script
    private let updaterScript = """
    #!/bin/bash
    # Arguments: $1=PID, $2=DMG, $3=AppName, $4=Dest
    OLD_PID=$1
    DMG_PATH=$2
    APP_NAME=$3
    DEST_PATH=$4

    # 1. Wait for host to exit
    while kill -0 $OLD_PID 2>/dev/null; do sleep 0.5; done

    # 2. Mount DMG
    MOUNT_POINT="/Volumes/${APP_NAME}_Update_$(date +%s)"
    hdiutil attach "$DMG_PATH" -mountpoint "$MOUNT_POINT" -nobrowse
    if [ ! -d "$MOUNT_POINT" ]; then exit 1; fi

    # 3. Swap App
    TARGET_APP="$DEST_PATH/$APP_NAME.app"
    rm -rf "$TARGET_APP"
    cp -R "$MOUNT_POINT/$APP_NAME.app" "$DEST_PATH/"

    # 4. Cleanup & Relaunch
    hdiutil detach "$MOUNT_POINT" -force
    open "$TARGET_APP"
    exit 0
    """
}
