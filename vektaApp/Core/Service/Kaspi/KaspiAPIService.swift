import Foundation

@MainActor
public final class KaspiAPIService: ObservableObject {
    // MARK: — Published
    @Published public private(set) var apiToken: String?
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    
    // MARK: — Private
    private let baseURL = URL(string: "https://kaspi.kz/shop/api/v2")!
    private let session = URLSession.shared
    
    // MARK: — Token Storage
    
    /// Сохраняет токен локально (UserDefaults)
    public func saveToken(_ token: String) {
        apiToken = token
        UserDefaults.standard.set(token, forKey: "KaspiAPIToken")
    }
    
    /// Загружает токен из хранилища
    public func loadToken() {
        apiToken = UserDefaults.standard.string(forKey: "KaspiAPIToken")
    }
    
    // MARK: — API Health Check
    
    /// Проверяет, годен ли текущий токен
    public func checkAPIHealth() async -> Bool {
        guard let token = apiToken else { return false }
        var req = URLRequest(url: baseURL.appendingPathComponent("health"))
        req.setValue(token, forHTTPHeaderField: "X-TOKEN")
        
        do {
            let (_, resp) = try await session.data(for: req)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // MARK: — Products
    
    /// GET /api/v2/products?page=0&size=50
    /// Получение списка товаров
    public func fetchAllProducts(page: Int = 0, size: Int = 50) async throws -> [KaspiProduct] {
        guard let token = apiToken else { throw APIError.tokenMissing }
        isLoading = true; defer { isLoading = false }
        
        let url = baseURL.appendingPathComponent("products?page=\(page)&size=\(size)")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.allHTTPHeaderFields = defaultHeaders
        
        let (data, resp) = try await session.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.serverError
        }
        let wrapper = try JSONDecoder().decode(KaspiProductResponse.self, from: data)
        return wrapper.content
    }
    
    /// GET /api/v2/prices/product-position/{product-id}
    /// Получение позиции товара
    public func fetchProductPosition(productId: String) async throws -> Int {
        guard let token = apiToken else { throw APIError.tokenMissing }
        let url = baseURL.appendingPathComponent("prices/product-position/\(productId)")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.allHTTPHeaderFields = defaultHeaders
        
        let (data, _) = try await session.data(for: req)
        let resp = try JSONDecoder().decode(ProductPositionResponse.self, from: data)
        return resp.position
    }
    
    /// PATCH /api/v2/prices/change
    /// Обновление цены товарa
    public func updatePrice(productId: String, newPrice: Double) async throws {
        guard let token = apiToken else { throw APIError.tokenMissing }
        let url = baseURL.appendingPathComponent("prices/change")
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.allHTTPHeaderFields = defaultHeaders
        
        // тело: [ { "productId": "...", "price": 1234 } ]
        let payload: [PriceChangePayload] = [ .init(productId: productId, price: Int(newPrice)) ]
        req.httpBody = try JSONEncoder().encode(payload)
        
        let (_, resp) = try await session.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.serverError
        }
    }
    
    // MARK: — High-level Wrappers for Test Service
    
    /// Обёртка для тестов — синхронизирует все товары
    public func syncAllProducts() async throws -> [KaspiProduct] {
        return try await fetchAllProducts()
    }
    
    /// Заглушка: отправка SMS — тестовый метод
    public func requestSMSCode(orderId: String, trackingNumber: String, customerPhone: String) async throws -> String {
        // TODO: реально вызывать API, пока заглушка:
        return UUID().uuidString
    }
    
    /// Заглушка: подтверждение доставки — тестовый метод
    public func confirmDelivery(orderId: String, trackingNumber: String, smsCode: String) async throws -> Bool {
        // TODO: реально вызывать API, пока заглушка:
        return false
    }
    
    /// Заглушка: обновление остатков — тестовый метод
    public func updateStock(productId: String,
                            warehouseId: String,
                            quantity: Int,
                            operation: StockOperation) async throws {
        // TODO: реально вызывать API, пока заглушка:
    }
    
    /// Заглушка: загрузка списка складов
    public func loadWarehouses() async throws -> [Warehouse] {
        // TODO: реальный запрос, пока заглушка:
        return []
    }
    
    // MARK: — Auto-Dumping (заглушка)
    
    /// Перебирает товары и демпит цену, если position > 1
    public func performAutoDumping(on products: [KaspiProduct]) async {
        for product in products where product.isActive {
            do {
                let pos = try await fetchProductPosition(productId: product.id)
                if pos > 1 {
                    let newPrice = floor(product.price * 0.98)
                    try await updatePrice(productId: product.id, newPrice: newPrice)
                }
            } catch {
                print("AutoDump error for \(product.name): \(error)")
            }
        }
    }
    
    // MARK: — Shared
    
    private var defaultHeaders: [String:String] {
        var h: [String:String] = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)...",
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
        if let t = apiToken { h["X-TOKEN"] = t }
        return h
    }
    
    // MARK: — Errors & DTOs
    
    public enum APIError: Error {
        case tokenMissing
        case serverError
    }
    
    public struct KaspiProductResponse: Codable {
        public let content: [KaspiProduct]
    }
    public struct KaspiProduct: Codable, Identifiable {
        public let id: String
        public let name: String
        public let shortDescription: String?
        public let category: String
        public let price: Double
        public let stockCount: Int
        public let isActive: Bool
        public let images: [String]
        
        private enum CodingKeys: String, CodingKey {
            case id = "code", name, shortDescription, category, price, stockCount, isActive, images
        }
    }
    private struct ProductPositionResponse: Codable {
        let position: Int
    }
    private struct PriceChangePayload: Codable {
        let productId: String
        let price: Int
    }
    
    // MARK: — Warehouses, Stock, Delivery Models
    
    public struct Warehouse: Codable, Identifiable {
        public let id: String
        public let name: String
    }
    public enum StockOperation: String, Codable {
        case set, increase, decrease
    }
}
