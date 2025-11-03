//
//  AppState.swift
//  Bagyt
//
//  Created by Жантемир Бериков on 02.11.2025.
//

import SwiftUI
import Combine

final class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = false
}

