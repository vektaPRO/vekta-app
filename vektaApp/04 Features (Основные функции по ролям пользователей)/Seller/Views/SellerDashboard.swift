//
//  SellerDashboard.swift
//  vektaApp
//
//  Created by Almas Kadeshov on 02.07.2025.
//

import SwiftUI

struct SellerDashboard: View {
    
    @StateObject private var ordersViewModel = OrdersViewModel()
    @StateObject private var productsViewModel = ProductsViewModel()
    
    @State private var showingOrders = false
    @State private var showingProducts = false
    @State private var showingCreateOrder = false
    @State private var showingKaspiToken = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Приветствие
                    headerSection
                    
                    // Быстрые действия
                    quickActionsSection
                    
                    // Статистика
                    statisticsSection
                    
                    // Последние заказы
                    recentOrdersSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Продавец")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingKaspiToken = true
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .refreshable {
                ordersViewModel.refreshOrders()
                productsViewModel.refreshProducts()
            }
        }
        .sheet(isPresented: $showingOrders) {
            OrdersListView()
        }
        .sheet(isPresented: $showingProducts) {
            ProductsView()
        }
        .sheet(isPresented: $showingCreateOrder) {
            CreateOrderView()
        }
        .sheet(isPresented: $showingKaspiToken) {
            KaspiAPITokenView()
        }
        .onAppear {
            ordersViewModel.loadOrders()
            productsViewModel.loadProducts()
        }
    }
}

// MARK: - Компоненты интерфейса
extension SellerDashboard {
    
    // 👋 Приветствие
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Добро пожаловать!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Управляйте вашими товарами и заказами на склад")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // ⚡ Быстрые действия
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Быстрые действия")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                
                QuickActionCard(
                    icon: "plus.circle.fill",
                    title: "Создать заказ",
                    subtitle: "Новый заказ на склад",
                    color: .blue
                ) {
                    showingCreateOrder = true
                }
                
                QuickActionCard(
                    icon: "list.bullet.rectangle",
                    title: "Мои заказы",
                    subtitle: "Все заказы",
                    color: .purple
                ) {
                    showingOrders = true
                }
                
                QuickActionCard(
                    icon: "cube.box.fill",
                    title: "Товары",
                    subtitle: "Каталог товаров",
                    color: .orange
                ) {
                    showingProducts = true
                }
                
                QuickActionCard(
                    icon: "creditcard.circle.fill",
                    title: "Kaspi API",
                    subtitle: "Настройки",
                    color: .green
                ) {
                    showingKaspiToken = true
                }
            }
        }
    }
    
    // 📊 Статистика
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Статистика")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Заказы
                StatisticsRow(
                    icon: "doc.text.fill",
                    title: "Заказы",
                    value: "\(ordersViewModel.totalOrders)",
                    subtitle: "Всего заказов",
                    color: .blue
                )
                
                // Товары
                StatisticsRow(
                    icon: "cube.box.fill",
                    title: "Товары",
                    value: "\(productsViewModel.totalProducts)",
                    subtitle: "В каталоге",
                    color: .orange
                )
                
                // Ожидающие заказы
                StatisticsRow(
                    icon: "clock.fill",
                    title: "В ожидании",
                    value: "\(ordersViewModel.pendingOrders)",
                    subtitle: "Готовы к отправке",
                    color: .yellow
                )
                
                // Общая стоимость
                StatisticsRow(
                    icon: "tenge.circle.fill",
                    title: "Стоимость",
                    value: ordersViewModel.formattedTotalValue,
                    subtitle: "Всех заказов",
                    color: .green
                )
            }
            .padding(16)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // 📦 Последние заказы
    private var recentOrdersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Последние заказы")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Все заказы") {
                    showingOrders = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            if ordersViewModel.isLoading {
                LoadingView("Загружаем заказы...")
                    .frame(height: 150)
            } else if ordersViewModel.orders.isEmpty {
                EmptyRecentOrdersView {
                    showingCreateOrder = true
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(ordersViewModel.orders.prefix(3))) { order in
                        CompactOrderCard(order: order)
                    }
                }
            }
        }
    }
}

// MARK: - UI Компоненты

/// Карточка быстрого действия
struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Строка статистики
struct StatisticsRow: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
}

/// Компактная карточка заказа
struct CompactOrderCard: View {
    let order: Order
    
    var body: some View {
        HStack(spacing: 12) {
            // Статус индикатор
            Circle()
                .fill(Color(order.statusColor))
                .frame(width: 12, height: 12)
            
            // Информация о заказе
            VStack(alignment: .leading, spacing: 2) {
                Text(order.orderNumber)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(order.warehouseName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Статус и дата
            VStack(alignment: .trailing, spacing: 2) {
                Text(order.status.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color(order.statusColor))
                
                Text(DateFormatter.shortDate.string(from: order.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(order.statusColor).opacity(0.2), lineWidth: 1)
        )
    }
}

/// Пустое состояние для последних заказов
struct EmptyRecentOrdersView: View {
    let onCreateOrder: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.below.ecg")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("Заказов пока нет")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("Создайте первый заказ на отправку товаров")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Создать заказ") {
                onCreateOrder()
            }
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    SellerDashboard()
}
