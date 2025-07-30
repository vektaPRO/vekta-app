//
//  CourierDeliveryViewModel.swift
//  vektaApp
//
//  ViewModel для управления доставками курьера
//

import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class CourierDeliveryViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var activeDeliveries: [DeliveryConfirmation] = []
    @Published var currentDelivery: DeliveryConfirmation?
    @Published var isLoading = false
    @Published var isRequestingSMS = false
    @Published var isVerifyingCode = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var enteredCode = ""
    
    // MARK: - Statistics
    @Published var pendingDeliveries = 0
    @Published var todayDeliveries = 0
    
    // MARK: - Services
    private let kaspiAPI = KaspiAPIService()
    private let db = Firestore.firestore()
    
    // MARK: - Initialization
    init() {
        loadDeliveries()
    }
    
    // MARK: - Main Methods
    
    /// Загрузить доставки курьера
    func loadDeliveries() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Пользователь не авторизован"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Для демонстрации используем тестовые данные
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.activeDeliveries = self.createMockDeliveries()
            self.updateStatistics()
            self.isLoading = false
        }
        
        // TODO: Реальная загрузка из Firestore
        /*
        db.collection("deliveries")
            .whereField("courierId", isEqualTo: userId)
            .whereField("status", in: [
                DeliveryStatus.pending.rawValue,
                DeliveryStatus.inTransit.rawValue,
                DeliveryStatus.arrived.rawValue,
                DeliveryStatus.awaitingCode.rawValue
            ])
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.errorMessage = "Ошибка загрузки: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self?.activeDeliveries = []
                        return
                    }
                    
                    self?.activeDeliveries = documents.compactMap { doc in
                        DeliveryConfirmation.fromFirestore(doc.data(), id: doc.documentID)
                    }
                    
                    self?.updateStatistics()
                }
            }
        */
    }
    
    /// Начать доставку
    func startDelivery(_ delivery: DeliveryConfirmation) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let updatedDelivery = delivery.updatingStatus(.inTransit)
            try await updateDeliveryInFirestore(updatedDelivery)
            
            if let index = activeDeliveries.firstIndex(where: { $0.id == delivery.id }) {
                activeDeliveries[index] = updatedDelivery
            }
            
            successMessage = "✅ Доставка начата"
            clearSuccessMessage()
            
        } catch {
            errorMessage = "Ошибка начала доставки: \(error.localizedDescription)"
        }
    }
    
    /// Отметить прибытие к клиенту
    func arrivedAtCustomer(_ delivery: DeliveryConfirmation) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let updatedDelivery = delivery.updatingStatus(.arrived)
            try await updateDeliveryInFirestore(updatedDelivery)
            
            if let index = activeDeliveries.firstIndex(where: { $0.id == delivery.id }) {
                activeDeliveries[index] = updatedDelivery
            }
            
            successMessage = "✅ Прибытие отмечено"
            clearSuccessMessage()
            
        } catch {
            errorMessage = "Ошибка отметки прибытия: \(error.localizedDescription)"
        }
    }
    
    /// Запросить SMS код для подтверждения доставки
    func requestSMSCode(for delivery: DeliveryConfirmation) async {
        isRequestingSMS = true
        defer { isRequestingSMS = false }
        
        do {
            // Запрашиваем код через Kaspi API
            let codeId = try await kaspiAPI.requestDeliveryConfirmationCode(
                orderId: delivery.orderId,
                trackingNumber: delivery.trackingNumber,
                customerPhone: delivery.customerPhone
            )
            
            // Обновляем статус доставки
            let updatedDelivery = delivery.withConfirmationCode(codeId).updatingStatus(.awaitingCode)
            try await updateDeliveryInFirestore(updatedDelivery)
            
            if let index = activeDeliveries.firstIndex(where: { $0.id == delivery.id }) {
                activeDeliveries[index] = updatedDelivery
            }
            
            successMessage = "✅ SMS код отправлен клиенту"
            clearSuccessMessage()
            
        } catch {
            errorMessage = "Ошибка отправки SMS: \(error.localizedDescription)"
        }
    }
    
    /// Подтвердить доставку с кодом
    func confirmDeliveryWithCode(_ code: String, for delivery: DeliveryConfirmation) async {
        isVerifyingCode = true
        defer { isVerifyingCode = false }
        
        do {
            // Подтверждаем доставку через Kaspi API
            let isConfirmed = try await kaspiAPI.confirmDeliveryWithCode(
                orderId: delivery.orderId,
                trackingNumber: delivery.trackingNumber,
                securityCode: code
            )
            
            if isConfirmed {
                // Обновляем статус доставки
                let confirmedDelivery = delivery.confirm(by: Auth.auth().currentUser?.uid ?? "")
                try await updateDeliveryInFirestore(confirmedDelivery)
                
                if let index = activeDeliveries.firstIndex(where: { $0.id == delivery.id }) {
                    activeDeliveries[index] = confirmedDelivery
                }
                
                successMessage = "✅ Доставка подтверждена"
                clearEnteredCode()
                clearSuccessMessage()
                
            } else {
                // Увеличиваем счетчик попыток
                let updatedDelivery = delivery.incrementAttempts()
                try await updateDeliveryInFirestore(updatedDelivery)
                
                if let index = activeDeliveries.firstIndex(where: { $0.id == delivery.id }) {
                    activeDeliveries[index] = updatedDelivery
                }
                
                errorMessage = "Неверный код подтверждения"
            }
            
        } catch {
            errorMessage = "Ошибка подтверждения: \(error.localizedDescription)"
        }
    }
    
    /// Отметить доставку как неуспешную
    func markDeliveryFailed(_ delivery: DeliveryConfirmation, reason: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let failedDelivery = delivery.updatingStatus(.failed)
            try await updateDeliveryInFirestore(failedDelivery)
            
            if let index = activeDeliveries.firstIndex(where: { $0.id == delivery.id }) {
                activeDeliveries[index] = failedDelivery
            }
            
            successMessage = "Доставка отмечена как неуспешная"
            clearSuccessMessage()
            
        } catch {
            errorMessage = "Ошибка отметки: \(error.localizedDescription)"
        }
    }
    
    /// Очистить введенный код
    func clearEnteredCode() {
        enteredCode = ""
    }
    
    // MARK: - Private Methods
    
    /// Обновить статистику
    private func updateStatistics() {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        pendingDeliveries = activeDeliveries.filter { delivery in
            delivery.status != .confirmed && delivery.status != .cancelled
        }.count
        
        todayDeliveries = activeDeliveries.filter { delivery in
            guard let confirmedAt = delivery.confirmedAt else { return false }
            return confirmedAt >= today && confirmedAt < tomorrow
        }.count
    }
    
    /// Обновить доставку в Firestore
    private func updateDeliveryInFirestore(_ delivery: DeliveryConfirmation) async throws {
        let deliveryData = delivery.toDictionary()
        try await db.collection("deliveries").document(delivery.id).setData(deliveryData)
    }
    
    /// Создать тестовые доставки для демонстрации
    private func createMockDeliveries() -> [DeliveryConfirmation] {
        return [
            DeliveryConfirmation(
                id: "delivery_1",
                orderId: "kaspi_order_001",
                trackingNumber: "KSP-789123",
                courierId: Auth.auth().currentUser?.uid ?? "",
                courierName: "Текущий курьер",
                customerPhone: "+77771234567",
                deliveryAddress: "г. Алматы, ул. Абая 150, кв. 25",
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
            ),
            DeliveryConfirmation(
                id: "delivery_2",
                orderId: "kaspi_order_002",
                trackingNumber: "KSP-789124",
                courierId: Auth.auth().currentUser?.uid ?? "",
                courierName: "Текущий курьер",
                customerPhone: "+77771234568",
                deliveryAddress: "г. Алматы, ул. Толе би 45, кв. 12",
                smsCodeRequested: true,
                smsCodeRequestedAt: Date(),
                confirmationCode: "123456",
                codeExpiresAt: Calendar.current.date(byAdding: .minute, value: 10, to: Date()),
                status: .awaitingCode,
                confirmedAt: nil,
                confirmedBy: nil,
                attemptCount: 0,
                maxAttempts: 3,
                createdAt: Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date(),
                updatedAt: Date()
            )
        ]
    }
    
    /// Очистить сообщение об успехе через 3 секунды
    private func clearSuccessMessage() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.successMessage = nil
        }
    }
}
