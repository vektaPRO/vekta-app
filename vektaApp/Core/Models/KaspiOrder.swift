import Foundation

// MARK: - Основная модель заказа Kaspi

struct KaspiOrder: Codable, Identifiable, Equatable {
    var id: String { orderId }

    let orderId: String
    let orderNumber: String
    let customerInfo: CustomerInfo
    let deliveryAddress: String
    let totalAmount: Double
    let status: String
    let createdAt: Date
    let items: [KaspiOrderItem]
}

// MARK: - Информация о клиенте

struct CustomerInfo: Codable, Equatable {
    let name: String
    let phone: String
    let email: String?
}

// MARK: - Товары в заказе

struct KaspiOrderItem: Codable, Equatable {
    let productId: String
    let productName: String
    let quantity: Int
    let price: Double
}
