import SwiftUI
import FirebaseCore

@main
struct vektaApp: App {
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
