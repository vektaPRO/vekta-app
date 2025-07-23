import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingRegister = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                
                // Логотип
                VStack(spacing: 16) {
                    Image(systemName: "truck.box.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Vekta App")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Система управления доставкой")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Форма входа
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Пароль", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Button(action: login) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            }
                            Text("Войти")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Регистрация
                VStack(spacing: 8) {
                    Text("Нет аккаунта?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Зарегистрироваться") {
                        showingRegister = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingRegister) {
            RegisterView()
        }
    }

    private func login() {
        isLoading = true
        errorMessage = ""
        
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    errorMessage = error.localizedDescription
                    print("❌ Ошибка входа: \(error.localizedDescription)")
                } else {
                    print("✅ Успешный вход для \(email)")
                    // Навигация происходит автоматически через ContentView
                }
            }
        }
    }
}

#Preview {
    LoginView()
}
