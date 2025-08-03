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
    /// Проходит по всем активным товарам и, если они не в топе,
    /// снижает цену на 2% (или другой процент).
    func runAutoDump() async {
        do {
            print("🚀 Старт автодемпинга...")
            
            // 1. Получаем товары из Kaspi API (сложная структура)
            let kaspiProducts = try await api.fetchAllProducts()
            
            // 2. Конвертируем в локальные модели (простая структура)
            let localProducts = kaspiProducts.map { $0.toLocalProduct() }
            
            // 3. Работаем только с активными товарами
            for product in localProducts where product.isActive {
                
                // Получаем позицию товара в поиске
                let pos = try await api.fetchProductPosition(productId: product.id)
                
                // Если товар уже в топе (позиция 1) - пропускаем
                guard pos > 1 else {
                    print("✅ \(product.name) уже в топе (позиция \(pos)).")
                    continue
                }
                
                // Снижаем цену на 2%
                let newPrice = Int(floor(product.price * 0.98))
                
                // Обновляем цену через API
                try await api.updatePrice(productId: product.id, newPrice: newPrice)
                
                print("📉 \(product.name) снижена до \(newPrice).")
            }
            
            print("🎉 Автодемпинг завершён.")
            
        } catch {
            print("❌ Ошибка автодемпинга: \(error.localizedDescription)")
        }
    }
}
