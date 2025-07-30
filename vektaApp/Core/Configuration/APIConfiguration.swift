//
//  APIConfiguration.swift
//  vektaApp
//
//  Конфигурация для работы с различными API окружениями
//

import Foundation
import UIKit
// MARK: - API Environment

enum APIEnvironment {
    case development
    case staging
    case production
    
    var baseURL: String {
        switch self {
        case .development:
            return "https://sandbox.kaspi.kz/merchantcabinet/api/v1"
        case .staging:
            return "https://staging.kaspi.kz/merchantcabinet/api/v1"
        case .production:
            return "https://kaspi.kz/merchantcabinet/api/v1"
        }
    }
    
    var timeout: TimeInterval {
        switch self {
        case .development:
            return 60.0
        case .staging:
            return 45.0
        case .production:
            return 30.0
        }
    }
    
    var maxRetries: Int {
        switch self {
        case .development:
            return 5
        case .staging:
            return 3
        case .production:
            return 3
        }
    }
}

// MARK: - API Configuration

class APIConfiguration {
    
    static let shared = APIConfiguration()
    
    // Текущее окружение
    #if DEBUG
    private(set) var environment: APIEnvironment = .development
    #else
    private(set) var environment: APIEnvironment = .production
    #endif
    
    // API ключи (загружаются динамически для каждого продавца)
    // Эти значения НЕ используются для продавцов - каждый продавец имеет свой токен
    var kaspiAPIKey: String? {
        // Только для внутреннего использования приложением (если нужно)
        return nil
    }
    
    var kaspiMerchantId: String? {
        // Merchant ID будет загружаться из профиля продавца
        return nil
    }
    
    // Rate limiting
    let maxRequestsPerMinute = 60
    let maxRequestsPerHour = 1000
    
    // SMS Configuration
    let smsCodeLength = 6
    let smsCodeExpirationMinutes = 10
    let maxSMSAttempts = 3
    let smsResendCooldownSeconds = 120
    
    // Pagination
    let defaultPageSize = 50
    let maxPageSize = 100
    
    // Cache settings
    let cacheExpirationHours = 4
    let maxCacheSize = 100 // MB
    
    private init() {}
    
    // MARK: - Methods
    
    /// Изменить окружение (только для DEBUG)
    func setEnvironment(_ environment: APIEnvironment) {
        #if DEBUG
        self.environment = environment
        print("🔧 API Environment changed to: \(environment)")
        #endif
    }
    
    /// Получить полный URL для эндпоинта
    func fullURL(for endpoint: String) -> String {
        return environment.baseURL + endpoint
    }
    
    /// Проверить валидность конфигурации
    func validateConfiguration() -> Bool {
        // Больше не проверяем Info.plist
        // Конфигурация всегда валидна, токены проверяются для каждого продавца отдельно
        return true
    }
}

// MARK: - API Headers Builder

extension APIConfiguration {
    
    /// Построить стандартные заголовки для запроса
    func buildHeaders(
        apiToken: String? = nil,
        contentType: String = "application/json",
        additionalHeaders: [String: String]? = nil
    ) -> [String: String] {
        
        var headers: [String: String] = [
            "Accept": "application/json",
            "Content-Type": contentType,
            "User-Agent": userAgent,
            "X-Client-Version": appVersion,
            "X-Platform": "iOS",
            "X-Device-ID": deviceId
        ]
        
        // Добавляем API токен если есть
        if let token = apiToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        
        // Добавляем merchant ID если есть
        if let merchantId = kaspiMerchantId {
            headers["X-Merchant-ID"] = merchantId
        }
        
        // Добавляем дополнительные заголовки
        if let additional = additionalHeaders {
            headers.merge(additional) { _, new in new }
        }
        
        return headers
    }
    
    private var userAgent: String {
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "VektaApp"
        let appVersion = self.appVersion
        let osVersion = UIDevice.current.systemVersion
        return "\(appName)/\(appVersion) iOS/\(osVersion)"
    }
    
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    private var deviceId: String {
        // Используем идентификатор для вендора как уникальный ID устройства
        return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }
}

// MARK: - Error Messages

extension APIConfiguration {
    
    /// Локализованные сообщения об ошибках
    enum ErrorMessage {
        static let noInternet = "Нет подключения к интернету"
        static let serverError = "Ошибка сервера. Попробуйте позже"
        static let unauthorized = "Необходима авторизация"
        static let forbidden = "Доступ запрещен"
        static let notFound = "Данные не найдены"
        static let rateLimited = "Слишком много запросов. Подождите немного"
        static let invalidData = "Получены некорректные данные"
        static let timeout = "Превышено время ожидания ответа"
        static let unknown = "Произошла неизвестная ошибка"
    }
    
    /// Получить сообщение об ошибке по коду HTTP
    static func errorMessage(for statusCode: Int) -> String {
        switch statusCode {
        case 400:
            return "Некорректный запрос"
        case 401:
            return ErrorMessage.unauthorized
        case 403:
            return ErrorMessage.forbidden
        case 404:
            return ErrorMessage.notFound
        case 429:
            return ErrorMessage.rateLimited
        case 500...599:
            return ErrorMessage.serverError
        default:
            return ErrorMessage.unknown
        }
    }
}
