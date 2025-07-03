//
//  OrderComponents.swift
//  vektaApp
//
//  Created by Almas Kadeshov on 02.07.2025.
//

import SwiftUI

// MARK: - Строка информации о заказе
struct OrderInfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Строка товара в заказе
struct OrderItemRow: View {
    let item: OrderItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Изображение товара
            AsyncImage(url: URL(string: item.imageURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(UIColor.systemGray5))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    )
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Информация о товаре
            VStack(alignment: .leading, spacing: 4) {
                Text(item.productName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                HStack {
                    Text("\(item.quantity) шт")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("×")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(item.formattedPrice)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Общая стоимость
            Text(item.formattedTotalPrice)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - QR-код экран
struct QRCodeView: View {
    let order: Order
    let onDismiss: () -> Void
    
    @StateObject private var ordersViewModel = OrdersViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Заголовок
                    VStack(spacing: 8) {
                        Text("QR-код заказа")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(order.orderNumber)
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 20)
                    
                    // QR-код
                    if let qrImage = ordersViewModel.createQRCodeImage(from: order.qrCodeData) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 250, height: 250)
                            .padding(20)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.systemGray5))
                            .frame(width: 250, height: 250)
                            .overlay(
                                VStack {
                                    Image(systemName: "qrcode")
                                        .font(.system(size: 60))
                                        .foregroundColor(.secondary)
                                    Text("Ошибка генерации QR-кода")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            )
                    }
                    
                    // Информация о заказе
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Информация о заказе")
                            .font(.headline)
                        
                        VStack(spacing: 12) {
                            OrderInfoRow(
                                icon: "building.2.fill",
                                title: "Склад назначения:",
                                value: order.warehouseName,
                                color: .green
                            )
                            
                            OrderInfoRow(
                                icon: "cube.box.fill",
                                title: "Количество товаров:",
                                value: "\(order.totalItems) шт",
                                color: .orange
                            )
                            
                            OrderInfoRow(
                                icon: "tenge.circle.fill",
                                title: "Общая стоимость:",
                                value: order.formattedTotalValue,
                                color: .purple
                            )
                            
                            OrderInfoRow(
                                icon: "calendar",
                                title: "Дата создания:",
                                value: DateFormatter.shortDate.string(from: order.createdAt),
                                color: .blue
                            )
                            
                            if order.priority != .normal {
                                OrderInfoRow(
                                    icon: order.priority.iconName,
                                    title: "Приоритет:",
                                    value: order.priority.rawValue,
                                    color: Color(order.priority.color)
                                )
                            }
                        }
                    }
                    .padding(20)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    
                    // Инструкция
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Инструкция")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            InstructionStep(
                                number: "1",
                                text: "Покажите этот QR-код курьеру при передаче товаров"
                            )
                            
                            InstructionStep(
                                number: "2",
                                text: "Курьер отсканирует код для подтверждения получения"
                            )
                            
                            InstructionStep(
                                number: "3",
                                text: "Статус заказа автоматически обновится в системе"
                            )
                        }
                    }
                    .padding(20)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(12)
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("QR-код")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Шаг инструкции (переиспользуем из KaspiAPITokenView)
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

// MARK: - Расширения DateFormatter
extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}
