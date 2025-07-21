//
//  ProductsViewModel.swift
//  vektaApp
//
//  Created by Almas Kadeshov on 30.06.2025.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// 🧠 ViewModel для управления товарами
class ProductsViewModel: ObservableObject {
    
    // 📊 Данные товаров
    @Published var products: [Product] = []
    @Published var filteredProducts: [Product] = []
    
    // 🔍 Поиск и фильтры
    @Published var searchText: String = "" {
        didSet {
            filterProducts()
        }
    }
    @Published var selectedStatus: ProductStatus? = nil {
        didSet {
            filterProducts()
        }
    }
    @Published var selectedCategory: String = "Все" {
        didSet {
            filterProducts()
        }
    }
    
    // 📱 Состояние интерфейса
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var isRefreshing: Bool = false
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    
    // 🔥 Firebase и Services
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private let kaspiService = KaspiAPIService()
    
    // 📚 Категории товаров
    var categories: [String] {
        let allCategories = products.map { $0.category }
        let uniqueCategories = Array(Set(allCategories)).sorted()
        return ["Все"] + uniqueCategories
    }
    
    // 📈 Статистика
    var totalProducts: Int { products.count }
    var inStockProducts: Int { products.filter { $0.status == .inStock }.count }
    var outOfStockProducts: Int { products.filter { $0.status == .outOfStock }.count }
    var inactiveProducts: Int { products.filter { $0.status == .inactive }.count }
    
    // 📊 Процентные показатели
    var inStockPercentage: Double {
        guard totalProducts > 0 else { return 0 }
        return Double(inStockProducts) / Double(totalProducts) * 100
    }
    
    var outOfStockPercentage: Double {
        guard totalProducts > 0 else { return 0 }
        return Double(outOfStockProducts) / Double(totalProducts) * 100
    }
    
    // 💰 Общая стоимость товаров
    var totalInventoryValue: Double {
        products.reduce(0) { total, product in
            let totalStock = product.totalStock
            return total + (product.price * Double(totalStock))
        }
    }
    
    var formattedTotalValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "KZT"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: totalInventoryValue)) ?? "\(Int(totalInventoryValue)) ₸"
    }
    
    init() {
        loadProducts()
        setupKaspiServiceObserver()
    }
    
    deinit {
        listener?.remove()
    }
    
    // MARK: - Основные методы
    
    // 📦 Загрузить товары
    func loadProducts() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Пользователь не авторизован"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Сначала пробуем загрузить из Firestore
        listener = db.collection("sellers").document(userId)
            .collection("products")
            .addSnapshotListener { [weak self] snapshot, error in
                
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.errorMessage = "Ошибка загрузки: \(error.localizedDescription)"
                        // Fallback к тестовым данным при ошибке
                        self?.products = Product.sampleProducts
                        self?.filterProducts()
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        // Если нет товаров в Firestore, используем тестовые данные
                        self?.products = Product.sampleProducts
                        self?.filterProducts()
                        return
                    }
                    
                    // Парсим товары из Firestore
                    self?.products = documents.compactMap { doc in
                        Product.fromFirestore(doc.data(), id: doc.documentID)
                    }
                    
                    // Если товаров нет, добавляем тестовые
                    if self?.products.isEmpty == true {
                        self?.products = Product.sampleProducts
                    }
                    
                    self?.filterProducts()
                    print("✅ Загружено \(self?.products.count ?? 0) товаров")
                }
            }
    }
    
    // 🔄 Обновить товары
    func refreshProducts() {
        isRefreshing = true
        
        Task {
            // Проверяем наличие токена Kaspi API
            let hasKaspiToken = await checkKaspiAPIAvailability()
            
            if hasKaspiToken {
                // Если есть токен, синхронизируем с Kaspi
                await syncWithKaspiAPI()
            } else {
                // Иначе просто обновляем из Firestore
                await refreshFromFirestore()
            }
            
            await MainActor.run {
                self.isRefreshing = false
            }
        }
    }
    
    // 📱 Обновление из Firestore
    private func refreshFromFirestore() async {
        await MainActor.run {
            loadProducts()
        }
        
        // Имитируем задержку
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
    }
    
    // 🔍 Фильтровать товары
    private func filterProducts() {
        var filtered = products
        
        // Фильтр по поиску
        if !searchText.isEmpty {
            filtered = filtered.filter { product in
                product.name.localizedCaseInsensitiveContains(searchText) ||
                product.description.localizedCaseInsensitiveContains(searchText) ||
                product.kaspiProductId.localizedCaseInsensitiveContains(searchText) ||
                product.category.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Фильтр по статусу
        if let status = selectedStatus {
            filtered = filtered.filter { $0.status == status }
        }
        
        // Фильтр по категории
        if selectedCategory != "Все" {
            filtered = filtered.filter { $0.category == selectedCategory }
        }
        
        filteredProducts = filtered
    }
    
    // MARK: - Kaspi API интеграция
    
    // 🔗 Настроить наблюдение за Kaspi сервисом
    private func setupKaspiServiceObserver() {
        kaspiService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isSyncing)
        
        kaspiService.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$errorMessage)
        
        kaspiService.$lastSyncDate
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastSyncDate)
    }
    
    // 🔄 Синхронизация с Kaspi API
    func syncWithKaspiAPI() async {
        await MainActor.run {
            isSyncing = true
            errorMessage = nil
        }
        
        do {
            // Проверяем токен
            let isValid = try await kaspiService.validateToken()
            guard isValid else {
                await MainActor.run {
                    self.errorMessage = "Неверный API токен. Проверьте настройки Kaspi API"
                    self.isSyncing = false
                }
                return
            }
            
            // Синхронизируем товары
            let syncedProducts = try await kaspiService.syncAllProducts()
            
            await MainActor.run {
                self.products = syncedProducts
                self.filterProducts()
                self.isSyncing = false
                self.lastSyncDate = Date()
                
                // Показываем успешное сообщение
                self.successMessage = "✅ Синхронизировано \(syncedProducts.count) товаров из Kaspi"
                
                // Очищаем сообщение через 3 секунды
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.successMessage = nil
                }
            }
            
        } catch {
            await MainActor.run {
                self.isSyncing = false
                if let kaspiError = error as? KaspiAPIError {
                    self.errorMessage = kaspiError.errorDescription
                } else {
                    self.errorMessage = "Ошибка синхронизации: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // 🔍 Проверить доступность Kaspi API
    private func checkKaspiAPIAvailability() async -> Bool {
        return await kaspiService.checkAPIHealth()
    }
    
    // 📊 Проверить статус API
    func checkKaspiAPIStatus() async -> Bool {
        return await kaspiService.checkAPIHealth()
    }
    
    // MARK: - Управление товарами
    
    // ➕ Добавить товар в отгрузку на склад
    func addToWarehouseShipment(product: Product) {
        guard product.status == .inStock && product.totalStock > 0 else {
            errorMessage = "Товар недоступен для отгрузки"
            return
        }
        
        // TODO: Интеграция с OrdersViewModel для создания заказа
        successMessage = "Товар '\(product.name)' добавлен в отгрузку"
        
        // Очищаем сообщение через 2 секунды
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.successMessage = nil
        }
        
        print("Добавлен в отгрузку: \(product.name)")
    }
    
    // 📊 Обновить остатки товара
    func updateProductStock(productId: String, warehouseId: String, newQuantity: Int) {
        Task {
            do {
                // Обновляем в Kaspi API
                try await kaspiService.updateStock(
                    productId: productId,
                    warehouseId: warehouseId,
                    quantity: newQuantity
                )
                
                // Обновляем локальные данные
                if let index = products.firstIndex(where: { $0.id == productId }) {
                    await MainActor.run {
                        var updatedProduct = self.products[index]
                        var updatedStock = updatedProduct.warehouseStock
                        updatedStock[warehouseId] = newQuantity
                        
                        // Создаем новый товар с обновленными остатками
                        let newProduct = Product(
                            id: updatedProduct.id,
                            kaspiProductId: updatedProduct.kaspiProductId,
                            name: updatedProduct.name,
                            description: updatedProduct.description,
                            price: updatedProduct.price,
                            category: updatedProduct.category,
                            imageURL: updatedProduct.imageURL,
                            status: newQuantity > 0 ? .inStock : .outOfStock,
                            warehouseStock: updatedStock,
                            createdAt: updatedProduct.createdAt,
                            updatedAt: Date(),
                            isActive: updatedProduct.isActive
                        )
                        
                        self.products[index] = newProduct
                        self.filterProducts()
                        
                        // Сохраняем в Firestore
                        self.saveProductToFirestore(newProduct)
                    }
                }
                
                await MainActor.run {
                    self.successMessage = "✅ Остатки обновлены"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.successMessage = nil
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "Ошибка обновления остатков: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // 🗑️ Деактивировать товар
    func deactivateProduct(product: Product) {
        Task {
            await MainActor.run {
                if let index = self.products.firstIndex(where: { $0.id == product.id }) {
                    let deactivatedProduct = Product(
                        id: product.id,
                        kaspiProductId: product.kaspiProductId,
                        name: product.name,
                        description: product.description,
                        price: product.price,
                        category: product.category,
                        imageURL: product.imageURL,
                        status: .inactive,
                        warehouseStock: product.warehouseStock,
                        createdAt: product.createdAt,
                        updatedAt: Date(),
                        isActive: false
                    )
                    
                    self.products[index] = deactivatedProduct
                    self.filterProducts()
                    
                    // Сохраняем в Firestore
                    self.saveProductToFirestore(deactivatedProduct)
                    
                    self.successMessage = "Товар '\(product.name)' деактивирован"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.successMessage = nil
                    }
                }
            }
        }
        
        print("Деактивирован товар: \(product.name)")
    }
    
    // 💾 Сохранить товар в Firestore
    private func saveProductToFirestore(_ product: Product) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let productRef = db.collection("sellers").document(userId)
            .collection("products").document(product.id)
        
        productRef.setData(product.toDictionary()) { error in
            if let error = error {
                print("❌ Ошибка сохранения товара: \(error)")
            } else {
                print("✅ Товар сохранен в Firestore")
            }
        }
    }
    
    // MARK: - Вспомогательные методы
    
    // 🎨 Получить цвет для статуса
    func colorForStatus(_ status: ProductStatus) -> Color {
        switch status {
        case .inStock:
            return .green
        case .outOfStock:
            return .orange
        case .inactive:
            return .gray
        }
    }
    
    // 🔍 Очистить фильтры
    func clearFilters() {
        searchText = ""
        selectedStatus = nil
        selectedCategory = "Все"
    }
    
    // 🔍 Найти товар по ID
    func findProduct(by id: String) -> Product? {
        return products.first { $0.id == id }
    }
    
    // 📊 Получить товары по категории
    func getProducts(by category: String) -> [Product] {
        return products.filter { $0.category == category }
    }
    
    // ⚠️ Товары с низкими остатками (меньше 5 штук)
    var lowStockProducts: [Product] {
        return products.filter { $0.totalStock > 0 && $0.totalStock < 5 }
    }
    
    // 🔥 Популярные категории (с наибольшим количеством товаров)
    var popularCategories: [(category: String, count: Int)] {
        let categoryGroups = Dictionary(grouping: products, by: { $0.category })
        return categoryGroups.map { (category: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { $0 }
    }
    
    // 💰 Самые дорогие товары
    var expensiveProducts: [Product] {
        return products.sorted { $0.price > $1.price }.prefix(10).map { $0 }
    }
    
    // 🎯 Товары без изображений
    var productsWithoutImages: [Product] {
        return products.filter { $0.imageURL.isEmpty || $0.imageURL == "https://example.com/photo.jpg" }
    }
    
    // 📈 Статистика по категориям
    func getCategoryStatistics() -> [String: (total: Int, inStock: Int, value: Double)] {
        var stats: [String: (total: Int, inStock: Int, value: Double)] = [:]
        
        for product in products {
            let category = product.category
            let currentStats = stats[category] ?? (total: 0, inStock: 0, value: 0.0)
            
            stats[category] = (
                total: currentStats.total + 1,
                inStock: currentStats.inStock + (product.status == .inStock ? 1 : 0),
                value: currentStats.value + (product.price * Double(product.totalStock))
            )
        }
        
        return stats
    }
    
    // 🔄 Получить статистику синхронизации
    var syncStatistics: (requests: Int, lastSync: Date?) {
        return kaspiService.apiStatistics
    }
    
    // 🧹 Очистить сообщения
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}
