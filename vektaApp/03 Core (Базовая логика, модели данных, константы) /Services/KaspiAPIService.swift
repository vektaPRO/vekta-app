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
            if user != nil {
                self?.loadApiToken()
            } else {
                self?.apiToken = nil
            }
        }
    }
    
    func loadApiToken() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Нет авторизованного пользователя")
            errorMessage = "Пользователь не авторизован"
            return
        }
        
        print("🔍 Загружаем токен для пользователя: \(userId)")
        
        db.collection("sellers").document(userId).getDocument { [weak self] snapshot, error in
            if let error = error {
                print("❌ Ошибка загрузки токена: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.errorMessage = "Ошибка загрузки токена"
                }
                return
            }
            
            if let data = snapshot?.data(),
               let token = data["kaspiApiToken"] as? String {
                DispatchQueue.main.async {
                    self?.apiToken = token
                    self?.errorMessage = nil
                    print("✅ Kaspi API токен загружен")
                }
            } else {
                print("⚠️ Kaspi API токен не найден")
                DispatchQueue.main.async {
                    self?.apiToken = nil
                    self?.errorMessage = "Токен не найден. Добавьте токен в настройках."
                }
            }
        }
    }
    
    // MARK: - API Methods
    
    /// Проверить валидность токена
    func validateToken() async throws -> Bool {
        guard let token = apiToken else {
            throw KaspiAPIError.tokenNotFound
        }
        
        let url = URL(string: "\(baseURL)/auth/validate")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    return true
                case 401:
                    throw KaspiAPIError.invalidToken
                case 429:
                    throw KaspiAPIError.rateLimitExceeded
                default:
                    throw KaspiAPIError.authenticationFailed
                }
            }
            
            return false
        } catch {
            throw KaspiAPIError.networkError(error.localizedDescription)
        }
    }
    
    /// Синхронизировать все товары
    func syncAllProducts() async throws -> [Product] {
        guard let token = apiToken else {
            throw KaspiAPIError.tokenNotFound
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.syncProgress = 0.0
        }
        
        do {
            // Валидируем токен
            let isValid = try await validateToken()
            guard isValid else {
                throw KaspiAPIError.invalidToken
            }
            
            // Получаем список товаров
            let kaspiProducts = try await fetchProductsFromKaspi(token: token)
            
            // Конвертируем в наши модели
            let products = kaspiProducts.enumerated().map { index, kaspiProduct in
                await MainActor.run {
                    self.syncProgress = Double(index + 1) / Double(kaspiProducts.count)
                }
                return convertKaspiProductToProduct(kaspiProduct)
            }
            
            // Сохраняем в Firestore
            try await saveProductsToFirestore(products)
            
            await MainActor.run {
                self.isLoading = false
                self.lastSyncDate = Date()
                self.syncProgress = 1.0
                print("✅ Синхронизация завершена! Загружено \(products.count) товаров")
            }
            
            return products
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                self.syncProgress = 0.0
            }
            throw error
        }
    }
    
    /// Получить товары из Kaspi API
    private func fetchProductsFromKaspi(token: String) async throws -> [KaspiProductResponse] {
        var allProducts: [KaspiProductResponse] = []
        var page = 1
        let pageSize = 50
        var hasMore = true
        
        while hasMore {
            let url = URL(string: "\(baseURL)/products?page=\(page)&size=\(pageSize)")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw KaspiAPIError.invalidResponse
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            struct ProductsResponse: Codable {
                let products: [KaspiProductResponse]
                let hasMore: Bool
                
                enum CodingKeys: String, CodingKey {
                    case products
                    case hasMore = "has_more"
                }
            }
            
            let productsResponse = try decoder.decode(ProductsResponse.self, from: data)
            allProducts.append(contentsOf: productsResponse.products)
            
            hasMore = productsResponse.hasMore
            page += 1
            
            // Обновляем прогресс
            await MainActor.run {
                self.syncProgress = Double(allProducts.count) / Double(allProducts.count + (hasMore ? pageSize : 0))
            }
        }
        
        return allProducts
    }
    
    /// Конвертировать товар Kaspi в нашу модель
    private func convertKaspiProductToProduct(_ kaspiProduct: KaspiProductResponse) -> Product {
        // Преобразуем остатки по складам
        var warehouseStock: [String: Int] = [:]
        for warehouse in kaspiProduct.stock.warehouses {
            warehouseStock[warehouse.warehouseId] = warehouse.available
        }
        
        // Определяем статус
        let status: ProductStatus = kaspiProduct.stock.total > 0 ? .inStock : .outOfStock
        
        return Product(
            id: kaspiProduct.id,
            kaspiProductId: kaspiProduct.sku,
            name: kaspiProduct.name,
            description: kaspiProduct.description ?? "",
            price: kaspiProduct.price,
            category: kaspiProduct.category,
            imageURL: kaspiProduct.images.first ?? "",
            status: kaspiProduct.isActive ? status : .inactive,
            warehouseStock: warehouseStock,
            createdAt: Date(),
            updatedAt: Date(),
            isActive: kaspiProduct.isActive
        )
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
        
        let url = URL(string: "\(baseURL)/delivery/request-code")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "order_id": orderId,
            "tracking_number": trackingNumber
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KaspiAPIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            print("✅ SMS код отправлен клиенту")
        case 400:
            throw KaspiAPIError.smsCodeError("Неверные данные заказа")
        case 404:
            throw KaspiAPIError.smsCodeError("Заказ не найден")
        case 429:
            throw KaspiAPIError.smsCodeError("Слишком много запросов. Попробуйте позже")
        default:
            throw KaspiAPIError.smsCodeError("Ошибка отправки SMS")
        }
    }
    
    /// Подтвердить доставку с помощью SMS кода
    func confirmDelivery(orderId: String, trackingNumber: String, smsCode: String) async throws -> Bool {
        guard let token = apiToken else {
            throw KaspiAPIError.tokenNotFound
        }
        
        let url = URL(string: "\(baseURL)/delivery/confirm")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "order_id": orderId,
            "tracking_number": trackingNumber,
            "confirmation_code": smsCode,
            "confirmed_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KaspiAPIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            // Сохраняем подтверждение в Firestore
            try await saveDeliveryConfirmation(orderId: orderId, trackingNumber: trackingNumber, smsCode: smsCode)
            return true
        case 400:
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorData["message"] as? String {
                throw KaspiAPIError.smsCodeError(errorMessage)
            }
            throw KaspiAPIError.smsCodeError("Неверный код подтверждения")
        case 404:
            throw KaspiAPIError.smsCodeError("Заказ не найден")
        default:
            throw KaspiAPIError.smsCodeError("Ошибка подтверждения доставки")
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
        
        let url = URL(string: "\(baseURL)/products/\(productId)/stock")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "warehouse_id": warehouseId,
            "quantity": quantity,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw KaspiAPIError.syncFailed("Не удалось обновить остатки")
        }
        
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
        // TODO: Implement request counting
        return (0, lastSyncDate)
    }
}

// MARK: - URLSession Extension for Better Error Handling

extension URLSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await self.data(for: request)
        } catch {
            if (error as NSError).code == NSURLErrorNotConnectedToInternet {
                throw KaspiAPIError.networkError("Нет подключения к интернету")
            } else if (error as NSError).code == NSURLErrorTimedOut {
                throw KaspiAPIError.networkError("Превышено время ожидания")
            } else {
                throw KaspiAPIError.networkError(error.localizedDescription)
            }
        }
    }
}
