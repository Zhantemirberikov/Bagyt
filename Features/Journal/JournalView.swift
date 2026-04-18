//
//  JournalView.swift
//  Bagyt
//
//  Created by Жантемир Бериков on 21.11.2025.
//

import SwiftUI
struct JournalView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lang: LanguageManager
    var body: some View {
        VStack(alignment: .leading) {
            Text("Journal (placeholder)").font(.title2).foregroundColor(.white)
            Text("Здесь будут записи пациента и история жалоб").foregroundColor(.white.opacity(0.8))
            Spacer()
        }
        .padding()
        .background(AnimatedGradientBackground().ignoresSafeArea())
    }
}
