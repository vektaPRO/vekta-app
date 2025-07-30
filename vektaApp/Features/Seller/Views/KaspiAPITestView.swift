//
//  KaspiAPITestView.swift
//  vektaApp
//
//  UI для тестирования Kaspi API
//

import SwiftUI

struct KaspiAPITestView: View {
    @StateObject private var testService = KaspiTestService()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                if testService.isRunning {
                    // Прогресс тестирования
                    VStack(spacing: 16) {
                        ProgressView("Выполняется тест: \(testService.currentTestName)")
                            .progressViewStyle(CircularProgressViewStyle())
                        
                        ProgressView(value: testService.progress)
                            .progressViewStyle(LinearProgressViewStyle())
                    }
                    .padding()
                    
                } else if testService.testResults.isEmpty {
                    // Начальное состояние
                    VStack(spacing: 16) {
                        Image(systemName: "testtube.2")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Тестирование Kaspi API")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Проверьте работоспособность всех функций")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Запустить тесты") {
                            Task {
                                await testService.runAllTests()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                } else {
                    // Результаты тестов
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            
                            // Общий статус
                            HStack {
                                Image(systemName: statusIcon)
                                    .foregroundColor(statusColor)
                                
                                Text("Тестирование завершено")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text(testService.getTestSummary())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(statusColor.opacity(0.1))
                            .cornerRadius(12)
                            
                            // Результаты тестов
                            ForEach(testService.testResults, id: \.id) { result in
                                TestResultCard(result: result)
                            }
                        }
                        .padding()
                    }
                    
                    // Кнопки действий
                    HStack(spacing: 12) {
                        Button("Повторить") {
                            testService.clearResults()
                            Task {
                                await testService.runAllTests()
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        if let exportData = testService.exportResults() {
                            ShareLink(
                                item: exportData,
                                preview: SharePreview("Результаты тестов Kaspi API")
                            ) {
                                Text("Экспорт")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Тест API")
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

struct TestResultCard: View {
    let result: KaspiTestService.TestResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                
                Text(result.name)
                    .font(.headline)
                
                Spacer()
                
                if let duration = result.duration {
                    Text(String(format: "%.2fs", duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(result.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let message = result.message {
                Text(message)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.1))
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
    
    private var statusIcon: String {
        switch result.status {
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        default: return "circle"
        }
    }
    
    private var statusColor: Color {
        switch result.status {
        case .passed: return .green
        case .failed: return .red
        default: return .gray
        }
    }
}

#Preview {
    KaspiAPITestView()
}
