//
//  OrdersViewModel.swift
//  vektaApp
//
//  Created by Almas Kadeshov on 02.07.2025.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import CoreImage // ← Добавили импорт для QR-кода
import CoreImage.CIFilterBuiltins

// MARK: - Errors
enum OrdersError: LocalizedError {
    case authenticationRequired
    case networkError
    case invalidData
    case orderNotFound
    
    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "Требуется авторизация"
        case .networkError:
            return "Ошибка сети"
        case .invalidData:
            return "Некорректные данные"
        case .orderNotFound:
            return "Заказ не найден"
        }
    }
}

// MARK: - Statistics
struct OrdersStatistics {
    let totalOrders: Int
    let totalValue: Double
    let averageOrderValue: Double
    let statusBreakdown: [OrderStatus: Int]
}

// 🧠 ViewModel для управления заказами на склад
class OrdersViewModel: ObservableObject {
    
    // 📊 Данные заказов
    @Published var orders: [Order] = []
    @Published var filteredOrders: [Order] = []
    
    // 🔍 Поиск и фильтры
    @Published var searchText: String = "" {
        didSet {
            filterOrders()
        }
    }
    @Published var selectedStatus: OrderStatus? = nil {
        didSet {
            filterOrders()
        }
    }
    @Published var selectedWarehouse: String = "Все" {
        didSet {
            filterOrders()
        }
    }
    
    // 📱 Состояние интерфейса
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var isRefreshing: Bool = false
    
    // 🔥 Firebase
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    // 📈 Статистика
    var totalOrders: Int { orders.count }
    var pendingOrders: Int { orders.filter { $0.status == .pending }.count }
    var shippedOrders: Int { orders.filter { $0.status == .shipped }.count }
    var completedOrders: Int { orders.filter { $0.status == .completed }.count }
    
    // 📚 Доступные склады
    var warehouses: [String] {
        let allWarehouses = orders.map { $0.warehouseName }
        let uniqueWarehouses = Array(Set(allWarehouses)).sorted()
        return ["Все"] + uniqueWarehouses
    }
    
    init() {
        loadOrders()
    }
    
    deinit {
        listener?.remove()
    }
    
    // MARK: - Основные методы
    
    // 📦 Загрузить заказы
    func loadOrders() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Пользователь не авторизован"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Для разработки используем тестовые данные
        // В продакшне здесь будет загрузка из Firestore
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.orders = Order.sampleOrders
            self.filterOrders()
            self.isLoading = false
        }
        
        // TODO: Реальная загрузка из Firestore
        /*
         listener = db.collection("sellers").document(userId)
         .collection("orders")
         .order(by: "createdAt", descending: true)
         .addSnapshotListener { [weak self] snapshot, error in
         
         DispatchQueue.main.async {
         self?.isLoading = false
         
         if let error = error {
         self?.errorMessage = "Ошибка загрузки: \(error.localizedDescription)"
         return
         }
         
         guard let documents = snapshot?.documents else {
         self?.orders = []
         self?.filterOrders()
         return
         }
         
         self?.orders = documents.compactMap { doc in
         Order.fromFirestore(doc.data(), id: doc.documentID)
         }
         
         self?.filterOrders()
         }
         }
         */
    }
    
    // 🔄 Обновить заказы
    func refreshOrders() {
        isRefreshing = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.loadOrders()
            self.isRefreshing = false
        }
    }
    
    // 🔍 Фильтровать заказы
    private func filterOrders() {
        var filtered = orders
        
        // Фильтр по поиску
        if !searchText.isEmpty {
            filtered = filtered.filter { order in
                order.orderNumber.localizedCaseInsensitiveContains(searchText) ||
                order.warehouseName.localizedCaseInsensitiveContains(searchText) ||
                order.notes.localizedCaseInsensitiveContains(searchText) ||
                order.items.contains { item in
                    item.productName.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
        
        // Фильтр по статусу
        if let status = selectedStatus {
            filtered = filtered.filter { $0.status == status }
        }
        
        // Фильтр по складу
        if selectedWarehouse != "Все" {
            filtered = filtered.filter { $0.warehouseName == selectedWarehouse }
        }
        
        filteredOrders = filtered
    }
    
    // MARK: - Создание заказов
    
    // ➕ Создать новый заказ
    func createOrder(
        selectedProducts: [Product: Int], // Продукт и количество
        warehouseId: String,
        warehouseName: String,
        notes: String,
        priority: OrderPriority,
        estimatedDelivery: Date?
    ) async -> Bool {
        
        guard let userId = Auth.auth().currentUser?.uid,
              let userEmail = Auth.auth().currentUser?.email else {
            await MainActor.run {
                errorMessage = "Пользователь не авторизован"
            }
            return false
        }
        
        // ✅ Добавили валидацию
        do {
            try validateOrderData(
                selectedProducts: selectedProducts,
                warehouseName: warehouseName,
                notes: notes
            )
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            return false
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // Создаем товары заказа
        let orderItems = selectedProducts.map { (product, quantity) in
            OrderItem(
                id: UUID().uuidString,
                productSKU: product.id,
                productName: product.name,
                quantity: quantity,
                price: product.price,
                imageURL: product.imageURL,
                category: product.category
            )
        }
        
        // Генерируем данные заказа
        let orderNumber = Order.generateOrderNumber()
        let qrData = Order.generateQRData(
            orderNumber: orderNumber,
            sellerId: userId,
            warehouseId: warehouseId
        )
        
        // Создаем заказ
        let newOrder = Order(
            id: UUID().uuidString,
            orderNumber: orderNumber,
            sellerId: userId,
            sellerEmail: userEmail,
            warehouseId: warehouseId,
            warehouseName: warehouseName,
            items: orderItems,
            notes: notes,
            status: .pending,
            priority: priority,
            createdAt: Date(),
            updatedAt: Date(),
            estimatedDelivery: estimatedDelivery,
            qrCodeData: qrData
        )
        
        // Сохраняем в Firestore
        do {
            try await saveOrderToFirestore(newOrder)
            
            await MainActor.run {
                // Добавляем в локальный список
                self.orders.insert(newOrder, at: 0)
                self.filterOrders()
                self.isLoading = false
                self.successMessage = "✅ Заказ \(orderNumber) создан!"
                
                // Очищаем сообщение через 3 секунды
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.successMessage = nil
                }
            }
            
            return true
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Ошибка создания заказа: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    // 💾 Сохранить заказ в Firestore
    private func saveOrderToFirestore(_ order: Order) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw OrdersError.authenticationRequired
        }
        
        // TODO: Реальное сохранение в Firestore
        // Пока имитируем задержку
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 секунды
        
        /*
         let orderData = order.toDictionary()
         try await db.collection("sellers").document(userId)
         .collection("orders").document(order.id)
         .setData(orderData)
         */
    }
    
    // MARK: - Управление заказами
    
    // 📝 Обновить статус заказа (УЛУЧШЕННАЯ ВЕРСИЯ)
    func updateOrderStatus(_ order: Order, newStatus: OrderStatus) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Находим индекс заказа
            guard let index = orders.firstIndex(where: { $0.id == order.id }) else {
                throw OrdersError.orderNotFound
            }
            
            // Создаем обновленный заказ (неизменяемый подход)
            let updatedOrder = order.updatingStatus(newStatus)
            
            // TODO: Сохранение в Firestore
            try await saveOrderToFirestore(updatedOrder)
            
            await MainActor.run {
                // Обновляем локальные данные
                self.orders[index] = updatedOrder
                self.filterOrders()
                self.isLoading = false
                self.successMessage = "✅ Статус заказа обновлен"
                
                // Очищаем сообщение через 3 секунды
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.successMessage = nil
                }
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // 🗑️ Отменить заказ
    func cancelOrder(_ order: Order) async {
        await updateOrderStatus(order, newStatus: .cancelled)
    }
    
    // 📦 Отправить заказ
    func shipOrder(_ order: Order) async {
        await updateOrderStatus(order, newStatus: .shipped)
    }
    
    // MARK: - QR-код генерация
    
    // 🏷️ Генерировать QR-код для заказа
    func generateQRCode(for order: Order) -> String {
        return order.qrCodeData
    }
    
    func createQRCodeImage(from string: String) -> UIImage? {
        // Сократим данные для QR-кода
        let qrData = createCompactQRData(from: string)
        
        guard let data = qrData.data(using: .utf8) else {
            print("❌ Не удалось конвертировать строку в Data")
            return nil
        }
        
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            print("❌ QR фильтр недоступен")
            return nil
        }
        
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // Высокий уровень коррекции
        
        guard let outputImage = filter.outputImage else {
            print("❌ Не удалось создать QR изображение")
            return nil
        }
        
        // Увеличиваем размер QR-кода
        let scaleX = 300.0 / outputImage.extent.size.width
        let scaleY = 300.0 / outputImage.extent.size.height
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            print("❌ Не удалось создать CGImage")
            return nil
        }
        
        print("✅ QR-код успешно создан")
        return UIImage(cgImage: cgImage)
    }
    private func createCompactQRData(from originalData: String) -> String {
        // Извлекаем номер заказа из оригинальных данных
        let components = originalData.split(separator: ":")
        if components.count >= 2 {
            let orderNumber = String(components[1])
            // Возвращаем только номер заказа - этого достаточно для идентификации
            return orderNumber
        }
        
        // Если не удалось извлечь, используем первые 50 символов
        return String(originalData.prefix(50))
        
        // MARK: - Вспомогательные методы
        
        // 🎨 Получить цвет для статуса
        func colorForStatus(_ status: OrderStatus) -> Color {
            switch status {
            case .draft: return .gray
            case .pending: return .orange
            case .shipped: return .blue
            case .received: return .green
            case .completed: return .green
            case .cancelled: return .red
            }
        }
        
        // 🔍 Очистить фильтры
        func clearFilters() {
            searchText = ""
            selectedStatus = nil
            selectedWarehouse = "Все"
        }
        
        // 📊 Получить процент завершенных заказов
        var completionPercentage: Double {
            guard totalOrders > 0 else { return 0 }
            return Double(completedOrders) / Double(totalOrders) * 100
        }
        
        // 💰 Общая стоимость всех заказов
        var totalOrdersValue: Double {
            orders.reduce(0) { $0 + $1.totalValue }
        }
        
        var formattedTotalValue: String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "KZT"
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: totalOrdersValue)) ?? "\(Int(totalOrdersValue)) ₸"
        }
        
        // 🔍 Найти заказ по ID
        func findOrder(by id: String) -> Order? {
            return orders.first { $0.id == id }
        }
        
        // 📊 Статистика за период
        func getOrdersStatistics(for period: DateInterval) -> OrdersStatistics {
            let periodOrders = orders.filter { period.contains($0.createdAt) }
            
            return OrdersStatistics(
                totalOrders: periodOrders.count,
                totalValue: periodOrders.reduce(0) { $0 + $1.totalValue },
                averageOrderValue: periodOrders.isEmpty ? 0 : periodOrders.reduce(0) { $0 + $1.totalValue } / Double(periodOrders.count),
                statusBreakdown: Dictionary(grouping: periodOrders, by: { $0.status })
                    .mapValues { $0.count }
            )
        }
        
        // ✅ Валидация данных заказа
        private func validateOrderData(
            selectedProducts: [Product: Int],
            warehouseName: String,
            notes: String
        ) throws {
            // Проверяем что выбраны товары
            guard !selectedProducts.isEmpty else {
                throw OrdersError.invalidData
            }
            
            // Проверяем что выбран склад
            guard !warehouseName.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw OrdersError.invalidData
            }
            
            // Проверяем что количества корректные
            for (_, quantity) in selectedProducts {
                guard quantity > 0 else {
                    throw OrdersError.invalidData
                }
            }
        }
    }
    
    // MARK: - Расширения для удобства
    extension OrdersViewModel {
        
        // 📅 Заказы за сегодня
        var todayOrders: [Order] {
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
            
            return orders.filter { order in
                order.createdAt >= today && order.createdAt < tomorrow
            }
        }
        
        // ⚡ Срочные заказы
        var urgentOrders: [Order] {
            orders.filter { $0.priority == .urgent && $0.status != .completed && $0.status != .cancelled }
        }
        
        // 📦 Заказы готовые к отправке
        var readyToShipOrders: [Order] {
            orders.filter { $0.status == .pending }
        }
    }
}
