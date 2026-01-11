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
    
    // GitHub raw content URL for the appcast file
    private let updateURL = URL(string: "https://raw.githubusercontent.com/senoldogann/Lustra-Macebook-Device-Cleaner/main/appcast.json")!
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        checkForUpdates()
    }
    
    func checkForUpdates() {
        URLSession.shared.dataTaskPublisher(for: updateURL)
            .map(\.data)
            .decode(type: AppVersion.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Update check failed: \(error)")
                    }
                },
                receiveValue: { [weak self] versionInfo in
                    self?.validateVersion(versionInfo)
                }
            )
            .store(in: &cancellables)
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
