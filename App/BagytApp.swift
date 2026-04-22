//
//  BagytApp.swift
//  Bagyt
//
//  Created by Жантемир Бериков on 01.11.2025.
//

import SwiftUI

@main
struct BagytApp: App {
    // MARK: - Global State Objects
    @StateObject private var appState = AppState()
    @StateObject private var langManager = LanguageManager()
    
    init() {
        print("🚀 BagytApp initialized")
        // AppState сам управляет флагами isLoggedIn и isFirstLaunch
    }
    
    var body: some Scene {
        WindowGroup {
            // 👇 Используем только один главный контейнер
            SplashView()
                .environmentObject(appState)
                .environmentObject(langManager)
                .onAppear {
                    print("✅ BagytApp started")
                    print("isFirstLaunch = \(appState.isFirstLaunch)")
                    print("isLoggedIn = \(appState.isLoggedIn)")
                }
        }
    }
}
