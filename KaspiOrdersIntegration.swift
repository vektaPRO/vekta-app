//
//  KaspiOrdersIntegration.swift
//  vektaApp
//
//  Интеграция заказов из Kaspi с системой доставки Vekta
//

import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Kaspi Orders Manager

@MainActor
class KaspiOrdersManager: ObservableObject {
    
    @Published var kaspiOrders: [private let kaspiService = KaspiAPIService()KaspiOrder] = []
    @Published var deliveries: [DeliveryConfirmation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private let kaspiService = KaspiAPIService()
    private let db = Firestore.firestore()
    private var ordersListener: ListenerRegistration?
    
    init() {
        setupOrdersListener()
    }
    
    deinit {
        ordersListener?.remove()
    }
    
    // MARK: - Setup
    
    private func setupOrdersListener() {
        // Слушаем новые заказы из Kaspi
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task {
                await self.syncKaspiOrders()
            }
        }
    }
    
    // MARK: - Kaspi Orders Sync
    
    /// Синхронизировать заказы из Kaspi
    func syncKaspiOrders() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let orders = try await kaspiService.loadOrders()
            
            // Фильтруем только новые заказы
            let newOrders = orders.filter { kaspiOrder in
                !kaspiOrders.contains { $0.orderId == kaspiOrder.orderId }
            }
            
            if !newOrders.isEmpty {
                kaspiOrders.append(contentsOf: newOrders)
                
                // Сохраняем новые заказы в Firestore
                try await saveKaspiOrdersToFirestore(newOrders)
                
                successMessage = "✅ Получено \(newOrders.count) новых заказов из Kaspi"
                
                // Автоматически создаем доставки для новых заказов
                for order in newOrders {
                    await createDeliveryFromKaspiOrder(order)
                }
            }
            
        } catch {
            errorMessage = "Ошибка синхронизации заказов: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Сохранить заказы Kaspi в Firestore
    private func saveKaspiOrdersToFirestore(_ orders: [KaspiOrder]) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
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
            batch.setData(orderData, forDocument: docRef)
        }
        
        try await batch.commit()
    }
    
    // MARK: - Delivery Management
    
    /// Создать доставку из заказа Kaspi
    func createDeliveryFromKaspiOrder(_ kaspiOrder: KaspiOrder) async {
        do {
            // Определяем метод доставки (фулфилмент или продавец)
            let deliveryMethod = determineDeliveryMethod(for: kaspiOrder)
            
            switch deliveryMethod {
            case .fulfillment:
                await createFulfillmentDelivery(kaspiOrder)
            case .seller:
                await createSellerDelivery(kaspiOrder)
            case .courier:
                await assignToCourier(kaspiOrder)
            }
            
        } catch {
            errorMessage = "Ошибка создания доставки: \(error.localizedDescription)"
        }
    }
    
    /// Определить метод доставки
    private func determineDeliveryMethod(for order: KaspiOrder) -> DeliveryMethod {
        // Логика определения метода доставки
        // Пока по умолчанию - через курьера
        return .courier
    }
    
    /// Создать доставку через фулфилмент
    private func createFulfillmentDelivery(_ kaspiOrder: KaspiOrder) async {
        // TODO: Интеграция с системой фулфилмента
        print("📦 Создание доставки через фулфилмент для заказа \(kaspiOrder.orderNumber)")
    }
    
    /// Создать доставку продавцом
    private func createSellerDelivery(_ kaspiOrder: KaspiOrder) async {
        // TODO: Уведомление продавца о необходимости самостоятельной доставки
        print("🚚 Продавец должен доставить заказ \(kaspiOrder.orderNumber)")
    }
    
    /// Назначить курьера
    private func assignToCourier(_ kaspiOrder: KaspiOrder) async {
        do {
            // Находим доступного курьера
            guard let courier = await findAvailableCourier(for: kaspiOrder.deliveryAddress) else {
                throw DeliveryError.noCourierAvailable
            }
            
            // Создаем доставку
            let delivery = try await kaspiService.createDeliveryFromKaspiOrder(
                kaspiOrder,
                courierId: courier.id,
                courierName: courier.name
            )
            
            deliveries.append(delivery)
            
            // Уведомляем курьера
            await notifyCourier(courier, about: delivery)
            
            successMessage = "✅ Заказ \(kaspiOrder.orderNumber) назначен курьеру \(courier.name)"
            
        } catch {
            errorMessage = "Ошибка назначения курьера: \(error.localizedDescription)"
        }
    }
    
    /// Найти доступного курьера
    private func findAvailableCourier(for address: String) async -> CourierInfo? {
        // TODO: Интеграция с системой курьеров
        // Пока возвращаем тестового курьера
        return CourierInfo(
            id: "courier_1",
            name: "Иван Курьеров",
            phone: "+77771234567",
            isAvailable: true,
            location: "Алматы"
        )
    }
    
    /// Уведомить курьера
    private func notifyCourier(_ courier: CourierInfo, about delivery: DeliveryConfirmation) async {
        let notification: [String: Any] = [
            "userId": courier.id,
            "type": "new_delivery",
            "title": "Новая доставка",
            "message": "Вам назначен заказ \(delivery.trackingNumber)",
            "deliveryId": delivery.id,
            "createdAt": FieldValue.serverTimestamp(),
            "read": false
        ]
        
        do {
            try await db.collection("notifications").addDocument(data: notification)
        } catch {
            print("❌ Ошибка отправки уведомления курьеру: \(error)")
        }
    }
    
    // MARK: - Status Updates
    
    /// Обновить статус заказа в Kaspi после доставки
    func updateKaspiOrderStatus(_ orderId: String, status: String) async {
        // TODO: Интеграция с Kaspi API для обновления статуса заказа
        print("📝 Обновление статуса заказа \(orderId) в Kaspi: \(status)")
    }
    
    /// Загрузить доставки
    func loadDeliveries() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let snapshot = try await db.collection("deliveries")
                .whereField("courierId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            deliveries = snapshot.documents.compactMap { doc in
                DeliveryConfirmation.fromFirestore(doc.data(), id: doc.documentID)
            }
            
        } catch {
            errorMessage = "Ошибка загрузки доставок: \(error.localizedDescription)"
        }
    }
}

// MARK: - Supporting Types

enum DeliveryMethod {
    case fulfillment    // Доставка через фулфилмент
    case seller        // Доставка продавцом
    case courier       // Доставка курьером
}

struct CourierInfo {
    let id: String
    let name: String
    let phone: String
    let isAvailable: Bool
    let location: String
}

enum DeliveryError: LocalizedError {
    case noCourierAvailable
    case invalidAddress
    case orderAlreadyProcessed
    
    var errorDescription: String? {
        switch self {
        case .noCourierAvailable:
            return "Нет доступных курьеров"
        case .invalidAddress:
            return "Некорректный адрес доставки"
        case .orderAlreadyProcessed:
            return "Заказ уже обработан"
        }
    }
}

// MARK: - Kaspi Orders View

struct KaspiOrdersView: View {
    @StateObject private var ordersManager = KaspiOrdersManager()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // Статистика
                if !ordersManager.kaspiOrders.isEmpty {
                    ordersStatsView
                }
                
                // Список заказов
                ordersListView
            }
            .navigationTitle("Заказы Kaspi")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await ordersManager.syncKaspiOrders()
                        }
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .disabled(ordersManager.isLoading)
                }
            }
            .refreshable {
                await ordersManager.syncKaspiOrders()
            }
            .alert("Ошибка", isPresented: .constant(ordersManager.errorMessage != nil)) {
                Button("OK") {
                    ordersManager.errorMessage = nil
                }
            } message: {
                Text(ordersManager.errorMessage ?? "")
            }
            .alert("Успех", isPresented: .constant(ordersManager.successMessage != nil)) {
                Button("OK") {
                    ordersManager.successMessage = nil
                }
            } message: {
                Text(ordersManager.successMessage ?? "")
            }
        }
        .onAppear {
            Task {
                await ordersManager.syncKaspiOrders()
                await ordersManager.loadDeliveries()
            }
        }
    }
    
    // MARK: - View Components
    
    private var ordersStatsView: some View {
        HStack(spacing: 20) {
            StatCard(
                icon: "doc.text.fill",
                title: "Всего заказов",
                value: "\(ordersManager.kaspiOrders.count)",
                color: .blue
            )
            
            StatCard(
                icon: "truck.box.fill",
                title: "В доставке",
                value: "\(ordersManager.deliveries.filter { $0.status != .confirmed }.count)",
                color: .orange
            )
            
            StatCard(
                icon: "checkmark.circle.fill",
                title: "Доставлено",
                value: "\(ordersManager.deliveries.filter { $0.status == .confirmed }.count)",
                color: .green
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemGray6))
    }
    
    private var ordersListView: some View {
        Group {
            if ordersManager.isLoading {
                LoadingView("Загрузка заказов...")
            } else if ordersManager.kaspiOrders.isEmpty {
                EmptyStateView(
                    icon: "doc.text",
                    title: "Нет заказов",
                    message: "Заказы из Kaspi появятся здесь автоматически",
                    actionTitle: "Синхронизировать",
                    action: {
                        Task {
                            await ordersManager.syncKaspiOrders()
                        }
                    }
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(ordersManager.kaspiOrders, id: \.orderId) { order in
                            KaspiOrderCard(
                                order: order,
                                delivery: ordersManager.deliveries.first { $0.orderId == order.orderId }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
    }
}

// MARK: - Kaspi Order Card

struct KaspiOrderCard: View {
    let order: KaspiOrder
    let delivery: DeliveryConfirmation?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // Заголовок
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Заказ #\(order.orderNumber)")
                        .font(.headline)
                    
                    Text(order.customerInfo.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Статус доставки
                if let delivery = delivery {
                    StatusBadge(status: delivery.status)
                } else {
                    StatusBadge(text: "Новый", icon: "star.fill", color: .blue)
                }
            }
            
            // Информация о заказе
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(
                    icon: "phone",
                    title: "Телефон:",
                    value: order.customerInfo.phone
                )
                
                InfoRow(
                    icon: "location",
                    title: "Адрес:",
                    value: order.deliveryAddress
                )
                
                InfoRow(
                    icon: "tenge.circle",
                    title: "Сумма:",
                    value: String(format: "%.0f ₸", order.totalAmount)
                )
                
                InfoRow(
                    icon: "calendar",
                    title: "Дата:",
                    value: DateFormatter.shortDateTime.string(from: order.createdAt)
                )
            }
            
            // Товары
            if !order.items.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Товары:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(Array(order.items.enumerated()), id: \.offset) { index, item in
                        HStack {
                            Text("• \(item.productName)")
                                .font(.caption)
                            
                            Spacer()
                            
                            Text("\(item.quantity) шт")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    KaspiOrdersView()
}
