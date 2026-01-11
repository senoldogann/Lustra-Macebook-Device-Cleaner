import Foundation
import Combine

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
    
    // GitHub Gist raw content URL for the appcast file (Public access)
    private let updateURL = URL(string: "https://gist.githubusercontent.com/senoldogann/a19b889926ee37d7473d3805eb7af1df/raw/076b8cdfd5d53afdf285fe9a3c831d1da8678ec6/appcast.json")!
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        checkForUpdates()
    }
    
    func checkForUpdates() {
        print("DEBUG: Checking for updates at \(updateURL.absoluteString)")
        
        URLSession.shared.dataTask(with: updateURL) { data, response, error in
            if let error = error {
                print("DEBUG: Network error: \(error.localizedDescription)")
                return
            }
            
            guard let data = data, let rawString = String(data: data, encoding: .utf8) else {
                print("DEBUG: No data received")
                return
            }
            
            print("DEBUG: Raw response: \(rawString)") // KEY DEBUG LINE
            
            do {
                let versionInfo = try JSONDecoder().decode(AppVersion.self, from: data)
                DispatchQueue.main.async {
                    self.validateVersion(versionInfo)
                }
            } catch {
                print("DEBUG: JSON Decode Error: \(error)")
            }
        }.resume()
    }
    
    private func validateVersion(_ remoteVersion: AppVersion) {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        print("DEBUG: Update Check - Remote: \(remoteVersion.version), Local: \(currentVersion)")
        
        if remoteVersion.version.compare(currentVersion, options: .numeric) == .orderedDescending {
            print("DEBUG: Update Available!")
            self.latestVersion = remoteVersion
            self.isUpdateAvailable = true
        } else {
            print("DEBUG: App is up to date.")
        }
    }
}
