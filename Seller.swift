//
//  Seller.swift
//  vektaApp
//
//  Модель продавца с API конфигурацией
//

import Foundation
import FirebaseFirestore

// MARK: - Seller Model

struct Seller: Identifiable, Codable {
    let id: String                    // Firebase UID
    let email: String
    let businessName: String?
    let phone: String?
    
    // Kaspi API Configuration
    var kaspiApiToken: String?
    var kaspiMerchantId: String?
    var kaspiMerchantName: String?
    var kaspiApiEnabled: Bool
    
    // API Statistics
    var lastApiSync: Date?
    var totalApiRequests: Int
    var apiRequestsToday: Int
    var lastApiError: String?
    
    // Subscription/Limits
    var subscriptionPlan: SubscriptionPlan
    var apiRateLimit: Int             // Requests per hour
    var monthlyApiCalls: Int
    var monthlyApiLimit: Int
    
    // Metadata
    let createdAt: Date
    var updatedAt: Date
    var isActive: Bool
    
    // Computed Properties
    var hasValidApiToken: Bool {
        return kaspiApiToken != nil && !kaspiApiToken!.isEmpty
    }
    
    var canMakeApiRequest: Bool {
        return hasValidApiToken && kaspiApiEnabled && apiRequestsToday < apiRateLimit
    }
    
    var apiUsagePercentage: Double {
        guard monthlyApiLimit > 0 else { return 0 }
        return Double(monthlyApiCalls) / Double(monthlyApiLimit) * 100
    }
}

// MARK: - Subscription Plan

enum SubscriptionPlan: String, Codable, CaseIterable {
    case free = "Free"
    case basic = "Basic"
    case professional = "Professional"
    case enterprise = "Enterprise"
    
    var apiRequestsPerHour: Int {
        switch self {
        case .free: return 10
        case .basic: return 60
        case .professional: return 300
        case .enterprise: return 1000
        }
    }
    
    var monthlyApiCalls: Int {
        switch self {
        case .free: return 1000
        case .basic: return 10000
        case .professional: return 100000
        case .enterprise: return -1 // Unlimited
        }
    }
    
    var features: [String] {
        switch self {
        case .free:
            return ["10 API запросов/час", "1,000 запросов/месяц", "Базовая синхронизация"]
        case .basic:
            return ["60 API запросов/час", "10,000 запросов/месяц", "Автоматическая синхронизация", "SMS уведомления"]
        case .professional:
            return ["300 API запросов/час", "100,000 запросов/месяц", "Приоритетная поддержка", "Расширенная аналитика"]
        case .enterprise:
            return ["Без лимитов", "Выделенный сервер", "24/7 поддержка", "Кастомная интеграция"]
        }
    }
}

// MARK: - Firestore Extensions

extension Seller {
    
    /// Создание из Firestore документа
    static func fromFirestore(_ data: [String: Any], id: String) -> Seller? {
        guard
            let email = data["email"] as? String,
            let kaspiApiEnabled = data["kaspiApiEnabled"] as? Bool,
            let totalApiRequests = data["totalApiRequests"] as? Int,
            let apiRequestsToday = data["apiRequestsToday"] as? Int,
            let apiRateLimit = data["apiRateLimit"] as? Int,
            let monthlyApiCalls = data["monthlyApiCalls"] as? Int,
            let monthlyApiLimit = data["monthlyApiLimit"] as? Int,
            let subscriptionPlanRaw = data["subscriptionPlan"] as? String,
            let subscriptionPlan = SubscriptionPlan(rawValue: subscriptionPlanRaw),
            let createdAtTimestamp = data["createdAt"] as? Timestamp,
            let updatedAtTimestamp = data["updatedAt"] as? Timestamp,
            let isActive = data["isActive"] as? Bool
        else { return nil }
        
        return Seller(
            id: id,
            email: email,
            businessName: data["businessName"] as? String,
            phone: data["phone"] as? String,
            kaspiApiToken: data["kaspiApiToken"] as? String,
            kaspiMerchantId: data["kaspiMerchantId"] as? String,
            kaspiMerchantName: data["kaspiMerchantName"] as? String,
            kaspiApiEnabled: kaspiApiEnabled,
            lastApiSync: (data["lastApiSync"] as? Timestamp)?.dateValue(),
            totalApiRequests: totalApiRequests,
            apiRequestsToday: apiRequestsToday,
            lastApiError: data["lastApiError"] as? String,
            subscriptionPlan: subscriptionPlan,
            apiRateLimit: apiRateLimit,
            monthlyApiCalls: monthlyApiCalls,
            monthlyApiLimit: monthlyApiLimit,
            createdAt: createdAtTimestamp.dateValue(),
            updatedAt: updatedAtTimestamp.dateValue(),
            isActive: isActive
        )
    }
    
    /// Конвертация в Dictionary для Firestore
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "email": email,
            "kaspiApiEnabled": kaspiApiEnabled,
            "totalApiRequests": totalApiRequests,
            "apiRequestsToday": apiRequestsToday,
            "subscriptionPlan": subscriptionPlan.rawValue,
            "apiRateLimit": apiRateLimit,
            "monthlyApiCalls": monthlyApiCalls,
            "monthlyApiLimit": monthlyApiLimit,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "isActive": isActive
        ]
        
        // Optional fields
        if let businessName = businessName {
            dict["businessName"] = businessName
        }
        if let phone = phone {
            dict["phone"] = phone
        }
        if let kaspiApiToken = kaspiApiToken {
            dict["kaspiApiToken"] = kaspiApiToken
        }
        if let kaspiMerchantId = kaspiMerchantId {
            dict["kaspiMerchantId"] = kaspiMerchantId
        }
        if let kaspiMerchantName = kaspiMerchantName {
            dict["kaspiMerchantName"] = kaspiMerchantName
        }
        if let lastApiSync = lastApiSync {
            dict["lastApiSync"] = Timestamp(date: lastApiSync)
        }
        if let lastApiError = lastApiError {
            dict["lastApiError"] = lastApiError
        }
        
        return dict
    }
}

// MARK: - Default Seller

extension Seller {
    
    /// Создать нового продавца с дефолтными настройками
    static func createNew(id: String, email: String) -> Seller {
        return Seller(
            id: id,
            email: email,
            businessName: nil,
            phone: nil,
            kaspiApiToken: nil,
            kaspiMerchantId: nil,
            kaspiMerchantName: nil,
            kaspiApiEnabled: false,
            lastApiSync: nil,
            totalApiRequests: 0,
            apiRequestsToday: 0,
            lastApiError: nil,
            subscriptionPlan: .free,
            apiRateLimit: SubscriptionPlan.free.apiRequestsPerHour,
            monthlyApiCalls: 0,
            monthlyApiLimit: SubscriptionPlan.free.monthlyApiCalls,
            createdAt: Date(),
            updatedAt: Date(),
            isActive: true
        )
    }
}
