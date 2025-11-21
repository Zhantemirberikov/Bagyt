//
//  AppState.swift
//  Bagyt
//
//  Created by Жантемир Бериков on 03.11.2025.
//

import SwiftUI
import Combine

/// Глобальное состояние приложения Bagyt
final class AppState: ObservableObject {
    // MARK: - Published properties
    /// Пользователь вошёл в систему
    @Published var isLoggedIn: Bool {
        didSet {
            UserDefaults.standard.set(isLoggedIn, forKey: "isLoggedIn")
        }
    }
    
    /// Нужно ли показывать онбординг при старте
    @Published var isFirstLaunch: Bool {
        didSet {
            UserDefaults.standard.set(isFirstLaunch, forKey: "isFirstLaunch")
        }
    }

    /// Токен пользователя
    @Published var userToken: String? {
        didSet {
            UserDefaults.standard.set(userToken, forKey: "userToken")
        }
    }

    /// ✅ Имя пользователя
    @Published var userName: String? {
        didSet {
            UserDefaults.standard.set(userName, forKey: "userName")
        }
    }

    // MARK: - Init
    init() {
        self.isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        self.isFirstLaunch = UserDefaults.standard.object(forKey: "isFirstLaunch") as? Bool ?? true
        self.userToken = UserDefaults.standard.string(forKey: "userToken")
        self.userName = UserDefaults.standard.string(forKey: "userName") // ✅ подгружаем имя из UserDefaults
    }

    // MARK: - Методы управления состоянием
    func logIn(token: String? = nil, name: String? = nil) {
        if let token = token {
            self.userToken = token
        }
        if let name = name {
            self.userName = name
        }
        withAnimation {
            self.isLoggedIn = true
        }
    }

    func logOut() {
        withAnimation {
            self.isLoggedIn = false
        }
        self.userToken = nil
        self.userName = nil
    }

    func finishOnboarding() {
        withAnimation {
            self.isFirstLaunch = false
        }
    }
}
