import SwiftUI
import Foundation
import UIKit

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

func vkFormatMoney(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = " "
    formatter.usesGroupingSeparator = true
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}

extension Date {
    var vkRelativeDay: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) { return "Сьогодні" }
        if calendar.isDateInYesterday(self) { return "Вчора" }
        let days = calendar.dateComponents([.day], from: self, to: Date()).day ?? 3
        return "\(max(days, 2)) дн. тому"
    }

    var vkShortDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: self)
    }

    var vkDateTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.dateFormat = "d MMMM, HH:mm"
        return formatter.string(from: self)
    }
}

extension View {
    func vkCard(padding: CGFloat = 16, cornerRadius: CGFloat = VK.radius) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VK.card)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(VK.hairline, lineWidth: 1)
            )
    }

    func vkShadow() -> some View {
        shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 6)
    }

    @ViewBuilder
    func vkHidden(_ hidden: Bool) -> some View {
        if hidden { self.hidden() } else { self }
    }
}

extension String {
    var vkTrimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var vkInitials: String {
        let letters = split(separator: " ").prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .opacity(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
