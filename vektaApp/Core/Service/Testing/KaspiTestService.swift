//
//  KaspiTestService.swift
//  vektaApp
//
//  Сервис для тестирования всех функций Kaspi API
//

import Foundation

@MainActor
final class KaspiTestService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRunning = false
    @Published var progress: Double = 0.0
    @Published var currentTestName = ""
    @Published var testResults: [TestResult] = []
    @Published var overallStatus: TestStatus = .notStarted
    
    // MARK: - Private Properties
    private let kaspiAPI = KaspiAPIService()
    
    // MARK: - Test Models
    
    struct TestResult: Identifiable {
        let id = UUID()
        let name: String
        let description: String
        let status: TestStatus
        let duration: TimeInterval?
        let message: String?
        let endpoint: String?
    }
    
    enum TestStatus {
        case notStarted
        case running
        case passed
        case failed
        case partial
    }
    
    // MARK: - Main Test Methods
    
    /// Запустить все тесты
    func runAllTests() async {
        isRunning = true
        testResults = []
        overallStatus = .running
        progress = 0.0
        
        let tests: [(String, String, () async -> TestResult)] = [
            ("Проверка токена", "Валидация API токена", testTokenValidation),
            ("Схема импорта", "Получение JSON схемы для товаров", testImportSchema),
            ("Категории", "Загрузка списка категорий", testCategories),
            ("Атрибуты", "Получение атрибутов категории", testCategoryAttributes),
            ("Список товаров", "Получение товаров через API", testProductsList),
            ("Список заказов", "Получение заказов через API", testOrdersList),
            ("Детали заказа", "Получение деталей заказа", testOrderDetails),
            ("Позиции заказа", "Получение позиций заказа", testOrderEntries),
            ("Информация о товаре", "Данные товара из позиции", testOrderEntryProduct),
            ("Подключение API", "Общий тест подключения", testApiConnection)
        ]
        
        let totalTests = Double(tests.count)
        
        for (index, (name, description, test)) in tests.enumerated() {
            currentTestName = name
            
            let result = await test()
            testResults.append(result)
            
            progress = Double(index + 1) / totalTests
            
            // Небольшая задержка для UI
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 секунды
        }
        
        // Определяем общий статус
        calculateOverallStatus()
        
        isRunning = false
        currentTestName = ""
    }
    
    // MARK: - Individual Tests
    
    /// Тест 1: Проверка токена
    private func testTokenValidation() async -> TestResult {
        let startTime = Date()
        
        guard kaspiAPI.apiToken != nil else {
            return TestResult(
                name: "Проверка токена",
                description: "Валидация API токена",
                status: .failed,
                duration: Date().timeIntervalSince(startTime),
                message: "API токен не найден",
                endpoint: nil
            )
        }
        
        let isValid = await kaspiAPI.validateToken()
        let duration = Date().timeIntervalSince(startTime)
        
        return TestResult(
            name: "Проверка токена",
            description: "Валидация API токена",
            status: isValid ? .passed : .failed,
            duration: duration,
            message: isValid ? "Токен действителен" : "Токен недействителен или истек",
            endpoint: "/products (проверочный запрос)"
        )
    }
    
    /// Тест 2: Схема импорта
    private func testImportSchema() async -> TestResult {
        let startTime = Date()

        do {
            let schema = try await kaspiAPI.getProductImportSchema() // KaspiImportSchema
            let duration = Date().timeIntervalSince(startTime)

            // Ожидаемые поля по инструкции
            let expectedFields = ["sku", "title", "brand", "description", "category", "images", "attributes"]

            // Берём реальные названия полей из properties и приводим к нижнему регистру
            let available = schema.properties.keys.map { $0.lowercased() }

            // Какие из ожидаемых есть
            let found = expectedFields.filter { available.contains($0.lowercased()) }

            // Обязательные минимальные: sku и title
            let hasMinimal = available.contains("sku") && available.contains("title")

            let status: TestStatus
            let message: String

            if hasMinimal {
                status = .passed
                let extras = found.filter { $0 != "sku" && $0 != "title" }
                message = "Есть обязательные поля (sku, title)" +
                          (extras.isEmpty ? "" : " и дополнительно: \(extras.joined(separator: ", "))")
            } else if !found.isEmpty {
                status = .partial
                message = "Присутствуют поля: \(found.joined(separator: ", ")), но не хватает sku и/или title"
            } else {
                status = .partial
                message = "Схема получена, но не содержит ожидаемых полей: \(expectedFields.joined(separator: ", "))"
            }

            return TestResult(
                name: "Схема импорта",
                description: "Получение JSON схемы для товаров",
                status: status,
                duration: duration,
                message: message,
                endpoint: "/products/import/schema"
            )
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            return TestResult(
                name: "Схема импорта",
                description: "Получение JSON схемы для товаров",
                status: .failed,
                duration: duration,
                message: "Ошибка: \(error.localizedDescription)",
                endpoint: "/products/import/schema"
            )
        }
    }
    
    /// Тест 3: Категории
    private func testCategories() async -> TestResult {
        let startTime = Date()
        
        do {
            let categories = try await kaspiAPI.getCategories()
            let duration = Date().timeIntervalSince(startTime)
            
            return TestResult(
                name: "Категории",
                description: "Загрузка списка категорий",
                status: categories.isEmpty ? .partial : .passed,
                duration: duration,
                message: "Получено \(categories.count) категорий",
                endpoint: "/products/classification/categories"
            )
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            return TestResult(
                name: "Категории",
                description: "Загрузка списка категорий",
                status: .failed,
                duration: duration,
                message: "Ошибка: \(error.localizedDescription)",
                endpoint: "/products/classification/categories"
            )
        }
    }
    
    /// Тест 4: Атрибуты категории
    private func testCategoryAttributes() async -> TestResult {
        let startTime = Date()
        
        do {
            // Попробуем получить атрибуты для популярной категории
            let attributes = try await kaspiAPI.getCategoryAttributes(categoryCode: "smartphone")
            let duration = Date().timeIntervalSince(startTime)
            
            return TestResult(
                name: "Атрибуты",
                description: "Получение атрибутов категории",
                status: .passed,
                duration: duration,
                message: "Получено \(attributes.count) атрибутов для категории 'smartphone'",
                endpoint: "/products/classification/attributes"
            )
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            return TestResult(
                name: "Атрибуты",
                description: "Получение атрибутов категории",
                status: .failed,
                duration: duration,
                message: "Ошибка: \(error.localizedDescription)",
                endpoint: "/products/classification/attributes"
            )
        }
    }
    
    /// Тест 5: Список товаров
    private func testProductsList() async -> TestResult {
        let startTime = Date()
        
        do {
            let response = try await kaspiAPI.getProducts(page: 0, size: 10)
            let duration = Date().timeIntervalSince(startTime)
            
            let productsCount = response.data?.count ?? 0
            
            return TestResult(
                name: "Список товаров",
                description: "Получение товаров через API",
                status: productsCount > 0 ? .passed : .partial,
                duration: duration,
                message: "Получено \(productsCount) товаров",
                endpoint: "/products"
            )
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            return TestResult(
                name: "Список товаров",
                description: "Получение товаров через API",
                status: .failed,
                duration: duration,
                message: "Ошибка: \(error.localizedDescription)",
                endpoint: "/products"
            )
        }
    }
    
    /// Тест 6: Список заказов
    private func testOrdersList() async -> TestResult {
        let startTime = Date()
        
        do {
            let response = try await kaspiAPI.getOrders(page: 0, size: 10)
            let duration = Date().timeIntervalSince(startTime)
            
            let ordersCount = response.data?.count ?? 0
            
            return TestResult(
                name: "Список заказов",
                description: "Получение заказов через API",
                status: .passed,
                duration: duration,
                message: "Получено \(ordersCount) заказов",
                endpoint: "/orders"
            )
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            return TestResult(
                name: "Список заказов",
                description: "Получение заказов через API",
                status: .failed,
                duration: duration,
                message: "Ошибка: \(error.localizedDescription)",
                endpoint: "/orders"
            )
        }
    }
    
    /// Тест 7: Детали заказа
    private func testOrderDetails() async -> TestResult {
        let startTime = Date()
        
        do {
            // Сначала получаем список заказов
            let ordersResponse = try await kaspiAPI.getOrders(page: 0, size: 1)
            
            guard let firstOrder = ordersResponse.data?.first else {
                let duration = Date().timeIntervalSince(startTime)
                return TestResult(
                    name: "Детали заказа",
                    description: "Получение деталей заказа",
                    status: .partial,
                    duration: duration,
                    message: "Нет заказов для тестирования",
                    endpoint: "/orders"
                )
            }
            
            // Получаем детали заказа
            let order = try await kaspiAPI.getOrder(code: firstOrder.attributes.code)
            let duration = Date().timeIntervalSince(startTime)
            
            return TestResult(
                name: "Детали заказа",
                description: "Получение деталей заказа",
                status: .passed,
                duration: duration,
                message: "Детали заказа \(order.attributes.code) получены",
                endpoint: "/orders?filter[orders][code]"
            )
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            return TestResult(
                name: "Детали заказа",
                description: "Получение деталей заказа",
                status: .failed,
                duration: duration,
                message: "Ошибка: \(error.localizedDescription)",
                endpoint: "/orders?filter[orders][code]"
            )
        }
    }
    
    /// Тест 8: Позиции заказа
    private func testOrderEntries() async -> TestResult {
        let startTime = Date()
        
        do {
            // Получаем первый заказ
            let ordersResponse = try await kaspiAPI.getOrders(page: 0, size: 1)
            
            guard let firstOrder = ordersResponse.data?.first else {
                let duration = Date().timeIntervalSince(startTime)
                return TestResult(
                    name: "Позиции заказа",
                    description: "Получение позиций заказа",
                    status: .partial,
                    duration: duration,
                    message: "Нет заказов для тестирования",
                    endpoint: "/orders/{orderId}/entries"
                )
            }
            
            // Получаем позиции заказа
            let entries = try await kaspiAPI.getOrderEntries(orderId: firstOrder.id)
            let duration = Date().timeIntervalSince(startTime)
            
            return TestResult(
                name: "Позиции заказа",
                description: "Получение позиций заказа",
                status: .passed,
                duration: duration,
                message: "Получено \(entries.count) позиций",
                endpoint: "/orders/{orderId}/entries"
            )
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            return TestResult(
                name: "Позиции заказа",
                description: "Получение позиций заказа",
                status: .failed,
                duration: duration,
                message: "Ошибка: \(error.localizedDescription)",
                endpoint: "/orders/{orderId}/entries"
            )
        }
    }
    
    /// Тест 9: Информация о товаре из позиции
    private func testOrderEntryProduct() async -> TestResult {
        let startTime = Date()
        
        do {
            // Получаем первый заказ и его позиции
            let ordersResponse = try await kaspiAPI.getOrders(page: 0, size: 1)
            
            guard let firstOrder = ordersResponse.data?.first else {
                let duration = Date().timeIntervalSince(startTime)
                return TestResult(
                    name: "Информация о товаре",
                    description: "Данные товара из позиции",
                    status: .partial,
                    duration: duration,
                    message: "Нет заказов для тестирования",
                    endpoint: "/orderentries/{entryId}/product"
                )
            }
            
            let entries = try await kaspiAPI.getOrderEntries(orderId: firstOrder.id)
            
            guard let firstEntry = entries.first else {
                let duration = Date().timeIntervalSince(startTime)
                return TestResult(
                    name: "Информация о товаре",
                    description: "Данные товара из позиции",
                    status: .partial,
                    duration: duration,
                    message: "Нет позиций в заказе",
                    endpoint: "/orderentries/{entryId}/product"
                )
            }
            
            // Получаем информацию о товаре
            let product = try await kaspiAPI.getOrderEntryProduct(entryId: firstEntry.id)
            let duration = Date().timeIntervalSince(startTime)
            
            return TestResult(
                name: "Информация о товаре",
                description: "Данные товара из позиции",
                status: .passed,
                duration: duration,
                message: "Данные товара \(product.attributes.name) получены",
                endpoint: "/orderentries/{entryId}/product"
            )
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            return TestResult(
                name: "Информация о товаре",
                description: "Данные товара из позиции",
                status: .failed,
                duration: duration,
                message: "Ошибка: \(error.localizedDescription)",
                endpoint: "/orderentries/{entryId}/product"
            )
        }
    }
    
    /// Тест 10: Общее подключение к API
    private func testApiConnection() async -> TestResult {
        let startTime = Date()
        
        do {
            // Простой тест подключения
            let response = try await kaspiAPI.getProducts(page: 0, size: 1)
            let duration = Date().timeIntervalSince(startTime)
            
            let hasData = response.data != nil
            let hasMeta = response.meta != nil
            
            return TestResult(
                name: "Подключение API",
                description: "Общий тест подключения",
                status: hasData && hasMeta ? .passed : .partial,
                duration: duration,
                message: hasData ? "API доступно и отвечает" : "API доступно, но структура ответа неполная",
                endpoint: "/products"
            )
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            return TestResult(
                name: "Подключение API",
                description: "Общий тест подключения",
                status: .failed,
                duration: duration,
                message: "API недоступно: \(error.localizedDescription)",
                endpoint: "/products"
            )
        }
    }
    
    // MARK: - Helper Methods
    
    /// Определить общий статус всех тестов
    private func calculateOverallStatus() {
        let passedCount = testResults.filter { $0.status == .passed }.count
        let failedCount = testResults.filter { $0.status == .failed }.count
        let totalCount = testResults.count
        
        if failedCount == 0 {
            overallStatus = .passed
        } else if passedCount == 0 {
            overallStatus = .failed
        } else {
            overallStatus = .partial
        }
    }
    
    /// Получить краткое резюме тестирования
    func getTestSummary() -> String {
        let passedCount = testResults.filter { $0.status == .passed }.count
        let failedCount = testResults.filter { $0.status == .failed }.count
        let partialCount = testResults.filter { $0.status == .partial }.count
        let totalCount = testResults.count
        
        if totalCount == 0 {
            return "Тесты не запущены"
        }
        
        return "\(passedCount) успешных, \(failedCount) неудачных, \(partialCount) частичных из \(totalCount)"
    }
    
    /// Экспорт результатов тестирования
    func exportResults() -> String? {
        guard !testResults.isEmpty else { return nil }
        
        var report = "=== Отчет о тестировании Kaspi API ===\n"
        report += "Дата: \(DateFormatter.mediumDate.string(from: Date()))\n"
        report += "Общий статус: \(overallStatus)\n"
        report += "Сводка: \(getTestSummary())\n\n"
        
        for result in testResults {
            report += "📋 \(result.name)\n"
            report += "   Описание: \(result.description)\n"
            report += "   Статус: \(result.status)\n"
            
            if let duration = result.duration {
                report += "   Время: \(String(format: "%.2f", duration))s\n"
            }
            
            if let endpoint = result.endpoint {
                report += "   Endpoint: \(endpoint)\n"
            }
            
            if let message = result.message {
                report += "   Результат: \(message)\n"
            }
            
            report += "\n"
        }
        
        return report
    }
    
    /// Очистить результаты тестов
    func clearResults() {
        testResults = []
        overallStatus = .notStarted
        progress = 0.0
        currentTestName = ""
    }
}
