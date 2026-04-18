//
//  LiquidBottomBarHolder.swift
//  Bagyt
//
//  Created by Жантемир Бериков on 23.11.2025.
//


// LiquidBottomBarHolder.swift (or keep it below HomeView in same file)
import SwiftUI

struct LiquidBottomBarHolder: View {
    @Binding var selectedTab: Int
    @ObservedObject var keyboard: KeyboardObserver
    @Binding var showAssistant: Bool

    init(selectedTab: Binding<Int>, keyboard: KeyboardObserver, showAssistant: Binding<Bool>) {
        self._selectedTab = selectedTab
        self.keyboard = keyboard
        self._showAssistant = showAssistant
    }

    var body: some View {
        // Call the external LiquidBottomBar (the implementation must live in LiquidBottomBar.swift)
        LiquidBottomBar(
            selectedTab: $selectedTab,
            safeAreaBottom: safeAreaBottom(),
            keyboardHeight: keyboard.keyboardHeight,
            showAssistant: $showAssistant
        )
    }

    private func safeAreaBottom() -> CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let window = scenes.first?.windows.first(where: \.isKeyWindow) { return window.safeAreaInsets.bottom }
        return 0
    }
}