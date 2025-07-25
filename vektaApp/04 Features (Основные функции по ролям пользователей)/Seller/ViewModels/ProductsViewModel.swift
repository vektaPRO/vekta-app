//
//  ProductsViewModel.swift
//  vektaApp
//
//  Created by Almas Kadeshov on 30.06.2025.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

// 🧠 ViewModel для управления товарами
@MainActor
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
    @Published var syncProgress: Double = 0.0
    
    // 🔥 Firebase и Services
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    let kaspiService = KaspiAPIService()
    private var cancellables = Set<AnyCancellable>()
    
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
        setupKaspiServiceObserver()
        loadProducts()
    }
    
    deinit {
        listener?.remove()
        cancellables.removeAll()
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
        
        // Загружаем из Firestore
        listener = db.collection("sellers").document(userId)
            .collection("products")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    self.isLoading = false
                    
                    if let error = error {
                        self.errorMessage = "Ошибка загрузки: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self.products = []
                        self.filterProducts()
                        return
                    }
                    
                    // Парсим товары из Firestore
                    self.products = documents.compactMap { doc in
                        Product.fromFirestore(doc.data(), id: doc.documentID)
                    }
                    
                    self.filterProducts()
                    print("✅ Загружено \(self.products.count) товаров из базы данных")
                    
                    // Проверяем дату последней синхронизации
                    self.checkLastSyncDate()
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
            
            self.isRefreshing = false
        }
    }
    
    // 📱 Обновление из Firestore
    private func refreshFromFirestore() async {
        loadProducts()
        
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
            .sink { [weak self] isLoading in
                self?.isSyncing = isLoading
            }
            .store(in: &cancellables)
        
        kaspiService.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] errorMessage in
                if errorMessage != nil {
                    self?.errorMessage = errorMessage
                }
            }
            .store(in: &cancellables)
        
        kaspiService.$lastSyncDate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] lastSyncDate in
                self?.lastSyncDate = lastSyncDate
                if lastSyncDate != nil {
                    Task {
                        await self?.saveLastSyncDate(lastSyncDate!)
                    }
                }
            }
            .store(in: &cancellables)
        
        kaspiService.$syncProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.syncProgress = progress
            }
            .store(in: &cancellables)
    }
    
    // 🔄 Синхронизация с Kaspi API
    func syncWithKaspiAPI() async {
        isSyncing = true
        errorMessage = nil
        syncProgress = 0.0
        
        do {
            // Проверяем токен
            let isValid = try await kaspiService.validateToken()
            guard isValid else {
                self.errorMessage = "Неверный API токен. Проверьте настройки Kaspi API"
                self.isSyncing = false
                return
            }
            
            // Синхронизируем товары
            let syncedProducts = try await kaspiService.syncAllProducts()
            
            // Заменяем все товары на синхронизированные
            self.products = syncedProducts
            self.filterProducts()
            self.isSyncing = false
            self.lastSyncDate = Date()
            self.syncProgress = 1.0
            
            // Показываем успешное сообщение
            self.successMessage = "✅ Синхронизировано \(syncedProducts.count) товаров из Kaspi"
            
            // Очищаем сообщение через 3 секунды
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.successMessage = nil
                self.syncProgress = 0.0
            }
            
        } catch {
            self.isSyncing = false
            self.syncProgress = 0.0
            if let kaspiError = error as? KaspiAPIError {
                self.errorMessage = kaspiError.errorDescription
            } else {
                self.errorMessage = "Ошибка синхронизации: \(error.localizedDescription)"
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
    
    // 📅 Проверить дату последней синхронизации
    private func checkLastSyncDate() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("sellers").document(userId)
            .getDocument { [weak self] snapshot, error in
                if let data = snapshot?.data(),
                   let timestamp = data["lastKaspiSync"] as? Timestamp {
                    Task { @MainActor in
                        self?.lastSyncDate = timestamp.dateValue()
                    }
                }
            }
    }
    
    // 💾 Сохранить дату последней синхронизации
    private func saveLastSyncDate(_ date: Date) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            try await db.collection("sellers").document(userId)
                .setData([
                    "lastKaspiSync": Timestamp(date: date)
                ], merge: true)
        } catch {
            print("❌ Ошибка сохранения даты синхронизации: \(error)")
        }
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
                    await self.saveProductToFirestore(newProduct)
                }
                
                self.successMessage = "✅ Остатки обновлены"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.successMessage = nil
                }
                
            } catch {
                self.errorMessage = "Ошибка обновления остатков: \(error.localizedDescription)"
            }
        }
    }
    
    // 🗑️ Деактивировать товар
    func deactivateProduct(product: Product) {
        Task {
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
                await self.saveProductToFirestore(deactivatedProduct)
                
                self.successMessage = "Товар '\(product.name)' деактивирован"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.successMessage = nil
                }
            }
        }
        
        print("Деактивирован товар: \(product.name)")
    }
    
    // 💾 Сохранить товар в Firestore
    private func saveProductToFirestore(_ product: Product) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let productRef = db.collection("sellers").document(userId)
            .collection("products").document(product.id)
        
        do {
            try await productRef.setData(product.toDictionary())
            print("✅ Товар сохранен в Firestore")
        } catch {
            print("❌ Ошибка сохранения товара: \(error)")
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
    
    // 📊 Товары по складам
    func getProductsByWarehouse(_ warehouseId: String) -> [Product] {
        return products.filter { product in
            product.warehouseStock[warehouseId] != nil &&
            product.warehouseStock[warehouseId]! > 0
        }
    }
    
    // 🏭 Статистика по складам
    var warehouseStatistics: [String: (products: Int, totalStock: Int, value: Double)] {
        var stats: [String: (products: Int, totalStock: Int, value: Double)] = [:]
        
        for product in products {
            for (warehouseId, stock) in product.warehouseStock {
                let currentStats = stats[warehouseId] ?? (products: 0, totalStock: 0, value: 0.0)
                stats[warehouseId] = (
                    products: currentStats.products + 1,
                    totalStock: currentStats.totalStock + stock,
                    value: currentStats.value + (product.price * Double(stock))
                )
            }
        }
        
        return stats
    }
    
    // 📅 Нужна ли синхронизация
    var needsSync: Bool {
        guard let lastSync = lastSyncDate else { return true }
        // Синхронизация нужна если прошло больше 4 часов
        return Date().timeIntervalSince(lastSync) > 14400 // 4 часа
    }
    
    // 🔄 Автоматическая синхронизация
    func startAutoSync() {
        Timer.scheduledTimer(withTimeInterval: 14400, repeats: true) { _ in
            Task {
                if await self.checkKaspiAPIAvailability() {
                    await self.syncWithKaspiAPI()
                }
            }
        }
    }
}
