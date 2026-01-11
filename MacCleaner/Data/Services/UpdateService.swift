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
    LOG_FILE="/tmp/lustra_update.log"

    # Redirect output to log file
    exec > "$LOG_FILE" 2>&1
    
    echo "Updater: Started at $(date)"
    echo "Updater: PID=$OLD_PID, DMG=$DMG_PATH, APP=$APP_NAME, DEST=$DEST_PATH"

    # 1. Wait for host to exit
    echo "Updater: Waiting for parent process $OLD_PID to die..."
    while kill -0 $OLD_PID 2>/dev/null; do sleep 0.5; done
    echo "Updater: Parent process died."

    # 2. Mount DMG
    MOUNT_POINT="/Volumes/${APP_NAME}_Update_$(date +%s)"
    echo "Updater: Mounting DMG to $MOUNT_POINT"
    hdiutil attach "$DMG_PATH" -mountpoint "$MOUNT_POINT" -nobrowse
    
    if [ ! -d "$MOUNT_POINT" ]; then 
        echo "Updater: Failed to mount DMG."
        exit 1
    fi

    # 3. Check Source App
    SOURCE_APP="$MOUNT_POINT/$APP_NAME.app"
    if [ ! -d "$SOURCE_APP" ]; then
        echo "Updater: Source app not found at $SOURCE_APP"
        hdiutil detach "$MOUNT_POINT" -force
        exit 1
    fi

    # 4. Swap App
    TARGET_APP="$DEST_PATH/$APP_NAME.app"
    echo "Updater: Removing old app at $TARGET_APP"
    rm -rf "$TARGET_APP"
    
    echo "Updater: Copying new app..."
    cp -R "$SOURCE_APP" "$DEST_PATH/"
    
    # 5. Clear Constraints (Quarantine)
    echo "Updater: Clearing quarantine attributes..."
    xattr -cr "$TARGET_APP"

    # 6. Cleanup & Relaunch
    echo "Updater: Detaching DMG..."
    hdiutil detach "$MOUNT_POINT" -force
    
    echo "Updater: Relaunching app at $TARGET_APP"
    open "$TARGET_APP"
    
    echo "Updater: Done."
    exit 0
    """
}
