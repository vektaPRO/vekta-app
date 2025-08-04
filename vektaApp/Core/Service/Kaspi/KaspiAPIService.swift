//
//  KaspiAPIService.swift
//  vektaApp
//
//  Полная реализация Kaspi API согласно документации
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class KaspiAPIService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var apiToken: String?
    @Published var lastSyncDate: Date?
    
    // MARK: - Private Properties
    private let networkManager = NetworkManager.shared
    private let db = Firestore.firestore()
    
    // API Configuration
    private let baseURL = "https://kaspi.kz/shop/api/v2"
    private let maxRetries = 3
    private let requestTimeout: TimeInterval = 30.0
    
    // MARK: - Initialization
    
    init() {
        loadTokenFromFirestore()
    }
    
    // MARK: - Token Management
    
    /// Загрузить токен из Firestore
    func loadTokenFromFirestore() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("sellers").document(userId).getDocument { [weak self] snapshot, error in
            DispatchQueue.main.async {
                if let data = snapshot?.data(),
                   let token = data["kaspiApiToken"] as? String {
                    self?.apiToken = token
                    self?.lastSyncDate = (data["lastApiSync"] as? Timestamp)?.dateValue()
                }
            }
        }
    }
    
    /// Сохранить токен в Firestore
    func saveToken(_ token: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw KaspiAPIError.authenticationFailed
        }
        
        apiToken = token
        
        try await db.collection("sellers").document(userId).setData([
            "kaspiApiToken": token,
            "tokenUpdatedAt": FieldValue.serverTimestamp(),
            "kaspiApiEnabled": true
        ], merge: true)
        
        successMessage = "✅ API токен успешно сохранен"
    }
    
    /// Проверить валидность токена
    func validateToken() async -> Bool {
        guard let token = apiToken else { return false }
        
        do {
            let _: KaspiAPIResponse<KaspiProduct> = try await performRequest(
                endpoint: "/products",
                method: .get,
                parameters: ["page[size]": "1"]
            )
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Products API
    
    /// Получить JSON схему для импорта товаров
    func getProductImportSchema() async throws -> KaspiImportSchema {
        return try await performRequest(
            endpoint: "/products/import/schema",
            method: .get
        )
    }
    
    /// Получить список категорий
    func getCategories() async throws -> [KaspiCategory] {
        let response: KaspiAPIResponse<KaspiCategory> = try await performRequest(
            endpoint: "/products/classification/categories",
            method: .get
        )
        return response.data ?? []
    }
    
    /// Получить атрибуты категории
    func getCategoryAttributes(categoryCode: String) async throws -> [KaspiAttribute] {
        let response: KaspiAPIResponse<KaspiAttribute> = try await performRequest(
            endpoint: "/products/classification/attributes",
            method: .get,
            parameters: ["c": categoryCode]
        )
        return response.data ?? []
    }
    
    /// Импорт товаров
    func importProducts(_ products: [KaspiProductImportItem]) async throws -> String {
        let importData = KaspiProductImport(data: products)
        
        let response: KaspiAPIResponse<KaspiImportStatus> = try await performRequest(
            endpoint: "/products/import",
            method: .post,
            body: importData
        )
        
        guard let importStatus = response.data?.first else {
            throw KaspiAPIError.invalidProductData
        }
        
        return importStatus.id
    }
    
    /// Проверить статус импорта
    func checkImportStatus(importId: String) async throws -> KaspiImportStatus {
        let response: KaspiAPIResponse<KaspiImportStatus> = try await performRequest(
            endpoint: "/products/import/\(importId)",
            method: .get
        )
        
        guard let status = response.data?.first else {
            throw KaspiAPIError.syncFailed("Статус импорта не найден")
        }
        
        return status
    }
    
    /// Получить список товаров
    func getProducts(page: Int = 0, size: Int = 100) async throws -> KaspiAPIResponse<KaspiProduct> {
        return try await performRequest(
            endpoint: "/products",
            method: .get,
            parameters: [
                "page[number]": "\(page)",
                "page[size]": "\(size)"
            ]
        )
    }
    
    // MARK: - Orders API
    
    /// Получить список заказов
    func getOrders(
        page: Int = 0,
        size: Int = 100,
        status: KaspiOrderStatus? = nil,
        state: KaspiOrderState? = nil,
        creationDateFrom: Date? = nil,
        creationDateTo: Date? = nil
    ) async throws -> KaspiAPIResponse<KaspiOrder> {
        
        var parameters: [String: String] = [
            "page[number]": "\(page)",
            "page[size]": "\(size)"
        ]
        
        if let status = status {
            parameters["filter[orders][status]"] = status.rawValue
        }
        
        if let state = state {
            parameters["filter[orders][state]"] = state.rawValue
        }
        
        if let fromDate = creationDateFrom {
            parameters["filter[orders][creationDate][from]"] = ISO8601DateFormatter().string(from: fromDate)
        }
        
        if let toDate = creationDateTo {
            parameters["filter[orders][creationDate][to]"] = ISO8601DateFormatter().string(from: toDate)
        }
        
        return try await performRequest(
            endpoint: "/orders",
            method: .get,
            parameters: parameters
        )
    }
    
    /// Получить заказ по коду
    func getOrder(code: String) async throws -> KaspiOrder {
        let response: KaspiAPIResponse<KaspiOrder> = try await performRequest(
            endpoint: "/orders",
            method: .get,
            parameters: ["filter[orders][code]": code]
        )
        
        guard let order = response.data?.first else {
            throw KaspiAPIError.orderNotFound
        }
        
        return order
    }
    
    /// Получить позиции заказа
    func getOrderEntries(orderId: String) async throws -> [KaspiOrderEntry] {
        let response: KaspiAPIResponse<KaspiOrderEntry> = try await performRequest(
            endpoint: "/orders/\(orderId)/entries",
            method: .get
        )
        return response.data ?? []
    }
    
    /// Получить детали позиции
    func getOrderEntryDetails(entryId: String) async throws -> KaspiOrderEntry {
        let response: KaspiAPIResponse<KaspiOrderEntry> = try await performRequest(
            endpoint: "/orderentries/\(entryId)",
            method: .get
        )
        
        guard let entry = response.data?.first else {
            throw KaspiAPIError.orderNotFound
        }
        
        return entry
    }
    
    /// Получить информацию о товаре позиции
    func getOrderEntryProduct(entryId: String) async throws -> KaspiProduct {
        let response: KaspiAPIResponse<KaspiProduct> = try await performRequest(
            endpoint: "/orderentries/\(entryId)/product",
            method: .get
        )
        
        guard let product = response.data?.first else {
            throw KaspiAPIError.productNotFound
        }
        
        return product
    }
    
    /// Получить IMEI коды заказа
    func getOrderIMEI(orderId: String) async throws -> [KaspiIMEI] {
        return try await performRequest(
            endpoint: "/orders/\(orderId)/imei",
            method: .get
        )
    }
    
    // MARK: - Order Operations
    
    /// Подтвердить заказ
    func acceptOrder(orderId: String, orderCode: String) async throws -> KaspiOrder {
        let operation = KaspiOrderOperation(
            type: "orders",
            id: orderId,
            attributes: KaspiOrderOperationAttributes(
                code: orderCode,
                status: .acceptedByMerchant,
                numberOfSpace: nil,
                reason: nil,
                comment: nil
            )
        )
        
        let response: KaspiAPIResponse<KaspiOrder> = try await performRequest(
            endpoint: "/orders",
            method: .post,
            body: ["data": operation]
        )
        
        guard let order = response.data?.first else {
            throw KaspiAPIError.syncFailed("Не удалось подтвердить заказ")
        }
        
        return order
    }
    
    /// Передать заказ на доставку
    func shipOrder(orderId: String, numberOfSpace: Int = 1) async throws -> KaspiOrder {
        let operation = KaspiOrderOperation(
            type: "orders",
            id: orderId,
            attributes: KaspiOrderOperationAttributes(
                code: "",
                status: .assemble,
                numberOfSpace: numberOfSpace,
                reason: nil,
                comment: nil
            )
        )
        
        let response: KaspiAPIResponse<KaspiOrder> = try await performRequest(
            endpoint: "/orders",
            method: .post,
            body: ["data": operation]
        )
        
        guard let order = response.data?.first else {
            throw KaspiAPIError.syncFailed("Не удалось передать заказ на доставку")
        }
        
        return order
    }
    
    /// Завершить заказ (первый этап - отправка кода)
    func completeOrderStep1(orderId: String) async throws {
        let operation = KaspiOrderOperation(
            type: "orders",
            id: orderId,
            attributes: KaspiOrderOperationAttributes(
                code: "",
                status: .completed,
                numberOfSpace: nil,
                reason: nil,
                comment: nil
            )
        )
        
        let _: KaspiAPIResponse<KaspiOrder> = try await performRequest(
            endpoint: "/orders",
            method: .post,
            body: ["data": operation],
            headers: ["X-Security-Code": ""] // Пустой код для первого запроса
        )
    }
    
    /// Завершить заказ (второй этап - с кодом)
    func completeOrderStep2(orderId: String, securityCode: String) async throws -> KaspiOrder {
        let operation = KaspiOrderOperation(
            type: "orders",
            id: orderId,
            attributes: KaspiOrderOperationAttributes(
                code: "",
                status: .completed,
                numberOfSpace: nil,
                reason: nil,
                comment: nil
            )
        )
        
        let response: KaspiAPIResponse<KaspiOrder> = try await performRequest(
            endpoint: "/orders",
            method: .post,
            body: ["data": operation],
            headers: ["X-Security-Code": securityCode]
        )
        
        guard let order = response.data?.first else {
            throw KaspiAPIError.syncFailed("Не удалось завершить заказ")
        }
        
        return order
    }
    
    /// Указать IMEI коды вручную
    func setOrderEntryIMEI(entryId: String, imeiData: KaspiIMEI) async throws {
        let _: KaspiAPIResponse<KaspiOrderEntry> = try await performRequest(
            endpoint: "/orderEntryImeiOperation/\(entryId)",
            method: .post,
            body: imeiData
        )
    }
    
    /// Получить информацию о складе
    func getDeliveryPointOfService(entryId: String) async throws -> KaspiDeliveryPoint {
        let response: KaspiAPIResponse<KaspiDeliveryPoint> = try await performRequest(
            endpoint: "/orderentries/\(entryId)/deliveryPointOfService",
            method: .get
        )
        
        guard let deliveryPoint = response.data?.first else {
            throw KaspiAPIError.warehouseNotFound
        }
        
        return deliveryPoint
    }
    
    /// Отменить позицию заказа
    func cancelOrderEntry(
        entryId: String,
        reason: String,
        remainedQuantity: Int = 0,
        notes: String? = nil
    ) async throws {
        let operation = KaspiOrderEntryOperation(
            type: "orderEntryCancelOperation",
            attributes: KaspiOrderEntryOperationAttributes(
                entryId: entryId,
                operationType: .cancel,
                reason: reason,
                remainedQuantity: remainedQuantity,
                newWeight: nil,
                notes: notes
            )
        )
        
        let _: KaspiAPIResponse<KaspiOrderEntry> = try await performRequest(
            endpoint: "/orderentries",
            method: .post,
            body: ["data": operation]
        )
    }
    
    /// Изменить вес товара
    func changeOrderEntryWeight(entryId: String, newWeight: Double) async throws {
        let operation = KaspiOrderEntryOperation(
            type: "orderEntryChangeWeightOperation",
            attributes: KaspiOrderEntryOperationAttributes(
                entryId: entryId,
                operationType: .changeWeight,
                reason: nil,
                remainedQuantity: nil,
                newWeight: newWeight,
                notes: nil
            )
        )
        
        let _: KaspiAPIResponse<KaspiOrderEntry> = try await performRequest(
            endpoint: "/orderentries",
            method: .post,
            body: ["data": operation]
        )
    }
    
    // MARK: - High-Level Business Logic Methods
    
    /// Синхронизировать все товары из Kaspi
    func syncAllProducts() async throws -> [Product] {
        isLoading = true
        defer { isLoading = false }
        
        var allProducts: [KaspiProduct] = []
        var currentPage = 0
        let pageSize = 100
        
        repeat {
            let response = try await getProducts(page: currentPage, size: pageSize)
            let products = response.data ?? []
            allProducts.append(contentsOf: products)
            
            // Проверяем есть ли еще страницы
            if let totalPages = response.meta?.pagination?.totalPages,
               currentPage + 1 >= totalPages {
                break
            }
            
            currentPage += 1
        } while true
        
        // Сохраняем дату синхронизации
        lastSyncDate = Date()
        try await updateLastSyncDate()
        
        // Конвертируем в локальные модели
        let localProducts = allProducts.map { $0.toLocalProduct() }
        
        successMessage = "✅ Синхронизировано \(localProducts.count) товаров"
        return localProducts
    }
    
    /// Синхронизировать заказы за последние дни
    func syncRecentOrders(days: Int = 7) async throws -> [Order] {
        isLoading = true
        defer { isLoading = false }
        
        let fromDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let toDate = Date()
        
        var allOrders: [KaspiOrder] = []
        var currentPage = 0
        let pageSize = 100
        
        repeat {
            let response = try await getOrders(
                page: currentPage,
                size: pageSize,
                state: .new,
                creationDateFrom: fromDate,
                creationDateTo: toDate
            )
            
            let orders = response.data ?? []
            allOrders.append(contentsOf: orders)
            
            if let totalPages = response.meta?.pagination?.totalPages,
               currentPage + 1 >= totalPages {
                break
            }
            
            currentPage += 1
        } while true
        
        // Конвертируем в локальные модели
        let localOrders = allOrders.map { $0.toLocalOrder() }
        
        successMessage = "✅ Синхронизировано \(localOrders.count) заказов"
        return localOrders
    }
    
    /// Обработать новые заказы (принять и передать на доставку)
    func processNewOrders() async throws {
        let newOrdersResponse = try await getOrders(size: 50, state: .new)
        let newOrders = newOrdersResponse.data ?? []
        
        for order in newOrders {
            do {
                // 1. Принимаем заказ
                let acceptedOrder = try await acceptOrder(
                    orderId: order.id,
                    orderCode: order.attributes.code
                )
                
                // 2. Сразу передаем на доставку (если Kaspi доставка)
                if order.attributes.isKaspiDelivery {
                    _ = try await shipOrder(orderId: acceptedOrder.id)
                }
                
                print("✅ Заказ \(order.attributes.code) обработан")
                
            } catch {
                print("❌ Ошибка обработки заказа \(order.attributes.code): \(error)")
            }
        }
    }
    
    /// Создать доставку из заказа Kaspi
    func createDeliveryFromKaspiOrder(
        _ order: KaspiOrder,
        courierId: String,
        courierName: String
    ) async throws -> DeliveryConfirmation {
        
        let delivery = DeliveryConfirmation(
            id: UUID().uuidString,
            orderId: order.id,
            trackingNumber: order.attributes.code,
            courierId: courierId,
            courierName: courierName,
            customerPhone: order.attributes.customer.cellPhone,
            deliveryAddress: order.attributes.deliveryAddress.formattedAddress,
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
        
        // Сохраняем в Firestore
        try await saveDeliveryToFirestore(delivery)
        
        return delivery
    }
    
    // MARK: - Delivery Management
    
    /// Запросить SMS код для подтверждения доставки
    func requestDeliveryConfirmationCode(
        orderId: String,
        trackingNumber: String,
        customerPhone: String
    ) async throws -> String {
        
        // Первый этап завершения заказа - отправка кода клиенту
        try await completeOrderStep1(orderId: orderId)
        
        // Возвращаем ID операции (в реальности код отправляется клиенту)
        return UUID().uuidString
    }
    
    /// Подтвердить доставку с кодом от клиента
    func confirmDeliveryWithCode(
        orderId: String,
        trackingNumber: String,
        securityCode: String
    ) async throws -> Bool {
        
        do {
            // Второй этап завершения заказа - с кодом от клиента
            let completedOrder = try await completeOrderStep2(
                orderId: orderId,
                securityCode: securityCode
            )
            
            // Проверяем что заказ действительно завершен
            return completedOrder.attributes.status == .completed
            
        } catch {
            // Если код неверный или произошла ошибка
            return false
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Выполнить HTTP запрос к Kaspi API
    private func performRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: String]? = nil,
        body: Encodable? = nil,
        headers: [String: String]? = nil
    ) async throws -> T {
        
        guard let token = apiToken else {
            throw KaspiAPIError.tokenNotFound
        }
        
        var apiHeaders = [
            "X-Auth-Token": token,
            "Content-Type": "application/vnd.api+json",
            "Accept": "application/vnd.api+json"
        ]
        
        // Добавляем дополнительные заголовки
        if let additionalHeaders = headers {
            apiHeaders.merge(additionalHeaders) { _, new in new }
        }
        
        return try await networkManager.request(
            endpoint: endpoint,
            method: method,
            parameters: parameters,
            body: body,
            headers: apiHeaders,
            retryPolicy: .default
        )
    }
    
    /// Обновить дату последней синхронизации
    private func updateLastSyncDate() async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        try await db.collection("sellers").document(userId).setData([
            "lastApiSync": FieldValue.serverTimestamp(),
            "totalApiRequests": FieldValue.increment(Int64(1))
        ], merge: true)
    }
    
    /// Сохранить доставку в Firestore
    private func saveDeliveryToFirestore(_ delivery: DeliveryConfirmation) async throws {
        let deliveryData = delivery.toDictionary()
        try await db.collection("deliveries").document(delivery.id).setData(deliveryData)
    }
    
    // MARK: - Error Handling
    
    func handleError(_ error: Error) {
        DispatchQueue.main.async {
            if let kaspiError = error as? KaspiAPIError {
                self.errorMessage = kaspiError.errorDescription
            } else if let networkError = error as? NetworkError {
                self.errorMessage = networkError.errorDescription
            } else {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
    
}
