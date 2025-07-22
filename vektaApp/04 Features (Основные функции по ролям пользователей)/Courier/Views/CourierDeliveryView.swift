//
//  CourierDeliveryView.swift
//  vektaApp
//
//  Интерфейс для управления доставками курьером
//

import SwiftUI

struct CourierDeliveryView: View {
    
    @StateObject private var viewModel = CourierDeliveryViewModel()
    @State private var showingDeliveryDetail = false
    @State private var showingSMSCodeInput = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // 📊 Статистика
                statsHeaderView
                
                // 📦 Список доставок
                deliveryListView
            }
            .navigationTitle("Мои доставки")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingDeliveryDetail) {
                if let delivery = viewModel.currentDelivery {
                    DeliveryDetailView(
                        delivery: delivery,
                        viewModel: viewModel,
                        showingSMSCodeInput: $showingSMSCodeInput
                    )
                }
            }
            .sheet(isPresented: $showingSMSCodeInput) {
                if let delivery = viewModel.currentDelivery {
                    SMSCodeInputView(
                        delivery: delivery,
                        viewModel: viewModel
                    )
                }
            }
            .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("Успех", isPresented: .constant(viewModel.successMessage != nil)) {
                Button("OK") {
                    viewModel.successMessage = nil
                }
            } message: {
                Text(viewModel.successMessage ?? "")
            }
        }
    }
}

// MARK: - Components

extension CourierDeliveryView {
    
    // 📊 Статистика в шапке
    private var statsHeaderView: some View {
        HStack(spacing: 20) {
            StatCard(
                icon: "truck.box.fill",
                title: "Активные",
                value: "\(viewModel.pendingDeliveries)",
                color: .blue
            )
            
            StatCard(
                icon: "checkmark.circle.fill",
                title: "Сегодня",
                value: "\(viewModel.todayDeliveries)",
                color: .green
            )
            
            StatCard(
                icon: "clock.fill",
                title: "В ожидании",
                value: "\(viewModel.activeDeliveries.filter { $0.status == .awaitingCode }.count)",
                color: .orange
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemGray6))
    }
    
    // 📦 Список доставок
    private var deliveryListView: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Загрузка доставок...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.activeDeliveries.isEmpty {
                EmptyDeliveriesView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.activeDeliveries) { delivery in
                            DeliveryCard(delivery: delivery) {
                                viewModel.currentDelivery = delivery
                                showingDeliveryDetail = true
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
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

// MARK: - Delivery Card

struct DeliveryCard: View {
    let delivery: DeliveryConfirmation
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                
                // Заголовок
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Заказ #\(delivery.trackingNumber)")
                            .font(.headline)
                        
                        Text(delivery.deliveryAddress)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Статус
                    StatusBadge(status: delivery.status)
                }
                
                // Информация о клиенте
                HStack(spacing: 12) {
                    Label(delivery.formattedPhone, systemImage: "phone.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if delivery.status == .awaitingCode {
                        Label("Ожидает код", systemImage: "lock.circle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                // Время
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(delivery.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
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

// MARK: - Status Badge

struct StatusBadge: View {
    let status: DeliveryStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.iconName)
                .font(.caption)
            
            Text(status.rawValue)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(Color(status.color))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(status.color).opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Empty State

struct EmptyDeliveriesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "truck.box")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Нет активных доставок")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Новые доставки появятся здесь")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Delivery Detail View

struct DeliveryDetailView: View {
    let delivery: DeliveryConfirmation
    @ObservedObject var viewModel: CourierDeliveryViewModel
    @Binding var showingSMSCodeInput: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Информация о заказе
                    orderInfoSection
                    
                    // Информация о клиенте
                    customerInfoSection
                    
                    // Действия
                    actionsSection
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
            .navigationTitle("Детали доставки")
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
    
    // Информация о заказе
    private var orderInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Информация о заказе")
                .font(.headline)
            
            VStack(spacing: 12) {
                InfoRow(
                    icon: "number",
                    title: "Номер заказа",
                    value: delivery.trackingNumber
                )
                
                InfoRow(
                    icon: "location.circle",
                    title: "Адрес доставки",
                    value: delivery.deliveryAddress
                )
                
                InfoRow(
                    icon: "clock",
                    title: "Создан",
                    value: DateFormatter.shortDateTimeFormatter.string(from: delivery.createdAt)
                )
            }
            .padding(16)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // Информация о клиенте
    private var customerInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Информация о клиенте")
                .font(.headline)
            
            VStack(spacing: 12) {
                InfoRow(
                    icon: "phone",
                    title: "Телефон",
                    value: delivery.formattedPhone
                )
                
                if delivery.smsCodeRequested {
                    InfoRow(
                        icon: "lock",
                        title: "Код отправлен",
                        value: delivery.smsCodeRequestedAt != nil ?
                            DateFormatter.shortTimeFormatter.string(from: delivery.smsCodeRequestedAt!) : "—"
                    )
                    
                    if let expiresAt = delivery.codeExpiresAt {
                        InfoRow(
                            icon: "timer",
                            title: "Действителен до",
                            value: DateFormatter.shortTimeFormatter.string(from: expiresAt)
                        )
                    }
                }
            }
            .padding(16)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // Действия
    private var actionsSection: some View {
        VStack(spacing: 12) {
            
            switch delivery.status {
            case .pending:
                ActionButton(
                    title: "Начать доставку",
                    icon: "play.circle.fill",
                    color: .blue,
                    isLoading: viewModel.isLoading
                ) {
                    Task {
                        await viewModel.startDelivery(delivery)
                    }
                }
                
            case .inTransit:
                ActionButton(
                    title: "Я прибыл к клиенту",
                    icon: "location.circle.fill",
                    color: .green,
                    isLoading: viewModel.isLoading
                ) {
                    Task {
                        await viewModel.arrivedAtCustomer(delivery)
                    }
                }
                
            case .arrived:
                ActionButton(
                    title: "Запросить SMS код",
                    icon: "envelope.circle.fill",
                    color: .orange,
                    isLoading: viewModel.isRequestingSMS
                ) {
                    Task {
                        await viewModel.requestSMSCode(for: delivery)
                    }
                }
                
            case .awaitingCode:
                ActionButton(
                    title: "Ввести код подтверждения",
                    icon: "keyboard",
                    color: .blue,
                    isLoading: false
                ) {
                    showingSMSCodeInput = true
                }
                
                if delivery.canRequestNewCode {
                    ActionButton(
                        title: "Запросить новый код",
                        icon: "arrow.clockwise",
                        color: .orange,
                        isLoading: viewModel.isRequestingSMS
                    ) {
                        Task {
                            await viewModel.requestSMSCode(for: delivery)
                        }
                    }
                }
                
            default:
                EmptyView()
            }
            
            // Кнопка отмены доставки
            if delivery.status != .confirmed && delivery.status != .cancelled {
                ActionButton(
                    title: "Не удалось доставить",
                    icon: "xmark.circle",
                    color: .red,
                    isLoading: false
                ) {
                    // TODO: Показать диалог с причиной
                    Task {
                        await viewModel.markDeliveryFailed(delivery, reason: "Клиент отказался")
                    }
                }
            }
        }
    }
}

// MARK: - Helper Views

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: icon)
                }
                
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isLoading ? Color.gray : color)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isLoading)
    }
}

// MARK: - SMS Code Input View

struct SMSCodeInputView: View {
    let delivery: DeliveryConfirmation
    @ObservedObject var viewModel: CourierDeliveryViewModel
    @Environment(\.dismiss) private var dismiss
    
    @FocusState private var isCodeFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                
                // Иконка
                Image(systemName: "lock.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .padding(.top, 40)
                
                // Заголовок
                VStack(spacing: 8) {
                    Text("Введите код подтверждения")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Код отправлен на номер")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(delivery.formattedPhone)
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                
                // Поле ввода кода
                HStack(spacing: 12) {
                    ForEach(0..<6, id: \.self) { index in
                        CodeDigitView(
                            digit: digitAt(index: index),
                            isActive: index == viewModel.enteredCode.count
                        )
                    }
                }
                .onTapGesture {
                    isCodeFieldFocused = true
                }
                
                // Скрытое поле для ввода
                TextField("", text: $viewModel.enteredCode)
                    .keyboardType(.numberPad)
                    .focused($isCodeFieldFocused)
                    .opacity(0)
                    .onChange(of: viewModel.enteredCode) { newValue in
                        // Ограничиваем 6 цифрами
                        if newValue.count > 6 {
                            viewModel.enteredCode = String(newValue.prefix(6))
                        }
                        
                        // Автоматически проверяем при вводе 6 цифр
                        if newValue.count == 6 {
                            verifyCode()
                        }
                    }
                
                // Информация о попытках
                if delivery.attemptCount > 0 {
                    Text("Осталось попыток: \(delivery.remainingAttempts)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                // Кнопка подтверждения
                Button(action: verifyCode) {
                    HStack {
                        if viewModel.isVerifyingCode {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.circle")
                        }
                        
                        Text("Подтвердить доставку")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.enteredCode.count == 6 ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(viewModel.enteredCode.count != 6 || viewModel.isVerifyingCode)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationTitle("Подтверждение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        viewModel.clearEnteredCode()
                        dismiss()
                    }
                }
            }
            .onAppear {
                isCodeFieldFocused = true
            }
        }
    }
    
    private func digitAt(index: Int) -> String {
        if index < viewModel.enteredCode.count {
            let stringIndex = viewModel.enteredCode.index(viewModel.enteredCode.startIndex, offsetBy: index)
            return String(viewModel.enteredCode[stringIndex])
        }
        return ""
    }
    
    private func verifyCode() {
        Task {
            await viewModel.confirmDeliveryWithCode(viewModel.enteredCode, for: delivery)
            
            // Если доставка подтверждена успешно, закрываем
            if viewModel.currentDelivery?.status == .confirmed {
                dismiss()
            }
        }
    }
}

// MARK: - Code Digit View

struct CodeDigitView: View {
    let digit: String
    let isActive: Bool
    
    var body: some View {
        Text(digit)
            .font(.title)
            .fontWeight(.bold)
            .frame(width: 45, height: 55)
            .background(Color(UIColor.systemGray6))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? Color.blue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(8)
    }
}

// MARK: - Date Formatter Extensions

extension DateFormatter {
    static let shortDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    CourierDeliveryView()
}
