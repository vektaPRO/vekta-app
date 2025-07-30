//
//  CompilationFixes.swift
//  vektaApp
//
//  Исправления и дополнения для успешной компиляции
//

import Foundation
import SwiftUI

// MARK: - Missing Extensions

extension Product {
    static var sampleProducts: [Product] {
        return [
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
            )
        ]
    }
}

// MARK: - Missing ShareLink for iOS compatibility

@available(iOS 16.0, *)
struct ShareLinkWrapper<T: Transferable>: View {
    let item: T
    let preview: SharePreview
    let label: () -> AnyView
    
    var body: some View {
        ShareLink(item: item, preview: preview) {
            label()
        }
    }
}

// Fallback for older iOS versions
struct ShareLinkFallback<T>: View {
    let item: T
    let preview: String
    let label: () -> AnyView
    
    var body: some View {
        Button(action: {
            // Fallback sharing implementation
            print("Sharing: \(preview)")
        }) {
            label()
        }
    }
}

// MARK: - Data Extension for Transferable

extension Data: @unchecked Sendable {}

@available(iOS 16.0, *)
extension Data: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .json) { data in
            data
        } importing: { data in
            data
        }
    }
}

// MARK: - GeoPoint for FirebaseFirestore compatibility

import FirebaseFirestore

extension GeoPoint {
    convenience init(_ latitude: Double, _ longitude: Double) {
        self.init(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Missing KaspiProduct properties

extension KaspiProduct {
    var isActive: Bool {
        return attributes.isActive
    }
    
    var stockCount: Int {
        return attributes.availableAmount
    }
    
    var shortDescription: String? {
        return attributes.description
    }
    
    var images: [String] {
        return attributes.images
    }
}

// MARK: - KaspiPriceOptimizer Mock Implementation

extension KaspiPriceOptimizer {
    convenience init() {
        self.init(apiService: KaspiAPIService())
    }
}

// MARK: - Missing CourierInfo struct

struct CourierInfo {
    let id: String
    let name: String
    let phone: String
    let isAvailable: Bool
    let location: String
}

// MARK: - Mock Methods for KaspiIntegrationManager

extension KaspiIntegrationManager {
    func refreshData() async {
        await syncData()
    }
}

// MARK: - Missing DeliveryDetailView

struct DeliveryDetailView: View {
    let delivery: DeliveryConfirmation
    let kaspiManager: KaspiIntegrationManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Delivery Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Информация о доставке")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            InfoRow(icon: "number", title: "Трек-номер", value: delivery.trackingNumber)
                            InfoRow(icon: "person", title: "Курьер", value: delivery.courierName)
                            InfoRow(icon: "phone", title: "Телефон клиента", value: delivery.formattedPhone)
                            InfoRow(icon: "location", title: "Адрес", value: delivery.deliveryAddress)
                            
                            HStack {
                                Text("Статус:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                StatusBadge(status: delivery.status)
                            }
                        }
                        .padding(16)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Actions
                    if delivery.status == .awaitingCode {
                        VStack(spacing: 12) {
                            Button("Запросить новый код") {
                                Task {
                                    _ = await kaspiManager.requestDeliveryCode(delivery)
                                }
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Подтвердить доставку") {
                                // TODO: Показать ввод кода
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Доставка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - SharePreview for iOS compatibility

@available(iOS 16.0, *)
extension SharePreview {
    init(_ title: String) {
        self.init(title)
    }
}

// MARK: - ProductStatus color extension

extension ProductStatus {
    var color: Color {
        switch self {
        case .inStock: return .green
        case .outOfStock: return .orange
        case .inactive: return .gray
        case .available: return .blue
        }
    }
}

// MARK: - OrderStatus color string

extension OrderStatus {
    var color: String {
        switch self {
        case .draft: return "gray"
        case .pending: return "orange"
        case .shipped: return "blue"
        case .received: return "green"
        case .completed: return "green"
        case .cancelled: return "red"
        }
    }
}

extension OrderPriority {
    var color: String {
        switch self {
        case .low: return "green"
        case .normal: return "blue"
        case .high: return "orange"
        case .urgent: return "red"
        }
    }
}

// MARK: - Missing DateFormatter extensions

extension DateFormatter {
    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
    
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

// MARK: - Missing KaspiOrder Identifiable conformance

extension KaspiOrder: Identifiable {
    var id: String {
        return self.attributes.code
    }
}

// MARK: - Missing DeliveryConfirmation Identifiable conformance

extension DeliveryConfirmation: Identifiable {
    // id property уже есть в структуре
}

// MARK: - Missing StatusBadge initializer

extension StatusBadge {
    init(text: String, icon: String, color: Color) {
        self.text = text
        self.icon = icon
        self.color = color
    }
}

// MARK: - iOS Version Compatibility

struct ViewModifier_iOS16: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
        } else {
            content
        }
    }
}

// MARK: - Missing KaspiOrdersSync methods

extension KaspiOrdersSync {
    func syncKaspiOrders() async {
        await syncOrders()
    }
}

// MARK: - Error Handling Extensions

extension KaspiAPIError {
    static func from(_ error: Error) -> KaspiAPIError {
        if let kaspiError = error as? KaspiAPIError {
            return kaspiError
        }
        if let networkError = error as? NetworkError {
            return .underlying(networkError)
        }
        return .syncFailed(error.localizedDescription)
    }
}

// MARK: - Missing Async/Await compatibility

extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Double) async throws {
        let nanoseconds = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}

// MARK: - Mock Data Extensions

extension KaspiOrder {
    static let mockOrder = KaspiOrder(
        id: "mock_order_1",
        type: "orders",
        attributes: KaspiOrderAttributes(
            code: "KSP-TEST-001",
            totalPrice: 599000,
            status: .acceptedByMerchant,
            state: .new,
            creationDate: Date(),
            plannedDeliveryDate: nil,
            deliveryCostForSeller: nil,
            isKaspiDelivery: true,
            customer: KaspiCustomer(
                id: "customer_1",
                name: "Тестовый Клиент",
                cellPhone: "+77771234567",
                email: "test@example.com",
                firstName: "Тестовый",
                lastName: "Клиент"
            ),
            deliveryAddress: KaspiDeliveryAddress(
                city: "Алматы",
                district: "Алмалинский",
                street: "ул. Абая",
                house: "150",
                apartment: "25",
                floor: "5",
                entrance: "2",
                doorCode: "123",
                formattedAddress: "г. Алматы, ул. Абая 150, кв. 25",
                latitude: 43.2220,
                longitude: 76.8512
            ),
            paymentMode: "CARD",
            credit: nil
        ),
        relationships: nil
    )
}

// MARK: - Final Compilation Fixes

// Fix for missing protocol conformances
extension AnyCodable: Sendable {}
extension KaspiError: Sendable {}
extension KaspiWarning: Sendable {}

// Fix for SwiftUI modifiers
extension View {
    func refreshable(action: @escaping () async -> Void) -> some View {
        if #available(iOS 15.0, *) {
            return self.refreshable {
                await action()
            }
        } else {
            return self
        }
    }
}

// MARK: - Platform Compatibility

#if canImport(UIKit)
import UIKit

extension UIDevice {
    static var isIOS15OrLater: Bool {
        if #available(iOS 15.0, *) {
            return true
        } else {
            return false
        }
    }
}
#endif
