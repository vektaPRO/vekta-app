//
//  KaspiPriceOptimizer.swift
//  vektaApp
//
//  Логика автодемпинга цен.
//

import Foundation

@MainActor
final class KaspiPriceOptimizer {
    private let api: KaspiAPIService

    init(apiService: KaspiAPIService) {
        self.api = apiService
    }

    /// Проходит по всем активным товарам и, если они не в топе,
    /// снижает цену на 2% (или другой процент).
    func runAutoDump() async {
        do {
            print("🚀 Старт автодемпинга...")
            let kaspiProducts = try await api.fetchAllProducts()
            for kp in kaspiProducts where kp.isActive {
                let pos = try await api.fetchProductPosition(productId: kp.id)
                guard pos > 1 else {
                    print("✅ \(kp.name) уже в топе (позиция \(pos)).")
                    continue
                }
                let newPrice = Int(floor(kp.price * 0.98))
                try await api.updatePrice(productId: kp.id, newPrice: newPrice)
                print("📉 \(kp.name) снижена до \(newPrice).")
            }
            print("🎉 Автодемпинг завершён.")
        } catch {
            print("❌ Ошибка автодемпинга: \(error.localizedDescription)")
        }
    }
}
