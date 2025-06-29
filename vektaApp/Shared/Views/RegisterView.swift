import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct RegisterView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var selectedRole = "Seller"
    
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

            Button("Зарегистрироваться") {
                register()
            }
        }
        .navigationTitle("Регистрация")
    }
    
    private func register() {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            guard let uid = result?.user.uid, error == nil else {
                print("Ошибка регистрации: \(error!.localizedDescription)")
                return
            }
            
            Firestore.firestore().collection("users").document(uid).setData([
                "email": email,
                "role": selectedRole
            ]) { error in
                if let error = error {
                    print("Ошибка сохранения пользователя: \(error.localizedDescription)")
                } else {
                    print("Пользователь успешно зарегистрирован с ролью \(selectedRole)")
                }
            }
        }
    }
}
