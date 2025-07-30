//
//  KaspiOrdersSync.swift
//  vektaApp
//
//  Сервис для синхронизации заказов из Kaspi
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: — Модели ответов Kaspi API

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
        case orderId        = "id"
        case orderNumber
        case status
        case createdDate
        case totalPrice
        case customerName
        case customerPhone
        case customerEmail
        case deliveryAddress
        case items          = "orderItems"
    }
}

struct KaspiOrderItemResponse: Codable {
    let productId: String
    let productName: String
    let sku: String
    let quantity: Int
    let price: Double
    let totalPrice: Double
}

struct KaspiOrdersListResponse: Codable {
    let content: [KaspiOrderResponse]
    let totalElements: Int
    let totalPages: Int
    let size: Int
    let number: Int
}

// MARK: — Локальные модели (предполагается, что они у тебя уже есть)
// struct KaspiOrder { … }
// struct KaspiAPIError: Error { … }

@MainActor
final class KaspiOrdersSync: ObservableObject {
    // MARK: Published
    @Published var orders: [KaspiOrder] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastSyncDate: Date?

    // MARK: Private
    private let db = Firestore.firestore()
    private let kaspiService: KaspiAPIService
    private let baseURL: URL

    // MARK: Init
    init() {
        self.kaspiService = KaspiAPIService()
        self.baseURL     = URL(string: "https://kaspi.kz/shop/api/v2")!
    }

    // MARK: Sync Orders
    func syncOrders() async {
        // 1) Проверяем токен
        guard let token = kaspiService.apiToken, !token.isEmpty else {
            errorMessage = "Kaspi API токен не найден"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // 2) Получаем из API
            let apiOrders = try await fetchOrdersFromAPI(token: token)

            // 3) Маппим и сохраняем
            let local = apiOrders.map(convertToLocalOrder)
            orders = local
            try await saveOrdersToFirestore(local)

            lastSyncDate = Date()
            print("✅ Синхронизировано \(local.count) заказов")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Ошибка синхронизации: \(error)")
        }

        isLoading = false
    }

    // MARK: Fetch from API
    private func fetchOrdersFromAPI(token: String) async throws -> [KaspiOrderResponse] {
        let url = baseURL
            .appendingPathComponent("orders")
            .appendingQueryItem(name: "status", value: "NEW,PROCESSING")
            .appendingQueryItem(name: "page", value: "0")
            .appendingQueryItem(name: "size", value: "100")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "X-TOKEN")

        let (data, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard http.statusCode == 200 else {
            throw NetworkError.serverError(http.statusCode,
                                          "Ошибка получения заказов (код \(http.statusCode))")
        }

        let wrapper = try JSONDecoder().decode(KaspiOrdersListResponse.self, from: data)
        return wrapper.content
    }

    // MARK: Mapping
    private func convertToLocalOrder(_ resp: KaspiOrderResponse) -> KaspiOrder {
        let customer = CustomerInfo(
            name: resp.customerName,
            phone: resp.customerPhone,
            email: resp.customerEmail
        )
        let items = resp.items.map {
            KaspiOrderItem(
                productId:   $0.productId,
                productName: $0.productName,
                quantity:    $0.quantity,
                price:       $0.price
            )
        }
        return KaspiOrder(
            orderId:         resp.orderId,
            orderNumber:     resp.orderNumber,
            customerInfo:    customer,
            deliveryAddress: resp.deliveryAddress,
            totalAmount:     resp.totalPrice,
            status:          resp.status,
            createdAt:       resp.createdDate,
            items:           items
        )
    }

    // MARK: Save to Firestore
    private func saveOrdersToFirestore(_ orders: [KaspiOrder]) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw KaspiAPIError.authenticationFailed
        }

        let batch = db.batch()
        for order in orders {
            let ref = db.collection("kaspiOrders").document(order.orderId)
            let data: [String: Any] = [
                "kaspiOrderId":   order.orderId,
                "orderNumber":    order.orderNumber,
                "customerName":   order.customerInfo.name,
                "customerPhone":  order.customerInfo.phone,
                "customerEmail":  order.customerInfo.email ?? "",
                "deliveryAddress":order.deliveryAddress,
                "totalAmount":    order.totalAmount,
                "status":         order.status,
                "items":          order.items.map { [
                    "productId":   $0.productId,
                    "productName": $0.productName,
                    "quantity":    $0.quantity,
                    "price":       $0.price
                ] },
                "createdAt":      Timestamp(date: order.createdAt),
                "syncedAt":       FieldValue.serverTimestamp(),
                "sellerId":       userId
            ]
            batch.setData(data, forDocument: ref, merge: true)
        }
        try await batch.commit()
    }
}

// MARK: — URLComponents helper

private extension URL {
    func appendingQueryItem(name: String, value: String) -> URL {
        guard var comps = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }
        var items = comps.queryItems ?? []
        items.append(URLQueryItem(name: name, value: value))
        comps.queryItems = items
        return comps.url ?? self
    }
}
