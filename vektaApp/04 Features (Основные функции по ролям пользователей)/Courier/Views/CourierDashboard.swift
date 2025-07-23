//
//  CourierDashboard.swift
//  vektaApp
//
//  Главная панель курьера
//

import SwiftUI
import MapKit

struct CourierDashboard: View {
    
    @StateObject private var deliveryViewModel = CourierDeliveryViewModel()
    @State private var showingDeliveryList = false
    @State private var showingProfile = false
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Главная
            homeView
                .tabItem {
                    Label("Главная", systemImage: "house.fill")
                }
                .tag(0)
            
            // Доставки
            CourierDeliveryView()
                .tabItem {
                    Label("Доставки", systemImage: "truck.box.fill")
                }
                .tag(1)
            
            // История
            historyView
                .tabItem {
                    Label("История", systemImage: "clock.arrow.circlepath")
                }
                .tag(2)
            
            // Профиль
            profileView
                .tabItem {
                    Label("Профиль", systemImage: "person.circle.fill")
                }
                .tag(3)
        }
    }
}

// MARK: - Views

extension CourierDashboard {
    
    // Главная страница
    private var homeView: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Приветствие
                    headerSection
                    
                    // Статистика дня
                    todayStatsSection
                    
                    // Текущая доставка
                    if let currentDelivery = deliveryViewModel.currentDelivery {
                        currentDeliverySection(currentDelivery)
                    }
                    
                    // Активные доставки
                    activeDeliveriesSection
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
            .navigationTitle("Курьер")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            deliveryViewModel.loadDeliveries()
        }
    }
    
    // История доставок
    private var historyView: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    
                    // Фильтр по датам
                    dateFilterSection
                    
                    // Список завершенных доставок
                    completedDeliveriesSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
            .navigationTitle("История")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // Профиль
    private var profileView: some View {
        NavigationView {
            List {
                // Информация о курьере
                Section("Личная информация") {
                    ProfileRow(icon: "person", title: "Имя", value: "Иван Иванов")
                    ProfileRow(icon: "phone", title: "Телефон", value: "+7 777 123 45 67")
                    ProfileRow(icon: "envelope", title: "Email", value: "courier@example.com")
                }
                
                // Статистика
                Section("Статистика") {
                    ProfileRow(icon: "calendar", title: "Дней работы", value: "45")
                    ProfileRow(icon: "truck.box", title: "Всего доставок", value: "324")
                    ProfileRow(icon: "star.fill", title: "Рейтинг", value: "4.8")
                }
                
                // Настройки
                Section("Настройки") {
                    Button(action: {}) {
                        Label("Уведомления", systemImage: "bell")
                    }
                    
                    Button(action: {}) {
                        Label("Смена пароля", systemImage: "lock")
                    }
                    
                    Button(action: {}) {
                        Label("Выйти", systemImage: "arrow.right.square")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Components

extension CourierDashboard {
    
    // Приветствие
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Добрый день!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("У вас \(deliveryViewModel.activeDeliveries.count) активных доставок")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // Статистика дня
    private var todayStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Сегодня")
                .font(.headline)
            
            HStack(spacing: 12) {
                CourierStatCard(
                    icon: "checkmark.circle.fill",
                    title: "Доставлено",
                    value: "\(deliveryViewModel.todayDeliveries)",
                    color: .green
                )
                
                CourierStatCard(
                    icon: "clock.fill",
                    title: "В процессе",
                    value: "\(deliveryViewModel.pendingDeliveries)",
                    color: .orange
                )
                
                CourierStatCard(
                    icon: "tenge.circle.fill",
                    title: "Заработано",
                    value: "15,000",
                    color: .blue
                )
            }
        }
    }
    
    // Текущая доставка
    private func currentDeliverySection(_ delivery: DeliveryConfirmation) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Текущая доставка")
                    .font(.headline)
                
                Spacer()
                
                StatusBadge(status: delivery.status)
            }
            
            CurrentDeliveryCard(delivery: delivery) {
                selectedTab = 1
            }
        }
    }
    
    // Активные доставки
    private var activeDeliveriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Предстоящие доставки")
                    .font(.headline)
                
                Spacer()
                
                Button("Все") {
                    selectedTab = 1
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            if deliveryViewModel.activeDeliveries.isEmpty {
                EmptyActiveDeliveries()
            } else {
                VStack(spacing: 12) {
                    ForEach(deliveryViewModel.activeDeliveries.prefix(3)) { delivery in
                        CompactDeliveryCard(delivery: delivery)
                    }
                }
            }
        }
    }
    
    // Фильтр по датам
    private var dateFilterSection: some View {
        HStack {
            Text("Период:")
                .font(.headline)
            
            Spacer()
            
            Menu {
                Button("Сегодня") {}
                Button("Вчера") {}
                Button("Неделя") {}
                Button("Месяц") {}
            } label: {
                HStack {
                    Text("Сегодня")
                        .font(.subheadline)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
    }
    
    // Завершенные доставки
    private var completedDeliveriesSection: some View {
        VStack(spacing: 12) {
            ForEach(deliveryViewModel.completedDeliveries) { delivery in
                CompletedDeliveryCard(delivery: delivery)
            }
        }
    }
}

// MARK: - Card Components

// Компонент StatCard для курьера (переименован для избежания конфликта)
struct CourierStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CurrentDeliveryCard: View {
    let delivery: DeliveryConfirmation
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                
                // Адрес
                HStack {
                    Image(systemName: "location.circle.fill")
                        .foregroundColor(.blue)
                    
                    Text(delivery.deliveryAddress)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Spacer()
                }
                
                // Телефон
                HStack {
                    Image(systemName: "phone.circle")
                        .foregroundColor(.green)
                    
                    Text(delivery.formattedPhone)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    // Кнопка звонка
                    Button(action: {
                        // TODO: Позвонить клиенту
                    }) {
                        Image(systemName: "phone.fill")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.green)
                            .clipShape(Circle())
                    }
                }
                
                // Карта
                MapPreview(address: delivery.deliveryAddress)
                    .frame(height: 150)
                    .cornerRadius(8)
                
                // Действие
                HStack {
                    Image(systemName: "arrow.right.circle")
                        .foregroundColor(.blue)
                    
                    Text("Перейти к доставке")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Spacer()
                }
            }
            .padding(16)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CompactDeliveryCard: View {
    let delivery: DeliveryConfirmation
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(delivery.deliveryAddress)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(delivery.formattedPhone)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(status: delivery.status)
                
                Text(delivery.createdAt, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(8)
    }
}

struct CompletedDeliveryCard: View {
    let delivery: DeliveryConfirmation
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(delivery.trackingNumber)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(delivery.deliveryAddress)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if let confirmedAt = delivery.confirmedAt {
                Text(confirmedAt, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
    }
}

struct ProfileRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            Text(title)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

struct EmptyActiveDeliveries: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Нет предстоящих доставок")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Map Preview

struct MapPreview: View {
    let address: String
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 43.238949, longitude: 76.889709), // Алматы
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    
    var body: some View {
        Map(coordinateRegion: $region, annotationItems: [MapPin(coordinate: region.center)]) { pin in
            MapMarker(coordinate: pin.coordinate, tint: .blue)
        }
        .disabled(true)
    }
}

struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

#Preview {
    CourierDashboard()
}
