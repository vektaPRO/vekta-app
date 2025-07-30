//
//  CourierDeliveryViewModel.swift
//  vektaApp
//
//  Логика запроса SMS-кода и подтверждения доставки через Kaspi API.
//

import Foundation

@MainActor
final class CourierDeliveryViewModel: ObservableObject {
    // MARK: - Published свойства для отслеживания состояния
    @Published var isLoading: Bool = false
    @Published var smsCodeSent: Bool = false
    @Published var deliveryConfirmed: Bool = false
    @Published var errorMessage: String?

    // MARK: - Сервис для работы с Kaspi API
    private let apiService = KaspiAPIService()

    // MARK: - Запрос SMS-кода

    /// Запрашивает SMS-код для подтверждения доставки заказа.
    /// - Parameters:
    ///   - orderId: Ваш локальный ID заказа
    ///   - trackingNumber: Трек-номер, полученный от Kaspi
    ///   - phoneNumber: Номер телефона, на который придёт SMS
    func requestSMSCode(orderId: String,
                        trackingNumber: String,
                        to phoneNumber: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await apiService.requestSMSCode(
                orderId: orderId,
                trackingNumber: trackingNumber,
                to: phoneNumber
            )
            smsCodeSent = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Подтверждение доставки

    /// Подтверждает доставку по коду из SMS.
    /// - Parameters:
    ///   - orderId: Ваш локальный ID заказа
    ///   - trackingNumber: Трек-номер, полученный от Kaspi
    ///   - smsCode: Код, который пришёл в SMS
    func confirmDelivery(orderId: String,
                         trackingNumber: String,
                         smsCode: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let success = try await apiService.confirmDelivery(
                orderId: orderId,
                trackingNumber: trackingNumber,
                smsCode: smsCode
            )
            deliveryConfirmed = success
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
