//
//  BagytApp.swift
//  Bagyt
//
//  Created by Жантемир Бериков on 01.11.2025.
//

import SwiftUI

@main
struct BagytApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var langManager = LanguageManager()

    var body: some Scene {
        WindowGroup {
            if appState.isLoggedIn {
                HomeView()
                    .environmentObject(appState)
                    .environmentObject(langManager)
            } else {
                OnboardingView()
                    .environmentObject(langManager)
                    .environmentObject(appState) // если хочешь доступ в onboarding
            }
        }
    }
}



