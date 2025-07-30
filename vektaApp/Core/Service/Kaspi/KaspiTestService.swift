import Foundation
import SwiftUI

@MainActor
class KaspiTestService: ObservableObject {
    // MARK: — Public API
    @Published var testResults: [TestResult] = []
    @Published var isRunning = false
    @Published var overallStatus: TestStatus = .notStarted

    private let kaspiService = KaspiAPIService()

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
    }

    // MARK: — Run Suite

    func runAllTests() async {
        isRunning = true
        overallStatus = .running
        testResults = []

        let tests: [(String, String, () async -> TestResult)] = [
            ("API Token",            "Проверка наличия токена",     testAPIToken),
            ("Token Validation",     "Валидация токена",           testTokenValidation),
            ("Products Sync",        "Синхронизация товаров",      testProductsSync),
            ("SMS Request",          "Отправка SMS кода",          testSMSRequest),
            ("Delivery Confirmation","Подтверждение доставки",      testDeliveryConfirmation),
            ("Stock Update",         "Обновление остатков",        testStockUpdate),
            ("Warehouses",           "Загрузка списка складов",    testWarehouses),
            ("Rate Limiting",        "Проверка лимитов запросов",  testRateLimiting)
        ]

        var passed = 0, failed = 0

        for (name, desc, fn) in tests {
            let res = await fn()
            testResults.append(res)
            if res.status == .passed { passed += 1 }
            if res.status == .failed { failed += 1 }
        }

        overallStatus = (failed == 0 ? .passed : (passed == 0 ? .failed : .partial))
        isRunning = false
    }

    // MARK: — Tests

    private func testAPIToken() async -> TestResult {
        let start = Date()
        let ok = (kaspiService.apiToken ?? "").isEmpty == false
        let dur = Date().timeIntervalSince(start)
        return TestResult(
            name: "API Token",
            description: "Проверка наличия токена",
            status: ok ? .passed : .failed,
            message: ok ? "Токен есть" : "Токен отсутствует",
            duration: dur
        )
    }

    private func testTokenValidation() async -> TestResult {
        let start = Date()
        do {
            let ok = await kaspiService.checkAPIHealth()
            let dur = Date().timeIntervalSince(start)
            return TestResult(
                name: "Token Validation",
                description: "Валидация токена",
                status: ok ? .passed : .failed,
                message: ok ? "Токен валиден" : "Токен невалиден",
                duration: dur
            )
        } catch {
            let dur = Date().timeIntervalSince(start)
            return TestResult(
                name: "Token Validation",
                description: "Валидация токена",
                status: .failed,
                message: error.localizedDescription,
                duration: dur,
                error: error
            )
        }
    }

    private func testProductsSync() async -> TestResult {
        let start = Date()
        do {
            let products = try await kaspiService.syncAllProducts()
            let dur = Date().timeIntervalSince(start)
            return TestResult(
                name: "Products Sync",
                description: "Синхронизация товаров",
                status: .passed,
                message: "Получено \(products.count) товаров",
                duration: dur
            )
        } catch {
            let dur = Date().timeIntervalSince(start)
            return TestResult(
                name: "Products Sync",
                description: "Синхронизация товаров",
                status: .failed,
                message: error.localizedDescription,
                duration: dur,
                error: error
            )
        }
    }

    private func testSMSRequest() async -> TestResult {
        let start = Date()
        do {
            let id = try await kaspiService.requestSMSCode(
                orderId: "TEST-123", trackingNumber: "TRK-456", customerPhone: "+7777"
            )
            let dur = Date().timeIntervalSince(start)
            return TestResult(
                name: "SMS Request",
                description: "Отправка SMS",
                status: .passed,
                message: "ID \(id)",
                duration: dur
            )
        } catch {
            let dur = Date().timeIntervalSince(start)
            return TestResult(
                name: "SMS Request",
                description: "Отправка SMS",
                status: .failed,
                message: error.localizedDescription,
                duration: dur,
                error: error
            )
        }
    }

    private func testDeliveryConfirmation() async -> TestResult {
        let start = Date()
        do {
            let ok = try await kaspiService.confirmDelivery(
                orderId: "TEST-123", trackingNumber: "TRK-456", smsCode: "123456"
            )
            let dur = Date().timeIntervalSince(start)
            return TestResult(
                name: "Delivery Confirmation",
                description: "Подтверждение доставки",
                status: ok ? .passed : .failed,
                message: ok ? "Подтверждено" : "Не подтверждено",
                duration: dur
            )
        } catch {
            let dur = Date().timeIntervalSince(start)
            return TestResult(
                name: "Delivery Confirmation",
                description: "Подтверждение доставки",
                status: .failed,
                message: error.localizedDescription,
                duration: dur,
                error: error
            )
        }
    }

    private func testStockUpdate() async -> TestResult {
        let start = Date()
        do {
            try await kaspiService.updateStock(
                productId: "P1", warehouseId: "W1", quantity: 5, operation: .set
            )
            let dur = Date().timeIntervalSince(start)
            return TestResult(
                name: "Stock Update",
                description: "Обновление остатков",
                status: .passed,
                message: "OK",
                duration: dur
            )
        } catch {
            let dur = Date().timeIntervalSince(start)
            return TestResult(
                name: "Stock Update",
                description: "Обновление остатков",
                status: .failed,
                message: error.localizedDescription,
                duration: dur,
                error: error
            )
        }
    }

    private func testWarehouses() async -> TestResult {
        let start = Date()
        do {
            let list = try await kaspiService.loadWarehouses()
            let dur = Date().timeIntervalSince(start)
            return TestResult(
                name: "Warehouses",
                description: "Загрузка складов",
                status: .passed,
                message: "Получено \(list.count)",
                duration: dur
            )
        } catch {
            let dur = Date().timeIntervalSince(start)
            return TestResult(
                name: "Warehouses",
                description: "Загрузка складов",
                status: .failed,
                message: error.localizedDescription,
                duration: dur,
                error: error
            )
        }
    }

    private func testRateLimiting() async -> TestResult {
        let start = Date()
        var success = 0, limited = false, lastErr: Error?
        for _ in 0..<5 {
            do {
                _ = try await kaspiService.checkAPIHealth()
                success += 1
            } catch {
                lastErr = error
                limited = true
                break
            }
        }
        let dur = Date().timeIntervalSince(start)
        let msg = limited
            ? "Rate limit hit after \(success)"
            : "All \(success) passed"
        return TestResult(
            name: "Rate Limiting",
            description: "Проверка лимитов",
            status: .passed,
            message: msg,
            duration: dur,
            error: limited ? lastErr : nil
        )
    }
}
