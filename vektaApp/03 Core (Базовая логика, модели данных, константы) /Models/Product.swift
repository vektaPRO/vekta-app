//
//  Product.swift
//  vektaApp
//
//  Created by Almas Kadeshov on 02.07.2025.
//

import Foundation
import FirebaseFirestore

// 📦 Модель товара
struct Product: Identifiable, Codable, Hashable {
    let id: String
    let kaspiProductId: String      // ID товара в Kaspi
    let name: String                // Название товара
    let description: String         // Описание
    let price: Double              // Цена
    let category: String           // Категория
    let imageURL: String           // URL изображения
    let status: ProductStatus      // Статус товара
    
    // Остатки по складам
    let warehouseStock: [String: Int] // warehouseId: quantity
    
    // Метаданные
    let createdAt: Date
    let updatedAt: Date
    let isActive: Bool
    
    // Вычисляемые свойства
    var totalStock: Int {
        warehouseStock.values.reduce(0, +)
    }
    
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "KZT"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "\(Int(price)) ₸"
    }
    
    // Реализация Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Product, rhs: Product) -> Bool {
        lhs.id == rhs.id
    }
}

// 🏷️ Статус товара
enum ProductStatus: String, CaseIterable, Codable {
    case inStock = "В наличии"
    case outOfStock = "Нет в наличии"
    case inactive = "Неактивен"
    
    var iconName: String {
        switch self {
        case .inStock:
            return "checkmark.circle.fill"
        case .outOfStock:
            return "exclamationmark.triangle.fill"
        case .inactive:
            return "xmark.circle.fill"
        }
    }
}

// 🧪 Тестовые данные
extension Product {
    static let sampleProducts: [Product] = [
        Product(
            id: "product_1",
            kaspiProductId: "kaspi_123456",
            name: "iPhone 15 Pro Max 256GB",
            description: "Новейший iPhone с камерой Pro",
            price: 599000,
            category: "Смартфоны",
            imageURL: "https://example.com/iphone15.jpg",
            status: .inStock,
            warehouseStock: [
                "warehouse_almaty": 5,
                "warehouse_astana": 3
            ],
            createdAt: Date(),
            updatedAt: Date(),
            isActive: true
        ),
        Product(
            id: "product_2",
            kaspiProductId: "kaspi_789012",
            name: "Samsung Galaxy S24 Ultra",
            description: "Флагманский Android смартфон",
            price: 459000,
            category: "Смартфоны",
            imageURL: "https://example.com/samsung_s24.jpg",
            status: .inStock,
            warehouseStock: [
                "warehouse_almaty": 2,
                "warehouse_shymkent": 4
            ],
            createdAt: Date(),
            updatedAt: Date(),
            isActive: true
        ),
        Product(
            id: "product_3",
            kaspiProductId: "kaspi_345678",
            name: "MacBook Air M2 13\"",
            description: "Ультратонкий ноутбук Apple",
            price: 899000,
            category: "Ноутбуки",
            imageURL: "https://example.com/macbook_air.jpg",
            status: .inStock,
            warehouseStock: [
                "warehouse_astana": 1,
                "warehouse_almaty": 2
            ],
            createdAt: Date(),
            updatedAt: Date(),
            isActive: true
        ),
        Product(
            id: "product_4",
            kaspiProductId: "kaspi_901234",
            name: "AirPods Pro 2",
            description: "Беспроводные наушники с шумоподавлением",
            price: 129000,
            category: "Наушники",
            imageURL: "https://example.com/airpods_pro.jpg",
            status: .outOfStock,
            warehouseStock: [:],
            createdAt: Date(),
            updatedAt: Date(),
            isActive: true
        )
    ]
}
