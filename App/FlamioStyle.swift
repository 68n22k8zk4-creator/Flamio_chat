import SwiftUI
import AudioToolbox
import UIKit

enum FlamioPalette {
    static let background = Color(red: 0.025, green: 0.018, blue: 0.055)
    static let panel = Color(red: 0.075, green: 0.045, blue: 0.12)
    static let purple = Color(red: 0.60, green: 0.20, blue: 1.0)
    static let violet = Color(red: 0.34, green: 0.10, blue: 0.72)
    static let orange = Color(red: 1.0, green: 0.43, blue: 0.10)
    static let gold = Color(red: 1.0, green: 0.72, blue: 0.22)
    static let muted = Color(red: 0.68, green: 0.64, blue: 0.76)
    static let gradient = LinearGradient(
        colors: [purple.opacity(0.95), violet.opacity(0.78), orange.opacity(0.82)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

struct FlamioBackground: View {
    var body: some View {
        ZStack {
            FlamioPalette.background.ignoresSafeArea()
            RadialGradient(colors: [FlamioPalette.purple.opacity(0.18), .clear],
                           center: .topLeading, startRadius: 8, endRadius: 390)
                .ignoresSafeArea()
            RadialGradient(colors: [FlamioPalette.orange.opacity(0.10), .clear],
                           center: .bottomTrailing, startRadius: 5, endRadius: 330)
                .ignoresSafeArea()
            VStack {
                Spacer()
                HStack {
                    Circle().fill(FlamioPalette.purple.opacity(0.12)).frame(width: 180, height: 180).blur(radius: 35)
                    Spacer()
                    Circle().fill(FlamioPalette.orange.opacity(0.08)).frame(width: 130, height: 130).blur(radius: 32)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}

struct FlamioCard: ViewModifier {
    var radius: CGFloat = 24
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [FlamioPalette.panel.opacity(0.98),
                                                  Color(red: 0.045, green: 0.025, blue: 0.075)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(FlamioPalette.purple.opacity(0.42), lineWidth: 1))
                    .shadow(color: FlamioPalette.purple.opacity(0.13), radius: 16, y: 7)
            )
    }
}

extension View {
    func flamioCard(radius: CGFloat = 24) -> some View { modifier(FlamioCard(radius: radius)) }
}

enum FlamioFeedback {
    static func tap() {
        AudioServicesPlaySystemSound(1104)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func success() {
        AudioServicesPlaySystemSound(1025)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func feed() {
        AudioServicesPlaySystemSound(1057)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
