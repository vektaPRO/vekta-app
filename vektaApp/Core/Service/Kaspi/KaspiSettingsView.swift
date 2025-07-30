//
//  KaspiSettingsView.swift
//  vektaApp
//
//  Расширенные настройки Kaspi интеграции
//

import SwiftUI

struct KaspiSettingsView: View {
    
    @StateObject private var kaspiAPI = KaspiAPIService()
    @StateObject private var testService = KaspiTestService()
    @Environment(\.dismiss) private var dismiss
    
    @State private var tokenInput = ""
    @State private var isValidatingToken = false
    @State private var showingTestResults = false
    @State private var showingInstructions = false
    
    // Configuration
    @State private var autoProcessingEnabled = false
    @State private var notificationsEnabled = true
    @State private var syncIntervalMinutes = 10
    @State private var maxOrdersPerHour = 50
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Connection Status
                    connectionStatusSection
                    
                    // Token Configuration
                    tokenConfigurationSection
                    
                    // API Test
                    apiTestSection
                    
                    // Automation Settings
                    automationSettingsSection
                    
                    // Notification Settings
                    notificationSettingsSection
                    
                    // Sync Settings
                    syncSettingsSection
                    
                    // Advanced Settings
                    advancedSettingsSection
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Настройки Kaspi")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingTestResults) {
                KaspiAPITestResultsView(testService: testService)
            }
            .sheet(isPresented: $showingInstructions) {
                KaspiInstructionsView()
            }
        }
        .onAppear {
            loadCurrentSettings()
        }
    }
}

// MARK: - View Components

extension KaspiSettingsView {
    
    // 🔗 Connection Status
    private var connectionStatusSection: some View {
        VStack(spacing: 16) {
            Image(systemName: kaspiAPI.apiToken != nil ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(kaspiAPI.apiToken != nil ? .green : .orange)
            
            VStack(spacing: 8) {
                Text(kaspiAPI.apiToken != nil ? "Kaspi API подключен" : "Требуется настройка")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(kaspiAPI.apiToken != nil
                     ? "Интеграция активна и готова к работе"
                     : "Добавьте API токен для подключения к Kaspi")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.bottom, 20)
    }
    
    // 🔑 Token Configuration
    private var tokenConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("API Токен")
                    .font(.headline)
                
                Spacer()
                
                Button("Инструкция") {
                    showingInstructions = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                TextField("Вставьте ваш Kaspi API токен", text: $tokenInput, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .lineLimit(3...6)
                
                HStack(spacing: 12) {
                    Button(action: saveToken) {
                        HStack {
                            if kaspiAPI.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.circle")
                            }
                            Text("Сохранить")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(tokenInput.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(tokenInput.isEmpty || kaspiAPI.isLoading)
                    
                    Button(action: validateToken) {
                        HStack {
                            if isValidatingToken {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.shield")
                            }
                            Text("Проверить")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(tokenInput.isEmpty ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(tokenInput.isEmpty || isValidatingToken)
                }
                
                // Success/Error Messages
                if let successMessage = kaspiAPI.successMessage {
                    Text(successMessage)
                        .foregroundColor(.green)
                        .font(.caption)
                }
                
                if let errorMessage = kaspiAPI.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding(20)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // 🧪 API Test Section
    private var apiTestSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Тестирование API")
                .font(.headline)
            
            VStack(spacing: 12) {
                Text("Проверьте работоспособность всех функций Kaspi API")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    Task {
                        await testService.runAllTests()
                        showingTestResults = true
                    }
                }) {
                    HStack {
                        if testService.isRunning {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "testtube.2")
                        }
                        Text("Запустить полное тестирование")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(testService.isRunning ? Color.gray : Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(testService.isRunning)
            }
            .padding(16)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // ⚙️ Automation Settings
    private var automationSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Автоматизация")
                .font(.headline)
            
            VStack(spacing: 16) {
                Toggle("Автоматическая обработка заказов", isOn: $autoProcessingEnabled)
                    .toggleStyle(SwitchToggleStyle())
                
                if autoProcessingEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Максимум заказов в час: \(maxOrdersPerHour)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Slider(value: Binding(
                            get: { Double(maxOrdersPerHour) },
                            set: { maxOrdersPerHour = Int($0) }
                        ), in: 1...100, step: 1)
                    }
                }
            }
            .padding(16)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // 🔔 Notification Settings
    private var notificationSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Уведомления")
                .font(.headline)
            
            VStack(spacing: 12) {
                Toggle("Push-уведомления", isOn: $notificationsEnabled)
                    .toggleStyle(SwitchToggleStyle())
                
                if notificationsEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Уведомлять о:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Новых заказах из Kaspi")
                            Text("• Ошибках синхронизации")
                            Text("• Успешных доставках")
                            Text("• Превышении лимитов API")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // 🔄 Sync Settings
    private var syncSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Синхронизация")
                .font(.headline)
            
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Интервал синхронизации: \(syncIntervalMinutes) мин")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Slider(value: Binding(
                        get: { Double(syncIntervalMinutes) },
                        set: { syncIntervalMinutes = Int($0) }
                    ), in: 5...60, step: 5)
                }
                
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    
                    Text("Рекомендуемый интервал: 10-15 минут")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            .padding(16)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // ⚡ Advanced Settings
    private var advancedSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Дополнительные настройки")
                .font(.headline)
            
            VStack(spacing: 12) {
                Button("Очистить кэш API") {
                    clearAPICache()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .cornerRadius(12)
                
                Button("Сбросить статистику") {
                    resetStatistics()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange.opacity(0.1))
                .foregroundColor(.orange)
                .cornerRadius(12)
                
                Button("Экспорт настроек") {
                    exportSettings()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(12)
            }
            .padding(16)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Actions
    
    private func saveToken() {
        kaspiAPI.apiToken = tokenInput
        Task {
            try await kaspiAPI.saveToken(tokenInput)
        }
    }
    
    private func validateToken() {
        isValidatingToken = true
        kaspiAPI.apiToken = tokenInput
        
        Task {
            let isValid = await kaspiAPI.validateToken()
            await MainActor.run {
                isValidatingToken = false
                if isValid {
                    kaspiAPI.successMessage = "✅ Токен действителен"
                } else {
                    kaspiAPI.errorMessage = "❌ Токен недействителен"
                }
            }
        }
    }
    
    private func loadCurrentSettings() {
        tokenInput = kaspiAPI.apiToken ?? ""
        // TODO: Загрузить другие настройки из UserDefaults или Firestore
    }
    
    private func saveSettings() {
        // TODO: Сохранить настройки в UserDefaults или Firestore
        print("Настройки сохранены")
    }
    
    private func clearAPICache() {
        // TODO: Очистить кэш API
        print("Кэш очищен")
    }
    
    private func resetStatistics() {
        // TODO: Сбросить статистику
        print("Статистика сброшена")
    }
    
    private func exportSettings() {
        // TODO: Экспорт настроек
        print("Настройки экспортированы")
    }
}

// MARK: - Test Results View

struct KaspiAPITestResultsView: View {
    @ObservedObject var testService: KaspiTestService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Overall Status
                    HStack {
                        Image(systemName: statusIcon)
                            .foregroundColor(statusColor)
                            .font(.title2)
                        
                        VStack(alignment: .leading) {
                            Text("Результаты тестирования")
                                .font(.headline)
                            
                            Text(testService.getTestSummary())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(statusColor.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Test Results
                    ForEach(testService.testResults, id: \.id) { result in
                        TestResultCard(result: result)
                    }
                }
                .padding()
            }
            .navigationTitle("Результаты тестов")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var statusIcon: String {
        switch testService.overallStatus {
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .partial: return "exclamationmark.triangle.fill"
        default: return "circle"
        }
    }
    
    private var statusColor: Color {
        switch testService.overallStatus {
        case .passed: return .green
        case .failed: return .red
        case .partial: return .orange
        default: return .gray
        }
    }
}

#Preview {
    KaspiSettingsView()
}
