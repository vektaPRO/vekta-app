import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct RegisterView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var selectedRole = "Seller"
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    let roles = ["SuperAdmin", "FulfillmentAdmin", "Seller", "Courier"]
    
    var body: some View {
        Form {
            TextField("Email", text: $email)
                .autocapitalization(.none)
            SecureField("Пароль", text: $password)

            Picker("Роль", selection: $selectedRole) {
                ForEach(roles, id: \.self) { role in
                    Text(role)
                }
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Button(action: {
                registerWithFirestoreSetup()
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text("Зарегистрироваться")
                }
            }
            .disabled(isLoading)
        }
        .navigationTitle("Регистрация")
    }
    
    // MARK: - Регистрация с автоматической настройкой Firestore
    
    private func registerWithFirestoreSetup() {
        isLoading = true
        errorMessage = ""
        
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            guard let uid = result?.user.uid, error == nil else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = error?.localizedDescription ?? "Ошибка регистрации"
                }
                print("Ошибка регистрации: \(error!.localizedDescription)")
                return
            }
            
            // Автоматически создаем структуру в Firestore
            Task {
                do {
                    let setupHelper = FirestoreSetupHelper()
                    try await setupHelper.createUserWithRole(
                        uid: uid,
                        email: self.email,
                        role: self.selectedRole
                    )
                    
                    DispatchQueue.main.async {
                        self.isLoading = false
                        print("✅ Пользователь и структура Firestore созданы")
                    }
                    
                } catch {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = "Ошибка настройки: \(error.localizedDescription)"
                    }
                    print("❌ Ошибка создания структуры Firestore: \(error)")
                }
            }
        }
    }
}
