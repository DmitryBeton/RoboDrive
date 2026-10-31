import SwiftUI
import SwiftData

@main struct RoboDriveApp: App {
    @AppStorage("appearance") private var appearance = "system"
    var body: some Scene {
        WindowGroup {
            ContentView().tint(.blue)
                .preferredColorScheme(appearance == "light" ? .light : (appearance == "dark" ? .dark : nil))
        }
        .modelContainer(for: Attempt.self)
    }
}
