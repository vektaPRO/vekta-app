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

/// Запрос на отправку SMS кода
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

/// Ответ на запрос SMS кода
struct KaspiSMSCodeResponse: Codable {
    let success: Bool
    let messageId: String?
    let expiresAt: Date?
    let attemptsLeft: Int
    
    enum CodingKeys: String, CodingKey {
        case success
        case messageId = "message_id"
        case expiresAt = "expires_at"
        case attemptsLeft = "attempts_left"
    }
}

/// Запрос подтверждения доставки
struct KaspiDeliveryConfirmationRequest: Codable {
    let orderId: String
    let trackingNumber: String
    let confirmationCode: String
    
    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case trackingNumber = "tracking_number"
        case confirmationCode = "confirmation_code"
    }
}

/// Ответ подтверждения доставки
struct KaspiDeliveryConfirmationResponse: Codable {
    let success: Bool
    let confirmed: Bool
    let confirmedAt: Date?
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case confirmed
        case confirmedAt = "confirmed_at"
        case message
    }
}

/// Обновление остатков
struct KaspiStockUpdateRequest: Codable {
    let productId: String
    let warehouseId: String
    let quantity: Int
    let operation: StockOperation
    
    enum StockOperation: String, Codable {
        case set = "SET"        // Установить точное количество
        case add = "ADD"        // Добавить к текущему
        case subtract = "SUBTRACT" // Вычесть из текущего
    }
    
    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case warehouseId = "warehouse_id"
        case quantity
        case operation
    }
}

/// Ответ об обновлении остатков
struct KaspiStockUpdateResponse: Codable {
    let success: Bool
    let productId: String
    let warehouseId: String
    let previousQuantity: Int
    let newQuantity: Int
    
    enum CodingKeys: String, CodingKey {
        case success
        case productId = "product_id"
        case warehouseId = "warehouse_id"
        case previousQuantity = "previous_quantity"
        case newQuantity = "new_quantity"
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
    case stockUpdateError(String)
    
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
        case .stockUpdateError(let message):
            return "Ошибка обновления остатков: \(message)"
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
    private let networkManager = NetworkManager.shared
    private var authListener: AuthStateDidChangeListenerHandle?
    
    // Endpoints
    private enum Endpoints {
        static let validateToken = "/auth/validate"
        static let products = "/products"
        static let productDetail = "/products/%@"
        static let updateStock = "/stock/update"
        static let requestSMSCode = "/delivery/sms/request"
        static let confirmDelivery = "/delivery/confirm"
        static let warehouses = "/warehouses"
    }
    
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
    
    // MARK: - API Methods
    
    /// Проверить валидность токена
    func validateToken() async throws -> Bool {
        guard let token = apiToken else {
            throw KaspiAPIError.tokenNotFound
        }
        
        struct ValidateResponse: Codable {
            let valid: Bool
            let merchantId: String?
            let merchantName: String?
            
            enum CodingKeys: String, CodingKey {
                case valid
                case merchantId = "merchant_id"
                case merchantName = "merchant_name"
            }
        }
        
        do {
            let response: ValidateResponse = try await networkManager.get(
                endpoint: Endpoints.validateToken,
                apiToken: token
            )
            
            if response.valid {
                // Сохраняем информацию о продавце
                if let userId = Auth.auth().currentUser?.uid,
                   let merchantId = response.merchantId {
                    try await db.collection("sellers").document(userId).updateData([
                        "kaspiMerchantId": merchantId,
                        "kaspiMerchantName": response.merchantName ?? ""
                    ])
                }
            }
            
            return response.valid
            
        } catch let error as NetworkError {
            switch error {
            case .unauthorized:
                throw KaspiAPIError.invalidToken
            case .rateLimited:
                throw KaspiAPIError.rateLimitExceeded
            default:
                throw KaspiAPIError.networkError(error.localizedDescription)
            }
        } catch {
            throw KaspiAPIError.networkError(error.localizedDescription)
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
            
            syncProgress = 0.1
            
            // Загружаем товары постранично
            var allProducts: [Product] = []
            var currentPage = 1
            var hasMorePages = true
            
            while hasMorePages {
                let response: KaspiResponse<[KaspiProductResponse]> = try await networkManager.get(
                    endpoint: Endpoints.products,
                    parameters: [
                        "page": currentPage,
                        "page_size": 100
                    ],
                    apiToken: token
                )
                
                if let kaspiProducts = response.data {
                    // Конвертируем Kaspi товары в наш формат
                    let products = kaspiProducts.compactMap { convertKaspiProductToProduct($0) }
                    allProducts.append(contentsOf: products)
                    
                    // Обновляем прогресс
                    if let pagination = response.pagination {
                        syncProgress = Double(currentPage) / Double(pagination.totalPages)
                        hasMorePages = currentPage < pagination.totalPages
                        currentPage += 1
                    } else {
                        hasMorePages = false
                    }
                }
            }
            
            // Сохраняем в Firestore
            try await saveProductsToFirestore(allProducts)
            
            isLoading = false
            lastSyncDate = Date()
            syncProgress = 1.0
            print("✅ Синхронизация завершена! Загружено \(allProducts.count) товаров")
            
            return allProducts
            
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            syncProgress = 0.0
            throw error
        }
    }
    
    /// Конвертация товара из формата Kaspi в наш формат
    private func convertKaspiProductToProduct(_ kaspiProduct: KaspiProductResponse) -> Product {
        // Конвертируем склады
        var warehouseStock: [String: Int] = [:]
        for warehouse in kaspiProduct.stock.warehouses {
            warehouseStock[warehouse.warehouseId] = warehouse.available
        }
        
        // Определяем статус
        let status: ProductStatus = kaspiProduct.isActive ?
            (kaspiProduct.stock.total > 0 ? .inStock : .outOfStock) : .inactive
        
        return Product(
            id: kaspiProduct.id,
            kaspiProductId: kaspiProduct.id,
            name: kaspiProduct.name,
            description: kaspiProduct.description ?? "",
            price: kaspiProduct.price,
            category: kaspiProduct.category,
            imageURL: kaspiProduct.images.first ?? "",
            status: status,
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
        
        // Удаляем старые товары
        let oldProducts = try await productsRef.getDocuments()
        for doc in oldProducts.documents {
            batch.deleteDocument(doc.reference)
        }
        
        // Добавляем новые товары
        for product in products {
            let docRef = productsRef.document(product.id)
            batch.setData(product.toDictionary(), forDocument: docRef)
        }
        
        try await batch.commit()
    }
    
    // MARK: - SMS Code & Delivery Confirmation
    
    /// Запросить SMS код для подтверждения доставки
    func requestSMSCode(orderId: String, trackingNumber: String, customerPhone: String) async throws -> String {
        guard let token = apiToken else {
            throw KaspiAPIError.tokenNotFound
        }
        
        let request = KaspiSMSCodeRequest(
            orderId: orderId,
            trackingNumber: trackingNumber,
            customerPhone: customerPhone
        )
        
        do {
            let response: KaspiSMSCodeResponse = try await networkManager.post(
                endpoint: Endpoints.requestSMSCode,
                body: request,
                apiToken: token
            )
            
            if response.success {
                print("✅ SMS код отправлен клиенту для заказа \(orderId)")
                
                // Сохраняем информацию о запросе в Firestore
                if let messageId = response.messageId {
                    try await db.collection("smsRequests").document(messageId).setData([
                        "orderId": orderId,
                        "trackingNumber": trackingNumber,
                        "customerPhone": customerPhone,
                        "requestedAt": FieldValue.serverTimestamp(),
                        "expiresAt": response.expiresAt ?? Date().addingTimeInterval(600),
                        "attemptsLeft": response.attemptsLeft
                    ])
                }
                
                return response.messageId ?? ""
            } else {
                throw KaspiAPIError.smsCodeError("Не удалось отправить SMS код")
            }
            
        } catch let error as NetworkError {
            switch error {
            case .serverError(_, let message):
                throw KaspiAPIError.smsCodeError(message ?? "Ошибка сервера")
            case .rateLimited:
                throw KaspiAPIError.rateLimitExceeded
            default:
                throw KaspiAPIError.networkError(error.localizedDescription)
            }
        } catch {
            throw KaspiAPIError.smsCodeError(error.localizedDescription)
        }
    }
    
    /// Подтвердить доставку с помощью SMS кода
    func confirmDelivery(orderId: String, trackingNumber: String, smsCode: String) async throws -> Bool {
        guard let token = apiToken else {
            throw KaspiAPIError.tokenNotFound
        }
        
        let request = KaspiDeliveryConfirmationRequest(
            orderId: orderId,
            trackingNumber: trackingNumber,
            confirmationCode: smsCode
        )
        
        do {
            let response: KaspiDeliveryConfirmationResponse = try await networkManager.post(
                endpoint: Endpoints.confirmDelivery,
                body: request,
                apiToken: token
            )
            
            if response.success && response.confirmed {
                // Сохраняем подтверждение в Firestore
                try await saveDeliveryConfirmation(
                    orderId: orderId,
                    trackingNumber: trackingNumber,
                    smsCode: smsCode,
                    confirmedAt: response.confirmedAt
                )
                
                return true
            } else {
                throw KaspiAPIError.smsCodeError(response.message ?? "Неверный код подтверждения")
            }
            
        } catch let error as NetworkError {
            switch error {
            case .serverError(_, let message):
                throw KaspiAPIError.smsCodeError(message ?? "Ошибка проверки кода")
            default:
                throw KaspiAPIError.networkError(error.localizedDescription)
            }
        } catch {
            throw error
        }
    }
    
    /// Сохранить подтверждение доставки в Firestore
    private func saveDeliveryConfirmation(
        orderId: String,
        trackingNumber: String,
        smsCode: String,
        confirmedAt: Date?
    ) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw KaspiAPIError.authenticationFailed
        }
        
        let confirmationData: [String: Any] = [
            "orderId": orderId,
            "trackingNumber": trackingNumber,
            "confirmationCode": smsCode,
            "confirmedAt": confirmedAt ?? Date(),
            "confirmedBy": userId,
            "syncedWithKaspi": true
        ]
        
        try await db.collection("deliveryConfirmations").document(orderId).setData(confirmationData)
    }
    
    // MARK: - Stock Management
    
    /// Обновить остатки товара
    func updateStock(productId: String, warehouseId: String, quantity: Int, operation: KaspiStockUpdateRequest.StockOperation = .set) async throws {
        guard let token = apiToken else {
            throw KaspiAPIError.tokenNotFound
        }
        
        let request = KaspiStockUpdateRequest(
            productId: productId,
            warehouseId: warehouseId,
            quantity: quantity,
            operation: operation
        )
        
        do {
            let response: KaspiStockUpdateResponse = try await networkManager.post(
                endpoint: Endpoints.updateStock,
                body: request,
                apiToken: token
            )
            
            if response.success {
                print("✅ Остатки обновлены для товара \(productId): \(response.previousQuantity) -> \(response.newQuantity)")
                
                // Обновляем локальные данные в Firestore
                if let userId = Auth.auth().currentUser?.uid {
                    let productRef = db.collection("sellers").document(userId)
                        .collection("products").document(productId)
                    
                    try await productRef.updateData([
                        "warehouseStock.\(warehouseId)": response.newQuantity,
                        "updatedAt": FieldValue.serverTimestamp()
                    ])
                }
            } else {
                throw KaspiAPIError.stockUpdateError("Не удалось обновить остатки")
            }
            
        } catch let error as NetworkError {
            switch error {
            case .serverError(_, let message):
                throw KaspiAPIError.stockUpdateError(message ?? "Ошибка сервера")
            default:
                throw KaspiAPIError.networkError(error.localizedDescription)
            }
        } catch {
            throw error
        }
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
    
    // MARK: - Batch Operations
    
    /// Загрузить товары по списку ID
    func loadProductsByIds(_ productIds: [String]) async throws -> [Product] {
        guard let token = apiToken else {
            throw KaspiAPIError.tokenNotFound
        }
        
        var products: [Product] = []
        
        // Загружаем товары батчами по 10
        for chunk in productIds.chunked(into: 10) {
            let requests = chunk.map { productId in
                networkManager.get(
                    endpoint: String(format: Endpoints.productDetail, productId),
                    apiToken: token
                ) as Future<KaspiProductResponse, Error>
            }
            
            // Ждем все запросы в батче
            let responses = try await withThrowingTaskGroup(of: KaspiProductResponse.self) { group in
                for request in requests {
                    group.addTask {
                        try await request.value
                    }
                }
                
                var results: [KaspiProductResponse] = []
                for try await response in group {
                    results.append(response)
                }
                return results
            }
            
            // Конвертируем в наш формат
            let convertedProducts = responses.map { convertKaspiProductToProduct($0) }
            products.append(contentsOf: convertedProducts)
        }
        
        return products
    }
    
    /// Получить список складов
    func loadWarehouses() async throws -> [Warehouse] {
        guard let token = apiToken else {
            throw KaspiAPIError.tokenNotFound
        }
        
        struct KaspiWarehouse: Codable {
            let id: String
            let name: String
            let address: String
            let city: String
            let isActive: Bool
            
            enum CodingKeys: String, CodingKey {
                case id = "warehouse_id"
                case name
                case address
                case city
                case isActive = "is_active"
            }
        }
        
        let response: KaspiResponse<[KaspiWarehouse]> = try await networkManager.get(
            endpoint: Endpoints.warehouses,
            apiToken: token
        )
        
        guard let kaspiWarehouses = response.data else {
            throw KaspiAPIError.invalidResponse
        }
        
        return kaspiWarehouses.map { kaspiWarehouse in
            Warehouse(
                id: kaspiWarehouse.id,
                name: kaspiWarehouse.name,
                address: kaspiWarehouse.address,
                city: kaspiWarehouse.city,
                isActive: kaspiWarehouse.isActive
            )
        }
    }
}

// MARK: - Helper Extensions

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Future extension for async/await

extension Future {
    var value: Output {
        get async throws {
            try await withCheckedThrowingContinuation { continuation in
                self.sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { value in
                        continuation.resume(returning: value)
                    }
                )
                .store(in: &Set<AnyCancellable>())
            }
        }
    }
}

// MARK: - Warehouse Model

struct Warehouse: Identifiable, Codable {
    let id: String
    let name: String
    let address: String
    let city: String
    let isActive: Bool
}
