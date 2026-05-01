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
    @AppStorage("isDarkModeEnabled") private var isDarkModeEnabled = false

    init() {
        print("🚀 BagytApp initialized")
    }

    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(appState)
                .environmentObject(langManager)
                .environment(\.locale, Locale(identifier: langManager.currentLanguage.localeIdentifier))
                .preferredColorScheme(isDarkModeEnabled ? .dark : .light)
                .onAppear {
                    print("✅ BagytApp started")
                    print("isFirstLaunch = \(appState.isFirstLaunch)")
                    print("isLoggedIn = \(appState.isLoggedIn)")
                }
        }
    }
}
