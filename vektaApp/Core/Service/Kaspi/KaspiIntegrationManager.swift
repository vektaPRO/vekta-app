//
//  KaspiBusinessLogic.swift
//  vektaApp
//
//  Бизнес-логика для автоматизации процессов Kaspi
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Kaspi Integration Manager

@MainActor
final class KaspiIntegrationManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isAutoProcessingEnabled = false
    @Published var newOrders: [KaspiOrder] = []
    @Published var processedOrders: [KaspiOrder] = []
    @Published var deliveries: [DeliveryConfirmation] = []
    @Published var products: [Product] = []
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // Statistics
    @Published var todayOrdersCount = 0
    @Published var todayDeliveredCount = 0
    @Published var pendingDeliveriesCount = 0
    
    // MARK: - Private Properties
    private let kaspiAPI = KaspiAPIService()
    private let db = Firestore.firestore()
    private var autoProcessingTimer: Timer?
    private var syncTimer: Timer?
    
    // MARK: - Configuration
    private let autoProcessingInterval: TimeInterval = 300 // 5 минут
    private let syncInterval: TimeInterval = 600 // 10 минут
    
    init() {
        setupTimers()
        loadConfiguration()
    }
    
    deinit {
        autoProcessingTimer?.invalidate()
        syncTimer?.invalidate()
    }
    
    // MARK: - Setup & Configuration
    
    private func setupTimers() {
        // Таймер автоматической обработки заказов
        autoProcessingTimer = Timer.scheduledTimer(withTimeInterval: autoProcessingInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.isAutoProcessingEnabled {
                Task {
                    await self.processNewOrdersAutomatically()
                }
            }
        }
        
        // Таймер синхронизации
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task {
                await self.syncData()
            }
        }
    }
    
    private func loadConfiguration() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("sellers").document(userId).getDocument { [weak self] snapshot, error in
            DispatchQueue.main.async {
                if let data = snapshot?.data() {
                    self?.isAutoProcessingEnabled = data["autoProcessingEnabled"] as? Bool ?? false
                }
            }
        }
    }
    
    // MARK: - Main Business Logic
    
    /// Полная синхронизация данных
    func syncData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.syncOrders() }
            group.addTask { await self.syncProducts() }
            group.addTask { await self.updateStatistics() }
        }
    }
    
    /// Синхронизация заказов
    func syncOrders() async {
        do {
            // Получаем новые заказы за последние 24 часа
            let fromDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            
            let ordersResponse = try await kaspiAPI.getOrders(
                page: 0,
                size: 100,
                state: .new,
                creationDateFrom: fromDate
            )
            
            let fetchedOrders = ordersResponse.data ?? []
            
            // Разделяем на новые и обработанные
            newOrders = fetchedOrders.filter { order in
                order.attributes.status == .acceptedByMerchant ||
                order.attributes.state == .new
            }
            
            processedOrders = fetchedOrders.filter { order in
                order.attributes.status != .acceptedByMerchant &&
                order.attributes.state != .new
            }
            
            // Сохраняем в Firestore
            await saveOrdersToFirestore(fetchedOrders)
            
        } catch {
            errorMessage = "Ошибка синхронизации заказов: \(error.localizedDescription)"
        }
    }
    
    /// Синхронизация товаров
    func syncProducts() async {
        do {
            let syncedProducts = try await kaspiAPI.syncAllProducts()
            products = syncedProducts
            
            // Сохраняем в Firestore
            await saveProductsToFirestore(syncedProducts)
            
        } catch {
            errorMessage = "Ошибка синхронизации товаров: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Order Processing
    
    /// Автоматическая обработка новых заказов
    func processNewOrdersAutomatically() async {
        guard !newOrders.isEmpty else { return }
        
        print("🤖 Автоматическая обработка \(newOrders.count) заказов")
        
        for order in newOrders {
            await processOrder(order)
        }
        
        // Обновляем список после обработки
        await syncOrders()
    }
    
    /// Обработка одного заказа
    func processOrder(_ order: KaspiOrder) async {
        do {
            // 1. Проверяем доступность товаров
            let hasStock = await checkOrderStock(order)
            if !hasStock {
                await cancelOrderDueToStock(order)
                return
            }
            
            // 2. Принимаем заказ
            let acceptedOrder = try await kaspiAPI.acceptOrder(
                orderId: order.id,
                orderCode: order.attributes.code
            )
            
            // 3. Если Kaspi доставка - сразу передаем
            if order.attributes.isKaspiDelivery {
                let shippedOrder = try await kaspiAPI.shipOrder(orderId: acceptedOrder.id)
                print("✅ Заказ \(order.attributes.code) передан на доставку Kaspi")
                
                // 4. Создаем запись о доставке
                await createDeliveryRecord(shippedOrder)
            } else {
                // 5. Для самовывоза создаем задачу продавцу
                await createSellerTask(acceptedOrder)
            }
            
            successMessage = "✅ Заказ \(order.attributes.code) обработан"
            
        } catch {
            print("❌ Ошибка обработки заказа \(order.attributes.code): \(error)")
            errorMessage = "Ошибка обработки заказа \(order.attributes.code)"
        }
    }
    
    /// Проверка наличия товаров в заказе
    private func checkOrderStock(_ order: KaspiOrder) async -> Bool {
        // Получаем позиции заказа
        do {
            let entries = try await kaspiAPI.getOrderEntries(orderId: order.id)
            
            for entry in entries {
                // Получаем информацию о товаре
                let product = try await kaspiAPI.getOrderEntryProduct(entryId: entry.id)
                
                // Проверяем доступное количество
                if product.attributes.availableAmount < entry.attributes.quantity {
                    print("⚠️ Недостаток товара: \(product.attributes.name)")
                    return false
                }
            }
            
            return true
            
        } catch {
            print("❌ Ошибка проверки наличия: \(error)")
            return false
        }
    }
    
    /// Отмена заказа из-за отсутствия товара
    private func cancelOrderDueToStock(_ order: KaspiOrder) async {
        do {
            let entries = try await kaspiAPI.getOrderEntries(orderId: order.id)
            
            for entry in entries {
                try await kaspiAPI.cancelOrderEntry(
                    entryId: entry.id,
                    reason: "MERCHANT_OUT_OF_STOCK",
                    notes: "Товар отсутствует на складе"
                )
            }
            
            print("❌ Заказ \(order.attributes.code) отменен из-за отсутствия товара")
            
        } catch {
            print("❌ Ошибка отмены заказа: \(error)")
        }
    }
    
    /// Создание записи о доставке
    private func createDeliveryRecord(_ order: KaspiOrder) async {
        do {
            // Ищем доступного курьера (заглушка)
            let courier = await findAvailableCourier()
            
            let delivery = try await kaspiAPI.createDeliveryFromKaspiOrder(
                order,
                courierId: courier.id,
                courierName: courier.name
            )
            
            deliveries.append(delivery)
            
            // Уведомляем курьера
            await notifyCourier(courier, about: delivery)
            
        } catch {
            print("❌ Ошибка создания доставки: \(error)")
        }
    }
    
    /// Создание задачи для продавца (самовывоз)
    private func createSellerTask(_ order: KaspiOrder) async {
        let taskData: [String: Any] = [
            "type": "self_pickup",
            "orderId": order.id,
            "orderCode": order.attributes.code,
            "customerName": order.attributes.customer.name,
            "customerPhone": order.attributes.customer.cellPhone,
            "totalAmount": order.attributes.totalPrice,
            "createdAt": FieldValue.serverTimestamp(),
            "status": "pending",
            "sellerId": Auth.auth().currentUser?.uid ?? ""
        ]
        
        do {
            try await db.collection("sellerTasks").addDocument(data: taskData)
            print("✅ Создана задача самовывоза для заказа \(order.attributes.code)")
        } catch {
            print("❌ Ошибка создания задачи: \(error)")
        }
    }
    
    // MARK: - Delivery Management
    
    /// Найти доступного курьера
    private func findAvailableCourier() async -> CourierInfo {
        // TODO: Реальная логика поиска курьера
        // Пока возвращаем тестового курьера
        return CourierInfo(
            id: "courier_\(UUID().uuidString)",
            name: "Курьер Тестовый",
            phone: "+77771234567",
            isAvailable: true,
            location: "Алматы"
        )
    }
    
    /// Уведомить курьера о новой доставке
    private func notifyCourier(_ courier: CourierInfo, about delivery: DeliveryConfirmation) async {
        let notificationData: [String: Any] = [
            "userId": courier.id,
            "type": "new_delivery",
            "title": "Новая доставка",
            "message": "Вам назначен заказ \(delivery.trackingNumber)",
            "deliveryId": delivery.id,
            "orderId": delivery.orderId,
            "customerPhone": delivery.customerPhone,
            "address": delivery.deliveryAddress,
            "createdAt": FieldValue.serverTimestamp(),
            "read": false,
            "priority": "normal"
        ]
        
        do {
            try await db.collection("notifications").addDocument(data: notificationData)
            print("✅ Курьер \(courier.name) уведомлен о доставке")
        } catch {
            print("❌ Ошибка отправки уведомления: \(error)")
        }
    }
    
    // MARK: - Delivery Confirmation
    
    /// Запросить код подтверждения доставки
    func requestDeliveryCode(_ delivery: DeliveryConfirmation) async -> Bool {
        do {
            let codeId = try await kaspiAPI.requestDeliveryConfirmationCode(
                orderId: delivery.orderId,
                trackingNumber: delivery.trackingNumber,
                customerPhone: delivery.customerPhone
            )
            
            // Обновляем статус доставки
            var updatedDelivery = delivery.withConfirmationCode(codeId)
            updatedDelivery.status = .awaitingCode
            
            try await updateDeliveryInFirestore(updatedDelivery)
            
            // Обновляем локальный массив
            if let index = deliveries.firstIndex(where: { $0.id == delivery.id }) {
                deliveries[index] = updatedDelivery
            }
            
            return true
            
        } catch {
            errorMessage = "Ошибка запроса кода: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Подтвердить доставку с кодом
    func confirmDelivery(_ delivery: DeliveryConfirmation, code: String) async -> Bool {
        do {
            let isConfirmed = try await kaspiAPI.confirmDeliveryWithCode(
                orderId: delivery.orderId,
                trackingNumber: delivery.trackingNumber,
                securityCode: code
            )
            
            if isConfirmed {
                // Обновляем статус доставки
                let confirmedDelivery = delivery.confirm(by: Auth.auth().currentUser?.uid ?? "")
                
                try await updateDeliveryInFirestore(confirmedDelivery)
                
                // Обновляем локальный массив
                if let index = deliveries.firstIndex(where: { $0.id == delivery.id }) {
                    deliveries[index] = confirmedDelivery
                }
                
                successMessage = "✅ Доставка подтверждена"
                return true
            } else {
                // Увеличиваем счетчик попыток
                let updatedDelivery = delivery.incrementAttempts()
                
                try await updateDeliveryInFirestore(updatedDelivery)
                
                if let index = deliveries.firstIndex(where: { $0.id == delivery.id }) {
                    deliveries[index] = updatedDelivery
                }
                
                errorMessage = "Неверный код подтверждения"
                return false
            }
            
        } catch {
            errorMessage = "Ошибка подтверждения: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Statistics
    
    private func updateStatistics() async {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        // Подсчитываем заказы за сегодня
        todayOrdersCount = newOrders.filter { order in
            order.attributes.creationDate >= today && order.attributes.creationDate < tomorrow
        }.count
        
        // Подсчитываем доставленные за сегодня
        todayDeliveredCount = deliveries.filter { delivery in
            guard let confirmedAt = delivery.confirmedAt else { return false }
            return confirmedAt >= today && confirmedAt < tomorrow
        }.count
        
        // Подсчитываем ожидающие доставки
        pendingDeliveriesCount = deliveries.filter { delivery in
            delivery.status != .confirmed && delivery.status != .cancelled
        }.count
    }
    
    // MARK: - Configuration Management
    
    /// Включить/выключить автоматическую обработку
    func toggleAutoProcessing() async {
        isAutoProcessingEnabled.toggle()
        
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            try await db.collection("sellers").document(userId).setData([
                "autoProcessingEnabled": isAutoProcessingEnabled,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            
            successMessage = isAutoProcessingEnabled ?
                "✅ Автообработка включена" : "⏸️ Автообработка отключена"
                
        } catch {
            errorMessage = "Ошибка сохранения настроек: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Data Persistence
    
    private func saveOrdersToFirestore(_ orders: [KaspiOrder]) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let batch = db.batch()
        
        for order in orders {
            let orderData: [String: Any] = [
                "kaspiOrderId": order.id,
                "orderCode": order.attributes.code,
                "customerName": order.attributes.customer.name,
                "customerPhone": order.attributes.customer.cellPhone,
                "customerEmail": order.attributes.customer.email ?? "",
                "deliveryAddress": order.attributes.deliveryAddress.formattedAddress,
                "totalAmount": order.attributes.totalPrice,
                "status": order.attributes.status.rawValue,
                "state": order.attributes.state.rawValue,
                "isKaspiDelivery": order.attributes.isKaspiDelivery,
                "createdAt": Timestamp(date: order.attributes.creationDate),
                "syncedAt": FieldValue.serverTimestamp(),
                "sellerId": userId
            ]
            
            let docRef = db.collection("kaspiOrders").document(order.id)
            batch.setData(orderData, forDocument: docRef, merge: true)
        }
        
        do {
            try await batch.commit()
        } catch {
            print("❌ Ошибка сохранения заказов: \(error)")
        }
    }
    
    private func saveProductsToFirestore(_ products: [Product]) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let batch = db.batch()
        
        for product in products {
            let productData = product.toDictionary()
            let docRef = db.collection("sellers").document(userId)
                .collection("products").document(product.id)
            
            batch.setData(productData, forDocument: docRef, merge: true)
        }
        
        do {
            try await batch.commit()
        } catch {
            print("❌ Ошибка сохранения товаров: \(error)")
        }
    }
    
    private func updateDeliveryInFirestore(_ delivery: DeliveryConfirmation) async throws {
        let deliveryData = delivery.toDictionary()
        try await db.collection("deliveries").document(delivery.id).setData(deliveryData)
    }
    
    // MARK: - Public Interface
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
    
    func refreshData() async {
        await syncData()
    }
}
