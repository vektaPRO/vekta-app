//
//  CourierDeliveryViewModel.swift
//  vektaApp
//
//  ViewModel для управления доставками курьером с реальным Kaspi API
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
    
    // SMS код информация
    @Published var smsMessageId: String?
    @Published var smsCodeExpiresAt: Date?
    @Published var smsAttemptsLeft: Int = 3
    
    // MARK: - Private Properties
    
    private let db = Firestore.firestore()
    private let kaspiService = KaspiAPIService()
    private var listener: ListenerRegistration?
    
    // Rate limiting для SMS
    private var lastSMSRequestTime: Date?
    private let smsRequestCooldown: TimeInterval = 120 // 2 минуты
    
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
        setupKaspiService()
    }
    
    deinit {
        listener?.remove()
    }
    
    // MARK: - Setup
    
    private func setupKaspiService() {
        Task {
            await kaspiService.loadApiToken()
        }
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
            // Получаем текущую геолокацию
            let location = await getCurrentLocation()
            
            let updated = delivery.updatingStatus(.arrived)
            try await updateDeliveryInFirestore(updated)
            
            // Добавляем в историю с геолокацией
            try await addToHistory(
                deliveryId: delivery.id,
                action: .arrived,
                details: "Курьер прибыл по адресу: \(delivery.deliveryAddress)",
                location: location != nil ? GeoPoint(
                    latitude: location!.latitude,
                    longitude: location!.longitude
                ) : nil
            )
            
            currentDelivery = updated
            successMessage = "✅ Вы прибыли к клиенту"
            
        } catch {
            errorMessage = "Ошибка: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - SMS Code Management
    
    /// Запросить SMS код через Kaspi API
    func requestSMSCode(for delivery: DeliveryConfirmation) async {
        isRequestingSMS = true
        errorMessage = nil
        
        do {
            // Проверяем rate limiting
            if let lastRequest = lastSMSRequestTime {
                let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
                if timeSinceLastRequest < smsRequestCooldown {
                    let waitTime = Int(smsRequestCooldown - timeSinceLastRequest)
                    throw NSError(
                        domain: "CourierDelivery",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Подождите \(waitTime) секунд перед повторным запросом"]
                    )
                }
            }
            
            // Проверяем наличие API токена
            guard kaspiService.apiToken != nil else {
                throw NSError(
                    domain: "CourierDelivery",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "API токен не настроен. Обратитесь к администратору."]
                )
            }
            
            // Запрашиваем код через реальный Kaspi API
            let messageId = try await kaspiService.requestSMSCode(
                orderId: delivery.orderId,
                trackingNumber: delivery.trackingNumber,
                customerPhone: delivery.customerPhone
            )
            
            // Сохраняем информацию о запросе
            smsMessageId = messageId
            smsCodeExpiresAt = Date().addingTimeInterval(600) // 10 минут
            lastSMSRequestTime = Date()
            
            // Обновляем доставку
            var updated = delivery
            updated.smsCodeRequested = true
            updated.smsCodeRequestedAt = Date()
            updated.codeExpiresAt = smsCodeExpiresAt
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
            
        } catch let error as KaspiAPIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isRequestingSMS = false
    }
    
    /// Подтвердить доставку с помощью кода через Kaspi API
    func confirmDeliveryWithCode(_ code: String, for delivery: DeliveryConfirmation) async {
        guard !code.isEmpty else {
            errorMessage = "Введите код подтверждения"
            return
        }
        
        // Валидация формата кода (6 цифр)
        let cleanedCode = code.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        guard cleanedCode.count == 6 else {
            errorMessage = "Код должен содержать 6 цифр"
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
            
            // Проверяем код через реальный Kaspi API
            let isValid = try await kaspiService.confirmDelivery(
                orderId: delivery.orderId,
                trackingNumber: delivery.trackingNumber,
                smsCode: cleanedCode
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
                
                // Уведомляем продавца
                try await notifySeller(
                    orderId: delivery.orderId,
                    message: "Заказ \(delivery.trackingNumber) успешно доставлен"
                )
                
                currentDelivery = nil
                enteredCode = ""
                successMessage = "✅ Доставка успешно подтверждена!"
                
                // Обновляем списки
                loadDeliveries()
                
            } else {
                // Неверный код - не должно произойти, так как API бросит ошибку
                throw NSError(
                    domain: "CourierDelivery",
                    code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "Неверный код подтверждения"]
                )
            }
            
        } catch let error as KaspiAPIError {
            // Обновляем доставку с новым количеством попыток
            try? await updateDeliveryInFirestore(updated)
            
            if updated.remainingAttempts == 0 {
                errorMessage = "Неверный код. Попытки исчерпаны. Запросите новый код."
            } else {
                errorMessage = "\(error.localizedDescription). Осталось попыток: \(updated.remainingAttempts)"
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
            
            // Уведомляем продавца
            try await notifySeller(
                orderId: delivery.orderId,
                message: "Не удалось доставить заказ \(delivery.trackingNumber): \(reason)"
            )
            
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
    
    /// Уведомить продавца
    private func notifySeller(orderId: String, message: String) async throws {
        // Получаем информацию о заказе
        let orderDoc = try await db.collection("orders").document(orderId).getDocument()
        guard let sellerId = orderDoc.data()?["sellerId"] as? String else { return }
        
        // Создаем уведомление
        let notification = [
            "userId": sellerId,
            "type": "delivery_update",
            "title": "Обновление доставки",
            "message": message,
            "orderId": orderId,
            "createdAt": FieldValue.serverTimestamp(),
            "read": false
        ]
        
        try await db.collection("notifications").addDocument(data: notification)
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
    
    /// Проверить можно ли запросить новый SMS код
    func canRequestNewSMS() -> Bool {
        guard let lastRequest = lastSMSRequestTime else { return true }
        return Date().timeIntervalSince(lastRequest) >= smsRequestCooldown
    }
    
    /// Время до возможности нового запроса SMS
    func timeUntilNextSMS() -> Int {
        guard let lastRequest = lastSMSRequestTime else { return 0 }
        let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
        let remaining = smsRequestCooldown - timeSinceLastRequest
        return max(0, Int(remaining))
    }
}

// MARK: - Location Extension

extension CourierDeliveryViewModel {
    
    /// Получить текущую геолокацию
    func getCurrentLocation() async -> CLLocationCoordinate2D? {
        // TODO: Implement proper location services with permissions
        // Для демо возвращаем координаты Алматы
        return CLLocationCoordinate2D(latitude: 43.238949, longitude: 76.889709)
    }
}
