import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @StateObject private var session = SessionViewModel()
    @State private var isCheckingAuth = true

    var body: some View {
        Group {
            if isCheckingAuth {
                // Экран загрузки пока проверяем авторизацию
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Загрузка...")
                        .padding(.top)
                }
            } else {
                // Основной контент на основе роли пользователя
                if Auth.auth().currentUser != nil, let role = session.currentUserRole {
                    switch role {
                    case "SuperAdmin":
                        SuperAdminDashboard()
                    case "FulfillmentAdmin":
                        FulfillmentDashboard()
                    case "Seller":
                        SellerDashboard()
                    case "Courier":
                        CourierDashboard()
                    default:
                        VStack {
                            Text("Неизвестная роль: \(role)")
                            Button("Выйти") {
                                try? Auth.auth().signOut()
                                session.currentUserRole = nil
                            }
                        }
                    }
                } else {
                    // Пользователь не авторизован
                    LoginView()
                }
            }
        }
        .onAppear {
            checkAuthState()
        }
        .onChange(of: Auth.auth().currentUser) { user in
            if user == nil {
                session.currentUserRole = nil
                isCheckingAuth = false
            } else {
                session.fetchUserRole()
            }
        }
    }
    
    private func checkAuthState() {
        // Проверяем текущего пользователя
        if Auth.auth().currentUser != nil {
            session.fetchUserRole()
        } else {
            isCheckingAuth = false
        }
        
        // Подписываемся на изменения роли
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isCheckingAuth = false
        }
    }
}

#Preview {
    ContentView()
}
