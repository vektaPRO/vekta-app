//
//  KaspiSettingsView.swift
//  vektaApp
//
//  Настройка интеграции с Kaspi API (X-TOKEN из cookies)
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
                     "API готов к работе" :
                     "Добавьте X-TOKEN для синхронизации")
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
                        Text("Автодемпинг")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Снижать цены если позиция > 1")
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
                        
                        Text("Проверка каждые 5 минут. Цена снижается на 2%")
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
                        message: "Токен валидный. API работает корректно.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        window.rootViewController?.present(alert, animated: true)
                    }
                } else {
                    kaspiService.errorMessage = "Токен недействителен или API недоступен"
                }
            }
        }
    }
    
    private func syncProducts() {
        Task {
            do {
                let products = try await kaspiService.syncAllProducts()
                
                await MainActor.run {
                    // Показываем успех
                    let alert = UIAlertController(
                        title: "✅ Синхронизация завершена",
                        message: "Загружено \(products.count) товаров",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        window.rootViewController?.present(alert, animated: true)
                    }
                }
            } catch {
                kaspiService.errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Instructions View

struct KaspiTokenInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Заголовок
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Как получить X-TOKEN")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("X-TOKEN необходим для работы с Kaspi API")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Важное предупреждение
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Важно!")
                                .font(.headline)
                            
                            Text("Kaspi не предоставляет публичный API. Токен берется из cookies в браузере.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Инструкции
                    VStack(alignment: .leading, spacing: 20) {
                        InstructionStep(
                            number: "1",
                            title: "Войдите в Kaspi Seller Cabinet",
                            description: "Откройте браузер и войдите в личный кабинет продавца на kaspi.kz"
                        )
                        
                        InstructionStep(
                            number: "2",
                            title: "Откройте Developer Tools",
                            description: "Нажмите F12 или Cmd+Option+I (Mac) / Ctrl+Shift+I (Windows)"
                        )
                        
                        InstructionStep(
                            number: "3",
                            title: "Перейдите во вкладку Application",
                            description: "В Developer Tools найдите вкладку Application (или Storage в Firefox)"
                        )
                        
                        InstructionStep(
                            number: "4",
                            title: "Найдите Cookies",
                            description: "В левой панели раскройте Cookies → kaspi.kz"
                        )
                        
                        InstructionStep(
                            number: "5",
                            title: "Скопируйте X-TOKEN",
                            description: "Найдите cookie с именем X-TOKEN и скопируйте его значение (Value)"
                        )
                    }
                    
                    // Скриншот примера
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Пример:")
                            .font(.headline)
                        
                        Image(systemName: "photo")
                            .font(.system(size: 100))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 200)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(12)
                            .overlay(
                                Text("Скриншот Developer Tools")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            )
                    }
                    
                    // Дополнительная информация
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Дополнительно:")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Токен действителен ограниченное время", systemImage: "clock")
                            Label("При выходе из кабинета токен становится недействительным", systemImage: "xmark.circle")
                            Label("Для автоматизации рекомендуется использовать отдельный браузер", systemImage: "macwindow")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Инструкция")
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

// MARK: - Helper Views

struct InstructionStep: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.orange)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

#Preview {
    KaspiSettingsView()
}
