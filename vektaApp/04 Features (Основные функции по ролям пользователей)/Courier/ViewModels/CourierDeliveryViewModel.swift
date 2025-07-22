//
//  CourierDeliveryViewModel.swift
//  vektaApp
//
//  ViewModel для управления доставками курьером
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import CoreLocation

@MainActor
class CourierDeliveryViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var activeDeliveries: [DeliveryConfirmation] = []
    @Published var completedDeliveries: [DeliveryConfirmation] = []
    @Published var currentDelivery: DeliveryConfirmation?
    
    @Published var enteredCode: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    @Published var isRequestingSMS = false
    @Published var isVerifyingCode = false
    
    // MARK: - Private Properties
    
    private let db = Firestore.firestore()
    private let kaspiService = KaspiAPIService()
    private var listener: ListenerRegistration?
    
    // MARK: - Statistics
    
    var todayDeliveries: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return completedDeliveries.filter { delivery in
            guard let confirmedAt = delivery.confirmedAt else { return false }
            return confirmedAt >= today
        }.count
    }
    
    var pendingDeliveries: Int {
        activeDeliveries.filter { $0.status == .pending || $0.status == .inTransit }.count
    }
    
    // MARK: - Initialization
    
    init() {
        loadDeliveries()
    }
    
    deinit {
        listener?.remove()
    }
    
    // MARK: - Load Deliveries
    
    func loadDeliveries() {
        guard let courierId = Auth.auth().currentUser?.uid else {
            errorMessage = "Курьер не авторизован"
            return
        }
        
        isLoading = true
        
        // Слушаем активные доставки
        listener = db.collection("deliveries")
            .whereField("courierId", isEqualTo: courierId)
            .whereField("status", notIn: [DeliveryStatus.confirmed.rawValue, DeliveryStatus.cancelled.rawValue])
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        self.errorMessage = "Ошибка загрузки: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self.activeDeliveries = []
                        return
                    }
                    
                    self.activeDeliveries = documents.compactMap { doc in
                        DeliveryConfirmation.fromFirestore(doc.data(), id: doc.documentID)
                    }.sorted { $0.createdAt > $1.createdAt }
                }
            }
        
        // Загружаем завершенные доставки за сегодня
        loadCompletedDeliveries()
    }
    
    private func loadCompletedDeliveries() {
        guard let courierId = Auth.auth().currentUser?.uid else { return }
        
        let today = Calendar.current.startOfDay(for: Date())
        
        db.collection("deliveries")
            .whereField("courierId", isEqualTo: courierId)
            .whereField("status", isEqualTo: DeliveryStatus.confirmed.rawValue)
            .whereField("confirmedAt", isGreaterThanOrEqualTo: Timestamp(date: today))
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if let documents = snapshot?.documents {
                        self.completedDeliveries = documents.compactMap { doc in
                            DeliveryConfirmation.fromFirestore(doc.data(), id: doc.documentID)
                        }
                    }
                }
            }
    }
    
    // MARK: - Delivery Actions
    
    /// Начать доставку
    func startDelivery(_ delivery: DeliveryConfirmation) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let updated = delivery.updatingStatus(.inTransit)
            try await updateDeliveryInFirestore(updated)
            
            // Добавляем в историю
            try await addToHistory(
                deliveryId: delivery.id,
                action: .started,
                details: "Курьер выехал к клиенту"
            )
            
            currentDelivery = updated
            successMessage = "✅ Доставка начата"
            
        } catch {
            errorMessage = "Ошибка: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Прибыть к клиенту
    func arrivedAtCustomer(_ delivery: DeliveryConfirmation) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let updated = delivery.updatingStatus(.arrived)
            try await updateDeliveryInFirestore(updated)
            
            // Добавляем в историю с геолокацией
            try await addToHistory(
                deliveryId: delivery.id,
                action: .arrived,
                details: "Курьер прибыл по адресу: \(delivery.deliveryAddress)",
                location: nil // TODO: Добавить реальную геолокацию
            )
            
            currentDelivery = updated
            successMessage = "✅ Вы прибыли к клиенту"
            
        } catch {
            errorMessage = "Ошибка: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - SMS Code Management
    
    /// Запросить SMS код
    func requestSMSCode(for delivery: DeliveryConfirmation) async {
        isRequestingSMS = true
        errorMessage = nil
        
        do {
            // Проверяем, можно ли запросить новый код
            guard delivery.canRequestNewCode else {
                throw NSError(
                    domain: "CourierDelivery",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Подождите 2 минуты перед повторным запросом"]
                )
            }
            
            // Запрашиваем код через Kaspi API
            try await kaspiService.requestSMSCode(
                orderId: delivery.orderId,
                trackingNumber: delivery.trackingNumber
            )
            
            // Генерируем код для тестирования (в продакшне код придет от Kaspi)
            let code = generateTestSMSCode()
            
            // Обновляем доставку с кодом
            var updated = delivery.withConfirmationCode(code)
            updated.status = .awaitingCode
            
            try await updateDeliveryInFirestore(updated)
            
            // Добавляем в историю
            try await addToHistory(
                deliveryId: delivery.id,
                action: .codeRequested,
                details: "SMS код отправлен на номер \(delivery.formattedPhone)"
            )
            
            currentDelivery = updated
            successMessage = "✅ SMS код отправлен клиенту"
            
            // Показываем код курьеру для тестирования
            #if DEBUG
            print("🔐 Тестовый SMS код: \(code)")
            #endif
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isRequestingSMS = false
    }
    
    /// Подтвердить доставку с помощью кода
    func confirmDeliveryWithCode(_ code: String, for delivery: DeliveryConfirmation) async {
        guard !code.isEmpty else {
            errorMessage = "Введите код подтверждения"
            return
        }
        
        isVerifyingCode = true
        errorMessage = nil
        
        do {
            // Проверяем количество попыток
            guard delivery.remainingAttempts > 0 else {
                throw NSError(
                    domain: "CourierDelivery",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Превышено количество попыток. Запросите новый код."]
                )
            }
            
            // Проверяем срок действия кода
            guard !delivery.isCodeExpired else {
                throw NSError(
                    domain: "CourierDelivery",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Код истек. Запросите новый код."]
                )
            }
            
            // Увеличиваем счетчик попыток
            var updated = delivery.incrementAttempts()
            
            // Проверяем код через Kaspi API
            let isValid = try await kaspiService.confirmDelivery(
                orderId: delivery.orderId,
                trackingNumber: delivery.trackingNumber,
                smsCode: code
            )
            
            if isValid {
                // Подтверждаем доставку
                updated = updated.confirm(by: Auth.auth().currentUser?.uid ?? "")
                try await updateDeliveryInFirestore(updated)
                
                // Обновляем статус заказа
                try await updateOrderStatus(orderId: delivery.orderId, status: .completed)
                
                // Добавляем в историю
                try await addToHistory(
                    deliveryId: delivery.id,
                    action: .delivered,
                    details: "Доставка подтверждена кодом"
                )
                
                currentDelivery = nil
                enteredCode = ""
                successMessage = "✅ Доставка успешно подтверждена!"
                
                // Обновляем списки
                loadDeliveries()
                
            } else {
                // Неверный код
                try await updateDeliveryInFirestore(updated)
                
                if updated.remainingAttempts == 0 {
                    errorMessage = "Неверный код. Попытки исчерпаны. Запросите новый код."
                } else {
                    errorMessage = "Неверный код. Осталось попыток: \(updated.remainingAttempts)"
                }
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isVerifyingCode = false
    }
    
    /// Отметить доставку как неудачную
    func markDeliveryFailed(_ delivery: DeliveryConfirmation, reason: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let updated = delivery.updatingStatus(.failed)
            try await updateDeliveryInFirestore(updated)
            
            // Добавляем в историю
            try await addToHistory(
                deliveryId: delivery.id,
                action: .failed,
                details: reason
            )
            
            // Обновляем статус заказа
            try await updateOrderStatus(orderId: delivery.orderId, status: .pending)
            
            currentDelivery = nil
            successMessage = "Доставка отмечена как неудачная"
            
        } catch {
            errorMessage = "Ошибка: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    /// Обновить доставку в Firestore
    private func updateDeliveryInFirestore(_ delivery: DeliveryConfirmation) async throws {
        try await db.collection("deliveries")
            .document(delivery.id)
            .setData(delivery.toDictionary(), merge: true)
    }
    
    /// Обновить статус заказа
    private func updateOrderStatus(orderId: String, status: OrderStatus) async throws {
        try await db.collection("orders")
            .document(orderId)
            .updateData([
                "status": status.rawValue,
                "updatedAt": FieldValue.serverTimestamp()
            ])
    }
    
    /// Добавить запись в историю
    private func addToHistory(
        deliveryId: String,
        action: DeliveryAction,
        details: String? = nil,
        location: GeoPoint? = nil
    ) async throws {
        
        let history = DeliveryHistory(
            id: UUID().uuidString,
            deliveryId: deliveryId,
            action: action,
            performedBy: Auth.auth().currentUser?.uid ?? "",
            performedByRole: "Courier",
            timestamp: Date(),
            details: details,
            location: location
        )
        
        try await db.collection("deliveryHistory")
            .document(history.id)
            .setData([
                "deliveryId": history.deliveryId,
                "action": history.action.rawValue,
                "performedBy": history.performedBy,
                "performedByRole": history.performedByRole,
                "timestamp": Timestamp(date: history.timestamp),
                "details": details ?? NSNull(),
                "location": location ?? NSNull()
            ])
    }
    
    /// Генерировать тестовый SMS код
    private func generateTestSMSCode() -> String {
        let digits = "0123456789"
        return String((0..<6).map { _ in digits.randomElement()! })
    }
    
    // MARK: - Utility Methods
    
    /// Очистить введенный код
    func clearEnteredCode() {
        enteredCode = ""
    }
    
    /// Форматировать код для отображения
    func formatCode(_ code: String) -> String {
        let cleaned = code.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if cleaned.count >= 3 {
            let index3 = cleaned.index(cleaned.startIndex, offsetBy: 3)
            let firstPart = cleaned[..<index3]
            let secondPart = cleaned[index3...]
            return "\(firstPart)-\(secondPart)"
        }
        return cleaned
    }
}

// MARK: - Location Extension

extension CourierDeliveryViewModel {
    
    /// Получить текущую геолокацию
    func getCurrentLocation() async -> CLLocationCoordinate2D? {
        // TODO: Implement location services
        return nil
    }
}
