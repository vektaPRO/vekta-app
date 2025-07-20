//
//  CreateOrderView.swift
//  vektaApp
//
//  Created by Almas Kadeshov on 02.07.2025.
//

import SwiftUI

struct CreateOrderView: View {
    
    // 🧠 ViewModels
    @StateObject private var ordersViewModel = OrdersViewModel()
    @StateObject private var productsViewModel = ProductsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    // 📦 Выбранные товары (Product: количество)
    @State private var selectedProducts: [Product: Int] = [:]
    
    // 📝 Данные формы
    @State private var selectedWarehouse = "Склад Алматы"
    @State private var notes = ""
    @State private var selectedPriority: OrderPriority = .normal
    @State private var estimatedDelivery = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
    @State private var hasEstimatedDelivery = true
    
    // 📱 Состояние интерфейса
    @State private var currentStep = 1
    @State private var showingQRCode = false
    @State private var createdOrder: Order?
    
    // 🏭 Доступные склады
    private let warehouses = [
        "Склад Алматы",
        "Склад Астана",
        "Склад Шымкент",
        "Склад Караганда"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // 📊 Прогресс бар
                progressBar
                
                // 📱 Основной контент
                ScrollView {
                    VStack(spacing: 20) {
                        
                        switch currentStep {
                        case 1:
                            productSelectionStep
                        case 2:
                            orderDetailsStep
                        case 3:
                            confirmationStep
                        default:
                            productSelectionStep
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
                
                // 🔘 Нижние кнопки
                bottomButtons
            }
            .navigationTitle("Создать заказ")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingQRCode) {
                if let order = createdOrder {
                    QRCodeView(order: order) {
                        dismiss()
                    }
                }
            }
            .alert("Ошибка", isPresented: .constant(ordersViewModel.errorMessage != nil)) {
                Button("OK") {
                    ordersViewModel.errorMessage = nil
                }
            } message: {
                Text(ordersViewModel.errorMessage ?? "")
            }
        }
        .onAppear {
            productsViewModel.loadProducts()
        }
    }
}

// MARK: - Компоненты интерфейса
extension CreateOrderView {
    
    // 📊 Прогресс бар
    private var progressBar: some View {
        VStack(spacing: 0) {
            HStack {
                ForEach(1...3, id: \.self) { step in
                    HStack {
                        Circle()
                            .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 30, height: 30)
                            .overlay(
                                Text("\(step)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(step <= currentStep ? .white : .gray)
                            )
                        
                        if step < 3 {
                            Rectangle()
                                .fill(step < currentStep ? Color.blue : Color.gray.opacity(0.3))
                                .frame(height: 2)
                        }
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 16)
            
            // Заголовки шагов
            HStack {
                Text("Товары")
                    .font(.caption)
                    .foregroundColor(currentStep >= 1 ? .blue : .secondary)
                    .frame(maxWidth: .infinity)
                
                Text("Детали")
                    .font(.caption)
                    .foregroundColor(currentStep >= 2 ? .blue : .secondary)
                    .frame(maxWidth: .infinity)
                
                Text("Подтверждение")
                    .font(.caption)
                    .foregroundColor(currentStep >= 3 ? .blue : .secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            
            Divider()
        }
        .background(Color(UIColor.systemGray6))
    }
    
    // 📦 Шаг 1: Выбор товаров
    private var productSelectionStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Заголовок
            VStack(alignment: .leading, spacing: 8) {
                Text("Выберите товары")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Отметьте товары которые хотите отправить на склад")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Выбранные товары (краткий обзор)
            if !selectedProducts.isEmpty {
                selectedProductsSummary
            }
            
            // Список доступных товаров
            if productsViewModel.isLoading {
                LoadingView("Загружаем товары...")
                    .frame(height: 200)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(productsViewModel.filteredProducts) { product in
                        ProductSelectionCard(
                            product: product,
                            selectedQuantity: selectedProducts[product] ?? 0
                        ) { quantity in
                            if quantity > 0 {
                                selectedProducts[product] = quantity
                            } else {
                                selectedProducts.removeValue(forKey: product)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // 📝 Шаг 2: Детали заказа
    private var orderDetailsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // Заголовок
            VStack(alignment: .leading, spacing: 8) {
                Text("Детали заказа")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Укажите склад назначения и дополнительную информацию")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Выбор склада
            VStack(alignment: .leading, spacing: 8) {
                Text("Склад назначения")
                    .font(.headline)
                
                Picker("Склад", selection: $selectedWarehouse) {
                    ForEach(warehouses, id: \.self) { warehouse in
                        Text(warehouse).tag(warehouse)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(8)
            }
            
            // Приоритет
            VStack(alignment: .leading, spacing: 8) {
                Text("Приоритет")
                    .font(.headline)
                
                Picker("Приоритет", selection: $selectedPriority) {
                    ForEach(OrderPriority.allCases, id: \.rawValue) { priority in
                        HStack {
                            Image(systemName: priority.iconName)
                            Text(priority.rawValue)
                        }.tag(priority)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Планируемая дата доставки
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Указать планируемую дату", isOn: $hasEstimatedDelivery)
                    .font(.headline)
                
                if hasEstimatedDelivery {
                    DatePicker(
                        "Дата доставки",
                        selection: $estimatedDelivery,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .frame(maxHeight: 400)
                }
            }
            
            // Заметки
            VStack(alignment: .leading, spacing: 8) {
                Text("Заметки к заказу")
                    .font(.headline)
                
                TextField("Введите дополнительные инструкции...", text: $notes, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...6)
            }
        }
    }
    
    // ✅ Шаг 3: Подтверждение
    private var confirmationStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // Заголовок
            VStack(alignment: .leading, spacing: 8) {
                Text("Подтверждение заказа")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Проверьте данные перед созданием заказа")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Сводка заказа
            OrderSummaryCard(
                selectedProducts: selectedProducts,
                warehouse: selectedWarehouse,
                priority: selectedPriority,
                estimatedDelivery: hasEstimatedDelivery ? estimatedDelivery : nil,
                notes: notes
            )
        }
    }
    
    // 🔘 Нижние кнопки
    private var bottomButtons: some View {
        VStack(spacing: 12) {
            
            if ordersViewModel.isLoading {
                ProgressView("Создаем заказ...")
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                HStack(spacing: 12) {
                    // Кнопка "Назад"
                    if currentStep > 1 {
                        Button("Назад") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    }
                    
                    // Основная кнопка
                    Button(action: {
                        handleMainButtonTap()
                    }) {
                        Text(mainButtonTitle)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canProceed ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(!canProceed)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 34)
        .background(Color(UIColor.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
    }
    
    // 📋 Краткий обзор выбранных товаров
    private var selectedProductsSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Выбранные товары (\(selectedProducts.count))")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(selectedProducts.keys), id: \.id) { product in
                        if let quantity = selectedProducts[product] {
                            HStack(spacing: 6) {
                                Text(product.name)
                                    .lineLimit(1)
                                Text("×\(quantity)")
                                    .fontWeight(.bold)
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(16)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
    
    // 🎯 Вспомогательные свойства
    private var mainButtonTitle: String {
        switch currentStep {
        case 1: return "Далее"
        case 2: return "Далее"
        case 3: return "Создать заказ"
        default: return "Далее"
        }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 1: return !selectedProducts.isEmpty
        case 2: return !selectedWarehouse.isEmpty
        case 3: return true
        default: return false
        }
    }
    
    // 🎬 Действия
    private func handleMainButtonTap() {
        switch currentStep {
        case 1, 2:
            withAnimation {
                currentStep += 1
            }
        case 3:
            createOrder()
        default:
            break
        }
    }
    
    private func createOrder() {
        Task {
            let success = await ordersViewModel.createOrder(
                selectedProducts: selectedProducts,
                warehouseId: selectedWarehouse.lowercased().replacingOccurrences(of: " ", with: "_"),
                warehouseName: selectedWarehouse,
                notes: notes,
                priority: selectedPriority,
                estimatedDelivery: hasEstimatedDelivery ? estimatedDelivery : nil
            )
            
            if success {
                // Получаем созданный заказ (первый в списке после создания)
                createdOrder = ordersViewModel.orders.first
                showingQRCode = true
            }
        }
    }
}

// MARK: - Подкомпоненты

/// Карточка выбора товара
struct ProductSelectionCard: View {
    let product: Product
    let selectedQuantity: Int
    let onQuantityChanged: (Int) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            
            // Изображение товара
            AsyncImage(url: URL(string: product.imageURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.systemGray5))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    )
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Информация о товаре
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(product.formattedPrice)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "cube.box")
                        .foregroundColor(.blue)
                    Text("В наличии: \(product.totalStock)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            // Селектор количества
            QuantitySelector(
                quantity: selectedQuantity,
                maxQuantity: product.totalStock,
                onQuantityChanged: onQuantityChanged
            )
        }
        .padding(12)
        .background(selectedQuantity > 0 ? Color.blue.opacity(0.05) : Color(UIColor.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(selectedQuantity > 0 ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

/// Селектор количества
struct QuantitySelector: View {
    let quantity: Int
    let maxQuantity: Int
    let onQuantityChanged: (Int) -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: {
                if quantity > 0 {
                    onQuantityChanged(quantity - 1)
                }
            }) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(quantity > 0 ? .red : .gray)
            }
            .disabled(quantity <= 0)
            
            Text("\(quantity)")
                .font(.headline)
                .frame(minWidth: 30)
            
            Button(action: {
                if quantity < maxQuantity {
                    onQuantityChanged(quantity + 1)
                }
            }) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(quantity < maxQuantity ? .blue : .gray)
            }
            .disabled(quantity >= maxQuantity)
        }
    }
}

/// Карточка сводки заказа
struct OrderSummaryCard: View {
    let selectedProducts: [Product: Int]
    let warehouse: String
    let priority: OrderPriority
    let estimatedDelivery: Date?
    let notes: String
    
    var totalValue: Double {
        selectedProducts.reduce(0) { total, item in
            total + (item.key.price * Double(item.value))
        }
    }
    
    var formattedTotalValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "KZT"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: totalValue)) ?? "\(Int(totalValue)) ₸"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Товары
            VStack(alignment: .leading, spacing: 8) {
                Text("Товары (\(selectedProducts.count))")
                    .font(.headline)
                
                ForEach(Array(selectedProducts.keys), id: \.id) { product in
                    if let quantity = selectedProducts[product] {
                        HStack {
                            Text(product.name)
                                .lineLimit(1)
                            Spacer()
                            Text("×\(quantity)")
                            Text(product.formattedPrice)
                                .foregroundColor(.secondary)
                        }
                        .font(.subheadline)
                    }
                }
                
                Divider()
                
                HStack {
                    Text("Итого:")
                        .font(.headline)
                    Spacer()
                    Text(formattedTotalValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            
            // Детали
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(title: "Склад:", value: warehouse)
                InfoRow(title: "Приоритет:", value: priority.rawValue)
                
                if let delivery = estimatedDelivery {
                    InfoRow(title: "Планируемая дата:", value: DateFormatter.mediumDateFormatter.string(from: delivery))
                }
                
                if !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Заметки:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(notes)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

/// Строка информации
struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Расширения DateFormatter
extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}

#Preview {
    CreateOrderView()
}
