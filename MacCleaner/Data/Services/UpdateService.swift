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
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return }
        
        if remoteVersion.version.compare(currentVersion, options: .numeric) == .orderedDescending {
            self.latestVersion = remoteVersion
            self.isUpdateAvailable = true
        }
    }
}
