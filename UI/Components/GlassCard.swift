//
//  GlassCard.swift
//  Bagyt
//
//  Created by Жантемир Бериков on 21.11.2025.
//

import SwiftUI

struct GlassCard: View {
    let title: String
    let subtitle: String
    let icon: String
    var accentColor: Color = .blue   // 👈 Добавили accentColor

    var body: some View {
        HStack(alignment: .center, spacing: 12) {

            // Иконка с акцентным цветом
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.25))
                    .frame(width: 46, height: 46)

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
            }

            Spacer()
        }
        .padding()
        .background(
            Color.white.opacity(0.10)
                .background(.ultraThinMaterial)
        )
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}
