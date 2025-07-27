//
//  FirestoreSetupHelper.swift
//  vektaApp
//
//  Автоматическое создание структуры Firestore при первом запуске
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class FirestoreSetupHelper: ObservableObject {
    
    @Published var isSetupComplete = false
    @Published var setupProgress = 0.0
    @Published var setupStatus = "Инициализация..."
    
    private let db = Firestore.firestore()
    
    // MARK: - Автоматическая настройка при регистрации
    
    /// Создать пользователя с ролью (автоматически при регистрации)
    func createUserWithRole(uid: String, email: String, role: String) async throws {
        setupStatus = "Создание пользователя..."
        
        // 1. Создаем пользователя в коллекции users
        try await db.collection("users").document(uid).setData([
            "email": email,
            "role": role,
            "createdAt": FieldValue.serverTimestamp(),
            "isActive": true
        ])
        
        // 2. Если продавец - создаем запись в sellers
        if role == "Seller" {
            try await createSellerProfile(uid: uid, email: email)
        }
        
        setupStatus = "Пользователь создан успешно!"
        print("✅ Пользователь \(email) создан с ролью \(role)")
    }
    
    /// Создать профиль продавца
    private func createSellerProfile(uid: String, email: String) async throws {
        setupStatus = "Создание профиля продавца..."
        
        let sellerData: [String: Any] = [
            "email": email,
            "businessName": nil as String?,
            "phone": nil as String?,
            
            // Kaspi API настройки (пустые)
            "kaspiApiToken": nil as String?,
            "kaspiMerchantId": nil as String?,
            "kaspiMerchantName": nil as String?,
            "kaspiApiEnabled": false,
            
            // API статистика
            "lastApiSync": nil as Timestamp?,
            "totalApiRequests": 0,
            "apiRequestsToday": 0,
            "lastApiError": nil as String?,
            
            // Подписка по умолчанию
            "subscriptionPlan": "Free",
            "apiRateLimit": 10,
            "monthlyApiCalls": 0,
            "monthlyApiLimit": 1000,
            
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "isActive": true
        ]
        
        try await db.collection("sellers").document(uid).setData(sellerData)
        print("✅ Профиль продавца создан")
    }
    
    // MARK: - Создание тестовых данных (для разработки)
    
    /// Создать тестовые данные для разработки
    func createTestData() async {
        setupStatus = "Создание тестовых данных..."
        setupProgress = 0.1
        
        do {
            // 1. Тестовые товары
            await createTestProducts()
            setupProgress = 0.3
            
            // 2. Тестовые заказы
            await createTestOrders()
            setupProgress = 0.6
            
            // 3. Тестовые заказы Kaspi
            await createTestKaspiOrders()
            setupProgress = 0.8
            
            // 4. Тестовые доставки
            await createTestDeliveries()
            setupProgress = 1.0
            
            setupStatus = "Тестовые данные созданы!"
            isSetupComplete = true
            
        } catch {
            setupStatus = "Ошибка: \(error.localizedDescription)"
            print("❌ Ошибка создания тестовых данных: \(error)")
        }
    }
    
    // MARK: - Создание тестовых товаров
    
    private func createTestProducts() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let testProducts = [
            [
                "kaspiProductId": "kaspi_123456",
                "name": "iPhone 15 Pro Max 256GB",
                "description": "Новейший iPhone с камерой Pro",
                "price": 599000.0,
                "category": "Смартфоны",
                "imageURL": "https://example.com/iphone15.jpg",
                "status": "inStock",
                "warehouseStock": [
                    "warehouse_almaty": 5,
                    "warehouse_astana": 3
                ],
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
                "isActive": true
            ],
            [
                "kaspiProductId": "kaspi_789012",
                "name": "Samsung Galaxy S24 Ultra",
                "description": "Флагманский Android смартфон",
                "price": 459000.0,
                "category": "Смартфоны",
                "imageURL": "https://example.com/samsung_s24.jpg",
                "status": "inStock",
                "warehouseStock": [
                    "warehouse_almaty": 2,
                    "warehouse_shymkent": 4
                ],
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
                "isActive": true
            ]
        ]
        
        for (index, product) in testProducts.enumerated() {
            do {
                try await db.collection("sellers").document(userId)
                    .collection("products").document("product_\(index + 1)")
                    .setData(product)
                print("✅ Тестовый товар \(index + 1) создан")
            } catch {
                print("❌ Ошибка создания товара: \(error)")
            }
        }
    }
    
    // MARK: - Создание тестовых заказов на склад
    
    private func createTestOrders() async {
        guard let userId = Auth.auth().currentUser?.uid,
              let userEmail = Auth.auth().currentUser?.email else { return }
        
        let testOrders = [
            [
                "orderNumber": "ORD-2025-001",
                "sellerId": userId,
                "sellerEmail": userEmail,
                "warehouseId": "warehouse_almaty",
                "warehouseName": "Склад Алматы",
                "items": [
                    [
                        "id": "item_1",
                        "productSKU": "iphone_15_pro_max",
                        "productName": "iPhone 15 Pro Max",
                        "quantity": 2,
                        "price": 599000.0,
                        "imageURL": "https://example.com/iphone.jpg",
                        "category": "Смартфоны"
                    ]
                ],
                "notes": "Тестовый заказ для разработки",
                "status": "pending",
                "priority": "normal",
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
                "qrCodeData": "ORDER:ORD-2025-001:\(userId):warehouse_almaty"
            ]
        ]
        
        for (index, order) in testOrders.enumerated() {
            do {
                try await db.collection("sellers").document(userId)
                    .collection("orders").document("order_test_\(index + 1)")
                    .setData(order)
                print("✅ Тестовый заказ \(index + 1) создан")
            } catch {
                print("❌ Ошибка создания заказа: \(error)")
            }
        }
    }
    
    // MARK: - Создание тестовых заказов Kaspi
    
    private func createTestKaspiOrders() async {
        let testKaspiOrders = [
            [
                "kaspiOrderId": "kaspi_order_001",
                "orderNumber": "KSP-789123",
                "customerName": "Иван Тестовый",
                "customerPhone": "+77771234567",
                "customerEmail": "test@example.com",
                "deliveryAddress": "г. Алматы, ул. Абая 150, кв. 25",
                "totalAmount": 599000.0,
                "status": "new",
                "items": [
                    [
                        "productId": "prod_123",
                        "productName": "iPhone 15 Pro Max",
                        "quantity": 1,
                        "price": 599000.0
                    ]
                ],
                "createdAt": FieldValue.serverTimestamp(),
                "syncedAt": FieldValue.serverTimestamp(),
                "sellerId": Auth.auth().currentUser?.uid ?? ""
            ]
        ]
        
        for (index, kaspiOrder) in testKaspiOrders.enumerated() {
            do {
                try await db.collection("kaspiOrders")
                    .document("kaspi_test_\(index + 1)")
                    .setData(kaspiOrder)
                print("✅ Тестовый заказ Kaspi \(index + 1) создан")
            } catch {
                print("❌ Ошибка создания заказа Kaspi: \(error)")
            }
        }
    }
    
    // MARK: - Создание тестовых доставок
    
    private func createTestDeliveries() async {
        let testDeliveries = [
            [
                "orderId": "kaspi_order_001",
                "trackingNumber": "TRK-456789",
                "courierId": "courier_test_123",
                "courierName": "Сергей Тестовый",
                "customerPhone": "+77771234567",
                "deliveryAddress": "г. Алматы, ул. Абая 150, кв. 25",
                "smsCodeRequested": false,
                "status": "pending",
                "attemptCount": 0,
                "maxAttempts": 3,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ]
        ]
        
        for (index, delivery) in testDeliveries.enumerated() {
            do {
                try await db.collection("deliveries")
                    .document("delivery_test_\(index + 1)")
                    .setData(delivery)
                print("✅ Тестовая доставка \(index + 1) создана")
            } catch {
                print("❌ Ошибка создания доставки: \(error)")
            }
        }
    }
    
    // MARK: - Проверка существования данных
    
    /// Проверить нужно ли создавать тестовые данные
    func shouldCreateTestData() async -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else { return false }
        
        do {
            let snapshot = try await db.collection("sellers").document(userId)
                .collection("products").limit(to: 1).getDocuments()
            
            return snapshot.documents.isEmpty
        } catch {
            return true
        }
    }
    
    // MARK: - Сброс всех данных (для разработки)
    
    /// Удалить все тестовые данные
    func clearTestData() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        setupStatus = "Очистка данных..."
        
        do {
            // Удаляем товары
            let productsSnapshot = try await db.collection("sellers").document(userId)
                .collection("products").getDocuments()
            
            for doc in productsSnapshot.documents {
                try await doc.reference.delete()
            }
            
            // Удаляем заказы
            let ordersSnapshot = try await db.collection("sellers").document(userId)
                .collection("orders").getDocuments()
            
            for doc in ordersSnapshot.documents {
                try await doc.reference.delete()
            }
            
            setupStatus = "Данные очищены!"
            print("✅ Тестовые данные удалены")
            
        } catch {
            setupStatus = "Ошибка очистки: \(error.localizedDescription)"
            print("❌ Ошибка очистки данных: \(error)")
        }
    }
}
