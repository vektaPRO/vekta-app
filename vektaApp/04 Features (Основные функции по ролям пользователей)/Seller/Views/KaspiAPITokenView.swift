//
//  KaspiAPITokenView.swift
//  vektaApp
//
//  Created by Almas Kadeshov on 29.06.2025.
//

import SwiftUI

struct KaspiAPITokenView: View {
    
    // 🧠 Подключаем ViewModel (мозг экрана)
    @StateObject private var viewModel = KaspiTokenViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // 🎨 Красивая шапка
                    headerSection
                    
                    // 📝 Форма ввода токена
                    tokenInputSection
                    
                    // ✅ Кнопка сохранения
                    saveButtonSection
                    
                    // 📖 Инструкция
                    instructionsSection
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Kaspi API")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
            .alert("Ошибка", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

// MARK: - Компоненты интерфейса
extension KaspiAPITokenView {
    
    // 🎨 Красивая шапка с иконкой
    private var headerSection: some View {
        VStack(spacing: 16) {
            
            // Иконка Kaspi
            Image(systemName: "creditcard.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("Подключение к Kaspi")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Введите ваш API токен для синхронизации товаров")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.bottom, 20)
    }
    
    // 📝 Поле ввода токена
    private var tokenInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            HStack {
                Text("API Токен")
                    .font(.headline)
                
                Spacer()
                
                // Статус токена
                if viewModel.isTokenSaved {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Сохранен")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            // Поле ввода
            TextField("Вставьте ваш Kaspi API токен", text: $viewModel.apiToken, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .lineLimit(3...6)
            
            // Сообщения
            if let successMessage = viewModel.successMessage {
                Text(successMessage)
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
        .padding(20)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
    
    // ✅ Кнопка сохранения
    private var saveButtonSection: some View {
        Button(action: {
            viewModel.saveApiToken()
        }) {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                }
                
                Text(viewModel.isTokenSaved ? "Обновить токен" : "Сохранить токен")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.isValidToken() ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(viewModel.isLoading || !viewModel.isValidToken())
    }
    
    // 📖 Инструкция
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            Text("Как получить API токен:")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                InstructionStep(number: "1", text: "Войдите в кабинет продавца Kaspi.kz")
                InstructionStep(number: "2", text: "Перейдите в раздел \"Интеграция\" или \"API\"")
                InstructionStep(number: "3", text: "Создайте или скопируйте ваш API токен")
                InstructionStep(number: "4", text: "Вставьте токен в поле выше")
            }
        }
        .padding(20)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

// 📝 Компонент для шагов инструкции
struct InstructionStep: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Номер шага
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .clipShape(Circle())
            
            // Текст шага
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

#Preview {
    KaspiAPITokenView()
}
