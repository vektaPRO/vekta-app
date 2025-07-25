//
//  NetworkError.swift
//  vektaApp
//
//  Централизованная обработка сетевых ошибок
//

import Foundation

// MARK: - Network Errors

/// Основные сетевые ошибки приложения
public enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(String)
    case serverError(Int, String?)
    case unauthorized
    case rateLimited
    case invalidResponse
    case networkError(Error)
    case timeout
    case noInternetConnection
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Некорректный URL адрес"
        case .noData:
            return "Нет данных от сервера"
        case .decodingError(let message):
            return "Ошибка декодирования: \(message)"
        case .serverError(let code, let message):
            return "Ошибка сервера \(code): \(message ?? "Неизвестная ошибка")"
        case .unauthorized:
            return "Необходима авторизация"
        case .rateLimited:
            return "Превышен лимит запросов"
        case .networkError(let error):
            return "Сетевая ошибка: \(error.localizedDescription)"
        case .invalidResponse:
            return "Некорректный ответ от сервера"
        case .timeout:
            return "Превышено время ожидания ответа"
        case .noInternetConnection:
            return "Нет подключения к интернету"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .invalidURL:
            return "URL не может быть обработан"
        case .noData:
            return "Сервер не вернул данные"
        case .decodingError:
            return "Не удалось разобрать ответ сервера"
        case .serverError(let code, _):
            return "Сервер вернул ошибку с кодом \(code)"
        case .unauthorized:
            return "Токен авторизации недействителен или отсутствует"
        case .rateLimited:
            return "Слишком много запросов за короткий период"
        case .networkError:
            return "Проблема с сетевым соединением"
        case .invalidResponse:
            return "Сервер вернул неожиданный формат данных"
        case .timeout:
            return "Сервер не отвечает в течение установленного времени"
        case .noInternetConnection:
            return "Устройство не подключено к интернету"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .invalidURL:
            return "Проверьте правильность адреса запроса"
        case .noData:
            return "Попробуйте повторить запрос позже"
        case .decodingError:
            return "Обратитесь к разработчику, если проблема повторяется"
        case .serverError(let code, _) where code >= 500:
            return "Попробуйте повторить запрос позже"
        case .serverError:
            return "Проверьте корректность отправляемых данных"
        case .unauthorized:
            return "Войдите в систему заново"
        case .rateLimited:
            return "Подождите немного перед следующим запросом"
        case .networkError, .noInternetConnection:
            return "Проверьте подключение к интернету"
        case .invalidResponse:
            return "Попробуйте повторить запрос"
        case .timeout:
            return "Проверьте подключение к интернету и повторите попытку"
        }
    }
    
    /// HTTP статус код ошибки (если есть)
    public var statusCode: Int? {
        if case .serverError(let code, _) = self {
            return code
        }
        return nil
    }
    
    /// Нужна ли повторная попытка для этой ошибки
    public var shouldRetry: Bool {
        switch self {
        case .timeout, .networkError, .noInternetConnection:
            return true
        case .serverError(let code, _) where code >= 500:
            return true
        case .rateLimited:
            return true // с задержкой
        default:
            return false
        }
    }
    
    /// Задержка перед повторной попыткой (в секундах)
    public var retryDelay: TimeInterval {
        switch self {
        case .rateLimited:
            return 60.0 // 1 минута
        case .timeout:
            return 5.0
        case .networkError, .noInternetConnection:
            return 3.0
        case .serverError:
            return 10.0
        default:
            return 1.0
        }
    }
}

// MARK: - Kaspi API Errors

/// Специфичные ошибки Kaspi API
public enum KaspiAPIError: LocalizedError {
    case tokenNotFound
    case invalidToken
    case merchantNotFound
    case productNotFound
    case orderNotFound
    case syncFailed(String)
    case smsCodeError(String)
    case stockUpdateError(String)
    case deliveryConfirmationFailed(String)
    case authenticationFailed
    case apiQuotaExceeded
    case invalidProductData
    case warehouseNotFound
    case underlying(NetworkError)
    
    public var errorDescription: String? {
        switch self {
        case .tokenNotFound:
            return "API токен не найден. Пожалуйста, добавьте токен в настройках."
        case .invalidToken:
            return "Неверный API токен. Проверьте правильность токена."
        case .merchantNotFound:
            return "Продавец не найден в системе Kaspi"
        case .productNotFound:
            return "Товар не найден"
        case .orderNotFound:
            return "Заказ не найден"
        case .syncFailed(let message):
            return "Ошибка синхронизации: \(message)"
        case .smsCodeError(let message):
            return "Ошибка отправки SMS кода: \(message)"
        case .stockUpdateError(let message):
            return "Ошибка обновления остатков: \(message)"
        case .deliveryConfirmationFailed(let message):
            return "Ошибка подтверждения доставки: \(message)"
        case .authenticationFailed:
            return "Ошибка аутентификации. Проверьте ваш API токен."
        case .apiQuotaExceeded:
            return "Превышен лимит запросов к API. Попробуйте позже."
        case .invalidProductData:
            return "Некорректные данные товара"
        case .warehouseNotFound:
            return "Склад не найден"
        case .underlying(let networkError):
            return networkError.errorDescription
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .tokenNotFound:
            return "Отсутствует API токен для доступа к Kaspi"
        case .invalidToken:
            return "Предоставленный токен недействителен"
        case .merchantNotFound:
            return "Учетная запись продавца не активна"
        case .underlying(let networkError):
            return networkError.failureReason
        default:
            return errorDescription
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .tokenNotFound, .invalidToken:
            return "Перейдите в настройки и добавьте действительный API токен"
        case .merchantNotFound:
            return "Обратитесь в службу поддержки Kaspi"
        case .syncFailed, .stockUpdateError:
            return "Попробуйте повторить операцию позже"
        case .smsCodeError:
            return "Проверьте номер телефона и попробуйте снова"
        case .apiQuotaExceeded:
            return "Подождите перед следующим запросом"
        case .underlying(let networkError):
            return networkError.recoverySuggestion
        default:
            return "Попробуйте повторить операцию"
        }
    }
    
    /// Можно ли повторить операцию
    public var canRetry: Bool {
        switch self {
        case .tokenNotFound, .invalidToken, .merchantNotFound:
            return false
        case .apiQuotaExceeded:
            return true
        case .underlying(let networkError):
            return networkError.shouldRetry
        default:
            return true
        }
    }
}

// MARK: - Firebase Errors

/// Ошибки Firebase операций
public enum FirebaseError: LocalizedError {
    case userNotAuthenticated
    case documentNotFound
    case permissionDenied
    case networkError
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "Пользователь не авторизован"
        case .documentNotFound:
            return "Документ не найден"
        case .permissionDenied:
            return "Недостаточно прав доступа"
        case .networkError:
            return "Ошибка подключения к Firebase"
        case .unknown(let error):
            return "Ошибка Firebase: \(error.localizedDescription)"
        }
    }
}

// MARK: - Application Errors

/// Общие ошибки приложения
public enum AppError: LocalizedError {
    case invalidInput(String)
    case dataCorrupted
    case featureUnavailable
    case configurationError
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidInput(let field):
            return "Некорректные данные в поле: \(field)"
        case .dataCorrupted:
            return "Данные повреждены"
        case .featureUnavailable:
            return "Функция временно недоступна"
        case .configurationError:
            return "Ошибка конфигурации приложения"
        case .unknown(let error):
            return "Неизвестная ошибка: \(error.localizedDescription)"
        }
    }
}

// MARK: - Circuit Breaker Error

/// Ошибка Circuit Breaker
public enum CircuitBreakerError: LocalizedError {
    case circuitOpen
    case configurationError
    
    public var errorDescription: String? {
        switch self {
        case .circuitOpen:
            return "Сервис временно недоступен. Попробуйте позже."
        case .configurationError:
            return "Ошибка конфигурации Circuit Breaker"
        }
    }
}

// MARK: - Error Extensions

extension NetworkError {
    /// Создать NetworkError из стандартной ошибки
    public static func from(_ error: Error) -> NetworkError {
        if let networkError = error as? NetworkError {
            return networkError
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .noInternetConnection
            case .timedOut:
                return .timeout
            case .cannotFindHost, .cannotConnectToHost:
                return .networkError(urlError)
            default:
                return .networkError(urlError)
            }
        }
        
        return .networkError(error)
    }
    
    /// Создать NetworkError из HTTP ответа
    public static func fromHTTPResponse(statusCode: Int, data: Data?) -> NetworkError {
        switch statusCode {
        case 400:
            return .serverError(statusCode, "Некорректный запрос")
        case 401:
            return .unauthorized
        case 403:
            return .serverError(statusCode, "Доступ запрещен")
        case 404:
            return .serverError(statusCode, "Не найдено")
        case 429:
            return .rateLimited
        case 500...599:
            return .serverError(statusCode, "Внутренняя ошибка сервера")
        default:
            return .serverError(statusCode, "HTTP ошибка \(statusCode)")
        }
    }
}

extension KaspiAPIError {
    /// Создать KaspiAPIError из NetworkError
    public static func from(_ networkError: NetworkError) -> KaspiAPIError {
        switch networkError {
        case .unauthorized:
            return .invalidToken
        case .rateLimited:
            return .apiQuotaExceeded
        default:
            return .underlying(networkError)
        }
    }
}

// MARK: - Error Handler

/// Централизованный обработчик ошибок
public class ErrorHandler {
    
    /// Обработать и логировать ошибку
    public static func handle(_ error: Error, context: String = "") {
        let errorInfo = ErrorInfo.from(error)
        
        // Логирование
        print("🚨 Error in \(context): \(errorInfo.title)")
        print("📝 Description: \(errorInfo.description)")
        if let suggestion = errorInfo.suggestion {
            print("💡 Suggestion: \(suggestion)")
        }
        
        // Здесь можно добавить отправку в crashlytics или другую систему аналитики
        // Crashlytics.record(error)
    }
    
    /// Получить пользовательское сообщение об ошибке
    public static func userMessage(for error: Error) -> String {
        return ErrorInfo.from(error).userMessage
    }
    
    /// Определить нужна ли повторная попытка
    public static func shouldRetry(_ error: Error) -> Bool {
        if let networkError = error as? NetworkError {
            return networkError.shouldRetry
        }
        if let kaspiError = error as? KaspiAPIError {
            return kaspiError.canRetry
        }
        return false
    }
    
    /// Получить задержку для повторной попытки
    public static func retryDelay(for error: Error) -> TimeInterval {
        if let networkError = error as? NetworkError {
            return networkError.retryDelay
        }
        return 1.0
    }
}

// MARK: - Error Info

/// Информация об ошибке для отображения пользователю
public struct ErrorInfo {
    let title: String
    let description: String
    let suggestion: String?
    let userMessage: String
    let canRetry: Bool
    
    static func from(_ error: Error) -> ErrorInfo {
        if let networkError = error as? NetworkError {
            return ErrorInfo(
                title: "Сетевая ошибка",
                description: networkError.errorDescription ?? "Неизвестная сетевая ошибка",
                suggestion: networkError.recoverySuggestion,
                userMessage: networkError.errorDescription ?? "Проблема с подключением",
                canRetry: networkError.shouldRetry
            )
        }
        
        if let kaspiError = error as? KaspiAPIError {
            return ErrorInfo(
                title: "Ошибка Kaspi API",
                description: kaspiError.errorDescription ?? "Ошибка API",
                suggestion: kaspiError.recoverySuggestion,
                userMessage: kaspiError.errorDescription ?? "Проблема с API",
                canRetry: kaspiError.canRetry
            )
        }
        
        if let firebaseError = error as? FirebaseError {
            return ErrorInfo(
                title: "Ошибка Firebase",
                description: firebaseError.errorDescription ?? "Ошибка базы данных",
                suggestion: "Попробуйте перезапустить приложение",
                userMessage: firebaseError.errorDescription ?? "Проблема с сервером",
                canRetry: true
            )
        }
        
        if let appError = error as? AppError {
            return ErrorInfo(
                title: "Ошибка приложения",
                description: appError.errorDescription ?? "Ошибка приложения",
                suggestion: "Обратитесь к разработчику",
                userMessage: appError.errorDescription ?? "Что-то пошло не так",
                canRetry: false
            )
        }
        
        return ErrorInfo(
            title: "Неизвестная ошибка",
            description: error.localizedDescription,
            suggestion: "Попробуйте перезапустить приложение",
            userMessage: "Произошла ошибка. Попробуйте еще раз.",
            canRetry: true
        )
    }
}
