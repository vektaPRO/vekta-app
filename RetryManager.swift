//
//  RetryManager.swift
//  vektaApp
//
//  Менеджер для обработки повторных попыток при сетевых ошибках
//

import Foundation

// MARK: - Retry Policy

struct RetryPolicy {
    let maxAttempts: Int
    let initialDelay: TimeInterval
    let maxDelay: TimeInterval
    let multiplier: Double
    let jitter: Bool
    
    static let `default` = RetryPolicy(
        maxAttempts: 3,
        initialDelay: 1.0,
        maxDelay: 60.0,
        multiplier: 2.0,
        jitter: true
    )
    
    static let aggressive = RetryPolicy(
        maxAttempts: 5,
        initialDelay: 0.5,
        maxDelay: 30.0,
        multiplier: 1.5,
        jitter: true
    )
    
    static let conservative = RetryPolicy(
        maxAttempts: 2,
        initialDelay: 2.0,
        maxDelay: 120.0,
        multiplier: 3.0,
        jitter: false
    )
}

// MARK: - Retry Manager

class RetryManager {
    
    static let shared = RetryManager()
    
    private init() {}
    
    /// Выполнить операцию с повторными попытками
    func perform<T>(
        operation: @escaping () async throws -> T,
        policy: RetryPolicy = .default,
        shouldRetry: ((Error, Int) -> Bool)? = nil
    ) async throws -> T {
        
        var lastError: Error?
        
        for attempt in 0..<policy.maxAttempts {
            do {
                // Пытаемся выполнить операцию
                return try await operation()
                
            } catch {
                lastError = error
                
                // Проверяем, нужно ли повторять
                let shouldRetryError = shouldRetry?(error, attempt) ?? shouldRetryDefault(error)
                
                if !shouldRetryError || attempt == policy.maxAttempts - 1 {
                    // Не повторяем или это была последняя попытка
                    throw error
                }
                
                // Вычисляем задержку
                let delay = calculateDelay(
                    attempt: attempt,
                    policy: policy
                )
                
                print("⚠️ Retry attempt \(attempt + 1)/\(policy.maxAttempts) after \(String(format: "%.2f", delay))s")
                
                // Ждем перед следующей попыткой
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // Если мы здесь, значит все попытки исчерпаны
        throw lastError ?? NetworkError.unknown
    }
    
    /// Вычислить задержку для повторной попытки
    private func calculateDelay(attempt: Int, policy: RetryPolicy) -> TimeInterval {
        // Экспоненциальная задержка
        var delay = policy.initialDelay * pow(policy.multiplier, Double(attempt))
        
        // Ограничиваем максимальной задержкой
        delay = min(delay, policy.maxDelay)
        
        // Добавляем случайный джиттер для избежания "thundering herd"
        if policy.jitter {
            let jitterRange = delay * 0.2
            let jitter = Double.random(in: -jitterRange...jitterRange)
            delay += jitter
        }
        
        return max(0, delay)
    }
    
    /// Определить, нужно ли повторять по умолчанию
    private func shouldRetryDefault(_ error: Error) -> Bool {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .networkError, .serverError(let code, _) where code >= 500:
                return true
            case .rateLimited:
                return true
            case .invalidResponse:
                return false
            default:
                return false
            }
        }
        
        // NSURLError
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotFindHost, .cannotConnectToHost,
                 .networkConnectionLost, .dnsLookupFailed:
                return true
            default:
                return false
            }
        }
        
        return false
    }
}

// MARK: - Circuit Breaker

/// Circuit Breaker для предотвращения лавинообразных отказов
class CircuitBreaker {
    
    enum State {
        case closed     // Нормальная работа
        case open       // Сервис недоступен
        case halfOpen   // Проверка восстановления
    }
    
    private var state: State = .closed
    private var failureCount = 0
    private var lastFailureTime: Date?
    private var successCount = 0
    
    private let failureThreshold: Int
    private let successThreshold: Int
    private let timeout: TimeInterval
    
    init(
        failureThreshold: Int = 5,
        successThreshold: Int = 2,
        timeout: TimeInterval = 60.0
    ) {
        self.failureThreshold = failureThreshold
        self.successThreshold = successThreshold
        self.timeout = timeout
    }
    
    /// Выполнить операцию через Circuit Breaker
    func execute<T>(_ operation: () async throws -> T) async throws -> T {
        switch state {
        case .open:
            // Проверяем, не пора ли перейти в half-open
            if let lastFailure = lastFailureTime,
               Date().timeIntervalSince(lastFailure) > timeout {
                state = .halfOpen
                successCount = 0
                print("🔄 Circuit Breaker: OPEN -> HALF-OPEN")
            } else {
                throw CircuitBreakerError.circuitOpen
            }
            
        case .halfOpen:
            // В состоянии half-open пробуем выполнить операцию
            break
            
        case .closed:
            // Нормальная работа
            break
        }
        
        do {
            let result = try await operation()
            recordSuccess()
            return result
        } catch {
            recordFailure()
            throw error
        }
    }
    
    private func recordSuccess() {
        failureCount = 0
        
        switch state {
        case .halfOpen:
            successCount += 1
            if successCount >= successThreshold {
                state = .closed
                print("✅ Circuit Breaker: HALF-OPEN -> CLOSED")
            }
        default:
            break
        }
    }
    
    private func recordFailure() {
        lastFailureTime = Date()
        
        switch state {
        case .closed:
            failureCount += 1
            if failureCount >= failureThreshold {
                state = .open
                print("❌ Circuit Breaker: CLOSED -> OPEN")
            }
            
        case .halfOpen:
            state = .open
            failureCount = 0
            print("❌ Circuit Breaker: HALF-OPEN -> OPEN")
            
        case .open:
            break
        }
    }
    
    /// Сбросить состояние Circuit Breaker
    func reset() {
        state = .closed
        failureCount = 0
        successCount = 0
        lastFailureTime = nil
    }
}

// MARK: - Circuit Breaker Error

enum CircuitBreakerError: LocalizedError {
    case circuitOpen
    
    var errorDescription: String? {
        switch self {
        case .circuitOpen:
            return "Сервис временно недоступен. Попробуйте позже."
        }
    }
}

// MARK: - Network Error Extension

enum NetworkError: LocalizedError {
    case unknown
    
    var errorDescription: String? {
        return "Неизвестная сетевая ошибка"
    }
}
