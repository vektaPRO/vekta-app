//
//  KaspiSettingsView.swift
//  vektaApp
//
//  Обновленная настройка интеграции с Kaspi API (X-TOKEN из cookies)
//

import SwiftUI

struct KaspiSettingsView: View {
    
    @StateObject private var kaspiService = KaspiAPIService()
    @State private var tokenInput = ""
    @State private var showingInstructions = false
    @State private var showingTestView = false
    @State private var isTestingToken = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Статус подключения
                    connectionStatusSection
                    
                    // Ввод токена
                    tokenInputSection
                    
                    // Автодемпинг
                    if kaspiService.kaspiToken != nil {
                        autoDumpingSection
                    }
                    
                    // Кнопки действий
                    actionButtonsSection
                    
                    // Последняя синхронизация
                    if let lastSync = kaspiService.lastSyncDate {
                        lastSyncSection(lastSync)
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Kaspi Integration")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingInstructions) {
                KaspiTokenInstructionsView()
            }
            .sheet(isPresented: $showingTestView) {
                KaspiAPITestView()
            }
            .alert("Ошибка", isPresented: .constant(kaspiService.errorMessage != nil)) {
                Button("OK") {
                    kaspiService.clearMessages()
                }
            } message: {
                Text(kaspiService.errorMessage ?? "")
            }
        }
        .onAppear {
            if let token = kaspiService.kaspiToken {
                tokenInput = token
            }
        }
    }
}

// MARK: - View Components

extension KaspiSettingsView {
    
    // Статус подключения
    private var connectionStatusSection: some View {
        VStack(spacing: 16) {
            Image(systemName: kaspiService.kaspiToken != nil ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(kaspiService.kaspiToken != nil ? .green : .orange)
            
            VStack(spacing: 8) {
                Text(kaspiService.kaspiToken != nil ? "Kaspi подключен" : "Требуется настройка")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(kaspiService.kaspiToken != nil ?
                     "X-TOKEN активен и готов к работе" :
                     "Добавьте X-TOKEN из cookies для синхронизации")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.bottom, 20)
    }
    
    // Ввод токена
    private var tokenInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("X-TOKEN из Kaspi")
                    .font(.headline)
                
                Spacer()
                
                Button("Как получить?") {
                    showingInstructions = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            VStack(spacing: 12) {
                TextField("Вставьте X-TOKEN из cookies", text: $tokenInput, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .lineLimit(2...4)
                
                HStack(spacing: 12) {
                    // Сохранить токен
                    Button(action: saveToken) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Сохранить")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(tokenInput.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(tokenInput.isEmpty)
                    
                    // Проверить токен
                    Button(action: testToken) {
                        HStack {
                            if isTestingToken {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.circle")
                            }
                            Text("Проверить")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(tokenInput.isEmpty ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(tokenInput.isEmpty || isTestingToken)
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
    
    // Автодемпинг
    private var autoDumpingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Автоматическое снижение цен")
                .font(.headline)
            
            VStack(spacing: 12) {
                Toggle(isOn: $kaspiService.isAutoDumpingEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Автодемпинг цен")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Снижать цены если позиция товара > 1")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: kaspiService.isAutoDumpingEnabled) { _ in
                    kaspiService.toggleAutoDumping()
                }
                
                if kaspiService.isAutoDumpingEnabled {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        
                        Text("Проверка каждые 5 минут. Цена снижается на 2% при позиции > 1")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
    
    // Кнопки действий
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Синхронизировать товары
            Button(action: syncProducts) {
                HStack {
                    if kaspiService.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Text("Синхронизировать товары")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(kaspiService.kaspiToken != nil ? Color.orange : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(kaspiService.kaspiToken == nil || kaspiService.isLoading)
            
            // Тестирование API
            Button(action: { showingTestView = true }) {
                HStack {
                    Image(systemName: "testtube.2")
                    Text("Полное тестирование API")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
    }
    
    // Информация о последней синхронизации
    private func lastSyncSection(_ date: Date) -> some View {
        HStack {
            Image(systemName: "clock")
                .foregroundColor(.secondary)
            
            Text("Последняя синхронизация: \(DateFormatter.shortDateTime.string(from: date))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(12)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - Actions
    
    private func saveToken() {
        kaspiService.kaspiToken = tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func testToken() {
        isTestingToken = true
        
        Task {
            let isValid = await kaspiService.checkAPIHealth()
            
            await MainActor.run {
                isTestingToken = false
                
                if isValid {
                    // Показываем успех
                    let alert = UIAlertController(
                        title: "✅ Успех",
                        message: "X-TOKEN валидный. Kaspi API работает корректно.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
