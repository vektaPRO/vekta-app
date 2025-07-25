//
//  SellerDashboard.swift
//  vektaApp
//
//  Обновленная главная панель продавца с Kaspi интеграцией
//

import SwiftUI

struct SellerDashboard: View {
    
    @StateObject private var ordersViewModel = OrdersViewModel()
    @StateObject private var productsViewModel = ProductsViewModel()
    @StateObject private var kaspiOrdersManager = KaspiOrdersManager()
    
    @State private var showingOrders = false
    @State private var showingProducts = false
    @State private var showingCreateOrder = false
    @State private var showingKaspiToken = false
    @State private var showingKaspiOrders = false
    @State private var showingKaspiTest = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Приветствие
                    headerSection
                    
                    // Kaspi статус
                    kaspiStatusSection
                    
                    // Быстрые действия
                    quickActionsSection
                    
                    // Статистика
                    statisticsSection
                    
                    // Последние заказы Kaspi
                    recentKaspiOrdersSection
                    
                    // Последние заказы на склад
                    recentWarehouseOrdersSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Продавец")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingKaspiToken = true }) {
                            Label("Настройки Kaspi API", systemImage: "creditcard.circle")
                        }
                        
                        Button(action: { showingKaspiTest = true }) {
                            Label("Тестирование API", systemImage: "testtube.2")
                        }
                        
                        Divider()
                        
                        Button(action: {}) {
                            Label("Выйти", systemImage: "arrow.right.square")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .refreshable {
                await refreshAllData()
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
        .sheet(isPresented: $showingKaspiOrders) {
            KaspiOrdersView()
        }
        .sheet(isPresented: $showingKaspiTest) {
            KaspiAPITestView()
        }
        .onAppear {
            loadInitialData()
        }
    }
    
    // MARK: - Data Loading
    
    private func loadInitialData() {
        ordersViewModel.loadOrders()
        productsViewModel.loadProducts()
        
        Task {
            await kaspiOrdersManager.syncKaspiOrders()
            await kaspiOrdersManager.loadDeliveries()
        }
    }
    
    private func refreshAllData() async {
        ordersViewModel.refreshOrders()
        await productsViewModel.refreshProducts()
        await kaspiOrdersManager.syncKaspiOrders()
        await kaspiOrdersManager.loadDeliveries()
    }
}

// MARK: - View Components

extension SellerDashboard {
    
    // 👋 Приветствие
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Добро пожаловать!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Управляйте товарами Kaspi и заказами на склад")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // 🔗 Статус Kaspi интеграции
    private var kaspiStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kaspi Integration")
                .font(.headline)
                .fontWeight(.semibold)
            
            KaspiStatusCard(
                hasToken: productsViewModel.kaspiService.apiToken != nil,
                lastSync: productsViewModel.lastSyncDate,
                newOrders: kaspiOrdersManager.kaspiOrders.count,
                pendingDeliveries: kaspiOrdersManager.deliveries.filter { $0.status != .confirmed }.count
            ) {
                showingKaspiOrders = true
            }
        }
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
                    icon: "creditcard.circle.fill",
                    title: "Kaspi Заказы",
                    subtitle: "\(kaspiOrdersManager.kaspiOrders.count) заказов",
                    color: .orange
                ) {
                    showingKaspiOrders = true
                }
                
                QuickActionCard(
                    icon: "cube.box.fill",
                    title: "Товары Kaspi",
                    subtitle: "\(productsViewModel.totalProducts) товаров",
                    color: .blue
                ) {
                    showingProducts = true
                }
                
                QuickActionCard(
                    icon: "plus.circle.fill",
                    title: "Заказ на склад",
                    subtitle: "Новый заказ",
                    color: .green
                ) {
                    showingCreateOrder = true
                }
                
                QuickActionCard(
                    icon: "list.bullet.rectangle",
                    title: "Мои заказы",
                    subtitle: "\(ordersViewModel.totalOrders) заказов",
                    color: .purple
                ) {
                    showingOrders = true
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
                // Kaspi статистика
                StatisticsRow(
                    icon: "creditcard.fill",
                    title: "Kaspi заказы",
                    value: "\(kaspiOrdersManager.kaspiOrders.count)",
                    subtitle: "Всего получено",
                    color: .orange
                )
                
                // Доставки
                StatisticsRow(
                    icon: "truck.box.fill",
                    title: "Доставки",
                    value: "\(kaspiOrdersManager.deliveries.filter { $0.status != .confirmed }.count)",
                    subtitle: "В процессе",
                    color: .blue
                )
                
                // Товары
                StatisticsRow(
                    icon: "cube.box.fill",
                    title: "Товары",
                    value: "\(productsViewModel.inStockProducts)",
                    subtitle: "В наличии",
                    color: .green
                )
                
                // Заказы на склад
                StatisticsRow(
                    icon: "doc.text.fill",
                    title: "Заказы на склад",
                    value: "\(ordersViewModel.pendingOrders)",
                    subtitle: "Ожидают отправки",
                    color: .purple
                )
            }
            .padding(16)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // 📦 Последние заказы Kaspi
    private var recentKaspiOrdersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Заказы Kaspi")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Все заказы") {
                    showingKaspiOrders = true
                }
                .font(.subheadline)
                .foregroundColor(.orange)
            }
            
            if kaspiOrdersManager.isLoading {
                LoadingView("Загружаем заказы...")
                    .frame(height: 150)
            } else if kaspiOrdersManager.kaspiOrders.isEmpty {
                EmptyKaspiOrdersView {
                    Task {
                        await kaspiOrdersManager.syncKaspiOrders()
                    }
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(kaspiOrdersManager.kaspiOrders.prefix(3)), id: \.orderId) { order in
                        CompactKaspiOrderCard(
                            order: order,
                            delivery: kaspiOrdersManager.deliveries.first { $0.orderId == order.orderId }
                        )
                    }
                }
            }
        }
    }
    
    // 📦 Последние заказы на склад
    private var recentWarehouseOrdersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Заказы на склад")
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

// MARK: - New UI Components

/// Карточка статуса Kaspi
struct KaspiStatusCard: View {
    let hasToken: Bool
    let lastSync: Date?
    let newOrders: Int
    let pendingDeliveries: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Kaspi иконка
                Image(systemName: "creditcard.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(hasToken ? .orange : .gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Kaspi.kz")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        // Статус подключения
                        HStack(spacing: 4) {
                            Circle()
                                .fill(hasToken ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            
                            Text(hasToken ? "Подключено" : "Не подключено")
                                .font(.caption)
                                .foregroundColor(hasToken ? .green : .red)
                        }
                    }
                    
                    if hasToken {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(newOrders)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Text("Новых заказов")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(pendingDeliveries)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Text("В доставке")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let lastSync = lastSync {
                            Text("Синхронизация: \(DateFormatter.shortTime.string(from: lastSync))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Настройте API токен для синхронизации с Kaspi")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(hasToken ? Color.orange.opacity(0.3) : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Компактная карточка заказа Kaspi
struct CompactKaspiOrderCard: View {
    let order: KaspiOrder
    let delivery: DeliveryConfirmation?
    
    var body: some View {
        HStack(spacing: 12) {
            // Статус индикатор
            Circle()
                .fill(delivery?.status == .confirmed ? Color.green : Color.orange)
                .frame(width: 12, height: 12)
            
            // Информация о заказе
            VStack(alignment: .leading, spacing: 2) {
                Text("Заказ #\(order.orderNumber)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(order.customerInfo.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Статус и сумма
            VStack(alignment: .trailing, spacing: 2) {
                if let delivery = delivery {
                    Text(delivery.status.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(delivery.status == .confirmed ? .green : .orange)
                } else {
                    Text("Новый")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                
                Text(String(format: "%.0f ₸", order.totalAmount))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
}

/// Пустое состояние для заказов Kaspi
struct EmptyKaspiOrdersView: View {
    let onSync: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "creditcard.circle")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("Нет заказов Kaspi")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("Заказы появятся автоматически при синхронизации")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Синхронизировать") {
                onSync()
            }
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

/// Карточка быстрого действия (обновленная)
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
                        .multilineTextAlignment(.center)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
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

/// Строка статистики (обновленная)
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

/// Компактная карточка заказа на склад
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
            
            Text("Заказов на склад пока нет")
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
