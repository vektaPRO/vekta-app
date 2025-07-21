//
//  KaspiAPIService.swift
//  vektaApp
//
//  УПРОЩЕННАЯ ВЕРСИЯ ДЛЯ ОТЛАДКИ
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

// Простая модель товара для тестирования
struct KaspiProduct: Codable {
    let id: String
    let name: String
    let price: Double
    let stock: Int
}

class KaspiAPIService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastSyncDate: Date?
    
    private let db = Firestore.firestore()
    private var apiToken: String?
    
    init() {
        print("🔧 KaspiAPIService инициализирован")
        loadApiToken()
    }
    
    // Загрузить токен из Firestore
    private func loadApiToken() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Нет авторизованного пользователя")
            return
        }
        
        print("🔍 Загружаем токен для пользователя: \(userId)")
        
        db.collection("sellers").document(userId).getDocument { [weak self] snapshot, error in
            if let error = error {
                print("❌ Ошибка загрузки токена: \(error.localizedDescription)")
                return
            }
            
            if let data = snapshot?.data(),
               let token = data["kaspiApiToken"] as? String {
                DispatchQueue.main.async {
                    self?.apiToken = token
                    print("✅ Kaspi API токен загружен: \(token.prefix(10))...")
                }
            } else {
                print("⚠️ Kaspi API токен не найден в Firestore")
                print("📄 Данные документа: \(snapshot?.data() ?? [:])")
            }
        }
    }
    
    // Проверить токен
    func validateToken() async throws -> Bool {
        print("🔐 Проверяем токен...")
        
        guard let token = apiToken else {
            print("❌ Токен не найден")
            throw NSError(domain: "KaspiAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Токен не найден"])
        }
        
        print("✅ Токен найден: \(token.prefix(10))...")
        
        // Для отладки возвращаем true
        // В реальном приложении здесь будет HTTP запрос к Kaspi API
        return true
    }
    
    // Синхронизировать товары (пока моковые данные)
    func syncAllProducts() async throws -> [Product] {
        print("🔄 Начинаем синхронизацию товаров...")
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        // Имитация запроса к API
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 секунды
        
        // Моковые данные для тестирования
        let mockProducts = [
            Product(
                id: "kaspi_1",
                kaspiProductId: "kaspi_mock_1",
                name: "iPhone 15 Pro Max (Kaspi)",
                description: "Загружено из Kaspi API",
                price: 599000,
                category: "Смартфоны",
                imageURL: "https://example.com/iphone.jpg",
                status: .inStock,
                warehouseStock: ["main": 10],
                createdAt: Date(),
                updatedAt: Date(),
                isActive: true
            ),
            Product(
                id: "kaspi_2",
                kaspiProductId: "kaspi_mock_2",
                name: "Samsung Galaxy S24 (Kaspi)",
                description: "Загружено из Kaspi API",
                price: 459000,
                category: "Смартфоны",
                imageURL: "https://example.com/samsung.jpg",
                status: .inStock,
                warehouseStock: ["main": 5],
                createdAt: Date(),
                updatedAt: Date(),
                isActive: true
            )
        ]
        
        await MainActor.run {
            self.isLoading = false
            self.lastSyncDate = Date()
            print("✅ Синхронизация завершена! Загружено \(mockProducts.count) товаров")
        }
        
        return mockProducts
    }
    
    // Проверить здоровье API
    func checkAPIHealth() async -> Bool {
        print("🏥 Проверяем здоровье API...")
        return apiToken != nil
    }
    
    // Статистика API
    var apiStatistics: (requests: Int, lastSync: Date?) {
        return (0, lastSyncDate)
    }
    
    // Обновить остатки (заглушка)
    func updateStock(productId: String, warehouseId: String, quantity: Int) async throws {
        print("📊 Обновляем остатки для товара \(productId): \(quantity) шт")
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
    }
}
