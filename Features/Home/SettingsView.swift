//
//  SettingsView.swift
//  Bagyt
//
//  Full redesign — Bagyt design system
//  Профиль · Настройки · Уведомления · Язык · Premium · Logout
//

import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lang: LanguageManager

    @State private var notificationsOn   = true
    @State private var healthKitOn       = true
    @State private var biometricOn       = false
    @State private var showLanguagePicker = false
    @State private var showLogoutAlert   = false
    @State private var appear            = false

    private let accent  = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)

    var body: some View {
        ZStack {
            Color(red: 0.937, green: 0.969, blue: 1.0).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    profileHero
                    premiumBanner
                    accountSection
                    appSection
                    aboutSection
                    logoutButton
                    versionLabel
                    Spacer(minLength: 110)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .confirmationDialog("Выберите язык", isPresented: $showLanguagePicker, titleVisibility: .visible) {
            ForEach(AppLanguage.allCases, id: \.self) { code in
                Button("\(code.flag)  \(code.title)") {
                    withAnimation(.easeInOut) { lang.changeLanguage(to: code) }
                }
            }
            Button("Отмена", role: .cancel) {}
        }
        .alert("Выйти из аккаунта?", isPresented: $showLogoutAlert) {
            Button("Выйти", role: .destructive) { appState.logOut() }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Вы уверены, что хотите выйти?")
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appear = true }
        }
    }

    // MARK: - Profile Hero

    private var profileHero: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(
                    colors: [accent, accent2],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .shadow(color: accent.opacity(0.4), radius: 20, x: 0, y: 10)

            // Deco circles
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 140, height: 140)
                .offset(x: -40, y: -55)
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 90, height: 90)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: 25, y: 25)

            HStack(spacing: 16) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 70, height: 70)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: 2))
                    Text(initials())
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(appState.userName ?? "Пользователь")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)

                    if let token = appState.userToken {
                        Text(emailFromToken(token))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    HStack(spacing: 5) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                        Text("Premium")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.22))
                    .clipShape(Capsule())
                }

                Spacer()
            }
            .padding(24)
        }
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .animation(.easeOut(duration: 0.45).delay(0.05), value: appear)
    }

    // MARK: - Premium Banner

    private var premiumBanner: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.75, blue: 0.1),
                        Color(red: 1.0, green: 0.5, blue: 0.1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.1).opacity(0.35), radius: 12, x: 0, y: 6)

            HStack(spacing: 14) {
                Text("✦")
                    .font(.system(size: 26))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Bagyt Premium активен")
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(.white)
                    Text("Неограниченный доступ ко всем функциям")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .animation(.easeOut(duration: 0.45).delay(0.10), value: appear)
    }

    // MARK: - Account Section

    private var accountSection: some View {
        settingsSection(title: "Аккаунт") {
            settingsRow(icon: "person.fill", iconColor: accent, label: "Личные данные") {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red: 0.7, green: 0.8, blue: 0.85))
            }

            divider()

            settingsRow(icon: "lock.fill", iconColor: Color(red: 0.55, green: 0.35, blue: 1.0), label: "Безопасность") {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red: 0.7, green: 0.8, blue: 0.85))
            }

            divider()

            Button { showLanguagePicker = true } label: {
                settingsRow(icon: "globe", iconColor: Color(red: 0.1, green: 0.78, blue: 0.48), label: "Язык") {
                    HStack(spacing: 6) {
                        Text(lang.currentLanguage.flag)
                            .font(.system(size: 16))
                        Text(lang.currentLanguage.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(red: 0.5, green: 0.63, blue: 0.72))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(red: 0.7, green: 0.8, blue: 0.85))
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .animation(.easeOut(duration: 0.45).delay(0.15), value: appear)
    }

    // MARK: - App Section

    private var appSection: some View {
        settingsSection(title: "Приложение") {
            settingsRow(icon: "bell.fill", iconColor: Color(red: 1.0, green: 0.55, blue: 0.1), label: "Уведомления") {
                Toggle("", isOn: $notificationsOn)
                    .tint(accent)
                    .labelsHidden()
            }

            divider()

            settingsRow(icon: "heart.fill", iconColor: Color(red: 0.95, green: 0.25, blue: 0.25), label: "HealthKit") {
                Toggle("", isOn: $healthKitOn)
                    .tint(accent)
                    .labelsHidden()
            }

            divider()

            settingsRow(icon: "faceid", iconColor: Color(red: 0.055, green: 0.647, blue: 0.914), label: "Face ID / Touch ID") {
                Toggle("", isOn: $biometricOn)
                    .tint(accent)
                    .labelsHidden()
            }

            divider()

            settingsRow(icon: "shield.fill", iconColor: Color(red: 0.1, green: 0.78, blue: 0.48), label: "Конфиденциальность") {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red: 0.7, green: 0.8, blue: 0.85))
            }
        }
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .animation(.easeOut(duration: 0.45).delay(0.20), value: appear)
    }

    // MARK: - About Section

    private var aboutSection: some View {
        settingsSection(title: "О приложении") {
            settingsRow(icon: "star.fill", iconColor: Color(red: 1.0, green: 0.75, blue: 0.1), label: "Оценить приложение") {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red: 0.7, green: 0.8, blue: 0.85))
            }

            divider()

            settingsRow(icon: "envelope.fill", iconColor: accent2, label: "Написать в поддержку") {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red: 0.7, green: 0.8, blue: 0.85))
            }

            divider()

            settingsRow(icon: "doc.text.fill", iconColor: Color(red: 0.5, green: 0.63, blue: 0.72), label: "Политика конфиденциальности") {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red: 0.7, green: 0.8, blue: 0.85))
            }
        }
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .animation(.easeOut(duration: 0.45).delay(0.25), value: appear)
    }

    // MARK: - Logout

    private var logoutButton: some View {
        Button { showLogoutAlert = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                Text("Выйти из аккаунта")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(Color(red: 0.95, green: 0.25, blue: 0.25))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color(red: 0.95, green: 0.25, blue: 0.25).opacity(0.2), lineWidth: 1.5)
                    )
            )
        }
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .animation(.easeOut(duration: 0.45).delay(0.30), value: appear)
    }

    // MARK: - Version

    private var versionLabel: some View {
        VStack(spacing: 4) {
            Text("Bagyt · Версия 1.0.0")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(red: 0.6, green: 0.72, blue: 0.78))
            Text("Сделано с ❤️ в Казахстане")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(red: 0.7, green: 0.80, blue: 0.85))
        }
        .padding(.top, 4)
        .opacity(appear ? 1 : 0)
        .animation(.easeOut(duration: 0.45).delay(0.35), value: appear)
    }

    // MARK: - Reusable Builders

    @ViewBuilder
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(red: 0.5, green: 0.63, blue: 0.72))
                .tracking(0.9)
                .padding(.leading, 4)

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.88))
                    .shadow(color: accent.opacity(0.08), radius: 12, x: 0, y: 5)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(accent.opacity(0.10), lineWidth: 1)
                VStack(spacing: 0) { content() }
            }
        }
    }

    @ViewBuilder
    private func settingsRow<Trailing: View>(
        icon: String,
        iconColor: Color,
        label: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))

            Spacer()

            trailing()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private func divider() -> some View {
        Rectangle()
            .fill(accent.opacity(0.07))
            .frame(height: 1)
            .padding(.leading, 68)
    }

    // MARK: - Helpers

    private func initials() -> String {
        let name = appState.userName ?? "U"
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    private func emailFromToken(_ token: String) -> String {
        if token.contains("@") { return token }
        if token.contains("google") { return "Google аккаунт" }
        if token.contains("apple")  { return "Apple аккаунт" }
        if token.contains("offline") {
            return token.replacingOccurrences(of: "offline-", with: "")
        }
        return "ID: \(String(token.prefix(8)))..."
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(AppState())
        .environmentObject(LanguageManager())
}
