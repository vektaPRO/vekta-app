//
//  ProductsViewModel.swift
//  vektaApp
//
//  ViewModel для управления товарами с Kaspi API интеграцией
//

import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class ProductsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var products: [Product] = []
    @Published var filteredProducts: [Product] = []
    @Published var isLoading = false
    @Published var isSyncing = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var lastSyncDate: Date?
    
    // MARK: - Search and Filters
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
    
    // MARK: - Services
    let kaspiService = KaspiAPIService()
    private let db = Firestore.firestore()
    
    // MARK: - Computed Properties
    var totalProducts: Int { products.count }
    var inStockProducts: Int { products.filter { $0.status == .inStock }.count }
    var outOfStockProducts: Int { products.filter { $0.status == .outOfStock }.count }
    var inactiveProducts: Int { products.filter { $0.status == .inactive }.count }
    
    var categories: [String] {
        let allCategories = products.map { $0.category }
        let uniqueCategories = Array(Set(allCategories)).sorted()
        return ["Все"] + uniqueCategories
    }
    
    // MARK: - Initialization
    init() {
        loadProducts()
    }
    
    // MARK: - Main Methods
    
    /// Загрузить товары из локального хранилища
    func loadProducts() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Пользователь не авторизован"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Для демонстрации используем тестовые данные
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.products = Product.sampleProducts
            self.filterProducts()
            self.isLoading = false
        }
        
        // TODO: Реальная загрузка из Firestore
        /*
        db.collection("sellers").document(userId)
            .collection("products")
            .order(by: "updatedAt", descending: true)
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
    
    /// Обновить товары
    func refreshProducts() async {
        await MainActor.run {
            isLoading = true
        }
        
        // Имитируем загрузку
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        await MainActor.run {
            self.loadProducts()
        }
    }
    
    /// Синхронизация с Kaspi API
    func syncWithKaspiAPI() async {
        await MainActor.run {
            isSyncing = true
            errorMessage = nil
        }
        
        do {
            // Синхронизируем товары через Kaspi API
            let syncedProducts = try await kaspiService.syncAllProducts()
            
            await MainActor.run {
                self.products = syncedProducts
                self.filterProducts()
                self.lastSyncDate = Date()
                self.successMessage = "✅ Синхронизировано \(syncedProducts.count) товаров"
                self.isSyncing = false
                
                // Очищаем сообщение через 3 секунды
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.successMessage = nil
                }
            }
            
            // Сохраняем в локальное хранилище
            await saveProductsToFirestore(syncedProducts)
            
        } catch {
            await MainActor.run {
                self.isSyncing = false
                self.errorMessage = "Ошибка синхронизации: \(error.localizedDescription)"
            }
        }
    }
    
    /// Фильтрация товаров
    private func filterProducts() {
        var filtered = products
        
        // Фильтр по поиску
        if !searchText.isEmpty {
            filtered = filtered.filter { product in
                product.name.localizedCaseInsensitiveContains(searchText) ||
                product.description.localizedCaseInsensitiveContains(searchText) ||
                product.category.localizedCaseInsensitiveContains(searchText) ||
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
    
    /// Добавить товар в отгрузку на склад
    func addToWarehouseShipment(product: Product) {
        // TODO: Реализовать добавление в корзину для отгрузки
        successMessage = "Товар \(product.name) добавлен в отгрузку"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.successMessage = nil
        }
    }
    
    /// Очистить фильтры
    func clearFilters() {
        searchText = ""
        selectedStatus = nil
        selectedCategory = "Все"
    }
    
    /// Получить цвет для статуса
    func colorForStatus(_ status: ProductStatus) -> Color {
        switch status {
        case .inStock: return .green
        case .outOfStock: return .orange
        case .inactive: return .gray
        case .available: return .blue
        }
    }
    
    /// Очистить сообщения
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
    
    // MARK: - Private Methods
    
    /// Сохранить товары в Firestore
    private func saveProductsToFirestore(_ products: [Product]) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let batch = db.batch()
        
        for product in products {
            let productData = product.toDictionary()
            let docRef = db.collection("sellers").document(userId)
                .collection("products").document(product.id)
            
            batch.setData(productData, forDocument: docRef, merge: true)
        }
        
        do {
            try await batch.commit()
            print("✅ Товары сохранены в Firestore")
        } catch {
            print("❌ Ошибка сохранения товаров: \(error)")
            await MainActor.run {
                self.errorMessage = "Ошибка сохранения: \(error.localizedDescription)"
            }
        }
    }
}
