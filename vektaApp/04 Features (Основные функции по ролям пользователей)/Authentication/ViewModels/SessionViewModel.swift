import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
class SessionViewModel: ObservableObject {
    @Published var currentUserRole: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var authListener: AuthStateDidChangeListenerHandle?
    
    init() {
        // Слушаем изменения авторизации
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if user != nil {
                    await self?.fetchUserRole()
                } else {
                    self?.currentUserRole = nil
                }
            }
        }
    }
    
    deinit {
        if let listener = authListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    func fetchUserRole() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ Нет авторизованного пользователя")
            currentUserRole = nil
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let document = try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .getDocument()
            
            if let role = document.data()?["role"] as? String {
                currentUserRole = role
                print("✅ Роль пользователя: \(role)")
            } else {
                print("⚠️ Роль не найдена для UID: \(uid)")
                errorMessage = "Роль пользователя не найдена"
                currentUserRole = nil
            }
        } catch {
            print("❌ Ошибка получения роли: \(error.localizedDescription)")
            errorMessage = "Ошибка получения роли пользователя"
            currentUserRole = nil
        }
        
        isLoading = false
    }
    
    func fetchUserRole() {
        Task {
            await fetchUserRole()
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            currentUserRole = nil
            print("✅ Пользователь вышел из системы")
        } catch {
            print("❌ Ошибка выхода: \(error.localizedDescription)")
            errorMessage = "Ошибка выхода из системы"
        }
    }
}
