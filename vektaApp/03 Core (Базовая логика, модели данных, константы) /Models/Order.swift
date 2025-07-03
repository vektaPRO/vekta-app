//
//  Order.swift
//  vektaApp
//
//  Created by Almas Kadeshov on 02.07.2025.
//

import Foundation
import FirebaseFirestore

// 📦 Модель заказа на отправку товаров на склад
struct Order: Identifiable, Codable {
    let id: String
    let orderNumber: String          // Номер заказа (например: ORD-2025-001)
    let sellerId: String             // ID продавца
    let sellerEmail: String          // Email продавца
    let warehouseId: String          // ID склада назначения
    let warehouseName: String        // Название склада
    
    // Товары в заказе
    let items: [OrderItem]
    
    // Информация о заказе
    let notes: String                // Заметки к заказу
    let status: OrderStatus          // Статус заказа
    let priority: OrderPriority      // Приоритет заказа
    
    // Временные метки
    let createdAt: Date             // Время создания
    let updatedAt: Date             // Время последнего обновления
    let estimatedDelivery: Date?     // Планируемая дата доставки
    
    // QR код
    let qrCodeData: String          // Данные для QR кода
    
    // Рассчитанные свойства
    var totalItems: Int {
        items.reduce(0) { $0 + $1.quantity }
    }
    
    var totalValue: Double {
        items.reduce(0) { $0 + ($1.price * Double($1.quantity)) }
    }
    
    var formattedTotalValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "KZT"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: totalValue)) ?? "\(Int(totalValue)) ₸"
    }
    
    var statusColor: String {
        status.color
    }
    
    var statusIcon: String {
        status.iconName
    }
}

// 📦 Товар в заказе
struct OrderItem: Identifiable, Codable {
    let id: String
    let productSKU: String          // SKU товара
    let productName: String         // Название товара
    let quantity: Int               // Количество
    let price: Double              // Цена за единицу
    let imageURL: String           // URL изображения
    let category: String           // Категория товара
    
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "KZT"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "\(Int(price)) ₸"
    }
    
    var totalPrice: Double {
        price * Double(quantity)
    }
    
    var formattedTotalPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "KZT"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: totalPrice)) ?? "\(Int(totalPrice)) ₸"
    }
}

// 🏷️ Статус заказа
enum OrderStatus: String, CaseIterable, Codable {
    case draft = "Черновик"           // Создается
    case pending = "Ожидает"          // Готов к отправке
    case shipped = "Отправлен"        // Отправлен на склад
    case received = "Получен"         // Получен складом
    case completed = "Завершен"       // Полностью обработан
    case cancelled = "Отменен"        // Отменен
    
    var color: String {
        switch self {
        case .draft:
            return "gray"
        case .pending:
            return "orange"
        case .shipped:
            return "blue"
        case .received:
            return "green"
        case .completed:
            return "green"
        case .cancelled:
            return "red"
        }
    }
    
    var iconName: String {
        switch self {
        case .draft:
            return "doc.text"
        case .pending:
            return "clock"
        case .shipped:
            return "truck.box"
        case .received:
            return "checkmark.circle"
        case .completed:
            return "checkmark.circle.fill"
        case .cancelled:
            return "xmark.circle"
        }
    }
    
    var description: String {
        switch self {
        case .draft:
            return "Заказ создается"
        case .pending:
            return "Готов к отправке на склад"
        case .shipped:
            return "Отправлен на склад"
        case .received:
            return "Получен складом"
        case .completed:
            return "Товары размещены на складе"
        case .cancelled:
            return "Заказ отменен"
        }
    }
}

// ⚡ Приоритет заказа
enum OrderPriority: String, CaseIterable, Codable {
    case low = "Низкий"
    case normal = "Обычный"
    case high = "Высокий"
    case urgent = "Срочный"
    
    var color: String {
        switch self {
        case .low:
            return "green"
        case .normal:
            return "blue"
        case .high:
            return "orange"
        case .urgent:
            return "red"
        }
    }
    
    var iconName: String {
        switch self {
        case .low:
            return "arrow.down.circle"
        case .normal:
            return "minus.circle"
        case .high:
            return "arrow.up.circle"
        case .urgent:
            return "exclamationmark.triangle.fill"
        }
    }
}

// 🏭 Расширение для работы с Firestore
extension Order {
    
    // Создание Order из Firestore документа
    static func fromFirestore(_ data: [String: Any], id: String) -> Order? {
        guard
            let orderNumber = data["orderNumber"] as? String,
            let sellerId = data["sellerId"] as? String,
            let sellerEmail = data["sellerEmail"] as? String,
            let warehouseId = data["warehouseId"] as? String,
            let warehouseName = data["warehouseName"] as? String,
            let notes = data["notes"] as? String,
            let statusRaw = data["status"] as? String,
            let status = OrderStatus(rawValue: statusRaw),
            let priorityRaw = data["priority"] as? String,
            let priority = OrderPriority(rawValue: priorityRaw),
            let createdAtTimestamp = data["createdAt"] as? Timestamp,
            let updatedAtTimestamp = data["updatedAt"] as? Timestamp,
            let qrCodeData = data["qrCodeData"] as? String
        else { return nil }
        
        // Парсим товары
        let itemsData = data["items"] as? [[String: Any]] ?? []
        let items = itemsData.compactMap { itemData -> OrderItem? in
            guard
                let id = itemData["id"] as? String,
                let productSKU = itemData["productSKU"] as? String,
                let productName = itemData["productName"] as? String,
                let quantity = itemData["quantity"] as? Int,
                let price = itemData["price"] as? Double,
                let imageURL = itemData["imageURL"] as? String,
                let category = itemData["category"] as? String
            else { return nil }
            
            return OrderItem(
                id: id,
                productSKU: productSKU,
                productName: productName,
                quantity: quantity,
                price: price,
                imageURL: imageURL,
                category: category
            )
        }
        
        // Парсим дату доставки (опционально)
        let estimatedDelivery = (data["estimatedDelivery"] as? Timestamp)?.dateValue()
        
        return Order(
            id: id,
            orderNumber: orderNumber,
            sellerId: sellerId,
            sellerEmail: sellerEmail,
            warehouseId: warehouseId,
            warehouseName: warehouseName,
            items: items,
            notes: notes,
            status: status,
            priority: priority,
            createdAt: createdAtTimestamp.dateValue(),
            updatedAt: updatedAtTimestamp.dateValue(),
            estimatedDelivery: estimatedDelivery,
            qrCodeData: qrCodeData
        )
    }
    
    // Конвертация в Dictionary для сохранения в Firestore
    func toDictionary() -> [String: Any] {
        let itemsData = items.map { item in
            [
                "id": item.id,
                "productSKU": item.productSKU,
                "productName": item.productName,
                "quantity": item.quantity,
                "price": item.price,
                "imageURL": item.imageURL,
                "category": item.category
            ]
        }
        
        var dict: [String: Any] = [
            "orderNumber": orderNumber,
            "sellerId": sellerId,
            "sellerEmail": sellerEmail,
            "warehouseId": warehouseId,
            "warehouseName": warehouseName,
            "items": itemsData,
            "notes": notes,
            "status": status.rawValue,
            "priority": priority.rawValue,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "qrCodeData": qrCodeData
        ]
        
        if let estimatedDelivery = estimatedDelivery {
            dict["estimatedDelivery"] = Timestamp(date: estimatedDelivery)
        }
        
        return dict
    }
}

// 🧪 Тестовые данные для разработки
extension Order {
    
    static let sampleOrders: [Order] = [
        Order(
            id: "order_1",
            orderNumber: "ORD-2025-001",
            sellerId: "seller_123",
            sellerEmail: "seller@example.com",
            warehouseId: "warehouse_almaty",
            warehouseName: "Склад Алматы",
            items: [
                OrderItem(
                    id: "item_1",
                    productSKU: "iphone_15_pro_max",
                    productName: "iPhone 15 Pro Max",
                    quantity: 2,
                    price: 599000,
                    imageURL: "https://example.com/iphone.jpg",
                    category: "Смартфоны"
                ),
                OrderItem(
                    id: "item_2",
                    productSKU: "samsung_s24",
                    productName: "Samsung Galaxy S24",
                    quantity: 1,
                    price: 459000,
                    imageURL: "https://example.com/samsung.jpg",
                    category: "Смартфоны"
                )
            ],
            notes: "Срочная отправка, хрупкий товар",
            status: .pending,
            priority: .high,
            createdAt: Date(),
            updatedAt: Date(),
            estimatedDelivery: Calendar.current.date(byAdding: .day, value: 2, to: Date()),
            qrCodeData: "ORDER:ORD-2025-001:seller_123:warehouse_almaty"
        ),
        Order(
            id: "order_2",
            orderNumber: "ORD-2025-002",
            sellerId: "seller_123",
            sellerEmail: "seller@example.com",
            warehouseId: "warehouse_astana",
            warehouseName: "Склад Астана",
            items: [
                OrderItem(
                    id: "item_3",
                    productSKU: "macbook_air_m2",
                    productName: "MacBook Air M2",
                    quantity: 1,
                    price: 899000,
                    imageURL: "https://example.com/macbook.jpg",
                    category: "Ноутбуки"
                )
            ],
            notes: "",
            status: .shipped,
            priority: .normal,
            createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            updatedAt: Date(),
            estimatedDelivery: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
            qrCodeData: "ORDER:ORD-2025-002:seller_123:warehouse_astana"
        )
    ]
}

// 🔧 Генератор номеров заказов
extension Order {
    
    static func generateOrderNumber() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        let year = formatter.string(from: Date())
        
        let randomNumber = Int.random(in: 1...9999)
        return "ORD-\(year)-\(String(format: "%04d", randomNumber))"
    }
    
    static func generateQRData(orderNumber: String, sellerId: String, warehouseId: String) -> String {
        return "ORDER:\(orderNumber):\(sellerId):\(warehouseId)"
    }
}
