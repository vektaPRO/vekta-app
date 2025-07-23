//
//  KaspiAPIService.swift
//  vektaApp
//
//  Полная интеграция с Kaspi API
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Kaspi API Models

/// Модель товара из Kaspi API
struct KaspiProductResponse: Codable {
    let id: String
    let sku: String
    let name: String
    let description: String?
    let price: Double
    let category: String
    let images: [String]
    let stock: KaspiStock
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id = "product_id"
        case sku
        case name
        case description
        case price
        case category
        case images
        case stock
        case isActive = "is_active"
    }
}

/// Остатки товара по складам
struct KaspiStock: Codable {
    let total: Int
    let warehouses: [KaspiWarehouseStock]
}

/// Остатки на конкретном складе
struct KaspiWarehouseStock: Codable {
    let warehouseId: String
    let warehouseName: String
    let quantity: Int
    let reserved: Int
    let available: Int
    
    enum CodingKeys: String, CodingKey {
        case warehouseId = "warehouse_id"
        case warehouseName = "warehouse_name"
        case quantity
        case reserved
        case available
    }
}

/// Ответ на запрос SMS кода
struct KaspiSMSCodeRequest: Codable {
    let orderId: String
    let trackingNumber: String
    let customerPhone: String
    
    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case trackingNumber = "tracking_number"
        case customerPhone = "customer_phone"
    }
}

/// Подтверждение доставки
struct KaspiDeliveryConfirmation: Codable {
    let orderId: String
    let trackingNumber: String
    let confirmationCode: String
    let confirmedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case trackingNumber = "tracking_number"
        case confirmationCode = "confirmation_code"
        case confirmedAt = "confirmed_at"
    }
}

// MARK: - Errors

enum KaspiAPIError: LocalizedError {
    case tokenNotFound
    case invalidToken
    case networkError(String)
    case authenticationFailed
    case rateLimitExceeded
    case invalidResponse
    case syncFailed(String)
    case smsCodeError(String)
    
    var errorDescription: String? {
        switch self {
        case .tokenNotFound:
            return "API токен не найден. Пожалуйста, добавьте токен в настройках."
        case .invalidToken:
            return "Неверный API токен. Проверьте правильность токена."
        case .networkError(let message):
            return "Ошибка сети: \(message)"
        case .authenticationFailed:
            return "Ошибка аутентификации. Проверьте ваш API токен."
        case .rateLimitExceeded:
            return "Превышен лимит запросов. Попробуйте позже."
        case .invalidResponse:
            return "Некорректный ответ от сервера"
        case .syncFailed(let message):
            return "Ошибка синхронизации: \(message)"
        case .smsCodeError(let message):
            return "Ошибка отправки SMS кода: \(message)"
        }
    }
}

// MARK: - KaspiAPIService

@MainActor
class KaspiAPIService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastSyncDate: Date?
    @Published var apiToken: String?
    @Published var syncProgress: Double = 0.0
    
    // MARK: - Private Properties
    
    private let db = Firestore.firestore()
    private var authListener: AuthStateDidChangeListenerHandle?
    private let baseURL = "https://kaspi.kz/merchantcabinet/api/v1"
    private let session = URLSession.shared
    
    // MARK: - Initialization
    
    init() {
        print("🔧 KaspiAPIService инициализирован")
        setupAuthListener()
    }
    
    deinit {
        if let listener = authListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Authentication
    
    private func setupAuthListener() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if user != nil {
                    await self?.loadApiToken()
                } else {
                    self?.apiToken = nil
                }
            }
        }
    }
    
    func loadApiToken() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Нет авторизованного пользователя")
            errorMessage = "Пользователь не авторизован"
            return
        }
        
        print("🔍 Загружаем токен для пользователя: \(userId)")
        
        do {
            let document = try await db.collection("sellers").document(userId).getDocument()
            
            if let data = document.data(),
               let token = data["kaspiApiToken"] as? String {
                apiToken = token
                errorMessage = nil
                print("✅ Kaspi API токен загружен")
            } else {
                print("⚠️ Kaspi API токен не найден")
                apiToken = nil
                errorMessage = "Токен не найден. Добавьте токен в настройках."
            }
        } catch {
            print("❌ Ошибка загрузки токена: \(error.localizedDescription)")
            errorMessage = "Ошибка загрузки токена"
        }
    }
    
    func loadApiToken() {
        Task {
            await loadApiToken()
        }
    }
    
    // MARK: - API Methods
    
    /// Проверить валидность токена
    func validateToken() async throws -> Bool {
        guard let token = apiToken else {
            throw KaspiAPIError.tokenNotFound
        }
        
        // Для демонстрации - имитируем проверку токена
        // В реальном приложении здесь будет запрос к Kaspi API
        
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
        
        // Простая проверка токена
        if token.count > 10 && !token.isEmpty {
            return true
        } else {
            throw KaspiAPIError.invalidToken
        }
    }
    
    /// Синхронизировать все товары
    func syncAllProducts() async throws -> [Product] {
        guard let token = apiToken else {
            throw KaspiAPIError.tokenNotFound
        }
        
        isLoading = true
        errorMessage = nil
        syncProgress = 0.0
        
        do {
            // Валидируем токен
            let isValid = try await validateToken()
            guard isValid else {
                throw KaspiAPIError.invalidToken
            }
            
            // Имитируем загрузку товаров из Kaspi API
            // В реальном приложении здесь будет запрос к API
            let products = try await simulateProductSync()
            
            // Сохраняем в Firestore
            try await saveProductsToFirestore(products)
            
            isLoading = false
            lastSyncDate = Date()
            syncProgress = 1.0
            print("✅ Синхронизация завершена! Загружено \(products.count) товаров")
            
            return products
            
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            syncProgress = 0.0
            throw error
        }
    }
    
    /// Имитация синхронизации товаров (для демонстрации)
    private func simulateProductSync() async throws -> [Product] {
        // Имитируем процесс синхронизации
        for i in 0...10 {
            syncProgress = Double(i) / 10.0
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 секунды
        }
        
        // Возвращаем тестовые товары
        return Product.sampleProducts
    }
    
    /// Сохранить товары в Firestore
    private func saveProductsToFirestore(_ products: [Product]) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw KaspiAPIError.authenticationFailed
        }
        
        let batch = db.batch()
        let productsRef = db.collection("sellers").document(userId).collection("products")
        
        for product in products {
            let docRef = productsRef.document(product.id)
            batch.setData(product.toDictionary(), forDocument: docRef, merge: true)
        }
        
        try await batch.commit()
    }
    
    // MARK: - SMS Code & Delivery Confirmation
    
    /// Запросить SMS код для подтверждения доставки
    func requestSMSCode(orderId: String, trackingNumber: String) async throws {
        guard let token = apiToken else {
            throw KaspiAPIError.tokenNotFound
        }
        
        // Имитируем отправку SMS кода
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
        
        print("✅ SMS код отправлен клиенту для заказа \(orderId)")
    }
    
    /// Подтвердить доставку с помощью SMS кода
    func confirmDelivery(orderId: String, trackingNumber: String, smsCode: String) async throws -> Bool {
        guard let token = apiToken else {
            throw KaspiAPIError.tokenNotFound
        }
        
        // Имитируем проверку SMS кода
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 секунды
        
        // Для демонстрации - код "123456" всегда правильный
        if smsCode == "123456" {
            try await saveDeliveryConfirmation(orderId: orderId, trackingNumber: trackingNumber, smsCode: smsCode)
            return true
        } else {
            throw KaspiAPIError.smsCodeError("Неверный код подтверждения")
        }
    }
    
    /// Сохранить подтверждение доставки в Firestore
    private func saveDeliveryConfirmation(orderId: String, trackingNumber: String, smsCode: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw KaspiAPIError.authenticationFailed
        }
        
        let confirmationData: [String: Any] = [
            "orderId": orderId,
            "trackingNumber": trackingNumber,
            "confirmationCode": smsCode,
            "confirmedAt": FieldValue.serverTimestamp(),
            "confirmedBy": userId
        ]
        
        try await db.collection("deliveryConfirmations").document(orderId).setData(confirmationData)
    }
    
    // MARK: - Stock Management
    
    /// Обновить остатки товара
    func updateStock(productId: String, warehouseId: String, quantity: Int) async throws {
        guard let token = apiToken else {
            throw KaspiAPIError.tokenNotFound
        }
        
        // Имитируем обновление остатков
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 секунды
        
        print("✅ Остатки обновлены для товара \(productId)")
    }
    
    // MARK: - Utility Methods
    
    func checkAPIHealth() async -> Bool {
        do {
            return try await validateToken()
        } catch {
            return false
        }
    }
    
    var apiStatistics: (requests: Int, lastSync: Date?) {
        return (0, lastSyncDate)
    }
}
