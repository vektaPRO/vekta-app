//
//  CourierDashboard.swift
//  vektaApp
//
//  Панель управления для курьера
//

import SwiftUI

struct CourierDashboard: View {
    @StateObject private var deliveryViewModel = CourierDeliveryViewModel()
    @State private var showingDeliveries = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Приветствие
                    headerSection
                    
                    // Статистика
                    statisticsSection
                    
                    // Активные доставки
                    activeDeliveriesSection
                    
                    // Быстрые действия
                    quickActionsSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Курьер")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingDeliveries = true
                    }) {
                        Image(systemName: "truck.box.fill")
                    }
                }
            }
            .refreshable {
                await loadDeliveries()
            }
        }
        .sheet(isPresented: $showingDeliveries) {
            CourierDeliveryView()
        }
        .onAppear {
            Task {
                await loadDeliveries()
            }
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Добро пожаловать!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Управляйте доставками и подтверждайте получения")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Статистика")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                
                StatCard(
                    icon: "truck.box.fill",
                    title: "Активные",
                    value: "5",
                    color: .blue,
                    style: .compact
                )
                
                StatCard(
                    icon: "checkmark.circle.fill",
                    title: "Сегодня",
                    value: "12",
                    color: .green,
                    style: .compact
                )
                
                StatCard(
                    icon: "clock.fill",
                    title: "В ожидании",
                    value: "3",
                    color: .orange,
                    style: .compact
                )
            }
        }
    }
    
    private var activeDeliveriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Активные доставки")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Все доставки") {
                    showingDeliveries = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            // Заглушка для активных доставок
            VStack(spacing: 8) {
                ForEach(1...3, id: \.self) { index in
                    MockDeliveryCard(orderNumber: "KSP-78912\(index)")
                }
            }
        }
    }
    
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
                    icon: "truck.box.fill",
                    title: "Мои доставки",
                    subtitle: "Активные заказы",
                    color: .blue
                ) {
                    showingDeliveries = true
                }
                
                QuickActionCard(
                    icon: "location.circle.fill",
                    title: "GPS Навигация",
                    subtitle: "Найти адрес",
                    color: .green
                ) {
                    // TODO: Открыть навигацию
                }
                
                QuickActionCard(
                    icon: "phone.circle.fill",
                    title: "Связь с клиентом",
                    subtitle: "Позвонить",
                    color: .orange
                ) {
                    // TODO: Открыть телефон
                }
                
                QuickActionCard(
                    icon: "lock.circle.fill",
                    title: "Код подтверждения",
                    subtitle: "Ввести код",
                    color: .purple
                ) {
                    showingDeliveries = true
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadDeliveries() async {
        // TODO: Загрузить реальные доставки
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
}

// MARK: - Mock Components

struct MockDeliveryCard: View {
    let orderNumber: String
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.orange)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Заказ #\(orderNumber)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("г. Алматы, ул. Абая 150")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("В пути")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                
                Text("599,000 ₸")
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

#Preview {
    CourierDashboard()
}
