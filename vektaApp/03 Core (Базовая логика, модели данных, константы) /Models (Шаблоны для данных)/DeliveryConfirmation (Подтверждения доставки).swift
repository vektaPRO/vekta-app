//
//  DeliveryConfirmation.swift
//  vektaApp
//
//  Модель для работы с подтверждением доставки через SMS
//

import Foundation
import FirebaseFirestore

// MARK: - Delivery Confirmation Model

/// Модель подтверждения доставки
struct DeliveryConfirmation: Identifiable, Codable {
    let id: String
    let orderId: String
    let trackingNumber: String
    let courierId: String
    let courierName: String
    let customerPhone: String
    let deliveryAddress: String
    
    // SMS код
    var smsCodeRequested: Bool
    var smsCodeRequestedAt: Date?
    var confirmationCode: String?
    var codeExpiresAt: Date?
    
    // Статус доставки
    var status: DeliveryStatus
    var confirmedAt: Date?
    var confirmedBy: String?
    
    // Попытки ввода кода
    var attemptCount: Int
    var maxAttempts: Int
    
    // Временные метки
    let createdAt: Date
    var updatedAt: Date
    
    // Вычисляемые свойства
    var isCodeExpired: Bool {
        guard let expiresAt = codeExpiresAt else { return true }
        return Date() > expiresAt
    }
    
    var remainingAttempts: Int {
        return max(0, maxAttempts - attemptCount)
    }
    
    var canRequestNewCode: Bool {
        guard let requestedAt = smsCodeRequestedAt else { return true }
        // Можно запросить новый код через 2 минуты
        return Date().timeIntervalSince(requestedAt) > 120
    }
    
    var formattedPhone: String {
        // Форматируем номер телефона для отображения
        let cleaned = customerPhone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if cleaned.count == 11 {
            let index0 = cleaned.startIndex
            let index1 = cleaned.index(cleaned.startIndex, offsetBy: 1)
            let index4 = cleaned.index(cleaned.startIndex, offsetBy: 4)
            let index7 = cleaned.index(cleaned.startIndex, offsetBy: 7)
            let index9 = cleaned.index(cleaned.startIndex, offsetBy: 9)
            let index11 = cleaned.index(cleaned.startIndex, offsetBy: 11)
            
            return "+\(cleaned[index0..<index1]) (\(cleaned[index1..<index4])) \(cleaned[index4..<index7])-\(cleaned[index7..<index9])-\(cleaned[index9..<index11])"
        }
        return customerPhone
    }
}

// MARK: - Delivery Status

/// Статус доставки
enum DeliveryStatus: String, CaseIterable, Codable {
    case pending = "Ожидает доставки"
    case inTransit = "В пути"
    case arrived = "Курьер прибыл"
    case awaitingCode = "Ожидает код"
    case confirmed = "Доставлено"
    case failed = "Не доставлено"
    case cancelled = "Отменено"
    
    var color: String {
        switch self {
        case .pending:
            return "gray"
        case .inTransit:
            return "blue"
        case .arrived:
            return "orange"
        case .awaitingCode:
            return "yellow"
        case .confirmed:
            return "green"
        case .failed:
            return "red"
        case .cancelled:
            return "red"
        }
    }
    
    var iconName: String {
        switch self {
        case .pending:
            return "clock"
        case .inTransit:
            return "truck.box"
        case .arrived:
            return "location.circle"
        case .awaitingCode:
            return "lock.circle"
        case .confirmed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle"
        case .cancelled:
            return "xmark.octagon"
        }
    }
}

// MARK: - SMS Code Model

/// Модель SMS кода
struct SMSCode: Codable {
    let code: String
    let orderId: String
    let sentAt: Date
    let expiresAt: Date
    let phoneNumber: String
    
    var isExpired: Bool {
        return Date() > expiresAt
    }
    
    var formattedCode: String {
        // Форматируем код для удобного отображения (например: 123-456)
        if code.count == 6 {
            let index3 = code.index(code.startIndex, offsetBy: 3)
            return "\(code[..<index3])-\(code[index3...])"
        }
        return code
    }
}

// MARK: - Firestore Extensions

extension DeliveryConfirmation {
    
    /// Создание из Firestore документа
    static func fromFirestore(_ data: [String: Any], id: String) -> DeliveryConfirmation? {
        guard
            let orderId = data["orderId"] as? String,
            let trackingNumber = data["trackingNumber"] as? String,
            let courierId = data["courierId"] as? String,
            let courierName = data["courierName"] as? String,
            let customerPhone = data["customerPhone"] as? String,
            let deliveryAddress = data["deliveryAddress"] as? String,
            let smsCodeRequested = data["smsCodeRequested"] as? Bool,
            let statusRaw = data["status"] as? String,
            let status = DeliveryStatus(rawValue: statusRaw),
            let attemptCount = data["attemptCount"] as? Int,
            let maxAttempts = data["maxAttempts"] as? Int,
            let createdAtTimestamp = data["createdAt"] as? Timestamp,
            let updatedAtTimestamp = data["updatedAt"] as? Timestamp
        else { return nil }
        
        return DeliveryConfirmation(
            id: id,
            orderId: orderId,
            trackingNumber: trackingNumber,
            courierId: courierId,
            courierName: courierName,
            customerPhone: customerPhone,
            deliveryAddress: deliveryAddress,
            smsCodeRequested: smsCodeRequested,
            smsCodeRequestedAt: (data["smsCodeRequestedAt"] as? Timestamp)?.dateValue(),
            confirmationCode: data["confirmationCode"] as? String,
            codeExpiresAt: (data["codeExpiresAt"] as? Timestamp)?.dateValue(),
            status: status,
            confirmedAt: (data["confirmedAt"] as? Timestamp)?.dateValue(),
            confirmedBy: data["confirmedBy"] as? String,
            attemptCount: attemptCount,
            maxAttempts: maxAttempts,
            createdAt: createdAtTimestamp.dateValue(),
            updatedAt: updatedAtTimestamp.dateValue()
        )
    }
    
    /// Конвертация в Dictionary для Firestore
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "orderId": orderId,
            "trackingNumber": trackingNumber,
            "courierId": courierId,
            "courierName": courierName,
            "customerPhone": customerPhone,
            "deliveryAddress": deliveryAddress,
            "smsCodeRequested": smsCodeRequested,
            "status": status.rawValue,
            "attemptCount": attemptCount,
            "maxAttempts": maxAttempts,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt)
        ]
        
        if let smsCodeRequestedAt = smsCodeRequestedAt {
            dict["smsCodeRequestedAt"] = Timestamp(date: smsCodeRequestedAt)
        }
        
        if let confirmationCode = confirmationCode {
            dict["confirmationCode"] = confirmationCode
        }
        
        if let codeExpiresAt = codeExpiresAt {
            dict["codeExpiresAt"] = Timestamp(date: codeExpiresAt)
        }
        
        if let confirmedAt = confirmedAt {
            dict["confirmedAt"] = Timestamp(date: confirmedAt)
        }
        
        if let confirmedBy = confirmedBy {
            dict["confirmedBy"] = confirmedBy
        }
        
        return dict
    }
}

// MARK: - Delivery History

/// История доставки
struct DeliveryHistory: Identifiable, Codable {
    let id: String
    let deliveryId: String
    let action: DeliveryAction
    let performedBy: String
    let performedByRole: String
    let timestamp: Date
    let details: String?
    let location: GeoPoint?
}

/// Действия в истории доставки
enum DeliveryAction: String, CaseIterable, Codable {
    case created = "Создана доставка"
    case assigned = "Назначен курьер"
    case started = "Начата доставка"
    case arrived = "Прибыл к клиенту"
    case codeRequested = "Запрошен код"
    case codeEntered = "Введен код"
    case delivered = "Доставлено"
    case failed = "Не доставлено"
    case rescheduled = "Перенесено"
    
    var iconName: String {
        switch self {
        case .created:
            return "doc.badge.plus"
        case .assigned:
            return "person.badge.plus"
        case .started:
            return "play.circle"
        case .arrived:
            return "mappin.circle"
        case .codeRequested:
            return "envelope.circle"
        case .codeEntered:
            return "keyboard"
        case .delivered:
            return "checkmark.seal.fill"
        case .failed:
            return "xmark.seal"
        case .rescheduled:
            return "calendar.badge.clock"
        }
    }
}

// MARK: - Helper Extensions

extension DeliveryConfirmation {
    
    /// Создать новое подтверждение доставки из заказа
    static func createFromOrder(_ order: Order, courierId: String, courierName: String) -> DeliveryConfirmation {
        return DeliveryConfirmation(
            id: UUID().uuidString,
            orderId: order.id,
            trackingNumber: order.orderNumber,
            courierId: courierId,
            courierName: courierName,
            customerPhone: "", // Должен быть заполнен из данных клиента
            deliveryAddress: order.warehouseName, // Временно используем склад
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
    }
    
    /// Обновить статус
    func updatingStatus(_ newStatus: DeliveryStatus) -> DeliveryConfirmation {
        var updated = self
        updated.status = newStatus
        updated.updatedAt = Date()
        return updated
    }
    
    /// Установить код подтверждения
    func withConfirmationCode(_ code: String) -> DeliveryConfirmation {
        var updated = self
        updated.confirmationCode = code
        updated.smsCodeRequested = true
        updated.smsCodeRequestedAt = Date()
        updated.codeExpiresAt = Calendar.current.date(byAdding: .minute, value: 10, to: Date())
        updated.updatedAt = Date()
        return updated
    }
    
    /// Увеличить счетчик попыток
    func incrementAttempts() -> DeliveryConfirmation {
        var updated = self
        updated.attemptCount += 1
        updated.updatedAt = Date()
        return updated
    }
    
    /// Подтвердить доставку
    func confirm(by userId: String) -> DeliveryConfirmation {
        var updated = self
        updated.status = .confirmed
        updated.confirmedAt = Date()
        updated.confirmedBy = userId
        updated.updatedAt = Date()
        return updated
    }
}
