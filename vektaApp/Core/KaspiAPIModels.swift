//
//  KaspiAPIModels.swift
//  vektaApp
//
//  Полные модели данных для Kaspi API согласно документации
//

import Foundation
import FirebaseFirestore

// MARK: - Kaspi API Response Models

/// Базовая структура ответа Kaspi API
struct KaspiAPIResponse<T: Codable>: Codable {
    let data: [T]?
    let included: [KaspiIncludedItem]?
    let meta: KaspiMeta?
    let errors: [KaspiError]?
    let warnings: [KaspiWarning]?
}
struct KaspiImportSchema: Codable {
    let type: String?
    let properties: [String: SchemaProperty]
    let required: [String]
    
    struct SchemaProperty: Codable {
        let type: String
        let description: String?
        let format: String?
        let items: SchemaItems?
        let enumValues: [String]?  // Возможные значения поля
        let minLength: Int?
        let maxLength: Int?
        let minimum: Double?
        let maximum: Double?
        
        enum CodingKeys: String, CodingKey {
            case type, description, format, items
            case enumValues = "enum"
            case minLength, maxLength, minimum, maximum
        }
    }
    
    struct SchemaItems: Codable {
        let type: String
        let format: String?
    }
}
    
    struct SchemaItems: Codable {
        let type: String
        let format: String?
    }



struct KaspiIncludedItem: Codable {
    let type: String
    let id: String
    let attributes: [String: AnyCodable]
}

struct KaspiMeta: Codable {
    let pagination: KaspiPagination?
    let totalItems: Int?
    let version: String?
}

struct KaspiPagination: Codable {
    let page: Int
    let size: Int
    let totalPages: Int
    let totalElements: Int
    
    enum CodingKeys: String, CodingKey {
        case page = "number"
        case size
        case totalPages
        case totalElements
    }
}

struct KaspiError: Codable {
    let code: String
    let message: String
    let details: [String: AnyCodable]?
}

struct KaspiWarning: Codable {
    let code: String
    let message: String
}

// MARK: - Products Models

/// Kaspi Product - товар в системе Kaspi
struct KaspiProduct: Codable, Identifiable {
    let id: String
    let type: String
    let attributes: KaspiProductAttributes
    let relationships: KaspiProductRelationships?
    
    enum CodingKeys: String, CodingKey {
        case id, type, attributes, relationships
    }
}

struct KaspiProductAttributes: Codable {
    let code: String
    let name: String
    let brand: String?
    let description: String?
    let category: String
    let images: [String]
    let price: Double
    let availableAmount: Int
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    
    // Характеристики товара
    let attributes: [KaspiProductCharacteristic]?
    
    // Статус модерации
    let moderationStatus: String?
    let moderationComment: String?
    
    enum CodingKeys: String, CodingKey {
        case code, name, brand, description, category, images
        case price, availableAmount, isActive
        case createdAt = "creationDate"
        case updatedAt = "lastUpdateDate"
        case attributes
        case moderationStatus = "moderation_status"
        case moderationComment = "moderation_comment"
    }
}

struct KaspiProductCharacteristic: Codable {
    let code: String
    let value: String
    let unit: String?
}

struct KaspiProductRelationships: Codable {
    let offers: KaspiRelationshipData?
    let warehouses: KaspiRelationshipData?
}

struct KaspiRelationshipData: Codable {
    let data: [KaspiRelationshipItem]
}

struct KaspiRelationshipItem: Codable {
    let type: String
    let id: String
}

// MARK: - Orders Models

/// Kaspi Order - заказ от клиента
struct KaspiOrder: Codable, Identifiable {
    let id: String
    let type: String
    let attributes: KaspiOrderAttributes
    let relationships: KaspiOrderRelationships?
}

struct KaspiOrderAttributes: Codable {
    let code: String
    let totalPrice: Double
    let status: KaspiOrderStatus
    let state: KaspiOrderState
    let creationDate: Date
    let plannedDeliveryDate: Date?
    let deliveryCostForSeller: Double?
    let isKaspiDelivery: Bool
    let customer: KaspiCustomer
    let deliveryAddress: KaspiDeliveryAddress
    let paymentMode: String
    let credit: KaspiCredit?
    
    enum CodingKeys: String, CodingKey {
        case code, totalPrice, status, state
        case creationDate, plannedDeliveryDate
        case deliveryCostForSeller, isKaspiDelivery
        case customer, deliveryAddress, paymentMode, credit
    }
}

enum KaspiOrderStatus: String, Codable, CaseIterable {
    case acceptedByMerchant = "ACCEPTED_BY_MERCHANT"
    case approvedByBank = "APPROVED_BY_BANK"
    case assemble = "ASSEMBLE"
    case kaspiDelivery = "KASPI_DELIVERY"
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"
    case returned = "RETURNED"
    
    var displayName: String {
        switch self {
        case .acceptedByMerchant: return "Принят продавцом"
        case .approvedByBank: return "Одобрен банком"
        case .assemble: return "Сборка"
        case .kaspiDelivery: return "Доставка Kaspi"
        case .completed: return "Завершен"
        case .cancelled: return "Отменен"
        case .returned: return "Возвращен"
        }
    }
}

enum KaspiOrderState: String, Codable {
    case new = "NEW"
    case processing = "PROCESSING"
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"
    case returned = "RETURNED"
}

struct KaspiCustomer: Codable {
    let id: String
    let name: String
    let cellPhone: String
    let email: String?
    let firstName: String?
    let lastName: String?
}

struct KaspiDeliveryAddress: Codable {
    let city: String
    let district: String?
    let street: String
    let house: String
    let apartment: String?
    let floor: String?
    let entrance: String?
    let doorCode: String?
    let formattedAddress: String
    let latitude: Double?
    let longitude: Double?
}

struct KaspiCredit: Codable {
    let period: Int
    let monthlyPayment: Double
}

struct KaspiOrderRelationships: Codable {
    let entries: KaspiRelationshipData?
    let deliveryPointOfService: KaspiRelationshipData?
}

// MARK: - Order Entries Models

/// Kaspi Order Entry - позиция в заказе
struct KaspiOrderEntry: Codable, Identifiable {
    let id: String
    let type: String
    let attributes: KaspiOrderEntryAttributes
    let relationships: KaspiOrderEntryRelationships?
}

struct KaspiOrderEntryAttributes: Codable {
    let quantity: Int
    let totalPrice: Double
    let basePrice: Double
    let unitPrice: Double
    let discountAmount: Double?
    let entryNumber: Int
    let weight: Double?
    let isImeiRequired: Bool
    let product: KaspiEntryProduct
}

struct KaspiEntryProduct: Codable {
    let code: String
    let name: String
    let brand: String?
    let category: String
    let image: String?
}

struct KaspiOrderEntryRelationships: Codable {
    let product: KaspiRelationshipData?
    let deliveryPointOfService: KaspiRelationshipData?
}

// MARK: - IMEI Models

struct KaspiIMEI: Codable {
    let entryId: String
    let items: [KaspiIMEIItem]
}

struct KaspiIMEIItem: Codable {
    let quantity: Int
    let imei: [String]
}

// MARK: - Delivery Point Models

struct KaspiDeliveryPoint: Codable, Identifiable {
    let id: String
    let type: String
    let attributes: KaspiDeliveryPointAttributes
}

struct KaspiDeliveryPointAttributes: Codable {
    let externalId: String
    let name: String
    let address: KaspiDeliveryAddress
    let contactPhone: String?
    let schedule: [KaspiScheduleItem]?
}

struct KaspiScheduleItem: Codable {
    let dayOfWeek: String
    let openTime: String
    let closeTime: String
    let isWorkingDay: Bool
}

// MARK: - Operations Models

/// Kaspi Operations - операции с заказами
struct KaspiOrderOperation: Codable {
    let type: String
    let id: String
    let attributes: KaspiOrderOperationAttributes
}

struct KaspiOrderOperationAttributes: Codable {
    let code: String
    let status: KaspiOrderStatus
    let numberOfSpace: Int?
    let reason: String?
    let comment: String?
}

// Order Entry Operations
struct KaspiOrderEntryOperation: Codable {
    let type: String
    let attributes: KaspiOrderEntryOperationAttributes
}

struct KaspiOrderEntryOperationAttributes: Codable {
    let entryId: String
    let operationType: KaspiEntryOperationType
    let reason: String?
    let remainedQuantity: Int?
    let newWeight: Double?
    let notes: String?
}

enum KaspiEntryOperationType: String, Codable {
    case cancel = "orderEntryCancelOperation"
    case changeWeight = "orderEntryChangeWeightOperation"
}

// MARK: - Import/Export Models

/// Kaspi Product Import - импорт товаров
struct KaspiProductImport: Codable {
    let data: [KaspiProductImportItem]
}

struct KaspiProductImportItem: Codable {
    let type: String
    let attributes: KaspiProductImportAttributes
}

struct KaspiProductImportAttributes: Codable {
    let sku: String
    let title: String
    let brand: String?
    let description: String?
    let category: String
    let images: [String]
    let price: Double
    let availableAmount: Int
    let attributes: [KaspiProductCharacteristic]
    let isActive: Bool
}

/// Import Status Response
struct KaspiImportStatus: Codable, Identifiable {
    let id: String
    let type: String
    let attributes: KaspiImportStatusAttributes
}

struct KaspiImportStatusAttributes: Codable {
    let state: KaspiImportState
    let errors: Int
    let warnings: Int
    let skipped: Int
    let total: Int
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case state, errors, warnings, skipped, total
        case createdAt = "creationDate"
    }
}

enum KaspiImportState: String, Codable {
    case success = "SUCCESS"
    case partial = "PARTIAL"
    case failed = "FAILED"
    case processing = "PROCESSING"
}

// MARK: - Categories and Attributes Models

struct KaspiCategory: Codable, Identifiable {
    let id: String
    let code: String
    let title: String
    let parentCode: String?
}

struct KaspiAttribute: Codable, Identifiable {
    let id: String
    let code: String
    let title: String
    let type: KaspiAttributeType
    let isRequired: Bool
    let values: [KaspiAttributeValue]?
    let unit: String?
}

enum KaspiAttributeType: String, Codable {
    case string = "STRING"
    case number = "NUMBER"
    case boolean = "BOOLEAN"
    case list = "LIST"
    case multiList = "MULTI_LIST"
}

struct KaspiAttributeValue: Codable, Identifiable {
    let id: String
    let code: String
    let value: String
}

// MARK: - Helper Types

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Local Models Extensions

extension KaspiOrder {
    /// Конвертация в локальную модель заказа
    func toLocalOrder() -> Order {
        let orderItems = self.relationships?.entries?.data.compactMap { entry in
            // Здесь нужно получить детали entry из included секции
            // Для примера создаем заглушку
            OrderItem(
                id: entry.id,
                productSKU: "unknown",
                productName: "Товар из Kaspi",
                quantity: 1,
                price: self.attributes.totalPrice,
                imageURL: "",
                category: "Kaspi"
            )
        } ?? []
        
        return Order(
            id: self.id,
            orderNumber: self.attributes.code,
            sellerId: "current_seller",
            sellerEmail: "seller@example.com",
            warehouseId: "kaspi_warehouse",
            warehouseName: "Kaspi Склад",
            items: orderItems,
            notes: "Заказ из Kaspi",
            status: self.attributes.status.toLocalStatus(),
            priority: .normal,
            createdAt: self.attributes.creationDate,
            updatedAt: Date(),
            estimatedDelivery: self.attributes.plannedDeliveryDate,
            qrCodeData: "KASPI:\(self.attributes.code)"
        )
    }
}

extension KaspiOrderStatus {
    func toLocalStatus() -> OrderStatus {
        switch self {
        case .acceptedByMerchant:
            return .pending
        case .approvedByBank:
            return .pending
        case .assemble:
            return .shipped
        case .kaspiDelivery:
            return .shipped
        case .completed:
            return .completed
        case .cancelled:
            return .cancelled
        case .returned:
            return .cancelled
        }
    }
}

extension KaspiProduct {
    /// Конвертация в локальную модель товара
    func toLocalProduct() -> Product {
        return Product(
            id: self.id,
            kaspiProductId: self.attributes.code,
            name: self.attributes.name,
            description: self.attributes.description ?? "",
            price: self.attributes.price,
            category: self.attributes.category,
            imageURL: self.attributes.images.first ?? "",
            status: self.attributes.isActive ?
                (self.attributes.availableAmount > 0 ? .inStock : .outOfStock) : .inactive,
            warehouseStock: ["default": self.attributes.availableAmount],
            createdAt: self.attributes.createdAt,
            updatedAt: self.attributes.updatedAt,
            isActive: self.attributes.isActive
        )
    }
}
