import SwiftUI
import FirebaseAuth

struct SellerDashboard: View {
    
    // 📱 Состояние для навигации
    @State private var showingKaspiTokenView = false
    @State private var showingProductsView = false
    @State private var userEmail = Auth.auth().currentUser?.email ?? "Неизвестный"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // 👋 Приветствие
                    welcomeSection
                    
                    // 📊 Статистика
                    statsSection
                    
                    // 🔧 Основные функции
                    mainFunctionsSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
            .navigationTitle("Seller Panel")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingKaspiTokenView) {
            KaspiAPITokenView()
        }
        .sheet(isPresented: $showingProductsView) {
            ProductsView()
        }
    }
}

// MARK: - Компоненты интерфейса
extension SellerDashboard {
    
    // 👋 Секция приветствия
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Добро пожаловать!")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(userEmail)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 12, height: 12)
                    
                    Text("Настройка")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
    }
    
    // 📊 Статистика
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Статистика")
                .font(.headline)
                .padding(.horizontal, 4)
            
            HStack(spacing: 12) {
                StatCard(title: "Товары", value: "—", icon: "cube.box", color: .blue)
                StatCard(title: "Заказы", value: "—", icon: "cart", color: .green)
                StatCard(title: "Продажи", value: "—", icon: "chart.line.uptrend.xyaxis", color: .purple)
            }
        }
    }
    
    // 🔧 Основные функции
    private var mainFunctionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Основные функции")
                .font(.headline)
                .padding(.horizontal, 4)
            
            VStack(spacing: 12) {
                
                // 🔥 РАБОЧАЯ кнопка Kaspi API
                FunctionButton(
                    title: "Kaspi API",
                    subtitle: "Подключить API для синхронизации",
                    icon: "creditcard.circle.fill",
                    color: .orange
                ) {
                    showingKaspiTokenView = true  // ✅ Открываем экран
                }
                
                // 🔥 РАБОЧАЯ кнопка Товары
                FunctionButton(
                    title: "Товары",
                    subtitle: "Управление каталогом товаров",
                    icon: "cube.box.fill",
                    color: .blue
                ) {
                    showingProductsView = true  // ✅ Открываем экран товаров
                }
                
                FunctionButton(
                    title: "Заказы",
                    subtitle: "Создание и отслеживание заказов",
                    icon: "cart.fill",
                    color: .purple
                ) {
                    print("Заказы нажата")
                }
            }
        }
    }
}

// MARK: - UI Компоненты
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

struct FunctionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SellerDashboard()
}
