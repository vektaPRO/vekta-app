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
    @Published var isRefreshing: Bool = false
    
    // 🔥 Firebase
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
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
    
    init() {
        loadProducts()
    }
    
    deinit {
        listener?.remove()
    }
    
    // 📦 Загрузить товары
    func loadProducts() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Пользователь не авторизован"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Для разработки используем тестовые данные
        // В продакшне здесь будет загрузка из Firestore + Kaspi API
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.products = Product.sampleProducts
            self.filterProducts()
            self.isLoading = false
        }
        
        // TODO: Реальная загрузка из Firestore
        /*
        listener = db.collection("sellers").document(userId)
            .collection("products")
            .addSnapshotListener { [weak self] snapshot, error in
                
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.errorMessage = "Ошибка загрузки: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self?.products = []
                        self?.filterProducts()
                        return
                    }
                    
                    self?.products = documents.compactMap { doc in
                        Product.fromFirestore(doc.data(), id: doc.documentID)
                    }
                    
                    self?.filterProducts()
                }
            }
        */
    }
    
    // 🔄 Обновить товары
    func refreshProducts() {
        isRefreshing = true
        
        // Имитация обновления
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.loadProducts()
            self.isRefreshing = false
        }
    }
    
    // 🔍 Фильтровать товары
    private func filterProducts() {
        var filtered = products
        
        // Фильтр по поиску
        if !searchText.isEmpty {
            filtered = filtered.filter { product in
                product.name.localizedCaseInsensitiveContains(searchText) ||
                product.description.localizedCaseInsensitiveContains(searchText) ||
                product.kaspiProductId.localizedCaseInsensitiveContains(searchText)
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
    
    // 🔄 Синхронизация с Kaspi API
    func syncWithKaspiAPI() {
        isLoading = true
        errorMessage = nil
        
        // TODO: Реальная синхронизация с Kaspi API
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.isLoading = false
            // Показываем успешное сообщение
            // В реальном приложении здесь будет обновление товаров
        }
    }
    
    // ➕ Добавить товар в отгрузку на склад
    func addToWarehouseShipment(product: Product) {
        // TODO: Логика создания заказа на отгрузку
        print("Добавлен в отгрузку: \(product.name)")
    }
    
    // 📊 Обновить остатки товара
    func updateProductStock(productId: String, warehouseId: String, newQuantity: Int) {
        // TODO: Обновление остатков в Firestore
        print("Обновлены остатки для товара \(productId)")
    }
    
    // 🗑️ Деактивировать товар
    func deactivateProduct(product: Product) {
        // TODO: Деактивация товара в Firestore
        print("Деактивирован товар: \(product.name)")
    }
}

// MARK: - Вспомогательные методы
extension ProductsViewModel {
    
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
    
    // 📊 Получить процент товаров в наличии
    var inStockPercentage: Double {
        guard totalProducts > 0 else { return 0 }
        return Double(inStockProducts) / Double(totalProducts) * 100
    }
    
    // 🔍 Очистить фильтры
    func clearFilters() {
        searchText = ""
        selectedStatus = nil
        selectedCategory = "Все"
    }
}
