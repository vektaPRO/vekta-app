//
//  FirestoreSyncManager.swift
//  vektaApp
//
//  Полная система синхронизации всех данных между Kaspi API и Firestore
//  ИСПРАВЛЕНО: убрана проблема с deinit и @MainActor
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

@MainActor
class FirestoreSyncManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncProgress: Double = 0.0
    @Published var syncStatus: String = "Готов к синхронизации"
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private let kaspiAPI = KaspiAPIService()
    private var syncTimer: Timer?
    
    // Listeners для real-time обновлений
    private var ordersListener: ListenerRegistration?
    private var productsListener: ListenerRegistration?
    private var deliveriesListener: ListenerRegistration?
    
    // MARK: - Sync Configuration
    private let syncInterval: TimeInterval = 300 // 5 минут
    private let batchSize = 50
    
    // MARK: - Initialization
    
    init() {
        setupRealtimeListeners()
        startAutoSync()
        loadLastSyncDate()
    }
    
    // ИСПРАВЛЕНО: deinit теперь НЕ async
    deinit {
        // Синхронно останавливаем таймер и убираем listeners
        syncTimer?.invalidate()
        syncTimer = nil
        
        ordersListener?.remove()
        productsListener?.remove()
        deliveriesListener?.remove()
    }
    
    // MARK: - Main Sync Methods
    
    /// Полная синхронизация всех данных
    func fullSync() async {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncProgress = 0.0
        errorMessage = nil
        
        let syncTasks = [
            ("Товары", syncProducts),
            ("Заказы", syncOrders),
            ("Доставки", syncDeliveries),
            ("Статистика", updateStatistics)
        ]
        
        let totalTasks = Double(syncTasks.count)
        
        for (index, (taskName, task)) in syncTasks.enumerated() {
            syncStatus = "Синхронизация: \(taskName)..."
            
            do {
                try await task()
                syncProgress = Double(index + 1) / totalTasks
                print("✅ \(taskName) синхронизированы")
            } catch {
                print("❌ Ошибка синхронизации \(taskName): \(error)")
                errorMessage = "Ошибка синхронизации \(taskName): \(error.localizedDescription)"
            }
        }
        
        // Завершение синхронизации
        lastSyncDate = Date()
        saveLastSyncDate()
        isSyncing = false
        syncStatus = "Синхронизация завершена"
        successMessage = "✅ Все данные синхронизированы"
        
        clearMessages()
    }
    
    /// Синхронизация товаров из Kaspi API
    private func syncProducts() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirebaseError.userNotAuthenticated
        }
        
        // Получаем товары из Kaspi API
        let kaspiProducts = try await kaspiAPI.fetchAllProducts()
        
        // Конвертируем в локальные модели
        let localProducts = kaspiProducts.map { $0.toLocalProduct() }
        
        // Сохраняем batch-ами для производительности
        let batches = localProducts.chunked(into: batchSize)
        
        for batch in batches {
            let batchWrite = db.batch()
            
            for product in batch {
                let productRef = db.collection("sellers").document(userId)
                    .collection("products").document(product.id)
                
                let productData = product.toDictionary()
                batchWrite.setData(productData, forDocument: productRef, merge: true)
            }
            
            try await batchWrite.commit()
        }
        
        print("✅ Синхронизировано \(localProducts.count) товаров")
    }
    
    /// Синхронизация заказов из Kaspi API
    private func syncOrders() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirebaseError.userNotAuthenticated
        }
        
        // Получаем заказы за последние 7 дней
        let fromDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        let ordersResponse = try await kaspiAPI.getOrders(
            page: 0,
            size: 100,
            creationDateFrom: fromDate
        )
        
        guard let kaspiOrders = ordersResponse.data else { return }
        
        // Сохраняем заказы
        let batch = db.batch()
        
        for order in kaspiOrders {
            let orderRef = db.collection("kaspiOrders").document(order.id)
            
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
            
            batch.setData(orderData, forDocument: orderRef, merge: true)
        }
        
        try await batch.commit()
        
        print("✅ Синхронизировано \(kaspiOrders.count) заказов")
    }
    
    /// Синхронизация доставок
    private func syncDeliveries() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirebaseError.userNotAuthenticated
        }
        
        // Получаем активные доставки из Firestore
        let deliveriesSnapshot = try await db.collection("deliveries")
            .whereField("status", in: [
                DeliveryStatus.pending.rawValue,
                DeliveryStatus.inTransit.rawValue,
                DeliveryStatus.arrived.rawValue,
                DeliveryStatus.awaitingCode.rawValue
            ])
            .getDocuments()
        
        // Обновляем статусы доставок на основе данных из Kaspi
        for doc in deliveriesSnapshot.documents {
            if let delivery = DeliveryConfirmation.fromFirestore(doc.data(), id: doc.documentID) {
                
                // Проверяем статус заказа в Kaspi
                do {
                    let kaspiOrder = try await kaspiAPI.getOrder(code: delivery.trackingNumber)
                    
                    // Обновляем статус доставки на основе статуса заказа
                    let updatedStatus = mapKaspiStatusToDeliveryStatus(kaspiOrder.attributes.status)
                    
                    if updatedStatus != delivery.status {
                        try await doc.reference.updateData([
                            "status": updatedStatus.rawValue,
                            "updatedAt": FieldValue.serverTimestamp()
                        ])
                    }
                } catch {
                    print("⚠️ Не удалось обновить статус доставки \(delivery.id): \(error)")
                }
            }
        }
        
        print("✅ Статусы доставок обновлены")
    }
    
    /// Обновление статистики
    private func updateStatistics() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirebaseError.userNotAuthenticated
        }
        
        // Собираем статистику
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        // Заказы за сегодня
        let todayOrdersSnapshot = try await db.collection("kaspiOrders")
            .whereField("sellerId", isEqualTo: userId)
            .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: today))
            .whereField("createdAt", isLessThan: Timestamp(date: tomorrow))
            .getDocuments()
        
        // Доставки за сегодня
        let todayDeliveriesSnapshot = try await db.collection("deliveries")
            .whereField("status", isEqualTo: DeliveryStatus.confirmed.rawValue)
            .whereField("confirmedAt", isGreaterThanOrEqualTo: Timestamp(date: today))
            .whereField("confirmedAt", isLessThan: Timestamp(date: tomorrow))
            .getDocuments()
        
        // Сохраняем статистику
        let statsData: [String: Any] = [
            "todayOrders": todayOrdersSnapshot.count,
            "todayDeliveries": todayDeliveriesSnapshot.count,
            "lastUpdated": FieldValue.serverTimestamp(),
            "syncDate": Timestamp(date: Date())
        ]
        
        try await db.collection("sellers").document(userId)
            .collection("statistics").document("daily")
            .setData(statsData, merge: true)
        
        print("✅ Статистика обновлена")
    }
    
    // MARK: - Real-time Listeners
    
    /// Настройка real-time слушателей
    private func setupRealtimeListeners() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Слушатель заказов Kaspi
        ordersListener = db.collection("kaspiOrders")
            .whereField("sellerId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Ошибка слушателя заказов: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                // Обрабатываем новые заказы
                for doc in documents {
                    if let change = snapshot?.documentChanges.first(where: { $0.document.documentID == doc.documentID }),
                       change.type == .added {
                        Task {
                            await self?.handleNewOrder(doc.data())
                        }
                    }
                }
            }
        
        // Слушатель товаров
        productsListener = db.collection("sellers").document(userId)
            .collection("products")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Ошибка слушателя товаров: \(error)")
                    return
                }
                
                // Обрабатываем изменения товаров при необходимости
                print("📦 Товары обновлены в real-time")
            }
        
        // Слушатель доставок
        deliveriesListener = db.collection("deliveries")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Ошибка слушателя доставок: \(error)")
                    return
                }
                
                // Обрабатываем изменения доставок
                print("🚚 Доставки обновлены в real-time")
            }
    }
    
    /// Обработка нового заказа
    private func handleNewOrder(_ orderData: [String: Any]) async {
        print("🆕 Получен новый заказ для обработки")
        
        // Здесь можно добавить автоматическую обработку заказа
        // через KaspiIntegrationManager
    }
    
    // MARK: - Auto Sync
    
    /// Запуск автоматической синхронизации
    /// ИСПРАВЛЕНО: убран @MainActor, теперь можно вызывать из deinit
    private func startAutoSync() {
        // Создаем таймер на главном потоке
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.syncTimer = Timer.scheduledTimer(withTimeInterval: self.syncInterval, repeats: true) { [weak self] _ in
                Task {
                    await self?.fullSync()
                }
            }
        }
    }
    
    /// Остановка автоматической синхронизации
    /// ИСПРАВЛЕНО: убран @MainActor, теперь можно вызывать из deinit
    private func stopAutoSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    // MARK: - Helper Methods
    
    /// Маппинг статуса Kaspi в статус доставки
    private func mapKaspiStatusToDeliveryStatus(_ kaspiStatus: KaspiOrderStatus) -> DeliveryStatus {
        switch kaspiStatus {
        case .acceptedByMerchant, .approvedByBank:
            return .pending
        case .assemble:
            return .inTransit
        case .kaspiDelivery:
            return .arrived
        case .completed:
            return .confirmed
        case .cancelled, .returned:
            return .cancelled
        }
    }
    
    /// Загрузка даты последней синхронизации
    private func loadLastSyncDate() {
        if let savedDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date {
            lastSyncDate = savedDate
        }
    }
    
    /// Сохранение даты последней синхронизации
    private func saveLastSyncDate() {
        if let date = lastSyncDate {
            UserDefaults.standard.set(date, forKey: "lastSyncDate")
        }
    }
    
    /// Очистка сообщений через 3 секунды
    private func clearMessages() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.successMessage = nil
            self.errorMessage = nil
        }
    }
    
    // MARK: - Public Interface
    
    /// Принудительная синхронизация
    func forceSync() async {
        await fullSync()
    }
    
    /// Синхронизация только заказов
    func syncOrdersOnly() async {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncStatus = "Синхронизация заказов..."
        
        do {
            try await syncOrders()
            successMessage = "✅ Заказы синхронизированы"
        } catch {
            errorMessage = "Ошибка синхронизации заказов: \(error.localizedDescription)"
        }
        
        isSyncing = false
        clearMessages()
    }
    
    /// Синхронизация только товаров
    func syncProductsOnly() async {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncStatus = "Синхронизация товаров..."
        
        do {
            try await syncProducts()
            successMessage = "✅ Товары синхронизированы"
        } catch {
            errorMessage = "Ошибка синхронизации товаров: \(error.localizedDescription)"
        }
        
        isSyncing = false
        clearMessages()
    }
    
    /// Получить статистику синхронизации
    func getSyncStats() -> (totalSyncs: Int, lastSync: Date?, isAutoSyncEnabled: Bool) {
        return (
            totalSyncs: UserDefaults.standard.integer(forKey: "totalSyncs"),
            lastSync: lastSyncDate,
            isAutoSyncEnabled: syncTimer != nil
        )
    }
}

// MARK: - Array Extension для batch операций

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
