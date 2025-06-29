import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoggedIn = false
    @StateObject private var session = SessionViewModel()

    var body: some View {
        NavigationStack {
            Form {
                TextField("Email", text: $email)
                    .autocapitalization(.none)
                SecureField("Пароль", text: $password)

                Button("Войти") {
                    login()
                }
                
                NavigationLink(destination: ContentView(), isActive: $isLoggedIn) {
                    EmptyView()
                }
            }
            .navigationTitle("Вход")
        }
    }

    private func login() {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                print("Ошибка входа: \(error.localizedDescription)")
            } else {
                print("Успешный вход для \(email)")
                session.fetchUserRole() // <—— Добавь эту строку!
                isLoggedIn = true
            }
        }
    }
}
