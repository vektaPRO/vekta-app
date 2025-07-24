//
//  NetworkManager.swift
//  vektaApp
//
//  Базовый менеджер для работы с сетевыми запросами
//

import Foundation

// MARK: - Network Errors

enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(String)
    case serverError(Int, String?)
    case unauthorized
    case rateLimited
    case networkError(Error)
    case invalidResponse
    
    var errorDescription: String? {
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
        }
    }
}

// MARK: - HTTP Method

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - Network Manager

class NetworkManager {
    
    static let shared = NetworkManager()
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let retryManager = RetryManager.shared
    private let circuitBreaker = CircuitBreaker()
    private let config = APIConfiguration.shared
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = config.environment.timeout
        configuration.timeoutIntervalForResource = config.environment.timeout
        configuration.httpAdditionalHeaders = [
            "Accept": "application/json",
            "Content-Type": "application/json"
        ]
        
        self.session = URLSession(configuration: configuration)
        
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601
        
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder.dateEncodingStrategy = .iso8601
    }
    
    // MARK: - Generic Request Method
    
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        body: Encodable? = nil,
        headers: [String: String]? = nil,
        apiToken: String? = nil,
        retryPolicy: RetryPolicy? = nil
    ) async throws -> T {
        
        // Используем circuit breaker и retry manager
        return try await circuitBreaker.execute {
            try await retryManager.perform(
                operation: {
                    try await self.performRequest(
                        endpoint: endpoint,
                        method: method,
                        parameters: parameters,
                        body: body,
                        headers: headers,
                        apiToken: apiToken
                    )
                },
                policy: retryPolicy ?? .default
            )
        }
    }
    
    private func performRequest<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        body: Encodable? = nil,
        headers: [String: String]? = nil,
        apiToken: String? = nil
    ) async throws -> T {
        
        // Build URL
        guard var urlComponents = URLComponents(string: config.environment.baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }
        
        // Add query parameters for GET requests
        if method == .get, let parameters = parameters {
            urlComponents.queryItems = parameters.map {
                URLQueryItem(name: $0.key, value: "\($0.value)")
            }
        }
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        // Add headers using configuration
        let configHeaders = config.buildHeaders(
            apiToken: apiToken,
            additionalHeaders: headers
        )
        configHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        
        // Add body for POST/PUT/PATCH
        if method != .get {
            if let body = body {
                request.httpBody = try encoder.encode(body)
            } else if let parameters = parameters {
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
            }
        }
        
        // Log request (только в DEBUG)
        #if DEBUG
        print("🌐 Request: \(method.rawValue) \(url)")
        if let headers = request.allHTTPHeaderFields {
            print("📋 Headers: \(headers)")
        }
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("📦 Body: \(bodyString)")
        }
        #endif
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Log response
            #if DEBUG
            print("✅ Response: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Data: \(responseString)")
            }
            #endif
            
            // Check status code
            switch httpResponse.statusCode {
            case 200...299:
                // Success
                do {
                    return try decoder.decode(T.self, from: data)
                } catch {
                    // Try to decode error message
                    if let errorResponse = try? decoder.decode(KaspiErrorResponse.self, from: data) {
                        throw NetworkError.serverError(httpResponse.statusCode, errorResponse.message)
                    }
                    throw NetworkError.decodingError(error.localizedDescription)
                }
                
            case 401:
                throw NetworkError.unauthorized
                
            case 429:
                throw NetworkError.rateLimited
                
            default:
                // Try to decode error message
                if let errorResponse = try? decoder.decode(KaspiErrorResponse.self, from: data) {
                    throw NetworkError.serverError(httpResponse.statusCode, errorResponse.message)
                }
                throw NetworkError.serverError(httpResponse.statusCode, nil)
            }
            
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.networkError(error)
        }
    }
    
    // MARK: - Convenience Methods
    
    func get<T: Decodable>(
        endpoint: String,
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil,
        apiToken: String? = nil,
        retryPolicy: RetryPolicy? = nil
    ) async throws -> T {
        return try await request(
            endpoint: endpoint,
            method: .get,
            parameters: parameters,
            headers: headers,
            apiToken: apiToken,
            retryPolicy: retryPolicy
        )
    }
    
    func post<T: Decodable>(
        endpoint: String,
        body: Encodable? = nil,
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil,
        apiToken: String? = nil,
        retryPolicy: RetryPolicy? = nil
    ) async throws -> T {
        return try await request(
            endpoint: endpoint,
            method: .post,
            parameters: parameters,
            body: body,
            headers: headers,
            apiToken: apiToken,
            retryPolicy: retryPolicy
        )
    }
    
    func put<T: Decodable>(
        endpoint: String,
        body: Encodable? = nil,
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil,
        apiToken: String? = nil,
        retryPolicy: RetryPolicy? = nil
    ) async throws -> T {
        return try await request(
            endpoint: endpoint,
            method: .put,
            parameters: parameters,
            body: body,
            headers: headers,
            apiToken: apiToken,
            retryPolicy: retryPolicy
        )
    }
    
    func patch<T: Decodable>(
        endpoint: String,
        body: Encodable? = nil,
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil,
        apiToken: String? = nil,
        retryPolicy: RetryPolicy? = nil
    ) async throws -> T {
        return try await request(
            endpoint: endpoint,
            method: .patch,
            parameters: parameters,
            body: body,
            headers: headers,
            apiToken: apiToken,
            retryPolicy: retryPolicy
        )
    }
    
    func delete<T: Decodable>(
        endpoint: String,
        headers: [String: String]? = nil,
        apiToken: String? = nil,
        retryPolicy: RetryPolicy? = nil
    ) async throws -> T {
        return try await request(
            endpoint: endpoint,
            method: .delete,
            headers: headers,
            apiToken: apiToken,
            retryPolicy: retryPolicy
        )
    }
}

// MARK: - Kaspi Error Response

struct KaspiErrorResponse: Codable {
    let error: String?
    let message: String?
    let code: String?
    let details: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case error
        case message
        case code
        case details
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        code = try container.decodeIfPresent(String.self, forKey: .code)
        
        // Handle dynamic details
        if let detailsData = try? container.decode([String: String].self, forKey: .details) {
            details = detailsData
        } else {
            details = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(error, forKey: .error)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(code, forKey: .code)
    }
}

// MARK: - Response Wrapper

struct KaspiResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: KaspiErrorResponse?
    let pagination: KaspiPagination?
}

// MARK: - Pagination

struct KaspiPagination: Codable {
    let page: Int
    let pageSize: Int
    let totalPages: Int
    let totalItems: Int
    
    enum CodingKeys: String, CodingKey {
        case page
        case pageSize = "page_size"
        case totalPages = "total_pages"
        case totalItems = "total_items"
    }
}
