import SwiftUI
import SwiftData

/// Точка входа: общая тема и контейнер результатов доступны всем вкладкам и полноэкранным заездам.
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
