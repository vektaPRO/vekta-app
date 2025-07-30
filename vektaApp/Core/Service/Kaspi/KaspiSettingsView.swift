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
                        }
