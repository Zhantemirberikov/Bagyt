//
//  AnimatedGradientBackground.swift
//  Bagyt
//

import SwiftUI

struct AnimatedGradientBackground: View {
    @State private var moveGradient = false
    @State private var breath: CGFloat = 0.0

    var body: some View {
        let accentColor: Color = {
            if let ui = UIColor(named: "AccentColor") {
                return Color(uiColor: ui)
            } else {
                return Color(red: 0.94, green: 0.96, blue: 1.0)
            }
        }()

        ZStack {
            // Оригинальный градиент — двигается медленно как было
            LinearGradient(
                gradient: Gradient(colors: [
                    accentColor.opacity(0.9),
                    Color.white.opacity(0.95),
                    accentColor.opacity(0.85)
                ]),
                startPoint: moveGradient ? .topLeading : .bottomTrailing,
                endPoint: moveGradient ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: moveGradient)

            // Дыхание — радиальный пульс, но медленный (4 сек вдох / 6 сек выдох)
            // Заменили 0.8 сек на 4+6 сек — всё то же самое, просто не мигает
            RadialGradient(
                gradient: Gradient(colors: [
                    accentColor.opacity(0.15 + 0.20 * breath),
                    Color.clear
                ]),
                center: .center,
                startRadius: 50,
                endRadius: 400
            )
            .blendMode(.softLight)
            .ignoresSafeArea()
        }
        .onAppear {
            moveGradient.toggle()
            inhale()
        }
    }

    private func inhale() {
        withAnimation(.easeIn(duration: 4.0)) { breath = 1.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) { exhale() }
    }

    private func exhale() {
        withAnimation(.easeOut(duration: 6.0)) { breath = 0.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) { inhale() }
    }
}
