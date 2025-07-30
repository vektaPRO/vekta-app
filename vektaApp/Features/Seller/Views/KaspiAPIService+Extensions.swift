//
//  KaspiAPIService+Extensions.swift
//  vektaApp
//
//  Дополнительные методы для KaspiAPIService
//

import Foundation

extension KaspiAPIService {
    
    /// Загрузить заказы (совместимость с KaspiOrdersManager)
    func loadOrders() async throws -> [KaspiOrder] {
        let ordersResponse = try await getOrders(page: 0, size: 100, state: .new)
        return ordersResponse.data ?? []
    }
    
    /// Запросить SMS код для подтверждения доставки
    func requestSMSCode(orderId: String, trackingNumber: String, to phoneNumber: String) async throws {
        // Первый этап завершения заказа - отправка кода клиенту
        try await completeOrderStep1(orderId: orderId)
    }
    
    /// Подтвердить доставку с SMS кодом
    func confirmDelivery(orderId: String, trackingNumber: String, smsCode: String) async throws -> Bool {
        do {
            // Второй этап завершения заказа - с кодом от клиента
            let completedOrder = try await completeOrderStep2(
                orderId: orderId,
                securityCode: smsCode
            )
            
            // Проверяем что заказ действительно завершен
            return completedOrder.attributes.status == .completed
            
        } catch {
            // Если код неверный или произошла ошибка
            return false
        }
    }
    
    /// Получить все товары (для ProductsViewModel)
    func fetchAllProducts() async throws -> [KaspiProduct] {
        var allProducts: [KaspiProduct] = []
        var currentPage = 0
        let pageSize = 100
        
        repeat {
            let response = try await getProducts(page: currentPage, size: pageSize)
            let products = response.data ?? []
            allProducts.append(contentsOf: products)
            
            // Проверяем есть ли еще страницы
            if let totalPages = response.meta?.pagination?.totalPages,
               currentPage + 1 >= totalPages {
                break
            }
            
            currentPage += 1
        } while true
        
        return allProducts
    }
    
    /// Получить позицию товара в поиске (для автодемпинга)
    func fetchProductPosition(productId: String) async throws -> Int {
        // Заглушка для позиции товара
        // В реальной реализации здесь был бы запрос к поисковому API Kaspi
        return Int.random(in: 1...10)
    }
    
    /// Обновить цену товара (для автодемпинга)
    func updatePrice(productId: String, newPrice: Int) async throws {
        // Заглушка для обновления цены
        // В реальной реализации здесь был бы API запрос на обновление цены
        print("Цена товара \(productId) обновлена до \(newPrice)")
    }
}

// MARK: - Compatibility Extensions

extension KaspiAPIService {
    
    /// Совместимость для старых методов
    var hasValidToken: Bool {
        return apiToken != nil && !(apiToken?.isEmpty ?? true)
    }
    
    /// Проверить подключение к API
    func testConnection() async -> Bool {
        return await validateToken()
    }
    
    /// Получить статистику API вызовов
    func getAPIStats() -> (totalCalls: Int, todayCalls: Int, lastError: String?) {
        // Заглушка для статистики
        return (totalCalls: 150, todayCalls: 12, lastError: nil)
    }
}

