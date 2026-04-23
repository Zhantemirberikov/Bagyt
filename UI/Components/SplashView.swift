//
//  SplashView.swift
//  Bagyt
//

import SwiftUI

struct SplashView: View {
    @State private var isActive = false

    var body: some View {
        if isActive {
            OnboardingContainerView()
        } else {
            Image("screen")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        isActive = true
                    }
                }
        }
    }
}

#Preview {
    SplashView()
        .environmentObject(AppState())
        .environmentObject(LanguageManager())
}
