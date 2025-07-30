//
//  KaspiInstructionsView.swift
//  vektaApp
//
//  Инструкции по получению Kaspi API токена
//

import SwiftUI

struct KaspiInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Заголовок
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Получение API токена Kaspi")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Пошаговая инструкция для настройки интеграции")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Шаги
                    VStack(alignment: .leading, spacing: 20) {
                        
                        InstructionStep(
                            number: "1",
                            text: "Перейдите на сайт kaspi.kz и войдите в кабинет продавца"
                        )
                        
                        InstructionStep(
                            number: "2",
                            text: "В меню найдите раздел \"Интеграция\" или \"API\""
                        )
                        
                        InstructionStep(
                            number: "3",
                            text: "Откройте браузерные инструменты разработчика (F12)"
                        )
                        
                        InstructionStep(
                            number: "4",
                            text: "Перейдите во вкладку \"Application\" или \"Хранилище\""
                        )
                        
                        InstructionStep(
                            number: "5",
                            text: "Найдите раздел \"Cookies\" и откройте cookies для kaspi.kz"
                        )
                        
                        InstructionStep(
                            number: "6",
                            text: "Найдите cookie с именем \"X-TOKEN\" и скопируйте его значение"
                        )
                        
                        InstructionStep(
                            number: "7",
                            text: "Вставьте скопированный токен в приложение и сохраните"
                        )
                    }
                    
                    // Важные заметки
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Важно", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• Токен действителен только пока вы авторизованы в Kaspi")
                            Text("• При выходе из кабинета токен перестанет работать")
                            Text("• Не делитесь токеном с третьими лицами")
                            Text("• При проблемах обратитесь в поддержку Kaspi")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Альтернативный способ
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Альтернативный способ", systemImage: "lightbulb.fill")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Text("Если у вас есть официальный API ключ от Kaspi, используйте его вместо токена из cookies. Официальный API ключ более стабилен и безопасен.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(Color.blue.opacity(0.1))
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
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    KaspiInstructionsView()
}
