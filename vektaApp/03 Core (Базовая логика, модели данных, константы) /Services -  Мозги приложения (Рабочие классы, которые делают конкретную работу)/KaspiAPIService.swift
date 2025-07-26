//
//  KaspiAPIService.swift
//  vektaApp
//
//  Обновленная интеграция с Kaspi API с централизованной обработкой ошибок
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

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
        static let orders = "/orders"
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
            throw KaspiAPIError.from(error)
        } catch {
            throw KaspiAPIError.underlying(NetworkError.from(error))
        }
    }
    
    /// Загрузить заказы из Kaspi API
    func loadOrders() async throws -> [KaspiOrder] {
        guard let token = apiToken else {
            throw KaspiAPIError.tokenNotFound
        }
        
        struct KaspiOrderResponse: Codable {
            let orderId: String
            let orderNumber: String
            let customerInfo: KaspiCustomerInfoResponse
            let deliveryAddress: String
            let totalAmount: Double
            let status: String
            let createdAt: Date
            let items: [KaspiOrderItemResponse]
            
            enum CodingKeys: String, CodingKey {
                case orderId = "order_id"
                case orderNumber = "order_number"
                case customerInfo = "customer_info"
                case deliveryAddress = "delivery_address"
                case totalAmount = "total_amount"
                case status
                case createdAt = "created_at"
                case items
            }
        }
        
        struct KaspiCustomerInfoResponse: Codable {
            let name: String
            let phone: String
            let email: String?
        }
        
        struct KaspiOrderItemResponse: Codable {
            let productId: String
            let productName: String
            let quantity: Int
            let price: Double
            
            enum CodingKeys: String, CodingKey {
                case productId = "product_id"
                case productName = "product_name"
                case quantity
                case price
            }
        }
        
        do {
            let response: KaspiResponse<[KaspiOrderResponse]> = try await networkManager.get(
                endpoint: Endpoints.orders,
                parameters: [
                    "status": "new,processing",
                    "limit": 100
                ],
                apiToken: token
            )
            
            guard let kaspiOrders = response.data else {
                return []
            }
            
            // Конвертируем в нашу модель
            return kaspiOrders.map { kaspiOrder in
                let customerInfo = CustomerInfo(
                    name: kaspiOrder.customerInfo.name,
                    phone: kaspiOrder.customerInfo.phone,
                    email: kaspiOrder.customerInfo.email
                )
                
                let items = kaspiOrder.items.map { item in
                    KaspiOrderItem(
                        productId: item.productId,
                        productName: item.productName,
                        quantity: item.quantity,
                        price: item.price
                    )
                }
                
                return KaspiOrder(
                    orderId: kaspiOrder.orderId,
                    orderNumber: kaspiOrder.orderNumber,
                    customerInfo: customerInfo,
                    deliveryAddress: kaspiOrder.deliveryAddress,
                    totalAmount: kaspiOrder.totalAmount,
                    status: kaspiOrder.status,
                    createdAt: kaspiOrder.createdAt,
                    items: items
                )
            }
            
        } catch let error as NetworkError {
            throw KaspiAPIError.from(error)
        } catch {
            throw KaspiAPIError.syncFailed(error.localizedDescription)
        }
    }
    
    /// Создать доставку из заказа Kaspi
    func createDeliveryFromKaspiOrder(
        _ kaspiOrder: KaspiOrder,
        courierId: String,
        courierName: String
    ) async throws -> DeliveryConfirmation {
        
        let delivery = DeliveryConfirmation(
            id: UUID().uuidString,
            orderId: kaspiOrder.orderId,
            trackingNumber: kaspiOrder.orderNumber,
            courierId: courierId,
            courierName: courierName,
            customerPhone: kaspiOrder.customerInfo.phone,
            deliveryAddress: kaspiOrder.deliveryAddress,
            smsCodeRequested: false,
            smsCodeRequestedAt: nil,
            confirmationCode: nil,
            codeExpiresAt: nil,
            status: .pending,
            confirmedAt: nil,
            confirmedBy: nil,
            attemptCount: 0,
            maxAttempts: 3,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Сохраняем доставку в Firestore
        try await db.collection("deliveries")
            .document(delivery.id)
            .setData(delivery.toDictionary())
        
        return delivery
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
            
        } catch let error as KaspiAPIError {
            isLoading = false
            errorMessage = error.localizedDescription
            syncProgress = 0.0
            throw error
        } catch let error as NetworkError {
            isLoading = false
            let kaspiError = KaspiAPIError.from(error)
            errorMessage = kaspiError.localizedDescription
            syncProgress = 0.0
            throw kaspiError
        } catch {
            isLoading = false
            let kaspiError = KaspiAPIError.underlying(NetworkError.from(error))
            errorMessage = kaspiError.localizedDescription
            syncProgress = 0.0
            throw kaspiError
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
            throw KaspiAPIError.from(error)
        } catch let error as KaspiAPIError {
            throw error
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
                throw KaspiAPIError.deliveryConfirmationFailed(response.message ?? "Неверный код подтверждения")
            }
            
        } catch let error as NetworkError {
            throw KaspiAPIError.from(error)
        } catch let error as KaspiAPIError {
            throw error
        } catch {
            throw KaspiAPIError.deliveryConfirmationFailed(error.localizedDescription)
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
            throw KaspiAPIError.from(error)
        } catch let error as KaspiAPIError {
            throw error
        } catch {
            throw KaspiAPIError.stockUpdateError(error.localizedDescription)
        }
    }
    
    // MARK: - Utility Methods
    
    func checkAPIHealth() async -> Bool {
        do {
            return try await validateToken()
        } catch {
            ErrorHandler.handle(error, context: "KaspiAPIService.checkAPIHealth")
            return false
        }
    }
    
    var apiStatistics: (requests: Int, lastSync: Date?) {
        // TODO: Implement request counting
        return (0, lastSyncDate)
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
        
        do {
            let response: KaspiResponse<[KaspiWarehouse]> = try await networkManager.get(
                endpoint: Endpoints.warehouses,
                apiToken: token
            )
            
            guard let kaspiWarehouses = response.data else {
                throw KaspiAPIError.warehouseNotFound
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
            
        } catch let error as NetworkError {
            throw KaspiAPIError.from(error)
        } catch let error as KaspiAPIError {
            throw error
        } catch {
            throw KaspiAPIError.warehouseNotFound
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
