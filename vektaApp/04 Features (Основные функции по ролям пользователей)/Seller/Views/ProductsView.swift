//
//  ProductsView.swift
//  vektaApp
//
//  Created by Almas Kadeshov on 30.06.2025.
//

import SwiftUI

struct ProductsView: View {
    
    @StateObject private var viewModel = ProductsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // 📊 Статистика товаров
                if !viewModel.isLoading && !viewModel.products.isEmpty {
                    statsHeaderView
                }
                
                // 🔍 Поиск и фильтры
                searchAndFiltersView
                
                // 📦 Список товаров
                productsListView
            }
            .navigationTitle("Товары")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Готово") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.syncWithKaspiAPI()
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .refreshable {
                viewModel.refreshProducts()
            }
        }
    }
}

// MARK: - Компоненты интерфейса
extension ProductsView {
    
    // 📊 Статистика в шапке
    private var statsHeaderView: some View {
        HStack(spacing: 20) {
            StatBadge(
                title: "Всего",
                value: "\(viewModel.totalProducts)",
                color: .blue
            )
            
            StatBadge(
                title: "В наличии",
                value: "\(viewModel.inStockProducts)",
                color: .green
            )
            
            StatBadge(
                title: "Нет в наличии",
                value: "\(viewModel.outOfStockProducts)",
                color: .orange
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemGray6))
    }
    
    // 🔍 Поиск и фильтры
    private var searchAndFiltersView: some View {
        VStack(spacing: 12) {
            
            // Поле поиска
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Поиск товаров...", text: $viewModel.searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(8)
            
            // Фильтры
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    
                    // Фильтр по статусу
                    ForEach([ProductStatus.inStock, .outOfStock, .inactive], id: \.rawValue) { status in
                        FilterChip(
                            title: status.rawValue,
                            isSelected: viewModel.selectedStatus == status,
                            color: viewModel.colorForStatus(status)
                        ) {
                            viewModel.selectedStatus = (viewModel.selectedStatus == status) ? nil : status
                        }
                    }
                    
                    // Разделитель
                    Divider()
                        .frame(height: 20)
                    
                    // Фильтр по категориям
                    ForEach(viewModel.categories, id: \.self) { category in
                        FilterChip(
                            title: category,
                            isSelected: viewModel.selectedCategory == category,
                            color: .blue
                        ) {
                            viewModel.selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // 📦 Список товаров
    private var productsListView: some View {
        Group {
            if viewModel.isLoading {
                LoadingView("Загружаем товары...")
            } else if viewModel.filteredProducts.isEmpty {
                EmptyStateView()
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(viewModel.filteredProducts) { product in
                        ProductCard(product: product) {
                            viewModel.addToWarehouseShipment(product: product)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - UI Компоненты

/// Статистический бейдж
struct StatBadge: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Фильтр чип
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : Color(UIColor.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

/// Карточка товара
struct ProductCard: View {
    let product: Product
    let onAddToShipment: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            
            // 🖼️ Изображение товара
            AsyncImage(url: URL(string: product.imageURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.systemGray5))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    )
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // 📝 Информация о товаре
            VStack(alignment: .leading, spacing: 6) {
                
                // Название
                Text(product.name)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Цена
                Text(product.formattedPrice)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // Статус
                HStack(spacing: 4) {
                    Image(systemName: product.status.iconName)
                        .foregroundColor(colorForStatus(product.status))
                    
                    Text(product.status.rawValue)
                        .font(.caption)
                        .foregroundColor(colorForStatus(product.status))
                    
                    Spacer()
                    
                    if product.totalStock > 0 {
                        Text("\(product.totalStock) шт")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Кнопка действия
                Button(action: onAddToShipment) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("В отгрузку")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(product.status == .inStock ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(product.status != .inStock)
            }
        }
        .padding(12)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func colorForStatus(_ status: ProductStatus) -> Color {
        switch status {
        case .inStock: return .green
        case .outOfStock: return .orange
        case .inactive: return .gray
        }
    }
}

/// Пустое состояние
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cube.box")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Товары не найдены")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Попробуйте изменить фильтры поиска или синхронизировать с Kaspi API")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Загрузка
struct LoadingView: View {
    let message: String
    
    init(_ message: String = "Загрузка...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ProductsView()
}
