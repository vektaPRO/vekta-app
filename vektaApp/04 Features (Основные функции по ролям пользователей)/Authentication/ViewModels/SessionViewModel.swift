import SwiftUI
import FirebaseAuth
import FirebaseFirestore

class SessionViewModel: ObservableObject {
    @Published var currentUserRole: String?
    
    init() {
        fetchUserRole()
    }
    
    func fetchUserRole() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("Нет авторизованного пользователя")
            return
        }
        
        Firestore.firestore().collection("users").document(uid).getDocument { snapshot, error in
            if let role = snapshot?.data()?["role"] as? String {
                DispatchQueue.main.async {
                    self.currentUserRole = role
                    print("✅ Роль пользователя: \(role)")
                }
            } else if let error = error {
                print("Ошибка получения роли: \(error.localizedDescription)")
            } else {
                print("Роль не найдена для UID: \(uid)")
            }
        }
    }
}
