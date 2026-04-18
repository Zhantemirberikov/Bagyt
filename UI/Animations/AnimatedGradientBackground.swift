//
//  AnimatedGradientBackground.swift
//  Bagyt
//
//  Created by Жантемир Бериков on 18.04.2026.
//
// MARK: - Анимированный фон с эффектом сердцебиения

import SwiftUI
struct AnimatedGradientBackground: View {
    @State private var moveGradient = false
    @State private var pulse = false

    var body: some View {
        let accentColor: Color = {
            if let ui = UIColor(named: "AccentColor") {
                return Color(uiColor: ui)
            } else {
                return Color(red: 0.94, green: 0.96, blue: 1.0)
            }
        }()

        ZStack {
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

            RadialGradient(
                gradient: Gradient(colors: [
                    accentColor.opacity(pulse ? 0.35 : 0.15),
                    Color.clear
                ]),
                center: .center,
                startRadius: 50,
                endRadius: 400
            )
            .blendMode(.softLight)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
        }
        .onAppear {
            moveGradient.toggle()
            pulse.toggle()
        }
    }
}

