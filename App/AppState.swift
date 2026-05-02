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
        let savedToken = UserDefaults.standard.string(forKey: "userToken")
        let savedName = UserDefaults.standard.string(forKey: "userName")

        self.userToken = savedToken
        self.userName = savedName

        // 🔥 ГЛАВНАЯ ЛОГИКА
        self.isLoggedIn = savedToken != nil

        self.isFirstLaunch = UserDefaults.standard.object(forKey: "isFirstLaunch") as? Bool ?? true
    }

    // MARK: - Методы управления состоянием
    func logIn(token: String? = nil, name: String? = nil) {
        if let token = token {
            self.userToken = token
            UserDefaults.standard.set(token, forKey: "userToken")
        }

        if let name = name {
            self.userName = name
            UserDefaults.standard.set(name, forKey: "userName")
            if let token = self.userToken, !token.isEmpty {
                UserDefaults.standard.set(name, forKey: "userName_\(token)")
            }
        }

        UserProfileStore.shared.load()

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

        UserDefaults.standard.removeObject(forKey: "userToken")
        UserDefaults.standard.removeObject(forKey: "userName")
    }
    }
