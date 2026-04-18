//
//  SettingsView.swift
//  Bagyt
//
//  Created by Жантемир Бериков on 21.11.2025.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            Text("Settings (placeholder)").font(.title2)
            Button("Выйти") {
                appState.logOut()
            }
            .foregroundColor(.red)
        }
        .padding()
    }
}
