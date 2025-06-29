// AppTheme.swift

import SwiftUI

// Цвета приложения
extension Color {
    static let vektaPrimary = Color("VektaPrimary") // добавь этот цвет в Assets.xcassets
    static let vektaSecondary = Color("VektaSecondary")
    static let vektaBackground = Color("VektaBackground")
}

// Шрифты приложения
extension Font {
    static func vektaTitle(size: CGFloat = 24) -> Font {
        Font.custom("SFPro-Bold", size: size)
    }
    
    static func vektaBody(size: CGFloat = 16) -> Font {
        Font.custom("SFPro-Regular", size: size)
    }
}
