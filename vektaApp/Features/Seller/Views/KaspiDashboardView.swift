//
//  KaspiDashboardView.swift
//  vektaApp
//
//  Главная панель управления интеграцией с Kaspi
//

import SwiftUI

struct KaspiDashboardView: View {
    
    @StateObject private var kaspiManager = KaspiIntegrationManager()
    @StateObject private var kaspiAPI = KaspiAPIService()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingSettings = false
    @State private var selectedOrder: KaspiOrder?
    @State private var selectedDelivery: DeliveryConfirmation?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Connection Status
                    connectionStatusSection
                    
                    // Quick Stats
                    quickStatsSection
                    
                    // Auto Processing Toggle
                    autoProcessingSection
                    
                    // Recent Orders
                    recentOrdersSection
                    
                    // Active Deliveries
                    activeDeliveriesSection
                    
                    // Product Sync Status
                    productSyncSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.top, 0)
            }
            .navigationTitle("Kaspi Integration")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Готово") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .refreshable {
                await kaspiManager.refreshData()
            }
            .sheet(isPresented: $showingSettings) {
                KaspiSettingsView()
            }
            .sheet(item: $selectedOrder) { order in
                KaspiOrderDetailView(order: order, kaspiManager: kaspiManager)
            }
            .sheet(item: $selectedDelivery) { delivery in
                KaspiDeliveryDetailView(delivery: delivery, kaspiManager: kaspiManager)
            }
            .alert("Ошибка", isPresented: .constant(kaspiManager.errorMessage != nil)) {
                Button("OK") {
                    kaspiManager.clearMessages()
                }
            } message: {
                Text(kaspiManager.errorMessage ?? "")
            }
            .alert("Успех", isPresented: .constant(kaspiManager.successMessage != nil)) {
                Button("OK") {
                    kaspiManager.clearMessages()
                }
            } message: {
                Text(kaspiManager.successMessage ?? "")
            }
            .onAppear {
                Task {
                    await kaspiManager.syncData()
                }
            }
        }
    }
}

// MARK: - View Components

private extension KaspiDashboardView {
    
    // 🔗 Connection Status
    var connectionStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Статус подключения")
                .font(.headline)
                .fontWeight(.semibold)
            
            KaspiConnectionCard(
                isConnected: kaspiAPI.apiToken != nil,
                lastSync: kaspiAPI.lastSyncDate,
                autoProcessing: kaspiManager.isAutoProcessingEnabled
            ) {
                showingSettings = true
            }
        }
        .padding(.horizontal, 20)
    }
    
    // 📊 Quick Stats
    var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Статистика за сегодня")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                
                StatCard(
                    icon: "doc.text.fill",
                    title: "Заказы",
                    value: "\(kaspiManager.todayOrdersCount)",
                    color: .blue,
                    style: .compact
                )
                
                StatCard(
                    icon: "checkmark.circle.fill",
                    title: "Доставлено",
                    value: "\(kaspiManager.todayDeliveredCount)",
                    color: .green,
                    style: .compact
                )
                
                StatCard(
                    icon: "clock.fill",
                    title: "В доставке",
                    value: "\(kaspiManager.pendingDeliveriesCount)",
                    color: .orange,
                    style: .compact
                )
            }
        }
        .padding(.horizontal, 20)
    }
    
    // ⚙️ Auto Processing
    var autoProcessingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Автоматизация")
                .font(.headline)
                .fontWeight(.semibold)
            
            AutoProcessingCard(
                isEnabled: kaspiManager.isAutoProcessingEnabled,
                onToggle: {
                    Task {
                        await kaspiManager.toggleAutoProcessing()
                    }
                }
            )
        }
        .padding(.horizontal, 20)
    }
    
    // 📦 Recent Orders
    var recentOrdersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Новые заказы")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !kaspiManager.newOrders.isEmpty {
                    Button("Обработать все") {
                        Task {
                            await kaspiManager.processNewOrdersAutomatically()
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }
            
            if kaspiManager.isLoading {
                LoadingView("Загружаем заказы...")
                    .frame(height: 150)
            } else if kaspiManager.newOrders.isEmpty {
                DashboardEmptyOrdersView()
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(kaspiManager.newOrders.prefix(5)), id: \.id) { order in
                        DashboardKaspiOrderCard(order: order) {
                            selectedOrder = order
                        }
                    }
                    
                    if kaspiManager.newOrders.count > 5 {
                        Text("И еще \(kaspiManager.newOrders.count - 5) заказов...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // 🚚 Active Deliveries
    var activeDeliveriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Активные доставки")
                .font(.headline)
                .fontWeight(.semibold)
            
            if kaspiManager.deliveries.isEmpty {
                DashboardEmptyDeliveriesView()
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(kaspiManager.deliveries.filter { $0.status != .confirmed }.prefix(5)), id: \.id) { delivery in
                        DashboardDeliveryCard(delivery: delivery) {
                            selectedDelivery = delivery
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // 📦 Product Sync
    var productSyncSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Синхронизация товаров")
                .font(.headline)
                .fontWeight(.semibold)
            
            ProductSyncCard(
                totalProducts: kaspiManager.products.count,
                lastSync: kaspiAPI.lastSyncDate,
                onSync: {
                    Task {
                        await kaspiManager.syncProducts()
                    }
                }
            )
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - UI Components

/// Connection Status Card
struct KaspiConnectionCard: View {
    let isConnected: Bool
    let lastSync: Date?
    let autoProcessing: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: isConnected ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(isConnected ? .green : .orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Kaspi API")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(isConnected ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            
                            Text(isConnected ? "Подключено" : "Не подключено")
                                .font(.caption)
                                .foregroundColor(isConnected ? .green : .red)
                        }
                    }
                    
                    if isConnected {
                        VStack(alignment: .leading, spacing: 2) {
                            if let lastSync = lastSync {
                                Text("Последняя синхронизация: \(DateFormatter.shortTime.string(from: lastSync))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: 8) {
                                Label(autoProcessing ? "Автообработка вкл" : "Автообработка выкл",
                                      systemImage: autoProcessing ? "play.circle.fill" : "pause.circle.fill")
                                .font(.caption)
                                .foregroundColor(autoProcessing ? .blue : .secondary)
                            }
                        }
                    } else {
                        Text("Настройте API токен для подключения")
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
                    .stroke(isConnected ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Auto Processing Card
struct AutoProcessingCard: View {
    let isEnabled: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Автоматическая обработка заказов")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Новые заказы будут автоматически приняты и переданы на доставку")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: .constant(isEnabled))
                    .labelsHidden()
                    .onChange(of: isEnabled) { _ in
                        onToggle()
                    }
            }
            
            if isEnabled {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                    
                    Text("Проверка новых заказов каждые 5 минут")
                        .font(.caption)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

/// Dashboard Kaspi Order Card
struct DashboardKaspiOrderCard: View {
    let order: KaspiOrder
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Заказ #\(order.attributes.code)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(order.attributes.customer.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(order.attributes.status.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(statusColor)
                    
                    Text(String(format: "%.0f ₸", order.attributes.totalPrice))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var statusColor: Color {
        switch order.attributes.status {
        case .acceptedByMerchant:
            return .blue
        case .approvedByBank:
            return .green
        case .assemble:
            return .orange
        case .kaspiDelivery:
            return .purple
        case .completed:
            return .green
        case .cancelled, .returned:
            return .red
        }
    }
}

/// Dashboard Delivery Card
struct DashboardDeliveryCard: View {
    let delivery: DeliveryConfirmation
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Доставка #\(delivery.trackingNumber)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(delivery.deliveryAddress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(delivery.status.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(statusColor)
                    
                    Text(DateFormatter.shortTime.string(from: delivery.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(statusColor.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var statusColor: Color {
        switch delivery.status {
        case .pending: return .gray
        case .inTransit: return .blue
        case .arrived: return .orange
        case .awaitingCode: return .yellow
        case .confirmed: return .green
        case .failed: return .red
        case .cancelled: return .red
        }
    }
}

/// Product Sync Card
struct ProductSyncCard: View {
    let totalProducts: Int
    let lastSync: Date?
    let onSync: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "cube.box.fill")
                .font(.system(size: 32))
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Товары: \(totalProducts)")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let lastSync = lastSync {
                    Text("Обновлено: \(DateFormatter.shortDateTime.string(from: lastSync))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Не синхронизировано")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            Button("Синхронизировать") {
                onSync()
            }
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding(16)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

/// Empty States

struct DashboardEmptyOrdersView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("Новых заказов нет")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("Заказы появятся здесь автоматически")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

struct DashboardEmptyDeliveriesView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "truck.box")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("Активных доставок нет")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("Доставки появятся после обработки заказов")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Detail Views

/// Kaspi Order Detail View
struct KaspiOrderDetailView: View {
    let order: KaspiOrder
    @ObservedObject var kaspiManager: KaspiIntegrationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var orderEntries: [KaspiOrderEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Order Info
                    orderInfoSection
                    
                    // Customer Info
                    customerInfoSection
                    
                    // Order Items
                    orderItemsSection
                    
                    // Actions
                    actionsSection
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Заказ #\(order.attributes.code)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadOrderDetails()
            }
        }
    }
    
    private var orderInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Информация о заказе")
                .font(.headline)
            
            VStack(spacing: 12) {
                InfoRow(icon: "number", title: "Номер заказа", value: order.attributes.code)
                InfoRow(icon: "tenge.circle", title: "Сумма", value: String(format: "%.0f ₸", order.attributes.totalPrice))
                InfoRow(icon: "calendar", title: "Дата создания", value: DateFormatter.shortDateTime.string(from: order.attributes.creationDate))
                InfoRow(icon: "truck.box", title: "Доставка", value: order.attributes.isKaspiDelivery ? "Kaspi Доставка" : "Самовывоз")
                
                HStack {
                    Text("Статус:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    StatusBadge(
                        text: order.attributes.status.displayName,
                        icon: "circle.fill",
                        color: statusColor
                    )
                }
            }
            .padding(16)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var customerInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Информация о клиенте")
                .font(.headline)
            
            VStack(spacing: 12) {
                InfoRow(icon: "person", title: "Имя", value: order.attributes.customer.name)
                InfoRow(icon: "phone", title: "Телефон", value: order.attributes.customer.cellPhone)
                
                if let email = order.attributes.customer.email {
                    InfoRow(icon: "envelope", title: "Email", value: email)
                }
                
                InfoRow(icon: "location", title: "Адрес", value: order.attributes.deliveryAddress.formattedAddress)
            }
            .padding(16)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var orderItemsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Товары в заказе")
                .font(.headline)
            
            if isLoading {
                LoadingView("Загружаем товары...")
                    .frame(height: 100)
            } else {
                VStack(spacing: 8) {
                    ForEach(orderEntries, id: \.id) { entry in
                        KaspiOrderEntryCard(entry: entry)
                    }
                }
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                Task {
                    await kaspiManager.processOrder(order)
                    dismiss()
                }
            }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("Обработать заказ")
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
    }
    
    private var statusColor: Color {
        switch order.attributes.status {
        case .acceptedByMerchant: return .blue
        case .approvedByBank: return .green
        case .assemble: return .orange
        case .kaspiDelivery: return .purple
        case .completed: return .green
        case .cancelled, .returned: return .red
        }
    }
    
    private func loadOrderDetails() {
        isLoading = true
        
        Task {
            do {
                let entries = try await KaspiAPIService().getOrderEntries(orderId: order.id)
                await MainActor.run {
                    self.orderEntries = entries
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

/// Kaspi Delivery Detail View
struct KaspiDeliveryDetailView: View {
    let delivery: DeliveryConfirmation
    @ObservedObject var kaspiManager: KaspiIntegrationManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Детали доставки")
                        .font(.title)
                    
                    Text("Заказ #\(delivery.trackingNumber)")
                        .font(.headline)
                    
                    Text("Статус: \(delivery.status.rawValue)")
                        .font(.subheadline)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Доставка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Kaspi Order Entry Card
struct KaspiOrderEntryCard: View {
    let entry: KaspiOrderEntry
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: entry.attributes.product.image ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(UIColor.systemGray5))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    )
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.attributes.product.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                if let brand = entry.attributes.product.brand {
                    Text(brand)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.attributes.quantity) шт")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(String(format: "%.0f ₸", entry.attributes.totalPrice))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Preview

struct KaspiDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        // Здесь можно подставить моковые менеджеры, если они умеют инъекцию или использовать реальные с тестовыми данными.
        KaspiDashboardView()
    }
}
