//
//  KaspiAPIService.swift
//  vektaApp
//
//  Сервис-клиент для работы с Kaspi Seller API.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class KaspiAPIService: ObservableObject {
    // MARK: - Published
    @Published var apiToken: String?
    @Published var errorMessage: String?
    @Published var isLoading = false

    // MARK: - Private
    private let baseURL = URL(string: "https://kaspi.kz/shop/api/v2")!
    private let firestore = Firestore.firestore()
    private let session = URLSession.shared

    // MARK: - Init
    init() {
        Task { await loadApiToken() }
    }

    // MARK: - Загрузка токена из Firestore
    func loadApiToken() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "Пользователь не авторизован"
            return
        }
        do {
            let doc = try await firestore.collection("sellers").document(uid).getDocument()
            if let token = doc.get("kaspiApiToken") as? String {
                self.apiToken = token
            } else {
                errorMessage = "Kaspi API токен не найден"
            }
        } catch {
            errorMessage = "Ошибка загрузки токена: \(error.localizedDescription)"
        }
    }

    private func ensureToken() throws -> String {
        guard let token = apiToken, !token.isEmpty else {
            throw APIError.tokenMissing
        }
        return token
    }

    private func makeRequest(path: String,
                             method: String = "GET",
                             body: Data? = nil) throws -> URLRequest {
        let token = try ensureToken()
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "X-TOKEN")
        if let b = body {
            request.httpBody = b
        }
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest, decodeTo type: T.Type) async throws -> T {
        let (data, resp) = try await session.data(for: request)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.serverError
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Получение всех товаров
    func fetchAllProducts(page: Int = 0, size: Int = 50) async throws -> [KaspiProduct] {
        let path = "products?page=\(page)&size=\(size)"
        let req = try makeRequest(path: path)
        let resp = try await send(req, decodeTo: KaspiProductResponse.self)
        return resp.content
    }

    // MARK: - Позиция товара
    func fetchProductPosition(productId: String) async throws -> Int {
        let req = try makeRequest(path: "prices/product-position/\(productId)")
        let resp = try await send(req, decodeTo: ProductPositionResponse.self)
        return resp.position
    }

    // MARK: - Обновление цены
    func updatePrice(productId: String, newPrice: Int) async throws {
        let payload = try JSONEncoder().encode(
            [["productId": productId, "price": newPrice]]
        )
        let req = try makeRequest(path: "prices/change",
                                  method: "PATCH",
                                  body: payload)
        _ = try await session.data(for: req)
    }

    // MARK: - DTOs & Errors
    struct KaspiProductResponse: Codable { let content: [KaspiProduct] }
    struct KaspiProduct: Codable, Identifiable {
        let id: String        // code
        let name: String
        let shortDescription: String?
        let category: String
        let price: Double
        let stockCount: Int
        let isActive: Bool
        let images: [String]
        enum CodingKeys: String, CodingKey {
            case id = "code"
            case name, shortDescription, category, price, stockCount, isActive, images
        }
    }
    struct ProductPositionResponse: Codable { let position: Int }

    enum APIError: Error {
        case tokenMissing, serverError
    }
}
