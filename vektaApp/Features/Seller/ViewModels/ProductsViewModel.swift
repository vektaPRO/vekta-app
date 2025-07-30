//
//  ProductsViewModel.swift
//  vektaApp
//
//  Синхронизация товаров из Kaspi API в Firestore и UI.
//

import Foundation
import FirebaseFirestore


@MainActor
final class ProductsViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = KaspiAPIService()
    private let firestore  = Firestore.firestore()

    /// Загружает все товары из Kaspi и сохраняет в Firestore
    func syncProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // 1) Получаем товары с Kaspi
            let kpList = try await apiService.fetchAllProducts()

            // 2) Маппим в локальные Product
            let localProducts = kpList.map { kp in
                Product(
                    id: UUID().uuidString,
                    kaspiProductId: kp.id,
                    name: kp.name,
                    description: kp.shortDescription ?? "",
                    price: kp.price,
                    category: kp.category,
                    imageURL: kp.images.first ?? "",
                    status: kp.isActive ? .inStock : .outOfStock,
                    warehouseStock: ["default": kp.stockCount],
                    createdAt: Date(),
                    updatedAt: Date(),
                    isActive: kp.isActive
                )
            }
            self.products = localProducts

            // 3) Сохраняем в Firestore батчем
            let batch = firestore.batch()
            for product in localProducts {
                let ref = firestore.collection("products").document(product.id)
                try batch.setData(from: product, forDocument: ref)
            }
            try await batch.commit()

        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
