//
//  Product.swift
//  vektaApp
//
//  Created by Almas Kadeshov on 30.06.2025.
//

import Foundation
import FirebaseCore

// 📦 Модель товара для всего приложения
struct Product: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let price: Double
    let imageURL: String
    let kaspiProductId: String
    let category: String
    let isActive: Bool
    let createdAt: Date
    
    // Информация о складах
    let warehouseStock: [WarehouseStock]
    
    // Статус товара
    var status: ProductStatus {
        if !isActive {
            return .inactive
        } else if totalStock > 0 {
            return .inStock
        } else {
            return .outOfStock
        }
    }
    
    // Общий остаток на всех складах
    var totalStock: Int {
        warehouseStock.reduce(0) { $0 + $1.quantity }
    }
    
    // Форматированная цена
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "KZT"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "\(Int(price)) ₸"
    }
}

// 📦 Остатки на складе
struct WarehouseStock: Codable {
    let warehouseId: String
    let warehouseName: String
    let quantity: Int
    let reservedQuantity: Int
    
    var availableQuantity: Int {
        quantity - reservedQuantity
    }
}

// 🏷️ Статус товара
enum ProductStatus: String, CaseIterable {
    case inStock = "В наличии"
    case outOfStock = "Нет в наличии"
    case inactive = "Неактивен"
    
    var color: String {
        switch self {
        case .inStock:
            return "green"
        case .outOfStock:
            return "orange"
        case .inactive:
            return "gray"
        }
    }
    
    var iconName: String {
        switch self {
        case .inStock:
            return "checkmark.circle.fill"
        case .outOfStock:
            return "exclamationmark.triangle.fill"
        case .inactive:
            return "pause.circle.fill"
        }
    }
}

// 🏭 Расширение для работы с Firestore
extension Product {
    
    // Создание Product из Firestore документа
    static func fromFirestore(_ data: [String: Any], id: String) -> Product? {
        guard
            let name = data["name"] as? String,
            let description = data["description"] as? String,
            let price = data["price"] as? Double,
            let imageURL = data["imageURL"] as? String,
            let kaspiProductId = data["kaspiProductId"] as? String,
            let category = data["category"] as? String,
            let isActive = data["isActive"] as? Bool,
            let timestamp = data["createdAt"] as? Timestamp
        else { return nil }
        
        // Парсим остатки на складах
        let warehouseStockData = data["warehouseStock"] as? [[String: Any]] ?? []
        let warehouseStock = warehouseStockData.compactMap { stockData -> WarehouseStock? in
            guard
                let warehouseId = stockData["warehouseId"] as? String,
                let warehouseName = stockData["warehouseName"] as? String,
                let quantity = stockData["quantity"] as? Int,
                let reservedQuantity = stockData["reservedQuantity"] as? Int
            else { return nil }
            
            return WarehouseStock(
                warehouseId: warehouseId,
                warehouseName: warehouseName,
                quantity: quantity,
                reservedQuantity: reservedQuantity
            )
        }
        
        return Product(
            id: id,
            name: name,
            description: description,
            price: price,
            imageURL: imageURL,
            kaspiProductId: kaspiProductId,
            category: category,
            isActive: isActive,
            createdAt: timestamp.dateValue(),
            warehouseStock: warehouseStock
        )
    }
    
    // Конвертация в Dictionary для сохранения в Firestore
    func toDictionary() -> [String: Any] {
        let warehouseStockData = warehouseStock.map { stock in
            [
                "warehouseId": stock.warehouseId,
                "warehouseName": stock.warehouseName,
                "quantity": stock.quantity,
                "reservedQuantity": stock.reservedQuantity
            ]
        }
        
        return [
            "name": name,
            "description": description,
            "price": price,
            "imageURL": imageURL,
            "kaspiProductId": kaspiProductId,
            "category": category,
            "isActive": isActive,
            "createdAt": Timestamp(date: createdAt),
            "warehouseStock": warehouseStockData
        ]
    }
}

// 🧪 Тестовые данные для разработки
extension Product {
    
    static let sampleProducts: [Product] = [
        Product(
            id: "1",
            name: "iPhone 15 Pro Max",
            description: "Флагманский смартфон Apple с чипом A17 Pro",
            price: 599000,
            imageURL: "https://example.com/iphone.jpg",
            kaspiProductId: "kaspi_iphone_123",
            category: "Смартфоны",
            isActive: true,
            createdAt: Date(),
            warehouseStock: [
                WarehouseStock(warehouseId: "wh1", warehouseName: "Склад Алматы", quantity: 15, reservedQuantity: 3),
                WarehouseStock(warehouseId: "wh2", warehouseName: "Склад Астана", quantity: 8, reservedQuantity: 1)
            ]
        ),
        Product(
            id: "2",
            name: "Samsung Galaxy S24",
            description: "Премиальный Android смартфон",
            price: 459000,
            imageURL: "https://example.com/samsung.jpg",
            kaspiProductId: "kaspi_samsung_456",
            category: "Смартфоны",
            isActive: true,
            createdAt: Date(),
            warehouseStock: [
                WarehouseStock(warehouseId: "wh1", warehouseName: "Склад Алматы", quantity: 0, reservedQuantity: 0),
                WarehouseStock(warehouseId: "wh2", warehouseName: "Склад Астана", quantity: 5, reservedQuantity: 2)
            ]
        ),
        Product(
            id: "3",
            name: "MacBook Air M2",
            description: "Ультрабук Apple с чипом M2",
            price: 899000,
            imageURL: "https://example.com/macbook.jpg",
            kaspiProductId: "kaspi_macbook_789",
            category: "Ноутбуки",
            isActive: false,
            createdAt: Date(),
            warehouseStock: []
        )
    ]
}
