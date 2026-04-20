//
//  GlassPanel.swift
//  Bagyt
//
//  Created by Жантемир Бериков on 18.04.2026.
//

import SwiftUI


// MARK: - Эффект стеклянной панели 
struct GlassPanel<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .background(
                Color.white.opacity(0.15)
                    .blur(radius: 20)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
    }
}
