//
//  CommonUIComponents.swift
//  vektaApp
//
//  Общие UI компоненты, используемые во всем приложении
//

import SwiftUI

// MARK: - Info Row
/// Универсальная строка с информацией
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let iconColor: Color?
    
    init(icon: String, title: String, value: String, iconColor: Color? = nil) {
        self.icon = icon
        self.title = title
        self.value = value
        self.iconColor = iconColor
    }
    
    var body: some View {
        HStack {
            if !icon.isEmpty {
                Image(systemName: icon)
                    .foregroundColor(iconColor ?? .secondary)
                    .frame(width: 20)
            }
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Status Badge
/// Универсальный бейдж для отображения статусов
struct StatusBadge: View {
    let text: String
    let icon: String?
    let color: Color
    
    init(text: String, icon: String? = nil, color: Color) {
        self.text = text
        self.icon = icon
        self.color = color
    }
    
    init(status: DeliveryStatus) {
        self.text = status.rawValue
        self.icon = status.iconName
        self.color = Self.colorForDeliveryStatus(status)
    }
    
    init(status: OrderStatus) {
        self.text = status.rawValue
        self.icon = status.iconName
        self.color = Color(status.color)
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption)
            }
            
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
    
    private static func colorForDeliveryStatus(_ status: DeliveryStatus) -> Color {
        switch status {
        case .pending: return .gray
        case .inTransit: return .blue
        case .arrived: return .orange
        case .awaitingCode: return .yellow
        case .confirmed: return .green
        case .failed: return .red
        case .cancelled: return .red
        }
    }
}

// MARK: - Stat Card
/// Карточка для отображения статистики
struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let style: StatCardStyle
    
    enum StatCardStyle {
        case compact
        case expanded
    }
    
    init(icon: String, title: String, value: String, color: Color, style: StatCardStyle = .compact) {
        self.icon = icon
        self.title = title
        self.value = value
        self.color = color
        self.style = style
    }
    
    var body: some View {
        switch style {
        case .compact:
            compactView
        case .expanded:
            expandedView
        }
    }
    
    private var compactView: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var expandedView: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
}

// MARK: - Instruction Step
/// Шаг инструкции с номером
struct InstructionStep: View {
    let number: String
    let text: String
    let numberBackgroundColor: Color
    
    init(number: String, text: String, numberBackgroundColor: Color = .blue) {
        self.number = number
        self.text = text
        self.numberBackgroundColor = numberBackgroundColor
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(numberBackgroundColor)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - Loading View
/// Универсальный вид для отображения загрузки
struct LoadingView: View {
    let message: String
    
    init(_ message: String = "Загрузка...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Date Formatter Extensions
/// Расширения для форматирования дат
extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
    
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - Filter Chip
/// Чип для фильтрации
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : Color(UIColor.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

// MARK: - Empty State View
/// Универсальный вид для пустого состояния
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
