import SwiftUI

@main
struct MacCleanerApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            SidebarCommands()
        }
        
        Settings {
            SettingsView()
        }
        
        // Menubar Utility
        MenuBarExtra("Lustra", systemImage: "sparkles") {
            MenubarView()
        }
        .menuBarExtraStyle(.window) // Allows complex SwiftUI view
    }
}
