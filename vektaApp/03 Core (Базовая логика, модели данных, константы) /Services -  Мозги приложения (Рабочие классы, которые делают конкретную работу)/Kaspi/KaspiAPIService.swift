//
//  KaspiAPIService.swift
//  vektaApp
//
//  Полностью переработанный сервис интеграции с Kaspi API
//  Основан на рабочем Python-проекте dumping
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

// MARK: - Kaspi API Models

/// Ответ от API с товарами
struct KaspiProductResponse: Codable {
    let content: [KaspiProduct]
    let totalElements: Int
    let totalPages: Int
    let size: Int
    let number: Int
}

/// Модель товара из Kaspi API
struct KaspiProduct: Codable {
    let id: String
    let name: String
    let sku: String
    let price: Double
    let isActive: Bool
    let category: String?
    let imageUrl: String?
    let position: Int?
    
    enum CodingKeys: String, CodingKey {
        case id = "productId"
        case name = "productName"
        case sku = "sku"
        case price = "price"
        case isActive = "isActive"
        case category = "category"
        case imageUrl = "imageUrl"
        case position = "position"
    }
}

/// Ответ позиции товара
struct ProductPositionResponse: Codable {
    let productId: String
    let position: Int
    let totalProducts: Int
}

/// Запрос обновления цены
struct PriceUpdateRequest: Codable {
    let productId: String
    let price: Int
}

/// Модель для отслеживания истории цен
struct PriceHistory: Codable {
    let productId: String
    let oldPrice: Double
    let newPrice: Double
    let position: Int
    let timestamp: Date
    let reason: String
}

// MARK: - KaspiAPIService

@MainActor
class KaspiAPIService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastSyncDate: Date?
    @Published var syncProgress: Double = 0.0
    @Published var isAutoDumpingEnabled = false
    
    // MARK: - Private Properties
    
    private let db = Firestore.firestore()
    private var authListener: AuthStateDidChangeListenerHandle?
    private var autoDumpTimer: Timer?
    
    // Базовый URL для Kaspi API
    private let baseURL = "https://kaspi.kz/shop/api/v2"
    
    // Заголовки для запросов (из Python проекта)
    private var headers: [String: String] {
        var headers = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
        
        if let token = kaspiToken {
            headers["X-TOKEN"] = token
        }
        
        return headers
    }
    
    // X-TOKEN из cookies (должен быть установлен продавцом)
    @Published var apiToken: String? {
        didSet {
            if kaspiToken != nil {
                saveTokenToFirestore()
            }
        }
    }
    
    // MARK: - Initialization
    
    init() {
        print("🔧 KaspiAPIService инициализирован (новая версия)")
        setupAuthListener()
    }
    
    deinit {
        if let listener = authListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
        autoDumpTimer?.invalidate()
    }
    
    // MARK: - Authentication
    
    private func setupAuthListener() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if user != nil {
                    await self?.loadKaspiToken()
                } else {
                    self?.kaspiToken = nil
                }
            }
        }
    }
    
    /// Загрузить токен из Firestore
    func loadKaspiToken() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Нет авторизованного пользователя")
            errorMessage = "Пользователь не авторизован"
            return
        }
        
        do {
            let document = try await db.collection("sellers").document(userId).getDocument()
            
            if let data = document.data(),
               let token = data["kaspiToken"] as? String { // Изменено с kaspiApiToken
                kaspiToken = token
                errorMessage = nil
                print("✅ Kaspi токен (X-TOKEN) загружен")
            } else {
                print("⚠️ Kaspi токен не найден")
                kaspiToken = nil
                errorMessage = "Токен не найден. Получите X-TOKEN из cookies в Kaspi Seller Cabinet."
            }
        } catch {
            print("❌ Ошибка загрузки токена: \(error.localizedDescription)")
            errorMessage = "Ошибка загрузки токена"
        }
    }
    
    /// Сохранить токен в Firestore
    private func saveTokenToFirestore() {
        guard let userId = Auth.auth().currentUser?.uid,
              let token = kaspiToken else { return }
        
        Task {
            do {
                try await db.collection("sellers").document(userId).setData([
                    "kaspiToken": token,
                    "tokenUpdatedAt": FieldValue.serverTimestamp()
                ], merge: true)
                print("✅ Токен сохранен в Firestore")
            } catch {
                print("❌ Ошибка сохранения токена: \(error)")
            }
        }
    }
    
    // MARK: - API Methods
    
    /// Получить все товары продавца
    func fetchAllProducts(page: Int = 0, size: Int = 50) async throws -> [KaspiProduct] {
        guard let token = kaspiToken else {
            throw KaspiAPIError.tokenNotFound
        }
        
        let urlString = "\(baseURL)/products?page=\(page)&size=\(size)"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw NetworkError.serverError(httpResponse.statusCode, "Ошибка получения товаров")
            }
            
            let decoded = try JSONDecoder().decode(KaspiProductResponse.self, from: data)
            print("✅ Получено \(decoded.content.count) товаров")
            return decoded.content
            
        } catch {
            print("❌ Ошибка получения товаров: \(error)")
            throw error
        }
    }
    
    /// Получить позицию товара в поиске
    func fetchProductPosition(productId: String) async throws -> Int {
        guard let token = kaspiToken else {
            throw KaspiAPIError.tokenNotFound
        }
        
        let urlString = "\(baseURL)/prices/product-position/\(productId)"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw NetworkError.serverError(httpResponse.statusCode, "Ошибка получения позиции")
            }
            
            let decoded = try JSONDecoder().decode(ProductPositionResponse.self, from: data)
            print("📍 Товар \(productId) на позиции: \(decoded.position)")
            return decoded.position
            
        } catch {
            print("❌ Ошибка получения позиции: \(error)")
            throw error
        }
    }
    
    /// Обновить цену товара
    func updatePrice(productId: String, newPrice: Double) async throws {
        guard let token = kaspiToken else {
            throw KaspiAPIError.tokenNotFound
        }
        
        let urlString = "\(baseURL)/prices/change"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.allHTTPHeaderFields = headers
        
        // Формат как в Python: массив с одним объектом
        let payload = [
            PriceUpdateRequest(productId: productId, price: Int(newPrice))
        ]
        
        request.httpBody = try JSONEncoder().encode(payload)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
                throw NetworkError.serverError(httpResponse.statusCode, "Ошибка обновления цены")
            }
            
            print("✅ Цена товара \(productId) обновлена до \(newPrice) ₸")
            
            // Сохраняем историю изменения цены
            await savePriceHistory(productId: productId, newPrice: newPrice)
            
        } catch {
            print("❌ Ошибка обновления цены: \(error)")
            throw error
        }
    }
    
    // MARK: - Синхронизация товаров
    
    /// Синхронизировать все товары с Firebase
    func syncAllProducts() async throws -> [Product] {
        isLoading = true
        errorMessage = nil
        syncProgress = 0.0
        
        do {
            // 1. Получаем все товары из Kaspi
            var allKaspiProducts: [KaspiProduct] = []
            var page = 0
            var hasMore = true
            
            while hasMore {
                let products = try await fetchAllProducts(page: page, size: 50)
                allKaspiProducts.append(contentsOf: products)
                
                syncProgress = Double(allKaspiProducts.count) / 200.0 // Примерная оценка
                
                if products.count < 50 {
                    hasMore = false
                } else {
                    page += 1
                }
            }
            
            // 2. Конвертируем в наш формат Product
            let products = allKaspiProducts.map { kaspiProduct in
                convertKaspiProductToProduct(kaspiProduct)
            }
            
            // 3. Сохраняем в Firestore
            try await saveProductsToFirestore(products)
            
            isLoading = false
            lastSyncDate = Date()
            syncProgress = 1.0
            
            print("✅ Синхронизировано \(products.count) товаров")
            return products
            
        } catch {
            isLoading = false
            syncProgress = 0.0
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    /// Конвертация из KaspiProduct в Product
    private func convertKaspiProductToProduct(_ kaspiProduct: KaspiProduct) -> Product {
        // Простая конвертация, так как у нас нет данных о складах из API
        return Product(
            id: kaspiProduct.id,
            kaspiProductId: kaspiProduct.id,
            name: kaspiProduct.name,
            description: kaspiProduct.category ?? "",
            price: kaspiProduct.price,
            category: kaspiProduct.category ?? "Без категории",
            imageURL: kaspiProduct.imageUrl ?? "",
            status: kaspiProduct.isActive ? .inStock : .inactive,
            warehouseStock: [:], // Будет заполнено отдельно
            createdAt: Date(),
            updatedAt: Date(),
            isActive: kaspiProduct.isActive
        )
    }
    
    /// Сохранить товары в Firestore
    private func saveProductsToFirestore(_ products: [Product]) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw KaspiAPIError.authenticationFailed
        }
        
        let batch = db.batch()
        let productsRef = db.collection("sellers").document(userId).collection("products")
        
        for product in products {
            let docRef = productsRef.document(product.id)
            batch.setData(product.toDictionary(), forDocument: docRef, merge: true)
        }
        
        try await batch.commit()
    }
    
    // MARK: - Автодемпинг (Price Optimizer)
    
    /// Включить/выключить автодемпинг
    func toggleAutoDumping() {
        isAutoDumpingEnabled.toggle()
        
        if isAutoDumpingEnabled {
            startAutoDumping()
        } else {
            stopAutoDumping()
        }
    }
    
    /// Запустить автодемпинг
    private func startAutoDumping() {
        print("🚀 Автодемпинг запущен")
        
        // Запускаем цикл каждые 5 минут
        autoDumpTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task {
                await self.performAutoDump()
            }
        }
        
        // Сразу запускаем первую проверку
        Task {
            await performAutoDump()
        }
    }
    
    /// Остановить автодемпинг
    private func stopAutoDumping() {
        print("⏹ Автодемпинг остановлен")
        autoDumpTimer?.invalidate()
        autoDumpTimer = nil
    }
    
    /// Выполнить автодемпинг для всех товаров
    private func performAutoDump() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        print("🔄 Выполняется автодемпинг...")
        
        do {
            // Получаем активные товары из Firestore
            let snapshot = try await db.collection("sellers").document(userId)
                .collection("products")
                .whereField("isActive", isEqualTo: true)
                .getDocuments()
            
            let products = snapshot.documents.compactMap { doc in
                Product.fromFirestore(doc.data(), id: doc.documentID)
            }
            
            // Проверяем позицию каждого товара
            for product in products {
                await checkAndUpdatePrice(for: product)
            }
            
            print("✅ Автодемпинг завершен")
            
        } catch {
            print("❌ Ошибка автодемпинга: \(error)")
        }
    }
    
    /// Проверить и обновить цену товара
    private func checkAndUpdatePrice(for product: Product) async {
        do {
            // Получаем текущую позицию
            let position = try await fetchProductPosition(productId: product.kaspiProductId)
            
            // Если позиция > 1, снижаем цену на 2%
            if position > 1 {
                let newPrice = floor(product.price * 0.98)
                
                // Проверяем минимальную цену (например, не ниже 70% от оригинала)
                let minPrice = product.price * 0.7
                if newPrice >= minPrice {
                    try await updatePrice(productId: product.kaspiProductId, newPrice: newPrice)
                    print("📉 \(product.name): позиция \(position) → цена снижена до \(newPrice) ₸")
                } else {
                    print("⚠️ \(product.name): достигнута минимальная цена")
                }
            } else {
                print("✅ \(product.name): позиция \(position) - оптимальная")
            }
            
        } catch {
            print("❌ Ошибка проверки \(product.name): \(error)")
        }
    }
    
    /// Сохранить историю изменения цены
    private func savePriceHistory(productId: String, newPrice: Double) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let history = [
                "productId": productId,
                "newPrice": newPrice,
                "timestamp": FieldValue.serverTimestamp(),
                "reason": "auto_dump"
            ]
            
            try await db.collection("sellers").document(userId)
                .collection("priceHistory")
                .addDocument(data: history)
                
        } catch {
            print("⚠️ Не удалось сохранить историю цены: \(error)")
        }
    }
    
    // MARK: - Вспомогательные методы
    
    /// Проверить здоровье API
    func checkAPIHealth() async -> Bool {
        do {
            _ = try await fetchAllProducts(page: 0, size: 1)
            return true
        } catch {
            return false
        }
    }
    
    /// Статистика API
    var apiStatistics: (requests: Int, lastSync: Date?) {
        // TODO: Implement request counting
        return (0, lastSyncDate)
    }
    
    /// Очистить сообщения об ошибках
    func clearMessages() {
        errorMessage = nil
    }
}

// MARK: - KaspiAPIError

extension KaspiAPIError {
    static var tokenNotFound: KaspiAPIError {
        KaspiAPIError.tokenNotFound
    }
    
    static var authenticationFailed: KaspiAPIError {
        KaspiAPIError.authenticationFailed
    }
}
