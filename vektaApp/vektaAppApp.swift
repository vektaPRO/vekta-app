import SwiftUI
import FirebaseCore

@main
struct VektaApp: App {
    // Инициализация Firebase при запуске приложения
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
