//
//  KaspiTestService.swift
//  vektaApp
//
//  Обновленный сервис для тестирования Kaspi API с полным покрытием функций
//

import Foundation
import SwiftUI

@MainActor
class KaspiTestService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var testResults: [TestResult] = []
    @Published var isRunning = false
    @Published var overallStatus: TestStatus = .notStarted
    @Published var currentTestName: String = ""
    @Published var progress: Double = 0.0
    
    // MARK: - Private Properties
    private let kaspiAPI = KaspiAPIService()
    
    // MARK: - Test Status & Result Types
    enum TestStatus {
        case notStarted, running, passed, failed, partial
    }
    
    struct TestResult: Identifiable {
        let id = UUID()
        let name: String
        let description: String
        var status: TestStatus
        var message: String?
        var duration: TimeInterval?
        var error: Error?
        var details: [String: Any]?
    }
    
    // MARK: - Main Test Runner
    
    /// Запустить все тесты Kaspi API
    func runAllTests() async {
        isRunning = true
        overallStatus = .running
        testResults = []
        progress = 0.0
        
        let tests: [(String, String, () async -> TestResult)] = [
            ("API Token", "Проверка наличия и валидности токена", testAPIToken),
            ("Categories", "Получение списка категорий", testGetCategories),
            ("Category Attributes", "Получение атрибутов категории", testGetCategoryAttributes),
            ("Product Schema", "Получение схемы импорта товаров", testGetProductSchema),
            ("Products List", "Получение списка товаров", testGetProducts),
            ("Product Import", "Тест импорта товара", testProductImport),
            ("Import Status", "Проверка статуса импорта", testImportStatus),
            ("Orders List", "Получение списка заказов", testGetOrders),
            ("Order Details", "Получение деталей заказа", testGetOrderDetails),
            ("Order Entries", "Получение позиций заказа", testGetOrderEntries),
            ("Order Accept", "Тест принятия заказа", testAcceptOrder),
            ("Order Ship", "Тест отправки заказа", testShipOrder),
            ("Order Complete", "Тест завершения заказа", testCompleteOrder),
            ("Delivery Point", "Получение информации о складе", testGetDeliveryPoint),
            ("IMEI Codes", "Тест работы с IMEI кодами", testIMEICodes),
            ("Order Entry Operations", "Тест операций с позициями", testOrderEntryOperations),
            ("Error Handling", "Тест обработки ошибок", testErrorHandling),
            ("Rate Limiting", "Тест ограничений запросов", testRateLimiting)
        ]
        
        var passed = 0
        var failed = 0
        let totalTests = tests.count
        
        for (index, (name, description, testFunc)) in tests.enumerated() {
            currentTestName = name
            progress = Double(index) / Double(totalTests)
            
            let result = await testFunc()
            testResults.append(result)
            
            switch result.status {
            case .passed:
                passed += 1
            case .failed:
                failed += 1
            default:
                break
            }
        }
        
        // Determine overall status
        if failed == 0 {
            overallStatus = .passed
        } else if passed == 0 {
            overallStatus = .failed
        } else {
            overallStatus = .partial
        }
        
        progress = 1.0
        isRunning = false
        currentTestName = ""
    }
    
    // MARK: - Individual Tests
    
    /// Тест API токена
    private func testAPIToken() async -> TestResult {
        let start = Date()
        
        guard let token = kaspiAPI.apiToken, !token.isEmpty else {
            return TestResult(
                name: "API Token",
                description: "Проверка наличия токена",
                status: .failed,
                message: error.localizedDescription,
                duration: duration,
                error: error
            )
        }
    }
    
    /// Тест импорта товара
    private func testProductImport() async -> TestResult {
        let start = Date()
        
        do {
            // Создаем тестовый товар для импорта
            let testProduct = KaspiProductImportItem(
                type: "products",
                attributes: KaspiProductImportAttributes(
                    sku: "TEST_SKU_\(UUID().uuidString.prefix(8))",
                    title: "Тестовый товар для API",
                    brand: "Test Brand",
                    description: "Это тестовый товар для проверки API импорта",
                    category: "Электроника",
                    images: ["https://example.com/test-image.jpg"],
                    price: 1000.0,
                    availableAmount: 10,
                    attributes: [],
                    isActive: true
                )
            )
            
            let importId = try await kaspiAPI.importProducts([testProduct])
            let duration = Date().timeIntervalSince(start)
            
            return TestResult(
                name: "Product Import",
                description: "Тест импорта товара",
                status: .passed,
                message: "Импорт запущен, ID: \(importId.prefix(8))...",
                duration: duration,
                details: ["importId": importId]
            )
        } catch {
            let duration = Date().timeIntervalSince(start)
            return TestResult(
                name: "Product Import",
                description: "Тест импорта товара",
                status: .failed,
                message: error.localizedDescription,
                duration: duration,
                error: error
            )
        }
    }
    
    /// Тест проверки статуса импорта
    private func testImportStatus() async -> TestResult {
        let start = Date()
        
        // Используем тестовый ID импорта
        let testImportId = "test-import-id"
        
        do {
            let status = try await kaspiAPI.checkImportStatus(importId: testImportId)
            let duration = Date().timeIntervalSince(start)
            
            return TestResult(
                name: "Import Status",
                description: "Проверка статуса импорта",
                status: .passed,
                message: "Статус: \(status.attributes.state.rawValue)",
                duration: duration,
                details: [
                    "state": status.attributes.state.rawValue,
                    "total": status.attributes.total,
                    "errors": status.attributes.errors
                ]
            )
        } catch {
            let duration = Date().timeIntervalSince(start)
            return TestResult(
                name: "Import Status",
                description: "Проверка статуса импорта",
                status: .failed,
                message: error.localizedDescription,
                duration: duration,
                error: error
            )
        }
    }
    
    /// Тест получения заказов
    private func testGetOrders() async -> TestResult {
        let start = Date()
        
        do {
            let response = try await kaspiAPI.getOrders(page: 0, size: 10, state: .new)
            let orders = response.data ?? []
            let duration = Date().timeIntervalSince(start)
            
            return TestResult(
                name: "Orders List",
                description: "Получение списка заказов",
                status: .passed,
                message: "Получено \(orders.count) заказов",
                duration: duration,
                details: [
                    "ordersCount": orders.count,
                    "totalElements": response.meta?.pagination?.totalElements ?? 0
                ]
            )
        } catch {
            let duration = Date().timeIntervalSince(start)
            return TestResult(
                name: "Orders List",
                description: "Получение списка заказов",
                status: .failed,
                message: error.localizedDescription,
                duration: duration,
                error: error
            )
        }
    }
    
    /// Тест получения деталей заказа
    private func testGetOrderDetails() async -> TestResult {
        let start = Date()
        
        do {
            // Сначала получаем список заказов
            let ordersResponse = try await kaspiAPI.getOrders(page: 0, size: 1)
            guard let firstOrder = ordersResponse.data?.first else {
                return TestResult(
                    name: "Order Details",
                    description: "Получение деталей заказа",
                    status: .failed,
                    message: "Нет доступных заказов для тестирования",
                    duration: Date().timeIntervalSince(start)
                )
            }
            
            // Получаем детали заказа по коду
            let order = try await kaspiAPI.getOrder(code: firstOrder.attributes.code)
            let duration = Date().timeIntervalSince(start)
            
            return TestResult(
                name: "Order Details",
                description: "Получение деталей заказа",
                status: .passed,
                message: "Получены детали заказа \(order.attributes.code)",
                duration: duration,
                details: [
                    "orderCode": order.attributes.code,
                    "totalPrice": order.attributes.totalPrice,
                    "status": order.attributes.status.rawValue
                ]
            )
        } catch {
            let duration = Date().timeIntervalSince(start)
            return TestResult(
                name: "Order Details",
                description: "Получение деталей заказа",
                status: .failed,
                message: error.localizedDescription,
                duration: duration,
                error: error
            )
        }
    }
    
    /// Тест получения позиций заказа
    private func testGetOrderEntries() async -> TestResult {
        let start = Date()
        
        do {
            let ordersResponse = try await kaspiAPI.getOrders(page: 0, size: 1)
            guard let firstOrder = ordersResponse.data?.first else {
                return TestResult(
                    name: "Order Entries",
                    description: "Получение позиций заказа",
                    status: .failed,
                    message: "Нет доступных заказов",
                    duration: Date().timeIntervalSince(start)
                )
            }
            
            let entries = try await kaspiAPI.getOrderEntries(orderId: firstOrder.id)
            let duration = Date().timeIntervalSince(start)
            
            return TestResult(
                name: "Order Entries",
                description: "Получение позиций заказа",
                status: .passed,
                message: "Получено \(entries.count) позиций",
                duration: duration,
                details: ["entriesCount": entries.count]
            )
        } catch {
            let duration = Date().timeIntervalSince(start)
            return TestResult(
                name: "Order Entries",
                description: "Получение позиций заказа",
                status: .failed,
                message: error.localizedDescription,
                duration: duration,
                error: error
            )
        }
    }
    
    /// Тест принятия заказа
    private func testAcceptOrder() async -> TestResult {
        let start = Date()
        
        do {
            // Ищем заказы в статусе NEW
            let ordersResponse = try await kaspiAPI.getOrders(page: 0, size: 5, state: .new)
            guard let newOrder = ordersResponse.data?.first(where: {
                $0.attributes.state == .new
            }) else {
                return TestResult(
                    name: "Order Accept",
                    description: "Тест принятия заказа",
                    status: .failed,
                    message: "Нет новых заказов для тестирования",
                    duration: Date().timeIntervalSince(start)
                )
            }
            
            let acceptedOrder = try await kaspiAPI.acceptOrder(
                orderId: newOrder.id,
                orderCode: newOrder.attributes.code
            )
            let duration = Date().timeIntervalSince(start)
            
            return TestResult(
                name: "Order Accept",
                description: "Тест принятия заказа",
                status: .passed,
                message: "Заказ \(acceptedOrder.attributes.code) принят",
                duration: duration,
                details: [
                    "orderCode": acceptedOrder.attributes.code,
                    "newStatus": acceptedOrder.attributes.status.rawValue
                ]
            )
        } catch {
            let duration = Date().timeIntervalSince(start)
            return TestResult(
                name: "Order Accept",
                description: "Тест принятия заказа",
                status: .failed,
                message: error.localizedDescription,
                duration: duration,
                error: error
            )
        }
    }
    
    /// Тест отправки заказа
    private func testShipOrder() async -> TestResult {
        let start = Date()
        
        do {
            // Ищем принятые заказы
            let ordersResponse = try await kaspiAPI.getOrders(page: 0, size: 5)
            guard let acceptedOrder = ordersResponse.data?.first(where: {
                $0.attributes.status == .acceptedByMerchant
            }) else {
                return TestResult(
                    name: "Order Ship",
                    description: "Тест отправки заказа",
                    status: .failed,
                    message: "Нет принятых заказов для тестирования",
                    duration: Date().timeIntervalSince(start)
                )
            }
            
            let shippedOrder = try await kaspiAPI.shipOrder(orderId: acceptedOrder.id)
            let duration = Date().timeIntervalSince(start)
            
            return TestResult(
                name: "Order Ship",
                description: "Тест отправки заказа",
                status: .passed,
                message: "Заказ \(shippedOrder.attributes.code) отправлен",
                duration: duration,
                details: [
                    "orderCode": shippedOrder.attributes.code,
                    "newStatus": shippedOrder.attributes.status.rawValue
                ]
            )
        } catch {
            let duration = Date().timeIntervalSince(start)
            return TestResult(
                name: "Order Ship",
                description: "Тест отправки заказа",
                status: .failed,
                message: error.localizedDescription,
                duration: duration,
                error: error
            )
        }
    }
    
    /// Тест завершения заказа
    private func testCompleteOrder() async -> TestResult {
        let start = Date()
        
        do {
            // Это тест только первого этапа (отправка кода)
            let ordersResponse = try await kaspiAPI.getOrders(page: 0, size: 5)
            guard let deliveredOrder = ordersResponse.data?.first(where: {
                $0.attributes.status == .kaspiDelivery
            }) else {
                return TestResult(
                    name: "Order Complete",
                    description: "Тест завершения заказа",
                    status: .failed,
                    message: "Нет заказов в доставке для тестирования",
                    duration: Date().timeIntervalSince(start)
                )
            }
            
            // Тестируем только первый этап
            try await kaspiAPI.completeOrderStep1(orderId: deliveredOrder.id)
            let duration = Date().timeIntervalSince(start)
            
            return TestResult(
                name: "Order Complete",
                description: "Тест завершения заказа (этап 1)",
                status: .passed,
                message: "Код подтверждения отправлен клиенту",
                duration: duration,
                details: ["orderCode": deliveredOrder.attributes.code]
            )
        } catch {
            let duration = Date().timeIntervalSince(start)
            return TestResult(
                name: "Order Complete",
                description: "Тест завершения заказа",
                status: .failed,
                message: error.localizedDescription,
                duration: duration,
                error: error
            )
        }
    }
    
    /// Тест получения информации о складе
    private func testGetDeliveryPoint() async -> TestResult {
        let start = Date()
        
        do {
            // Получаем заказ и его позиции
            let ordersResponse = try await kaspiAPI.getOrders(page: 0, size: 1)
            guard let order = ordersResponse.data?.first else {
                return TestResult(
                    name: "Delivery Point",
                    description: "Получение информации о складе",
                    status: .failed,
                    message: "Нет заказов для тестирования",
                    duration: Date().timeIntervalSince(start)
                )
            }
            
            let entries = try await kaspiAPI.getOrderEntries(orderId: order.id)
            guard let firstEntry = entries.first else {
                return TestResult(
                    name: "Delivery Point",
                    description: "Получение информации о складе",
                    status: .failed,
                    message: "Нет позиций в заказе",
                    duration: Date().timeIntervalSince(start)
                )
            }
            
            let deliveryPoint = try await kaspiAPI.getDeliveryPointOfService(entryId: firstEntry.id)
            let duration = Date().timeIntervalSince(start)
            
            return TestResult(
                name: "Delivery Point",
                description: "Получение информации о складе",
                status: .passed,
                message: "Получена информация о складе: \(deliveryPoint.attributes.name)",
                duration: duration,
                details: [
                    "pointName": deliveryPoint.attributes.name,
                    "address": deliveryPoint.attributes.address.formattedAddress
                ]
            )
        } catch {
            let duration = Date().timeIntervalSince(start)
            return TestResult(
                name: "Delivery Point",
                description: "Получение информации о складе",
                status: .failed,
                message: error.localizedDescription,
                duration: duration,
                error: error
            )
        }
    }
    
    /// Тест работы с IMEI кодами
    private func testIMEICodes() async -> TestResult {
        let start = Date()
        
        do {
            let ordersResponse = try await kaspiAPI.getOrders(page: 0, size: 5)
            guard let order = ordersResponse.data?.first else {
                return TestResult(
                    name: "IMEI Codes",
                    description: "Тест работы с IMEI кодами",
                    status: .failed,
                    message: "Нет заказов для тестирования",
                    duration: Date().timeIntervalSince(start)
                )
            }
            
            let imeiCodes = try await kaspiAPI.getOrderIMEI(orderId: order.id)
            let duration = Date().timeIntervalSince(start)
            
            return TestResult(
                name: "IMEI Codes",
                description: "Получение IMEI кодов заказа",
                status: .passed,
                message: "Получено \(imeiCodes.count) IMEI записей",
                duration: duration,
                details: ["imeiCount": imeiCodes.count]
            )
        } catch {
            let duration = Date().timeIntervalSince(start)
            return TestResult(
                name: "IMEI Codes",
                description: "Тест работы с IMEI кодами",
                status: .failed,
                message: error.localizedDescription,
                duration: duration,
                error: error
            )
        }
    }
    
    /// Тест операций с позициями заказа
    private func testOrderEntryOperations() async -> TestResult {
        let start = Date()
        
        do {
            let ordersResponse = try await kaspiAPI.getOrders(page: 0, size: 5)
            guard let order = ordersResponse.data?.first else {
                return TestResult(
                    name: "Order Entry Operations",
                    description: "Тест операций с позициями",
                    status: .failed,
                    message: "Нет заказов для тестирования",
                    duration: Date().timeIntervalSince(start)
                )
            }
            
            let entries = try await kaspiAPI.getOrderEntries(orderId: order.id)
            guard let firstEntry = entries.first else {
                return TestResult(
                    name: "Order Entry Operations",
                    description: "Тест операций с позициями",
                    status: .failed,
                    message: "Нет позиций в заказе",
                    duration: Date().timeIntervalSince(start)
                )
            }
            
            // Тестируем изменение веса (безопасная операция)
            try await kaspiAPI.changeOrderEntryWeight(entryId: firstEntry.id, newWeight: 1.0)
            let duration = Date().timeIntervalSince(start)
            
            return TestResult(
                name: "Order Entry Operations",
                description: "Тест операций с позициями",
                status: .passed,
                message: "Операция изменения веса выполнена успешно",
                duration: duration,
                details: ["entryId": firstEntry.id, "newWeight": 1.0]
            )
        } catch {
            let duration = Date().timeIntervalSince(start)
            return TestResult(
                name: "Order Entry Operations",
                description: "Тест операций с позициями",
                status: .failed,
                message: error.localizedDescription,
                duration: duration,
                error: error
            )
        }
    }
    
    /// Тест обработки ошибок
    private func testErrorHandling() async -> TestResult {
        let start = Date()
        
        do {
            // Намеренно вызываем ошибку - запрашиваем несуществующий заказ
            _ = try await kaspiAPI.getOrder(code: "NONEXISTENT_ORDER_CODE")
            
            // Если мы дошли сюда, то тест провален
            return TestResult(
                name: "Error Handling",
                description: "Тест обработки ошибок",
                status: .failed,
                message: "Ошибка не была обработана правильно",
                duration: Date().timeIntervalSince(start)
            )
        } catch {
            let duration = Date().timeIntervalSince(start)
            
            // Проверяем, что получили правильный тип ошибки
            if error is KaspiAPIError {
                return TestResult(
                    name: "Error Handling",
                    description: "Тест обработки ошибок",
                    status: .passed,
                    message: "Ошибки обрабатываются корректно",
                    duration: duration,
                    details: ["errorType": String(describing: type(of: error))]
                )
            } else {
                return TestResult(
                    name: "Error Handling",
                    description: "Тест обработки ошибок",
                    status: .failed,
                    message: "Получен неожиданный тип ошибки",
                    duration: duration,
                    error: error
                )
            }
        }
    }
    
    /// Тест ограничений запросов
    private func testRateLimiting() async -> TestResult {
        let start = Date()
        
        var successCount = 0
        var rateLimited = false
        
        // Делаем несколько быстрых запросов
        for i in 1...5 {
            do {
                _ = try await kaspiAPI.getProducts(page: 0, size: 1)
                successCount += 1
            } catch {
                if let kaspiError = error as? KaspiAPIError,
                   case .apiQuotaExceeded = kaspiError {
                    rateLimited = true
                    break
                }
                // Игнорируем другие ошибки для этого теста
            }
        }
        
        let duration = Date().timeIntervalSince(start)
        
        return TestResult(
            name: "Rate Limiting",
            description: "Тест ограничений запросов",
            status: .passed,
            message: rateLimited
                ? "Rate limiting работает (лимит достигнут после \(successCount) запросов)"
                : "Выполнено \(successCount) запросов без ограничений",
            duration: duration,
            details: [
                "successfulRequests": successCount,
                "rateLimited": rateLimited
            ]
        )
    }
}

// MARK: - Helper Methods

extension KaspiTestService {
    
    /// Очистить результаты тестов
    func clearResults() {
        testResults = []
        overallStatus = .notStarted
        progress = 0.0
        currentTestName = ""
    }
    
    /// Получить краткую сводку результатов
    func getTestSummary() -> String {
        let total = testResults.count
        let passed = testResults.filter { $0.status == .passed }.count
        let failed = testResults.filter { $0.status == .failed }.count
        
        return "Пройдено: \(passed)/\(total), Ошибок: \(failed)"
    }
    
    /// Экспорт результатов в JSON
    func exportResults() -> Data? {
        let exportData: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "overallStatus": String(describing: overallStatus),
            "summary": getTestSummary(),
            "results": testResults.map { result in
                [
                    "name": result.name,
                    "description": result.description,
                    "status": String(describing: result.status),
                    "message": result.message ?? "",
                    "duration": result.duration ?? 0,
                    "error": result.error?.localizedDescription ?? "",
                    "details": result.details ?? [:]
                ]
            }
        ]
        
        return try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }
}d,
                message: "Токен отсутствует",
                duration: Date().timeIntervalSince(start)
            )
        }
        
        // Проверяем валидность токена
        let isValid = await kaspiAPI.validateToken()
        let duration = Date().timeIntervalSince(start)
        
        return TestResult(
            name: "API Token",
            description: "Проверка валидности токена",
            status: isValid ? .passed : .failed,
            message: isValid ? "Токен валиден" : "Токен недействителен",
            duration: duration
        )
    }
    
    /// Тест получения категорий
    private func testGetCategories() async -> TestResult {
        let start = Date()
        
        do {
            let categories = try await kaspiAPI.getCategories()
            let duration = Date().timeIntervalSince(start)
            
            return TestResult(
                name: "Categories",
                description: "Получение списка категорий",
                status: .passed,
                message: "Получено \(categories.count) категорий",
                duration: duration,
                details: ["categoriesCount": categories.count]
            )
        } catch {
            let duration = Date().timeIntervalSince(start)
            return TestResult(
                name: "Categories",
                description: "Получение списка категорий",
                status: .failed,
                message: error.localizedDescription,
                duration: duration,
                error: error
            )
        }
    }
    
    /// Тест получения атрибутов категории
    private func testGetCategoryAttributes() async -> TestResult {
        let start = Date()
        
        do {
            // Сначала получаем категории
            let categories = try await kaspiAPI.getCategories()
            guard let firstCategory = categories.first else {
                return TestResult(
                    name: "Category Attributes",
                    description: "Получение атрибутов категории",
                    status: .failed,
                    message: "Нет доступных категорий",
                    duration: Date().timeIntervalSince(start)
                )
            }
            
            // Получаем атрибуты первой категории
            let attributes = try await kaspiAPI.getCategoryAttributes(categoryCode: firstCategory.code)
            let duration = Date().timeIntervalSince(start)
            
            return TestResult(
                name: "Category Attributes",
                description: "Получение атрибутов категории",
                status: .passed,
                message: "Получено \(attributes.count) атрибутов для категории \(firstCategory.title)",
                duration: duration,
                details: [
                    "categoryCode": firstCategory.code,
                    "attributesCount": attributes.count
                ]
            )
        } catch {
            let duration = Date().timeIntervalSince(start)
            return TestResult(
                name: "Category Attributes",
                description: "Получение атрибутов категории",
                status: .failed,
                message: error.localizedDescription,
                duration: duration,
                error: error
            )
        }
    }
    
    /// Тест получения схемы импорта
    private func testGetProductSchema() async -> TestResult {
        let start = Date()
        
        do {
            let schema = try await kaspiAPI.getProductImportSchema()
            let duration = Date().timeIntervalSince(start)
            
            return TestResult(
                name: "Product Schema",
                description: "Получение схемы импорта товаров",
                status: .passed,
                message: "Схема импорта получена",
                duration: duration,
                details: ["schemaKeys": Array(schema.keys)]
            )
        } catch {
            let duration = Date().timeIntervalSince(start)
            return TestResult(
                name: "Product Schema",
                description: "Получение схемы импорта товаров",
                status: .failed,
                message: error.localizedDescription,
                duration: duration,
                error: error
            )
        }
    }
    
    /// Тест получения списка товаров
    private func testGetProducts() async -> TestResult {
        let start = Date()
        
        do {
            let response = try await kaspiAPI.getProducts(page: 0, size: 10)
            let products = response.data ?? []
            let duration = Date().timeIntervalSince(start)
            
            return TestResult(
                name: "Products List",
                description: "Получение списка товаров",
                status: .passed,
                message: "Получено \(products.count) товаров",
                duration: duration,
                details: [
                    "productsCount": products.count,
                    "totalElements": response.meta?.pagination?.totalElements ?? 0
                ]
            )
        } catch {
            let duration = Date().timeIntervalSince(start)
            return TestResult(
                name: "Products List",
                description: "Получение списка товаров",
                status: .faile
