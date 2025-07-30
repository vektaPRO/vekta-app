import SwiftUI

struct KaspiSettingsView: View {
    @StateObject private var service = KaspiAPIService()
    @State private var tokenInput = ""
    @State private var isTesting = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    connectionSection
                    tokenSection
                    if service.apiToken != nil {
                        autoDumpSection
                    }
                    actionButtons
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Kaspi Integration")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) {
                Button("Готово") { dismiss() }
            }}
            .onAppear { service.loadToken() }  // сразу подтянем ранее сохранённый токен
        }
    }

    // MARK: — Connection Status
    private var connectionSection: some View {
        VStack(spacing: 16) {
            Image(systemName: service.apiToken != nil
                  ? "checkmark.seal.fill"
                  : "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(service.apiToken != nil ? .green : .orange)

            VStack(spacing: 8) {
                Text(service.apiToken != nil ? "Kaspi подключен" : "Требуется настройка")
                    .font(.title2).fontWeight(.bold)
                Text(service.apiToken != nil
                     ? "X-TOKEN активен и готов к работе"
                     : "Добавьте X-TOKEN из cookies для синхронизации")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: — Token Input
    private var tokenSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("X-TOKEN из Kaspi").font(.headline)
                Spacer()
                Button("Как получить?") {
                    // показать тут инструкции
                }
                .font(.caption).foregroundColor(.blue)
            }

            TextField("Вставьте X-TOKEN", text: $tokenInput, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .lineLimit(2...4)

            HStack(spacing: 12) {
                Button("Сохранить") {
                    service.saveToken(tokenInput.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                .disabled(tokenInput.isEmpty)
                .buttonStyle(PrimaryButtonStyle(color: tokenInput.isEmpty ? .gray : .blue))

                Button {
                    isTesting = true
                    Task {
                        _ = await service.checkAPIHealth()
                        isTesting = false
                    }
                } label: {
                    HStack {
                        if isTesting {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.circle")
                        }
                        Text("Проверить")
                    }
                }
                .disabled(tokenInput.isEmpty || isTesting)
                .buttonStyle(PrimaryButtonStyle(color: tokenInput.isEmpty ? .gray : .green))
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: — Auto-Dumping Toggle
    private var autoDumpSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Автоматическое снижение цен").font(.headline)

            Toggle(isOn: $service.isAutoDumpingEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Автодемпинг цен").font(.subheadline).fontWeight(.medium)
                    Text("Снижать цены если позиция товара > 1")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .onChange(of: service.isAutoDumpingEnabled) { _ in
                service.toggleAutoDumping()
            }

            if service.isAutoDumpingEnabled {
                Text("Проверка каждые 5 минут. Цена снижается на 2% при позиции > 1")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: — Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task { try? await service.fetchAllProducts() }
            } label: {
                HStack {
                    if service.isLoading {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Text("Синхронизировать товары")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(service.apiToken != nil ? Color.orange : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(service.apiToken == nil || service.isLoading)

            Button {
                // TODO: здесь полное тестирование API
            } label: {
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
}

// MARK: — Вспомогательный стиль кнопки

fileprivate struct PrimaryButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(color.opacity(configuration.isPressed ? 0.7 : 1))
            .cornerRadius(12)
    }
}
