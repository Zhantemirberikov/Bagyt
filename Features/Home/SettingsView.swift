import SwiftUI
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lang: LanguageManager
    @StateObject private var profile = UserProfileStore.shared

    @AppStorage("isDarkModeEnabled") private var isDarkModeEnabled = false
    @AppStorage("notificationsEnabled") private var notificationsOn = true
    @AppStorage("healthKitEnabled") private var healthKitOn = true
    @AppStorage("biometricEnabled") private var biometricOn = false

    @State private var showLanguagePicker = false
    @State private var showLogoutAlert = false
    @State private var showAvatarOptions = false
    @State private var showPhotoPicker = false
    @State private var showCropView = false
    @State private var showAccountEditor = false
    @State private var showGoalsEditor = false
    @State private var showEnlargedAvatar = false
    @State private var appear = false

    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var pendingImage: UIImage?

    @State private var cropOffset: CGSize = .zero
    @State private var cropScale: CGFloat = 1.0
    @State private var dragStartOffset: CGSize = .zero
    @State private var zoomStartScale: CGFloat = 1.0

    private let accent = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)

    private var baseBg: Color {
        isDarkModeEnabled ? Color(red: 0.04, green: 0.06, blue: 0.10) : Color(red: 0.94, green: 0.97, blue: 1.0)
    }

    private var primaryText: Color {
        isDarkModeEnabled ? .white : Color(red: 0.06, green: 0.09, blue: 0.16)
    }

    private var secondaryText: Color {
        isDarkModeEnabled ? Color.white.opacity(0.62) : Color(red: 0.40, green: 0.55, blue: 0.65)
    }

    private var mutedText: Color {
        isDarkModeEnabled ? Color.white.opacity(0.42) : Color(red: 0.56, green: 0.67, blue: 0.74)
    }

    private var cardBg: Color {
        isDarkModeEnabled ? Color(red: 0.10, green: 0.12, blue: 0.18).opacity(0.78) : Color.white.opacity(0.82)
    }

    private var softBg: Color {
        isDarkModeEnabled ? Color.white.opacity(0.07) : Color.white.opacity(0.52)
    }

    private var cardStroke: Color {
        isDarkModeEnabled ? Color.white.opacity(0.11) : Color.white.opacity(0.72)
    }

    private let cropViewport: CGFloat = 300

    private var displayName: String {
        let trimmed = (appState.userName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Пользователь" : trimmed
    }

    private var goalLabel: String {
        profile.goalLabel
    }

    private var accountSubtitle: String {
        var parts: [String] = []
        if profile.age > 0 { parts.append(profile.age.formattedAge) }
        if profile.height > 0 { parts.append("\(Int(profile.height.rounded())) см") }
        if profile.weight > 0 { parts.append("\(Int(profile.weight.rounded())) кг") }
        return parts.isEmpty ? "Заполните медицинский профиль" : parts.joined(separator: " · ")
    }

    var body: some View {
        ZStack {
            backgroundLayer

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header
                    profileHero
                    healthSnapshot
                    sectionTitle("Управление")
                    managementCard
                    sectionTitle("Настройки")
                    preferencesCard
                    sectionTitle("Поддержка")
                    supportRow
                    versionBlock
                    logoutButton
                    Spacer(minLength: 110)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 24)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 14)
            }

            if showCropView, let image = pendingImage {
                avatarCropView(image)
                    .transition(.opacity)
                    .zIndex(50)
            }

            if showEnlargedAvatar, let image = avatarImage {
                enlargedAvatarOverlay(image)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                    .zIndex(100)
            }
        }
        .preferredColorScheme(isDarkModeEnabled ? .dark : .light)
        .confirmationDialog("Фото профиля", isPresented: $showAvatarOptions, titleVisibility: .visible) {
            Button("Выбрать из галереи") {
                showPhotoPicker = true
            }

            if avatarImage != nil {
                Button("Удалить фото", role: .destructive) {
                    avatarImage = nil
                    UserDefaults.standard.removeObject(forKey: avatarKey())
                }
            }

            Button("Отмена", role: .cancel) {}
        }
        .confirmationDialog("Выберите язык", isPresented: $showLanguagePicker, titleVisibility: .visible) {
            ForEach(AppLanguage.allCases, id: \.self) { code in
                Button("\(code.flag)  \(code.title)") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        lang.changeLanguage(to: code)
                    }
                }
            }
            Button("Отмена", role: .cancel) {}
        }
        .alert("Выйти из аккаунта?", isPresented: $showLogoutAlert) {
            Button("Выйти", role: .destructive) {
                appState.logOut()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Вы уверены, что хотите выйти?")
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $avatarItem, matching: .images)
        .sheet(isPresented: $showAccountEditor) {
            AccountEditorView(
                initialName: appState.userName ?? "",
                initialAge: profile.age,
                initialWeight: profile.weight,
                initialHeight: profile.height,
                initialGender: profile.gender.isEmpty ? "other" : profile.gender
            ) { result in
                saveAccount(result)
            }
        }
        .sheet(isPresented: $showGoalsEditor) {
            GoalsEditorView(
                initialGoal: profile.goal.isEmpty ? "general" : profile.goal,
                initialStepsGoal: profile.stepsGoal,
                initialWaterGoal: profile.waterGoal,
                initialSleepGoal: profile.sleepGoal,
                initialCaloriesGoal: profile.caloriesGoal
            ) { result in
                saveGoals(result)
            }
        }
        .onAppear {
            loadAvatar()
            profile.load()
            restoreUserName()

            withAnimation(.easeOut(duration: 0.35)) {
                appear = true
            }
        }
        .onChange(of: appState.userToken) { _ in
            loadAvatar()
            restoreUserName()
        }
        .onChange(of: avatarItem) { item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        pendingImage = normalizedImage(image)
                        resetCropState()
                        showCropView = true
                    }
                }
            }
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            baseBg.ignoresSafeArea()

            LinearGradient(
                colors: isDarkModeEnabled
                    ? [
                        Color(red: 0.04, green: 0.06, blue: 0.10),
                        Color(red: 0.07, green: 0.10, blue: 0.16),
                        Color(red: 0.04, green: 0.06, blue: 0.10)
                    ]
                    : [
                        Color(red: 0.86, green: 0.95, blue: 0.99),
                        Color(red: 0.94, green: 0.98, blue: 1.0),
                        Color.white
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack {
                LinearGradient(
                    colors: [
                        accent.opacity(isDarkModeEnabled ? 0.18 : 0.20),
                        accent2.opacity(isDarkModeEnabled ? 0.10 : 0.12),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 260)
                .ignoresSafeArea(edges: .top)

                Spacer()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Профиль")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundColor(primaryText)

                Text("Настройки здоровья и аккаунта")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(secondaryText)
            }

            Spacer()

            Image(systemName: isDarkModeEnabled ? "moon.fill" : "sun.max.fill")
                .font(.system(size: 16, weight: .black))
                .foregroundColor(isDarkModeEnabled ? .white : accent)
                .padding(12)
                .background(softBg, in: Circle())
                .overlay(Circle().strokeBorder(cardStroke, lineWidth: 1))
        }
    }

    // MARK: - Profile Hero

    private var profileHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                avatarView

                VStack(alignment: .leading, spacing: 7) {
                    Text(displayName)
                        .font(.system(size: 25, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .multilineTextAlignment(.leading)

                    Text(goalLabel)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.82))
                }

                Spacer()

                Button {
                    showAccountEditor = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.16), in: Circle())
                }
                .buttonStyle(.plain)
            }

            Rectangle()
                .fill(Color.white.opacity(0.17))
                .frame(height: 1)

            HStack(spacing: 12) {
                heroMetric(title: "Шаги", value: profile.stepsGoal.formattedWithSpaces, subtitle: "в день")
                heroDivider
                heroMetric(title: "Вода", value: String(format: "%.1f", profile.waterGoal), subtitle: "л")
                heroDivider
                heroMetric(title: "Сон", value: String(format: "%.1f", profile.sleepGoal), subtitle: "ч")
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent,
                            Color(red: 0.08, green: 0.58, blue: 0.86),
                            accent2
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: accent.opacity(isDarkModeEnabled ? 0.16 : 0.26), radius: 20, x: 0, y: 12)
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.22))
                .frame(width: 90, height: 90)

            Circle()
                .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                .frame(width: 90, height: 90)

            if let image = avatarImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 78, height: 78)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.32), lineWidth: 1))
            } else {
                Circle()
                    .fill(Color.white.opacity(0.96))
                    .frame(width: 78, height: 78)

                Text(initials(from: displayName))
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(accent)
            }

            Image(systemName: "camera.fill")
                .font(.system(size: 11, weight: .black))
                .foregroundColor(accent)
                .frame(width: 28, height: 28)
                .background(Color.white, in: Circle())
                .offset(x: 31, y: 31)
        }
        .contentShape(Circle())
        .onTapGesture {
            showAvatarOptions = true
        }
        .onLongPressGesture(minimumDuration: 0.15) {
            if avatarImage != nil {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    showEnlargedAvatar = true
                }
            } else {
                showAvatarOptions = true
            }
        }
    }

    private func heroMetric(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.62))

            Text(value)
                .font(.system(size: 19, weight: .black, design: .rounded))
                .foregroundColor(.white)

            Text(subtitle)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.64))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.18))
            .frame(width: 1, height: 42)
    }

    // MARK: - Health Snapshot

    private var healthSnapshot: some View {
        HStack(spacing: 10) {
            snapshotCard(
                icon: "person.fill.checkmark",
                title: "Профиль",
                value: profile.age > 0 ? "\(profile.age)" : "-",
                unit: profile.age > 0 ? profile.age.ageWord : "лет",
                color: accent
            )

            snapshotCard(
                icon: "scalemass.fill",
                title: "ИМТ",
                value: profile.bmi > 0 ? String(format: "%.1f", profile.bmi) : "-",
                unit: profile.bmi > 0 ? profile.bmiLabel : "нет",
                color: profile.bmiColor(accent: accent)
            )

            snapshotCard(
                icon: "flame.fill",
                title: "Калории",
                value: profile.caloriesGoal.formattedWithSpaces,
                unit: "ккал",
                color: Color(red: 1.0, green: 0.58, blue: 0.12)
            )
        }
    }

    private func snapshotCard(icon: String, title: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .black))
                .foregroundColor(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(isDarkModeEnabled ? 0.16 : 0.11), in: Circle())

            Text(title)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(mutedText)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundColor(primaryText)

                Text(unit)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(cardSurface(cornerRadius: 22))
    }

    // MARK: - Sections

    private func sectionTitle(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(mutedText)
                .tracking(1.2)

            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.top, 2)
        .padding(.bottom, -4)
    }

    private var managementCard: some View {
        cardContainer {
            VStack(spacing: 0) {
                mainActionRow(
                    icon: "person.text.rectangle.fill",
                    iconColor: accent,
                    title: "Мой аккаунт",
                    subtitle: accountSubtitle,
                    action: { showAccountEditor = true }
                )

                dividerCard

                mainActionRow(
                    icon: "target",
                    iconColor: accent2,
                    title: "Мои цели",
                    subtitle: "\(profile.stepsGoal.formattedWithSpaces) шагов · \(String(format: "%.1f", profile.waterGoal)) л · \(String(format: "%.1f", profile.sleepGoal)) ч",
                    action: { showGoalsEditor = true }
                )
            }
        }
    }

    private var preferencesCard: some View {
        cardContainer {
            VStack(spacing: 0) {
                toggleRow(
                    icon: "moon.fill",
                    color: Color(red: 0.55, green: 0.35, blue: 1.0),
                    title: "Тёмный режим",
                    subtitle: "Переключает тему интерфейса",
                    isOn: $isDarkModeEnabled
                )

                dividerCard

                toggleRow(
                    icon: "bell.fill",
                    color: Color(red: 1.0, green: 0.56, blue: 0.15),
                    title: "Уведомления",
                    subtitle: "Напоминания и важные сигналы",
                    isOn: $notificationsOn
                )

                dividerCard

                toggleRow(
                    icon: "heart.fill",
                    color: Color(red: 0.96, green: 0.30, blue: 0.30),
                    title: "HealthKit",
                    subtitle: "Данные активности и здоровья",
                    isOn: $healthKitOn
                )

                dividerCard

                toggleRow(
                    icon: "faceid",
                    color: accent2,
                    title: "Face ID / Touch ID",
                    subtitle: "Быстрый защищённый вход",
                    isOn: $biometricOn
                )

                dividerCard

                mainActionRow(
                    icon: "globe",
                    iconColor: Color(red: 0.12, green: 0.82, blue: 0.52),
                    title: "Язык",
                    subtitle: lang.currentLanguage.title,
                    action: { showLanguagePicker = true }
                )
            }
        }
    }

    private var supportRow: some View {
        HStack(spacing: 12) {
            supportCard(icon: "star.fill", title: "Rate Us", subtitle: "Оценить Bagyt")
            supportCard(icon: "message.fill", title: "Contact", subtitle: "Связаться")
        }
    }

    private func supportCard(icon: String, title: String, subtitle: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(alignment: .leading, spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(accent)
                    .frame(width: 36, height: 36)
                    .background(accent.opacity(isDarkModeEnabled ? 0.16 : 0.11), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(primaryText)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(secondaryText)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 114, alignment: .leading)
            .padding(16)
            .background(cardSurface(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }

    private var versionBlock: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 17, weight: .black))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.15), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bagyt")
                            .font(.system(size: 23, weight: .black, design: .rounded))
                            .foregroundColor(.white)

                        Text("Version 1.0.0")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.72))
                    }
                }

                Spacer()
            }

            Rectangle()
                .fill(Color.white.opacity(0.16))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 6) {
                Text("together, every\nstep forward")
                    .font(.system(size: 31, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.18))
                    .lineSpacing(-2)

                Text("Сделано с любовью в Казахстане")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.76))
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.62, blue: 0.90),
                            Color(red: 0.08, green: 0.48, blue: 0.86)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isDarkModeEnabled ? 0.22 : 0.06), radius: 14, x: 0, y: 8)
    }

    private var logoutButton: some View {
        Button {
            showLogoutAlert = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .black))

                Text("Выйти из аккаунта")
                    .font(.system(size: 16, weight: .black, design: .rounded))
            }
            .foregroundColor(Color(red: 0.95, green: 0.30, blue: 0.30))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(cardSurface(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reusable Rows

    private func cardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(cardSurface(cornerRadius: 28))
    }

    private var dividerCard: some View {
        Rectangle()
            .fill(isDarkModeEnabled ? Color.white.opacity(0.08) : Color.black.opacity(0.055))
            .frame(height: 1)
            .padding(.leading, 70)
    }

    private func mainActionRow(icon: String, iconColor: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                settingIcon(icon: icon, color: iconColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(primaryText)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(mutedText)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 17)
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(icon: String, color: Color, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            settingIcon(icon: icon, color: color)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(primaryText)

                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(secondaryText)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(accent)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 17)
    }

    private func settingIcon(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 17, weight: .black))
            .foregroundColor(color)
            .frame(width: 44, height: 44)
            .background(color.opacity(isDarkModeEnabled ? 0.16 : 0.11), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private func cardSurface(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(cardBg)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(cardStroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isDarkModeEnabled ? 0.16 : 0.045), radius: 10, x: 0, y: 6)
    }

    // MARK: - Overlays

    private func enlargedAvatarOverlay(_ image: UIImage) -> some View {
        ZStack {
            Color.black.opacity(0.86)
                .ignoresSafeArea()
                .onTapGesture {
                    closeEnlargedAvatar()
                }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        closeEnlargedAvatar()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.86))
                            .padding(20)
                    }
                }
                Spacer()
            }

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 15)
                .padding(24)
                .onTapGesture {
                    closeEnlargedAvatar()
                }
        }
    }

    private func closeEnlargedAvatar() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showEnlargedAvatar = false
        }
    }

    // MARK: - Save

    private func saveAccount(_ result: AccountEditorResult) {
        let trimmed = result.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        appState.userName = trimmed

        let nameKey = "userName_\(appState.userToken ?? "guest")"
        UserDefaults.standard.set(trimmed, forKey: nameKey)

        profile.age = result.age
        profile.weight = result.weight
        profile.height = result.height
        profile.gender = result.gender
        profile.save()
        profile.load()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func saveGoals(_ result: GoalsEditorResult) {
        profile.goal = result.goal == "general" ? "" : result.goal
        profile.stepsGoal = result.stepsGoal
        profile.waterGoal = result.waterGoal
        profile.sleepGoal = result.sleepGoal
        profile.caloriesGoal = result.caloriesGoal
        profile.save()
        profile.load()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func restoreUserName() {
        let nameKey = "userName_\(appState.userToken ?? "guest")"
        if let savedName = UserDefaults.standard.string(forKey: nameKey), !savedName.isEmpty {
            appState.userName = savedName
        }
    }

    // MARK: - Avatar Crop

    private func avatarCropView(_ image: UIImage) -> some View {
        let normalized = normalizedImage(image)
        let displaySize = cropDisplaySize(for: normalized.size, viewport: cropViewport, scale: cropScale)

        return ZStack {
            Color.black.opacity(0.94).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Настройка фото")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: cropViewport + 24, height: cropViewport + 24)

                    ZStack {
                        Image(uiImage: normalized)
                            .resizable()
                            .frame(width: displaySize.width, height: displaySize.height)
                            .offset(cropOffset)

                        Circle()
                            .strokeBorder(Color.white.opacity(0.85), lineWidth: 2)
                    }
                    .frame(width: cropViewport, height: cropViewport)
                    .clipShape(Circle())
                    .contentShape(Circle())
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                let proposed = CGSize(
                                    width: dragStartOffset.width + value.translation.width,
                                    height: dragStartOffset.height + value.translation.height
                                )
                                cropOffset = clampedOffset(
                                    proposed,
                                    imageSize: normalized.size,
                                    viewport: cropViewport,
                                    scale: cropScale
                                )
                            }
                            .onEnded { _ in
                                dragStartOffset = cropOffset
                            }
                    )
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                cropScale = min(max(zoomStartScale * value, 1.0), 4.0)
                                cropOffset = clampedOffset(
                                    cropOffset,
                                    imageSize: normalized.size,
                                    viewport: cropViewport,
                                    scale: cropScale
                                )
                            }
                            .onEnded { _ in
                                zoomStartScale = cropScale
                                dragStartOffset = cropOffset
                            }
                    )
                }

                Text("Перемещайте и масштабируйте фото")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))

                HStack(spacing: 14) {
                    Button {
                        showCropView = false
                        pendingImage = nil
                        resetCropState()
                    } label: {
                        Text("Отмена")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.14))
                            .clipShape(Capsule())
                    }

                    Button {
                        if let cropped = cropImage(normalized) {
                            avatarImage = cropped
                            saveAvatar(cropped)
                        }
                        showCropView = false
                        pendingImage = nil
                        resetCropState()
                    } label: {
                        Text("Сохранить")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 28)
            }
        }
    }

    private func cropDisplaySize(for imageSize: CGSize, viewport: CGFloat, scale: CGFloat) -> CGSize {
        let fillScale = max(viewport / imageSize.width, viewport / imageSize.height) * scale
        return CGSize(width: imageSize.width * fillScale, height: imageSize.height * fillScale)
    }

    private func clampedOffset(_ proposed: CGSize, imageSize: CGSize, viewport: CGFloat, scale: CGFloat) -> CGSize {
        let displaySize = cropDisplaySize(for: imageSize, viewport: viewport, scale: scale)
        let maxX = max((displaySize.width - viewport) / 2, 0)
        let maxY = max((displaySize.height - viewport) / 2, 0)

        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }

    private func cropImage(_ image: UIImage) -> UIImage? {
        let output: CGFloat = 700
        let displaySize = cropDisplaySize(for: image.size, viewport: cropViewport, scale: cropScale)
        let origin = CGPoint(
            x: (cropViewport - displaySize.width) / 2 + cropOffset.width,
            y: (cropViewport - displaySize.height) / 2 + cropOffset.height
        )
        let ratio = output / cropViewport

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: output, height: output))
        return renderer.image { _ in
            image.draw(
                in: CGRect(
                    x: origin.x * ratio,
                    y: origin.y * ratio,
                    width: displaySize.width * ratio,
                    height: displaySize.height * ratio
                )
            )
        }
    }

    private func normalizedImage(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private func resetCropState() {
        cropOffset = .zero
        cropScale = 1.0
        dragStartOffset = .zero
        zoomStartScale = 1.0
    }

    // MARK: - Avatar Storage

    private func avatarKey() -> String {
        "userAvatar_\(appState.userToken ?? "guest")"
    }

    private func saveAvatar(_ image: UIImage) {
        if let data = image.jpegData(compressionQuality: 0.9) {
            UserDefaults.standard.set(data, forKey: avatarKey())
        }
    }

    private func loadAvatar() {
        if let data = UserDefaults.standard.data(forKey: avatarKey()),
           let image = UIImage(data: data) {
            avatarImage = image
        } else {
            avatarImage = nil
        }
    }

    // MARK: - Helpers

    private func initials(from name: String) -> String {
        let result = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
            .uppercased()

        return result.isEmpty ? "B" : result
    }
}

// MARK: - Editor Models

struct AccountEditorResult {
    let name: String
    let age: Int
    let weight: Double
    let height: Double
    let gender: String
}

struct GoalsEditorResult {
    let goal: String
    let stepsGoal: Int
    let waterGoal: Double
    let sleepGoal: Double
    let caloriesGoal: Int
}

// MARK: - Account Editor

private struct AccountEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkModeEnabled") private var isDarkModeEnabled = false

    @State private var name: String
    @State private var age: Double
    @State private var weight: Double
    @State private var height: Double
    @State private var gender: String

    private let onSave: (AccountEditorResult) -> Void
    private let accent = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)

    private var baseBg: Color {
        isDarkModeEnabled ? Color(red: 0.04, green: 0.06, blue: 0.10) : Color(red: 0.94, green: 0.97, blue: 1.0)
    }

    private var cardBg: Color {
        isDarkModeEnabled ? Color(red: 0.10, green: 0.12, blue: 0.18).opacity(0.86) : Color.white.opacity(0.88)
    }

    private var primaryText: Color {
        isDarkModeEnabled ? .white : Color(red: 0.06, green: 0.09, blue: 0.16)
    }

    private var secondaryText: Color {
        isDarkModeEnabled ? .white.opacity(0.62) : Color(red: 0.40, green: 0.55, blue: 0.65)
    }

    private var stroke: Color {
        isDarkModeEnabled ? Color.white.opacity(0.11) : Color.white.opacity(0.72)
    }

    private let genders: [(String, String, String)] = [
        ("male", "Мужской", "figure.stand"),
        ("female", "Женский", "figure.stand.dress"),
        ("other", "Другой", "sparkles")
    ]

    init(initialName: String, initialAge: Int, initialWeight: Double, initialHeight: Double, initialGender: String, onSave: @escaping (AccountEditorResult) -> Void) {
        _name = State(initialValue: initialName)
        _age = State(initialValue: Double(max(initialAge, 18)))
        _weight = State(initialValue: initialWeight > 0 ? initialWeight : 70)
        _height = State(initialValue: initialHeight > 0 ? initialHeight : 175)
        _gender = State(initialValue: initialGender)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                editorBackground

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        editorHeader(
                            icon: "person.text.rectangle.fill",
                            title: "Мой аккаунт",
                            subtitle: "Данные профиля помогают Bagyt точнее считать цели и рекомендации."
                        )

                        editorField(title: "Имя") {
                            TextField("Введите имя", text: $name)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(primaryText)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                        }

                        sliderBlock(title: "Возраст", value: Int(age.rounded()).formattedAge, binding: $age, range: 12...90, step: 1, tint: accent)
                        sliderBlock(title: "Вес", value: "\(Int(weight.rounded())) кг", binding: $weight, range: 30...180, step: 1, tint: Color(red: 0.10, green: 0.78, blue: 0.48))
                        sliderBlock(title: "Рост", value: "\(Int(height.rounded())) см", binding: $height, range: 120...220, step: 1, tint: Color(red: 0.55, green: 0.35, blue: 1.0))

                        genderBlock

                        saveButton
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Мой аккаунт")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(isDarkModeEnabled ? .dark : .light)
        }
    }

    private var editorBackground: some View {
        ZStack {
            baseBg.ignoresSafeArea()

            LinearGradient(
                colors: [
                    accent.opacity(isDarkModeEnabled ? 0.16 : 0.13),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    private func editorHeader(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .black))
                .foregroundColor(accent)
                .frame(width: 54, height: 54)
                .background(accent.opacity(isDarkModeEnabled ? 0.16 : 0.11), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(primaryText)

                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(18)
        .background(cardSurface(cornerRadius: 24))
    }

    private func editorField<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            label(title)
            content()
                .padding(15)
                .background(cardSurface(cornerRadius: 18))
        }
    }

    private var genderBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("Пол")

            HStack(spacing: 8) {
                ForEach(genders, id: \.0) { item in
                    let isSelected = gender == item.0

                    Button {
                        gender = item.0
                    } label: {
                        VStack(spacing: 7) {
                            Image(systemName: item.2)
                                .font(.system(size: 16, weight: .black))

                            Text(item.1)
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .foregroundColor(isSelected ? .white : primaryText.opacity(0.72))
                        .frame(maxWidth: .infinity, minHeight: 70)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .fill(cardBg)

                                if isSelected {
                                    if item.0 == "other" {
                                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                                            .fill(LinearGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .opacity(0.85)
                                    } else if item.0 == "female" {
                                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                                            .fill(Color.pink.opacity(0.95))
                                    } else {
                                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                                            .fill(accent.opacity(0.95))
                                    }
                                }
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .strokeBorder(isSelected ? Color.white.opacity(0.18) : stroke, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }


    private var saveButton: some View {
        Button {
            onSave(
                AccountEditorResult(
                    name: name,
                    age: Int(age.rounded()),
                    weight: weight,
                    height: height,
                    gender: gender
                )
            )
            dismiss()
        } label: {
            Text("Сохранить")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                .shadow(color: accent.opacity(0.24), radius: 12, x: 0, y: 7)
        }
        .buttonStyle(.plain)
        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
    }

    private func sliderBlock(title: String, value: String, binding: Binding<Double>, range: ClosedRange<Double>, step: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(primaryText)

                Spacer()

                Text(value)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(tint)
            }

            Slider(value: binding, in: range, step: step)
                .tint(tint)
        }
        .padding(16)
        .background(cardSurface(cornerRadius: 20))
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundColor(secondaryText)
            .tracking(0.8)
    }

    private func cardSurface(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(cardBg)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isDarkModeEnabled ? 0.14 : 0.04), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Goals Editor

private struct GoalsEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkModeEnabled") private var isDarkModeEnabled = false

    @State private var goal: String
    @State private var stepsGoal: Double
    @State private var waterGoal: Double
    @State private var sleepGoal: Double
    @State private var caloriesGoal: Double

    private let onSave: (GoalsEditorResult) -> Void
    private let accent = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)

    private var baseBg: Color {
        isDarkModeEnabled ? Color(red: 0.04, green: 0.06, blue: 0.10) : Color(red: 0.94, green: 0.97, blue: 1.0)
    }

    private var cardBg: Color {
        isDarkModeEnabled ? Color(red: 0.10, green: 0.12, blue: 0.18).opacity(0.86) : Color.white.opacity(0.88)
    }

    private var primaryText: Color {
        isDarkModeEnabled ? .white : Color(red: 0.06, green: 0.09, blue: 0.16)
    }

    private var secondaryText: Color {
        isDarkModeEnabled ? .white.opacity(0.62) : Color(red: 0.40, green: 0.55, blue: 0.65)
    }

    private var stroke: Color {
        isDarkModeEnabled ? Color.white.opacity(0.11) : Color.white.opacity(0.72)
    }

    private let goals: [(String, String, String)] = [
        ("general", "Общее самочувствие", "sun.max.fill"),
        ("prevention", "Профилактика", "shield.fill"),
        ("stress_relief", "Снижение стресса", "brain.head.profile"),
        ("weight_control", "Контроль веса", "scalemass.fill"),
        ("chronic_disease", "Хронические болезни", "cross.case.fill")
    ]

    init(initialGoal: String, initialStepsGoal: Int, initialWaterGoal: Double, initialSleepGoal: Double, initialCaloriesGoal: Int, onSave: @escaping (GoalsEditorResult) -> Void) {
        _goal = State(initialValue: initialGoal)
        _stepsGoal = State(initialValue: Double(initialStepsGoal))
        _waterGoal = State(initialValue: initialWaterGoal)
        _sleepGoal = State(initialValue: initialSleepGoal)
        _caloriesGoal = State(initialValue: Double(initialCaloriesGoal))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                editorBackground

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        editorHeader

                        goalGrid

                        sliderBlock(
                            title: "Шаги",
                            value: "\(Int(stepsGoal.rounded()).formattedWithSpaces) шагов",
                            binding: $stepsGoal,
                            range: 2000...20000,
                            step: 500,
                            tint: accent,
                            icon: "figure.walk"
                        )

                        sliderBlock(
                            title: "Вода",
                            value: String(format: "%.1f л", waterGoal),
                            binding: $waterGoal,
                            range: 1.0...5.0,
                            step: 0.1,
                            tint: Color(red: 0.18, green: 0.55, blue: 1.0),
                            icon: "drop.fill"
                        )

                        sliderBlock(
                            title: "Сон",
                            value: String(format: "%.1f ч", sleepGoal),
                            binding: $sleepGoal,
                            range: 5.0...10.0,
                            step: 0.1,
                            tint: Color(red: 0.55, green: 0.35, blue: 1.0),
                            icon: "moon.stars.fill"
                        )

                        sliderBlock(
                            title: "Калории",
                            value: "\(Int(caloriesGoal.rounded()).formattedWithSpaces) ккал",
                            binding: $caloriesGoal,
                            range: 1200...4000,
                            step: 50,
                            tint: Color(red: 1.0, green: 0.58, blue: 0.12),
                            icon: "flame.fill"
                        )

                        saveButton
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Мои цели")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(isDarkModeEnabled ? .dark : .light)
        }
    }

    private var editorBackground: some View {
        ZStack {
            baseBg.ignoresSafeArea()

            LinearGradient(
                colors: [
                    accent.opacity(isDarkModeEnabled ? 0.16 : 0.13),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    private var editorHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "target")
                .font(.system(size: 22, weight: .black))
                .foregroundColor(accent2)
                .frame(width: 54, height: 54)
                .background(accent2.opacity(isDarkModeEnabled ? 0.16 : 0.11), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text("Мои цели")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(primaryText)

                Text("Настройте ежедневные ориентиры для активности, сна, воды и питания.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(18)
        .background(cardSurface(cornerRadius: 24))
    }

    private var goalGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("Фокус")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                ForEach(goals, id: \.0) { item in
                    Button {
                        goal = item.0
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: item.2)
                                .font(.system(size: 13, weight: .black))

                            Text(item.1)
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .foregroundColor(goal == item.0 ? .white : primaryText.opacity(0.72))
                        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                        .padding(.horizontal, 12)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 17, style: .continuous).fill(cardBg)
                                if goal == item.0 {
                                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .fill(LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing))
                                }
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .strokeBorder(goal == item.0 ? Color.white.opacity(0.18) : stroke, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var saveButton: some View {
        Button {
            onSave(
                GoalsEditorResult(
                    goal: goal,
                    stepsGoal: Int(stepsGoal.rounded()),
                    waterGoal: waterGoal,
                    sleepGoal: sleepGoal,
                    caloriesGoal: Int(caloriesGoal.rounded())
                )
            )
            dismiss()
        } label: {
            Text("Сохранить")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                .shadow(color: accent.opacity(0.24), radius: 12, x: 0, y: 7)
        }
        .buttonStyle(.plain)
    }

    private func sliderBlock(title: String, value: String, binding: Binding<Double>, range: ClosedRange<Double>, step: Double, tint: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(isDarkModeEnabled ? 0.16 : 0.11), in: Circle())

                Text(title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(primaryText)

                Spacer()

                Text(value)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(tint)
            }

            Slider(value: binding, in: range, step: step)
                .tint(tint)
        }
        .padding(16)
        .background(cardSurface(cornerRadius: 20))
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundColor(secondaryText)
            .tracking(0.8)
    }

    private func cardSurface(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(cardBg)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isDarkModeEnabled ? 0.14 : 0.04), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Helpers

private extension Int {
    var formattedWithSpaces: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
    
    var ageWord: String {
        let mod10 = self % 10
        let mod100 = self % 100
        
        if mod100 >= 11 && mod100 <= 14 {
            return "лет"
        }
        
        switch mod10 {
        case 1:
            return "год"
        case 2, 3, 4:
            return "года"
        default:
            return "лет"
        }
    }
    
    var formattedAge: String {
        return "\(self) \(self.ageWord)"
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
        .environmentObject(LanguageManager())
}
