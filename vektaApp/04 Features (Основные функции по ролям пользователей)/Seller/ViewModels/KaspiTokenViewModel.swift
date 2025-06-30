//
//  KaspiTokenViewModel.swift
//  vektaApp
//
//  Created by Almas Kadeshov on 29.06.2025.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// 🧠 ViewModel - это "мозг" для управления API токеном
class KaspiTokenViewModel: ObservableObject {
    
    // 📊 Данные, которые отслеживает интерфейс
    @Published var apiToken: String = ""           // Токен от пользователя
    @Published var isTokenSaved: Bool = false      // Сохранен ли токен
    @Published var isLoading: Bool = false         // Показываем ли загрузку
    @Published var successMessage: String?         // Сообщение об успехе
    @Published var errorMessage: String?           // Сообщение об ошибке
    
    // 🔥 Ссылка на Firestore
    private let db = Firestore.firestore()
    
    // 🎯 Инициализация - проверяем есть ли сохраненный токен
    init() {
        loadSavedToken()
    }
    
    // 💾 Сохранить API токен в Firebase
    func saveApiToken() {
        // Проверяем что токен не пустой
        guard !apiToken.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Пожалуйста, введите API токен"
            return
        }
        
        // Получаем ID текущего пользователя
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Ошибка: пользователь не авторизован"
            return
        }
        
        // Показываем загрузку
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        // 🚀 Сохраняем в Firestore
        db.collection("sellers").document(userId).setData([
            "kaspiApiToken": apiToken,
            "tokenUpdatedAt": Timestamp(),
            "isActive": true
        ], merge: true) { [weak self] error in
            
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Ошибка сохранения: \(error.localizedDescription)"
                } else {
                    self?.successMessage = "✅ API токен успешно сохранен!"
                    self?.isTokenSaved = true
                    
                    // Очищаем сообщение через 3 секунды
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self?.successMessage = nil
                    }
                }
            }
        }
    }
    
    // 📖 Загрузить сохраненный токен
    private func loadSavedToken() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("sellers").document(userId).getDocument { [weak self] snapshot, error in
            DispatchQueue.main.async {
                if let data = snapshot?.data(),
                   let savedToken = data["kaspiApiToken"] as? String {
                    self?.apiToken = savedToken
                    self?.isTokenSaved = true
                }
            }
        }
    }
    
    // 🔍 Проверить правильность токена (простая проверка)
    func isValidToken() -> Bool {
        return apiToken.count > 10 && !apiToken.contains(" ")
    }
}
