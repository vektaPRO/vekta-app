//
//  OrdersListView.swift
//  vektaApp
//
//  Created by Almas Kadeshov on 02.07.2025.
//

import SwiftUI

struct OrdersListView: View {
    
    @StateObject private var viewModel = OrdersViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingCreateOrder = false
    @State private var selectedOrder: Order?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // 📊 Статистика заказов
                if !viewModel.isLoading && !viewModel.orders.isEmpty {
                    statsHeaderView
                }
                
                // 🔍 Поиск и фильтры
                searchAndFiltersView
                
                // 📦 Список заказов
                ordersListView
            }
            .navigationTitle("Мои заказы")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Готово") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingCreateOrder = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            .refreshable {
                viewModel.refreshOrders()
            }
        }
        .sheet(isPresented: $showingCreateOrder) {
            CreateOrderView()
        }
        .sheet(item: $selectedOrder) { order in
            OrderDetailView(order: order)
        }
    }
}

// MARK: - Компоненты интерфейса
extension OrdersListView {
    
    // 📊 Статистика в шапке
    private var statsHeaderView: some View {
        HStack(spacing: 16) {
            OrderStatBadge(
                title: "Всего",
                value: "\(viewModel.totalOrders)",
                color: .blue
            )
            
            OrderStatBadge(
                title: "В ожидании",
                value: "\(viewModel.pendingOrders)",
                color: .orange
            )
            
            OrderStatBadge(
                title: "Отправлено",
                value: "\(viewModel.shippedOrders)",
                color: .purple
            )
            
            OrderStatBadge(
                title: "Завершено",
                value: "\(viewModel.completedOrders)",
                color: .green
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
                
                TextField("Поиск заказов...", text: $viewModel.searchText)
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
                    ForEach(OrderStatus.allCases, id: \.rawValue) { status in
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
                    
                    // Фильтр по складам
                    ForEach(viewModel.warehouses, id: \.self) { warehouse in
                        FilterChip(
                            title: warehouse,
                            isSelected: viewModel.selectedWarehouse == warehouse,
                            color: .blue
                        ) {
                            viewModel.selectedWarehouse = warehouse
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // 📦 Список заказов
    private var ordersListView: some View {
        Group {
            if viewModel.isLoading {
                LoadingView("Загружаем заказы...")
            } else if viewModel.filteredOrders.isEmpty {
                OrdersEmptyStateView {
                    showingCreateOrder = true
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.filteredOrders) { order in
                            OrderCard(order: order) {
                                selectedOrder = order
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
            }
        }
    }
}

// MARK: - UI Компоненты

/// Статистический бейдж для заказов
struct OrderStatBadge: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Карточка заказа
struct OrderCard: View {
    let order: Order
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                
                // Заголовок заказа
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(order.orderNumber)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(order.warehouseName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Статус
                    HStack(spacing: 4) {
                        Image(systemName: order.statusIcon)
                            .foregroundColor(Color(order.statusColor))
                        
                        Text(order.status.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color(order.statusColor))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(order.statusColor).opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Информация о заказе
                HStack {
                    InfoPill(
                        icon: "cube.box",
                        text: "\(order.totalItems) шт",
                        color: .blue
                    )
                    
                    InfoPill(
                        icon: "tenge.circle",
                        text: order.formattedTotalValue,
                        color: .green
                    )
                    
                    if order.priority != .normal {
                        InfoPill(
                            icon: order.priority.iconName,
                            text: order.priority.rawValue,
                            color: Color(order.priority.color)
                        )
                    }
                    
                    Spacer()
                }
                
                // Дата создания
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Text(DateFormatter.shortDateTimeFormatter.string(from: order.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .padding(16)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Информационная таблетка
struct InfoPill: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

/// Пустое состояние для заказов
struct OrdersEmptyStateView: View {
    let onCreateOrder: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.below.ecg")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("Заказов пока нет")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Создайте первый заказ на отправку товаров на склад")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: onCreateOrder) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Создать заказ")
                }
                .fontWeight(.semibold)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Детальный просмотр заказа
struct OrderDetailView: View {
    let order: Order
    @Environment(\.dismiss) private var dismiss
    @State private var showingQRCode = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Заголовок
                    VStack(alignment: .leading, spacing: 8) {
                        Text(order.orderNumber)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        HStack {
                            Image(systemName: order.statusIcon)
                                .foregroundColor(Color(order.statusColor))
                            
                            Text(order.status.rawValue)
                                .font(.headline)
                                .foregroundColor(Color(order.statusColor))
                            
                            Spacer()
                            
                            Text(DateFormatter.shortDateTimeFormatter.string(from: order.createdAt))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // QR-код кнопка
                    Button(action: {
                        showingQRCode = true
                    }) {
                        HStack {
                            Image(systemName: "qrcode")
                            Text("Показать QR-код")
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    // Информация о заказе
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Информация о заказе")
                            .font(.headline)
                        
                        VStack(spacing: 12) {
                            OrderInfoRow(
                                icon: "building.2.fill",
                                title: "Склад:",
                                value: order.warehouseName,
                                color: .green
                            )
                            
                            OrderInfoRow(
                                icon: "cube.box.fill",
                                title: "Товаров:",
                                value: "\(order.totalItems) шт",
                                color: .orange
                            )
                            
                            OrderInfoRow(
                                icon: "tenge.circle.fill",
                                title: "Сумма:",
                                value: order.formattedTotalValue,
                                color: .purple
                            )
                        }
                    }
                    .padding(16)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    
                    // Товары
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Товары в заказе")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            ForEach(order.items) { item in
                                OrderItemRow(item: item)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Детали заказа")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingQRCode) {
            QRCodeView(order: order) {
                showingQRCode = false
            }
        }
    }
}

#Preview {
    OrdersListView()
}
