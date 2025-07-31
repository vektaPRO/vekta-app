//
//  FinalCompilationFixes.swift
//  vektaApp
//
//  Финальные исправления для устранения всех ошибок компиляции
//

import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - StatusBadge Initialization Fix

extension StatusBadge {
    init(status: DeliveryStatus) {
        self.text = status.rawValue
        self.icon = status.iconName
        self.color = Self.colorForDeliveryStatus(status)
    }
    
    init(status: OrderStatus) {
        self.text = status.rawValue
        self.icon = status.iconName
        self.color = Color(status.color)
    }
    
    private static func colorForDeliveryStatus(_ status: DeliveryStatus) -> Color {
        switch status {
        case .pending: return .gray
        case .inTransit: return .blue
        case .arrived: return .orange
        case .awaitingCode: return .yellow
        case .confirmed: return .green
        case .failed: return .red
        case .cancelled: return .red
        }
    }
}

// MARK: - Missing DateFormatter Extensions

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

// MARK: - Color Extension for String

extension Color {
    init(_ colorString: String) {
        switch colorString.lowercased() {
        case "red":
            self = .red
        case "blue":
            self = .blue
        case "green":
            self = .green
        case "orange":
            self = .orange
        case "yellow":
            self = .yellow
        case "purple":
            self = .purple
        case "gray", "grey":
            self = .gray
        default:
            self = .primary
        }
    }
}

// MARK: - Missing CourierInfo

struct CourierInfo {
    let id: String
    let name: String
    let phone: String
    let isAvailable: Bool
    let location: String
}

// MARK: - KaspiIntegrationManager refreshData

extension KaspiIntegrationManager {
    func refreshData() async {
        await syncData()
    }
}

// MARK: - Missing Methods for KaspiAPIService

extension KaspiAPIService {
    
    /// Получить все товары (для совместимости)
    func fetchAllProducts() async throws -> [KaspiProduct] {
        var allProducts: [KaspiProduct] = []
        var currentPage = 0
        let pageSize = 100
        
        repeat {
            let response = try await getProducts(page: currentPage, size: pageSize)
            let products = response.data ?? []
            allProducts.append(contentsOf: products)
            
            if let totalPages = response.meta?.pagination?.totalPages,
               currentPage + 1 >= totalPages {
                break
            }
            
            currentPage += 1
        } while true
        
        return allProducts
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
        
        return delivery
    }
}

// MARK: - Missing KaspiOrdersSync methods

extension KaspiOrdersSync {
    func syncKaspiOrders() async {
        await syncOrders()
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

// MARK: - SharePreview iOS 16 Fix

@available(iOS 16.0, *)
extension SharePreview {
    init(_ title: String) {
        self.init(title)
    }
}

// MARK: - ShareLink Wrapper for iOS compatibility

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

// MARK: - KaspiPriceOptimizer Mock Implementation

extension KaspiPriceOptimizer {
    convenience init() {
        self.init(apiService: KaspiAPIService())
    }
}

// MARK: - Refreshable action fix

extension View {
    func refreshableCompat(action: @escaping () async -> Void) -> some View {
        if #available(iOS 15.0, *) {
            return self.refreshable {
                await action()
            }
        } else {
            return self
        }
    }
}

// MARK: - Missing TestResultCard

struct TestResultCard: View {
    let result: KaspiTestService.TestResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                
                Text(result.name)
                    .font(.headline)
                
                Spacer()
                
                if let duration = result.duration {
                    Text(String(format: "%.2fs", duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(result.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let message = result.message {
                Text(message)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.1))
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
    
    private var statusIcon: String {
        switch result.status {
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        default: return "circle"
        }
    }
    
    private var statusColor: Color {
        switch result.status {
        case .passed: return .green
        case .failed: return .red
        default: return .gray
        }
    }
}

// MARK: - Fix for KaspiOrder Identifiable conformance

extension KaspiOrder: Identifiable {
    var id: String {
        return self.attributes.code
    }
}

// MARK: - Fix for missing Product sample data

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

// MARK: - OrderStatus/OrderPriority color string fixes

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

// MARK: - Final Protocol Conformances

extension AnyCodable: Sendable {}
extension KaspiError: Sendable {}
extension KaspiWarning: Sendable {}

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

// MARK: - DeliveryConfirmation Identifiable conformance

extension DeliveryConfirmation: Identifiable {
    // id property уже есть в структуре, поэтому дополнительная реализация не нужна
}

// MARK: - Missing KaspiInstructionsView

struct KaspiInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    Text("Получение API токена Kaspi")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        
                        InstructionStep(
                            number: "1",
                            text: "Перейдите на сайт kaspi.kz и войдите в кабинет продавца"
                        )
                        
                        InstructionStep(
                            number: "2",
                            text: "В меню найдите раздел \"Интеграция\" или \"API\""
                        )
                        
                        InstructionStep(
                            number: "3",
                            text: "Создайте или скопируйте ваш API токен"
                        )
                        
                        InstructionStep(
                            number: "4",
                            text: "Вставьте токен в приложение и сохраните"
                        )
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Инструкция")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
    }
}
