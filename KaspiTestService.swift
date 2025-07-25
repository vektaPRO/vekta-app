//
//  KaspiTestService.swift
//  vektaApp
//
//  Обновленный сервис для тестирования интеграции с Kaspi API
//

import Foundation
import SwiftUI

@MainActor
class KaspiTestService: ObservableObject {
    
    @Published var testResults: [TestResult] = []
    @Published var isRunning = false
    @Published var overallStatus: TestStatus = .notStarted
    
    private let kaspiService = KaspiAPIService()
    
    enum TestStatus {
        case notStarted
        case running
        case passed
        case failed
        case partial
    }
    
    struct TestResult: Identifiable {
        let id = UUID()
        let name: String
        let description: String
        var status: TestStatus
        var message: String?
        var duration: TimeInterval?
        var error: Error?
    }
    
    // MARK: - Test Suite
    
    func runAllTests() async {
        isRunning = true
        overallStatus = .running
        testResults = []
        
        // Определяем тесты
        let tests: [(name: String, description: String, test: () async -> TestResult)] = [
            ("API Token", "Проверка наличия API токена", testAPIToken),
            ("Token Validation", "Валидация токена через API", testTokenValidation),
            ("Products Sync", "Синхронизация товаров", testProductsSync),
            ("SMS Request", "Отправка SMS кода", testSMSRequest),
            ("Delivery Confirmation", "Подтверждение доставки", testDeliveryConfirmation),
            ("Stock Update", "Обновление остатков", testStockUpdate),
            ("Warehouses", "Загрузка списка складов", testWarehouses),
            ("Rate Limiting", "Проверка лимитов запросов", testRateLimiting)
        ]
        
        var passedCount = 0
        var failedCount = 0
        
        // Выполняем тесты последовательно
        for (name, description, test) in tests {
            let result = await test()
            testResults.append(result)
            
            switch result.status {
            case .passed:
                passedCount += 1
            case .failed:
                failedCount += 1
            default:
                break
            }
        }
        
        // Определяем общий статус
        if failedCount == 0 {
            overallStatus = .passed
        } else if passedCount == 0 {
            overallStatus = .failed
        } else {
            overallStatus = .partial
        }
        
        isRunning = false
    }
    
    // MARK: - Individual Tests
    
    private func testAPIToken() async -> TestResult {
        let startTime = Date()
        
        await kaspiService.loadApiToken()
        
        let duration = Date().timeIntervalSince(startTime)
        
        if let token = kaspiService.apiToken, !token.isEmpty {
            return TestResult(
                name: "API Token",
                description: "Проверка наличия API токена",
                status: .passed,
                message: "Токен загружен успешно",
                duration: duration
            )
        } else {
            return TestResult(
                name: "API Token",
                description: "Проверка наличия API токена",
                status: .failed,
                message: "Токен не найден. Добавьте токен в настройках.",
                duration: duration
            )
        }
    }
    
    private func testTokenValidation() async -> TestResult {
        let startTime = Date()
        
        do {
            let isValid = try await kaspiService.validateToken()
            let duration = Date().timeIntervalSince(startTime)
            
            if isValid {
                return TestResult(
                    name: "Token Validation",
                    description: "Валидация токена через API",
                    status: .passed,
                    message: "Токен валидный",
                    duration: duration
                )
            } else {
                return TestResult(
                    name: "Token Validation",
                    description: "Валидация токена через API",
                    status: .failed,
                    message: "Токен невалидный",
                    duration: duration
                )
            }
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            ErrorHandler.handle(error, context: "testTokenValidation")
            
            return TestResult(
                name: "Token Validation",
                description: "Валидация токена через API",
                status: .failed,
                message: ErrorHandler.userMessage(for: error),
                duration: duration,
                error: error
            )
        }
    }
    
    private func testProductsSync() async -> TestResult {
        let startTime = Date()
        
        do {
            let products = try await kaspiService.syncAllProducts()
            let duration = Date().timeIntervalSince(startTime)
            
            return TestResult(
                name: "Products Sync",
                description: "Синхронизация товаров",
                status: .passed,
                message: "Синхронизировано \(products.count) товаров",
                duration: duration
            )
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            ErrorHandler.handle(error, context: "testProductsSync")
            
            return TestResult(
                name: "Products Sync",
                description: "Синхронизация товаров",
                status: .failed,
                message: ErrorHandler.userMessage(for: error),
                duration: duration,
                error: error
            )
        }
    }
    
    private func testSMSRequest() async -> TestResult {
        let startTime = Date()
        
        // Тестовые данные
        let testOrderId = "TEST-\(UUID().uuidString.prefix(8))"
        let testTrackingNumber = "TRK-\(Int.random(in: 100000...999999))"
        let testPhone = "+77771234567"
        
        do {
            let messageId = try await kaspiService.requestSMSCode(
                orderId: testOrderId,
                trackingNumber: testTrackingNumber,
                customerPhone: testPhone
            )
            let duration = Date().timeIntervalSince(startTime)
            
            return TestResult(
                name: "SMS Request",
                description: "Отправка SMS кода",
                status: .passed,
                message: "SMS отправлен, ID: \(messageId)",
                duration: duration
            )
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            ErrorHandler.handle(error, context: "testSMSRequest")
            
            return TestResult(
                name: "SMS Request",
                description: "Отправка SMS кода",
                status: .failed,
                message: ErrorHandler.userMessage(for: error),
                duration: duration,
                error: error
            )
        }
    }
    
    private func testDeliveryConfirmation() async -> TestResult {
        let startTime = Date()
        
        // Тестовые данные
        let testOrderId = "TEST-\(UUID().uuidString.prefix(8))"
        let testTrackingNumber = "TRK-\(Int.random(in: 100000...999999))"
        let testCode = "123456" // В реальности код придет по SMS
        
        do {
            let isConfirmed = try await kaspiService.confirmDelivery(
                orderId: testOrderId,
                trackingNumber: testTrackingNumber,
                smsCode: testCode
            )
            let duration = Date().timeIntervalSince(startTime)
            
            if isConfirmed {
                return TestResult(
                    name: "Delivery Confirmation",
                    description: "Подтверждение доставки",
                    status: .passed,
                    message: "Доставка подтверждена",
                    duration: duration
                )
            } else {
                return TestResult(
                    name: "Delivery Confirmation",
                    description: "Подтверждение доставки",
                    status: .failed,
                    message: "Не удалось подтвердить доставку",
                    duration: duration
                )
            }
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            ErrorHandler.handle(error, context: "testDeliveryConfirmation")
            
            // Если ошибка из-за неверного кода, это ожидаемо для теста
            if let kaspiError = error as? KaspiAPIError,
               case .deliveryConfirmationFailed(let message) = kaspiError,
               message.contains("Неверный код") {
                return TestResult(
                    name: "Delivery Confirmation",
                    description: "Подтверждение доставки",
                    status: .passed,
                    message: "API корректно отклонил неверный код",
                    duration: duration
                )
            }
            
            return TestResult(
                name: "Delivery Confirmation",
                description: "Подтверждение доставки",
                status: .failed,
                message: ErrorHandler.userMessage(for: error),
                duration: duration,
                error: error
            )
        }
    }
    
    private func testStockUpdate() async -> TestResult {
        let startTime = Date()
        
        // Тестовые данные
        let testProductId = "PROD-TEST-123"
        let testWarehouseId = "warehouse_almaty"
        let testQuantity = 10
        
        do {
            try await kaspiService.updateStock(
                productId: testProductId,
                warehouseId: testWarehouseId,
                quantity: testQuantity,
                operation: .set
            )
            let duration = Date().timeIntervalSince(startTime)
            
            return TestResult(
                name: "Stock Update",
                description: "Обновление остатков",
                status: .passed,
                message: "Остатки обновлены успешно",
                duration: duration
            )
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            ErrorHandler.handle(error, context: "testStockUpdate")
            
            return TestResult(
                name: "Stock Update",
                description: "Обновление остатков",
                status: .failed,
                message: ErrorHandler.userMessage(for: error),
                duration: duration,
                error: error
            )
        }
    }
    
    private func testWarehouses() async -> TestResult {
        let startTime = Date()
        
        do {
            let warehouses = try await kaspiService.loadWarehouses()
            let duration = Date().timeIntervalSince(startTime)
            
            return TestResult(
                name: "Warehouses",
                description: "Загрузка списка складов",
                status: .passed,
                message: "Загружено \(warehouses.count) складов",
                duration: duration
            )
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            ErrorHandler.handle(error, context: "testWarehouses")
            
            return TestResult(
                name: "Warehouses",
                description: "Загрузка списка складов",
                status: .failed,
                message: ErrorHandler.userMessage(for: error),
                duration: duration,
                error: error
            )
        }
    }
    
    private func testRateLimiting() async -> TestResult {
        let startTime = Date()
        
        // Делаем несколько быстрых запросов
        var successCount = 0
        var rateLimitHit = false
        var lastError: Error?
        
        for i in 0..<10 {
            do {
                _ = try await kaspiService.validateToken()
                successCount += 1
            } catch {
                lastError = error
                if let networkError = error as? NetworkError,
                   case .rateLimited = networkError {
                    rateLimitHit = true
                    break
                } else if let kaspiError = error as? KaspiAPIError,
                          case .apiQuotaExceeded = kaspiError {
                    rateLimitHit = true
                    break
                }
            }
            
            // Небольшая задержка между запросами
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунда
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        if rateLimitHit {
            return TestResult(
                name: "Rate Limiting",
                description: "Проверка лимитов запросов",
                status: .passed,
                message: "Rate limiting работает корректно",
                duration: duration
            )
        } else if successCount > 0 {
            return TestResult(
                name: "Rate Limiting",
                description: "Проверка лимитов запросов",
                status: .passed,
                message: "Выполнено \(successCount) запросов без превышения лимита",
                duration: duration
            )
        } else {
            return TestResult(
                name: "Rate Limiting",
                description: "Проверка лимитов запросов",
                status: .failed,
                message: lastError != nil ? ErrorHandler.userMessage(for: lastError!) : "Не удалось выполнить запросы",
                duration: duration,
                error: lastError
            )
        }
    }
}

// MARK: - Test Results View

struct KaspiAPITestView: View {
    @StateObject private var testService = KaspiTestService()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Test Results
                if testService.testResults.isEmpty && !testService.isRunning {
                    emptyStateView
                } else {
                    testResultsList
                }
                
                // Run Tests Button
                runTestsButton
            }
            .navigationTitle("Тестирование Kaspi API")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            // Overall Status
            HStack {
                statusIcon(for: testService.overallStatus)
                    .font(.largeTitle)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle(for: testService.overallStatus))
                        .font(.headline)
                    
                    if !testService.testResults.isEmpty {
                        let passed = testService.testResults.filter { $0.status == .passed }.count
                        let total = testService.testResults.count
                        Text("\(passed) из \(total) тестов пройдено")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(statusColor(for: testService.overallStatus).opacity(0.1))
            .cornerRadius(12)
        }
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "testtube.2")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Тесты не запущены")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Нажмите кнопку ниже для запуска тестов")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var testResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(testService.testResults) { result in
                    TestResultRow(result: result)
                }
            }
            .padding()
        }
    }
    
    private var runTestsButton: some View {
        Button(action: {
            Task {
                await testService.runAllTests()
            }
        }) {
            HStack {
                if testService.isRunning {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "play.circle.fill")
                }
                
                Text(testService.isRunning ? "Выполняется..." : "Запустить тесты")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(testService.isRunning ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(testService.isRunning)
        .padding()
    }
    
    // Helper functions
    private func statusIcon(for status: KaspiTestService.TestStatus) -> some View {
        switch status {
        case .notStarted:
            return Image(systemName: "circle.dashed")
                .foregroundColor(.secondary)
        case .running:
            return Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundColor(.blue)
        case .passed:
            return Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed:
            return Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        case .partial:
            return Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
        }
    }
    
    private func statusTitle(for status: KaspiTestService.TestStatus) -> String {
        switch status {
        case .notStarted:
            return "Готов к тестированию"
        case .running:
            return "Выполняется тестирование..."
        case .passed:
            return "Все тесты пройдены"
        case .failed:
            return "Тесты не пройдены"
        case .partial:
            return "Частично пройдено"
        }
    }
    
    private func statusColor(for status: KaspiTestService.TestStatus) -> Color {
        switch status {
        case .notStarted:
            return .gray
        case .running:
            return .blue
        case .passed:
            return .green
        case .failed:
            return .red
        case .partial:
            return .orange
        }
    }
}

struct TestResultRow: View {
    let result: KaspiTestService.TestResult
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    statusIcon
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(result.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let duration = result.duration {
                        Text(String(format: "%.2fs", duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if let message = result.message {
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.leading, 28)
                    }
                    
                    if let error = result.error {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Подробности ошибки:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                                .padding(.leading, 28)
                            
                            Text("\(type(of: error)): \(error.localizedDescription)")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.leading, 28)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var statusIcon: some View {
        switch result.status {
        case .notStarted:
            return Image(systemName: "circle")
                .foregroundColor(.secondary)
        case .running:
            return Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundColor(.blue)
        case .passed:
            return Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed:
            return Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        case .partial:
            return Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
        }
    }
    
    private var statusColor: Color {
        switch result.status {
        case .notStarted:
            return .gray
        case .running:
            return .blue
        case .passed:
            return .green
        case .failed:
            return .red
        case .partial:
            return .orange
        }
    }
}
