//
//  KaspiOrdersSync.swift
//  vektaApp
//
//  Сервис для синхронизации заказов из Kaspi
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Kaspi Order Models

/// Модель заказа из Kaspi API
struct KaspiOrderResponse: Codable {
    let orderId: String
    let orderNumber: String
    let status: String
    let createdDate: Date
    let totalPrice: Double
    let customerName: String
    let customerPhone: String
    let customerEmail: String?
    let deliveryAddress: String
    let items: [KaspiOrderItemResponse]
    
    enum CodingKeys: String, CodingKey {
        case orderId = "id"
        case orderNumber = "orderNumber"
        case status = "status"
        case createdDate = "createdDate"
        case totalPrice = "totalPrice"
        case customerName = "customerName"
        case customerPhone = "customerPhone"
        case customerEmail = "customerEmail"
        case deliveryAddress = "deliveryAddress"
        case items = "orderItems"
    }
}

/// Товар в заказе Kaspi
struct KaspiOrderItemResponse: Codable {
    let productId: String
    let productName: String
    let sku: String
    let quantity: Int
    let price: Double
    let totalPrice: Double
}

/// Список заказов
struct KaspiOrdersListResponse: Codable {
    let content: [KaspiOrderResponse]
    let totalElements: Int
    let totalPages: Int
    let size: Int
    let number: Int
}

// MARK: - KaspiOrdersSync Service

@MainActor
class KaspiOrdersSync: ObservableObject {
    
    @Published var orders: [KaspiOrder] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastSyncDate: Date?
    
    private let db = Firestore.firestore()
    private let kaspiService: KaspiAPIService
    private let baseURL = "https://kaspi.kz/shop/api/v2"
    
    init(kaspiService: KaspiAPIService) {
        self.kaspiService = kaspiService
    }
    
    // MARK: - Sync Orders
    
    /// Синхронизировать заказы из Kaspi
    func syncOrders() async {
        guard let token = kaspiService.kaspiToken else {
            errorMessage = "Отсутствует Kaspi токен"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Получаем заказы из API
            let kaspiOrders = try await fetchOrdersFromAPI(token: token)
            
            // Конвертируем в наш формат
            self.orders = kaspiOrders.map { convertToKaspiOrder($0) }
            
            // Сохраняем в Firestore
            try await saveOrdersToFirestore(orders)
            
            lastSyncDate = Date()
            isLoading = false
            
            print("✅ Синхронизировано \(orders.count) заказов из Kaspi")
            
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            print("❌ Ошибка синхронизации заказов: \(error)")
        }
    }
    
    /// Получить заказы из API
    private func fetchOrdersFromAPI(token: String) async throws -> [KaspiOrderResponse] {
        let urlString = "\(baseURL)/orders?status=NEW,PROCESSING&page=0&size=100"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "X-TOKEN": token
        ]
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(httpResponse.statusCode, "Ошибка получения заказов")
        }
        
        let decoded = try JSONDecoder().decode(KaspiOrdersListResponse.self, from: data)
        return decoded.content
    }
    
    /// Конвертировать в наш формат KaspiOrder
    private func convertToKaspiOrder(_ response: KaspiOrderResponse) -> KaspiOrder {
        let customerInfo = CustomerInfo(
            name: response.customerName,
            phone: response.customerPhone,
            email: response.customerEmail
        )
        
        let items = response.items.map { item in
            KaspiOrderItem(
                productId: item.productId,
                productName: item.productName,
                quantity: item.quantity,
                price: item.price
            )
        }
        
        return KaspiOrder(
            orderId: response.orderId,
            orderNumber: response.orderNumber,
            customerInfo: customerInfo,
            deliveryAddress: response.deliveryAddress,
            totalAmount: response.totalPrice,
            status: response.status,
            createdAt: response.createdDate,
            items: items
        )
    }
    
    /// Сохранить заказы в Firestore
    private func saveOrdersToFirestore(_ orders: [KaspiOrder]) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw KaspiAPIError.authenticationFailed
        }
        
        let batch = db.batch()
        
        for order in orders {
            let orderData: [String: Any] = [
                "kaspiOrderId": order.orderId,
                "orderNumber": order.orderNumber,
                "customerName": order.customerInfo.name,
                "customerPhone": order.customerInfo.phone,
                "customerEmail": order.customerInfo.email ?? "",
                "deliveryAddress": order.deliveryAddress,
                "totalAmount": order.totalAmount,
                "status": order.status,
                "items": order.items.map { item in
                    [
                        "productId": item.productId,
                        "productName": item.productName,
                        "quantity": item.quantity,
                        "price": item.price
                    ]
                },
                "createdAt": Timestamp(date: order.createdAt),
                "syncedAt": FieldValue.serverTimestamp(),
                "sellerId": userId
            ]
            
            let docRef = db.collection("kaspiOrders").document(order.orderId)
            batch.setData(orderData, forDocument: docRef, merge: true)
        }
        
        try await batch.commit()
    }
    
    // MARK: - Order Status Updates
    
    /// Обновить статус заказа
    func updateOrderStatus(_ orderId: String, status: String) async throws {
        guard let token = kaspiService.kaspiToken else {
            throw KaspiAPIError.tokenNotFound
        }
        
        let urlString = "\(baseURL)/orders/\(orderId)/status"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.allHTTPHeaderFields = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "X-TOKEN": token
        ]
        
        let payload = ["status": status]
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            throw NetworkError.serverError(httpResponse.statusCode, "Ошибка обновления статуса")
        }
        
        // Обновляем статус в Firestore
        try await db.collection("kaspiOrders").document(orderId).updateData([
            "status": status,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        print("✅ Статус заказа \(orderId) обновлен на \(status)")
    }
    
    // MARK: - Delivery Confirmation
    
    /// Подтвердить доставку заказа
    func confirmDelivery(orderId: String, smsCode: String) async throws -> Bool {
        guard let token = kaspiService.kaspiToken else {
            throw KaspiAPIError.tokenNotFound
        }
        
        let urlString = "\(baseURL)/orders/\(orderId)/confirm-delivery"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "X-TOKEN": token
        ]
        
        let payload = [
            "orderId": orderId,
            "confirmationCode": smsCode
        ]
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            // Обновляем статус на "Доставлен"
            try await updateOrderStatus(orderId, status: "DELIVERED")
            return true
        } else {
            // Попытка декодировать ошибку
            if let errorResponse = try? JSONDecoder().decode(KaspiErrorResponse.self, from: data) {
                throw KaspiAPIError.deliveryConfirmationFailed(errorResponse.message ?? "Неверный код")
            }
            return false
        }
    }
    
    // MARK: - SMS Code Request
    
    /// Запросить SMS код для заказа
    func requestSMSCode(for order: KaspiOrder) async throws -> String {
        guard let token = kaspiService.kaspiToken else {
            throw KaspiAPIError.tokenNotFound
        }
        
        let urlString = "\(baseURL)/orders/\(order.orderId)/request-sms"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "X-TOKEN": token
        ]
        
        let payload = [
            "orderId": order.orderId,
            "customerPhone": order.customerInfo.phone
        ]
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(httpResponse.statusCode, "Ошибка отправки SMS")
        }
        
        struct SMSResponse: Codable {
            let messageId: String
            let expiresIn: Int
        }
        
        let smsResponse = try JSONDecoder().decode(SMSResponse.self, from: data)
        
        print("✅ SMS код отправлен для заказа \(order.orderNumber)")
        return smsResponse.messageId
    }
    
    // MARK: - Helpers
    
    /// Получить заказ по ID
    func getOrder(by orderId: String) -> KaspiOrder? {
        return orders.first { $0.orderId == orderId }
    }
    
    /// Получить новые заказы (со статусом NEW)
    var newOrders: [KaspiOrder] {
        return orders.filter { $0.status == "NEW" }
    }
    
    /// Получить заказы в обработке
    var processingOrders: [KaspiOrder] {
        return orders.filter { $0.status == "PROCESSING" }
    }
}
