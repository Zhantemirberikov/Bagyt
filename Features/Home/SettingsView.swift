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
    @State private var appear = false

    // Стейт для просмотра увеличенной аватарки
    @State private var showEnlargedAvatar = false

    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var pendingImage: UIImage?

    @State private var cropOffset: CGSize = .zero
    @State private var cropScale: CGFloat = 1.0
    @State private var dragStartOffset: CGSize = .zero
    @State private var zoomStartScale: CGFloat = 1.0

    private let accent = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)
    private let bg = Color(red: 0.878, green: 0.949, blue: 0.992)
    private let cropViewport: CGFloat = 300

    private var displayName: String {
        let trimmed = (appState.userName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Пользователь" : trimmed
    }

    private var goalLabel: String {
        switch profile.goal.isEmpty ? "general" : profile.goal {
        case "prevention": return "Профилактика"
        case "stress_relief": return "Снижение стресса"
        case "weight_control": return "Контроль веса"
        case "chronic_disease": return "Хронические болезни"
        default: return "Общее самочувствие"
        }
    }

    var body: some View {
        ZStack {
            backgroundLayer

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    heroCard
                    sectionTitle("Управление")
                    managementCard
                    sectionTitle("Настройки")
                    preferencesCard
                    supportRow
                    promoCard
                    versionBlock
                    logoutButton
                    Spacer(minLength: 110)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }

            if showCropView, let image = pendingImage {
                avatarCropView(image)
            }

            // Оверлей увеличенной аватарки
            if showEnlargedAvatar, let image = avatarImage {
                ZStack {
                    Color.black.opacity(0.85)
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
                                    .font(.system(size: 28))
                                    .foregroundColor(.white.opacity(0.8))
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
                .zIndex(100)
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
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
                    withAnimation(.easeInOut) {
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
            withAnimation(.easeOut(duration: 0.55)) {
                appear = true
            }
            loadAvatar()
            profile.load()
            
            // Защита: восстанавливаем имя из памяти, если оно вдруг пропало после логина
            let nameKey = "userName_\(appState.userToken ?? "guest")"
            if let savedName = UserDefaults.standard.string(forKey: nameKey), !savedName.isEmpty {
                appState.userName = savedName
            }
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

    private func closeEnlargedAvatar() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showEnlargedAvatar = false
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.86, green: 0.95, blue: 0.99),
                    Color(red: 0.93, green: 0.98, blue: 1.0),
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(accent.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 40)
                .offset(x: -140, y: -280)

            Circle()
                .fill(accent2.opacity(0.12))
                .frame(width: 240, height: 240)
                .blur(radius: 34)
                .offset(x: 150, y: -180)

            Circle()
                .fill(Color(red: 0.20, green: 0.75, blue: 0.90).opacity(0.08))
                .frame(width: 220, height: 220)
                .blur(radius: 28)
                .offset(x: 100, y: 420)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [accent, accent2],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 88, height: 88)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 62, height: 62)

                    if let image = avatarImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 78, height: 78)
                            .clipShape(Circle())
                    } else {
                        Text(initials(from: displayName))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(accent)
                    }
                }
                .contentShape(Circle())
                .onTapGesture {
                    showAvatarOptions = true
                }
                .onLongPressGesture(minimumDuration: 0.4) {
                    if avatarImage != nil {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            showEnlargedAvatar = true
                        }
                    } else {
                        showAvatarOptions = true
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: isDarkModeEnabled ? "moon.fill" : "sun.max.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(isDarkModeEnabled ? "Dark" : "Light")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white.opacity(0.92))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.16))
                    .clipShape(Capsule())

                    if let token = appState.userToken {
                        Text(emailFromToken(token))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.74))
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(displayName)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(goalLabel)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.84))
            }

            Divider()
                .overlay(Color.white.opacity(0.20))

            HStack {
                statColumn(title: "Шаги", value: "\(profile.stepsGoal.formattedWithSpaces)", subtitle: "в день")
                dividerLine
                statColumn(title: "Вода", value: String(format: "%.1f", profile.waterGoal), subtitle: "л")
                dividerLine
                statColumn(title: "Сон", value: String(format: "%.1f", profile.sleepGoal), subtitle: "ч")
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent,
                            Color(red: 0.10, green: 0.63, blue: 0.90),
                            accent2
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: accent.opacity(0.28), radius: 18, x: 0, y: 10)
        )
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 24)
        .animation(.easeOut(duration: 0.45), value: appear)
    }

    private func statColumn(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.62))
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(Color.white.opacity(0.18))
            .frame(width: 1, height: 40)
    }

    private func sectionTitle(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 0.50, green: 0.60, blue: 0.70))
                .tracking(1.2)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.bottom, -4)
    }

    private var managementCard: some View {
        cardContainer {
            VStack(spacing: 0) {
                mainActionRow(
                    icon: "person.text.rectangle.fill",
                    iconColor: accent,
                    title: "Мой аккаунт",
                    subtitle: "Имя, возраст, рост, вес и пол"
                ) {
                    showAccountEditor = true
                }

                dividerCard

                mainActionRow(
                    icon: "target",
                    iconColor: accent2,
                    title: "Мои цели",
                    subtitle: "Шаги, вода, сон, калории и фокус"
                ) {
                    showGoalsEditor = true
                }
            }
        }
    }

    private var preferencesCard: some View {
        cardContainer {
            VStack(spacing: 0) {
                toggleRow(icon: "moon.fill", color: Color(red: 0.15, green: 0.18, blue: 0.34), title: "Тёмный режим", isOn: $isDarkModeEnabled)
                dividerCard
                toggleRow(icon: "bell.fill", color: Color(red: 1.0, green: 0.56, blue: 0.15), title: "Уведомления", isOn: $notificationsOn)
                dividerCard
                toggleRow(icon: "heart.fill", color: Color(red: 0.96, green: 0.30, blue: 0.30), title: "HealthKit", isOn: $healthKitOn)
                dividerCard
                toggleRow(icon: "faceid", color: accent2, title: "Face ID / Touch ID", isOn: $biometricOn)
                dividerCard

                mainActionRow(
                    icon: "globe",
                    iconColor: Color(red: 0.12, green: 0.82, blue: 0.52),
                    title: "Язык",
                    subtitle: lang.currentLanguage.title
                ) {
                    showLanguagePicker = true
                }
            }
        }
    }

    private var supportRow: some View {
        HStack(spacing: 12) {
            supportCard(icon: "star.fill", title: "Rate Us")
            supportCard(icon: "message.fill", title: "Contact Us")
        }
    }

    private func supportCard(icon: String, title: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.black.opacity(0.92))
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(Color.black.opacity(0.92))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color.black.opacity(0.45))
        }
        .padding(.horizontal, 20)
        .frame(height: 82)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.98))
        )
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 6)
    }

    private var promoCard: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.48, blue: 0.32), Color(red: 1.0, green: 0.68, blue: 0.30)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 68, height: 68)
                .overlay(
                    Image(systemName: "heart.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("Bagyt Profile")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Структурированный профиль, цели и персональные привычки")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.84))
            }

            Spacer()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent, Color(red: 0.18, green: 0.55, blue: 0.95)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private var versionBlock: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Bagyt")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("Version 1.0.0")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.84))
            }

            Rectangle()
                .fill(Color.white.opacity(0.16))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 6) {
                Text("together, every\nstep forward")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.18))

                Text("Сделано с любовью в Казахстане")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.76))
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.13, green: 0.62, blue: 0.90),
                            Color(red: 0.10, green: 0.48, blue: 0.86)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
        )
    }

    private func cardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white.opacity(0.97))
                .shadow(color: accent.opacity(0.08), radius: 16, x: 0, y: 8)

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color(red: 0.80, green: 0.92, blue: 0.98), lineWidth: 1)

            VStack(spacing: 0) {
                content()
            }
        }
    }

    private var dividerCard: some View {
        Rectangle()
            .fill(Color.black.opacity(0.06))
            .frame(height: 1)
            .padding(.leading, 66)
    }

    private func mainActionRow(icon: String, iconColor: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 42, height: 42)

                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.black.opacity(0.85))
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.45))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.35))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(icon: String, color: Color, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 42, height: 42)

                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(color)
            }

            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(Color.black.opacity(0.85))

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(accent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }

    private var logoutButton: some View {
        Button {
            showLogoutAlert = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                Text("Выйти из аккаунта")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            .foregroundColor(Color(red: 0.95, green: 0.25, blue: 0.25))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.94))
            )
        }
        .buttonStyle(.plain)
    }

    private func saveAccount(_ result: AccountEditorResult) {
        let trimmed = result.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Обновляем в текущей сессии
        appState.userName = trimmed
        
        // СОХРАНЯЕМ В ДОЛГОВРЕМЕННУЮ ПАМЯТЬ ТЕЛЕФОНА
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

    private func avatarCropView(_ image: UIImage) -> some View {
        let normalized = normalizedImage(image)
        let displaySize = cropDisplaySize(for: normalized.size, viewport: cropViewport, scale: cropScale)

        return ZStack {
            Color.black.opacity(0.94).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Настройка фото")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.05))
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
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
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
                            .font(.system(size: 16, weight: .bold, design: .rounded))
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
        }
    }

    private func initials(from name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    private func emailFromToken(_ token: String) -> String {
        if token.contains("@") { return token }
        if token.contains("offline") { return token.replacingOccurrences(of: "offline-", with: "") }
        return "ID: \(String(token.prefix(8)))..."
    }
}

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

private struct AccountEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var age: Double
    @State private var weight: Double
    @State private var height: Double
    @State private var gender: String

    private let onSave: (AccountEditorResult) -> Void
    private let accent = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)

    private let genders: [(String, String, String)] = [
        ("male", "Мужской", "figure.stand"),
        ("female", "Женский", "figure.dress.line.vertical.figure"),
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
            ScrollView {
                VStack(spacing: 18) {
                    editorField(title: "Имя") {
                        TextField("Введите имя", text: $name)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                    }

                    sliderBlock(title: "Возраст", value: "\(Int(age.rounded())) лет", binding: $age, range: 12...90, step: 1, tint: accent)
                    sliderBlock(title: "Вес", value: "\(Int(weight.rounded())) кг", binding: $weight, range: 30...180, step: 1, tint: .green)
                    sliderBlock(title: "Рост", value: "\(Int(height.rounded())) см", binding: $height, range: 120...220, step: 1, tint: .purple)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Пол")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            ForEach(genders, id: \.0) { item in
                                Button {
                                    gender = item.0
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: item.2)
                                        Text(item.1)
                                    }
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(gender == item.0 ? .white : .black.opacity(0.70))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        Group {
                                            if gender == item.0 {
                                                LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing)
                                            } else {
                                                Color(red: 0.95, green: 0.98, blue: 1.0)
                                            }
                                        }
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

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
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)
                }
                .padding(20)
            }
            .background(Color(red: 0.97, green: 0.99, blue: 1.0))
            .navigationTitle("Мой аккаунт")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func editorField<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
            content()
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.white)
                )
        }
    }

    private func sliderBlock(title: String, value: String, binding: Binding<Double>, range: ClosedRange<Double>, step: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Spacer()
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(tint)
            }

            Slider(value: binding, in: range, step: step)
                .tint(tint)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white)
        )
    }
}

private struct GoalsEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var goal: String
    @State private var stepsGoal: Double
    @State private var waterGoal: Double
    @State private var sleepGoal: Double
    @State private var caloriesGoal: Double

    private let onSave: (GoalsEditorResult) -> Void
    private let accent = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)

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
            ScrollView {
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Фокус")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(goals, id: \.0) { item in
                                Button {
                                    goal = item.0
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: item.2)
                                        Text(item.1)
                                            .lineLimit(2)
                                    }
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(goal == item.0 ? .white : .black.opacity(0.70))
                                    .frame(maxWidth: .infinity, minHeight: 52)
                                    .padding(.horizontal, 10)
                                    .background(
                                        Group {
                                            if goal == item.0 {
                                                LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing)
                                            } else {
                                                Color.white
                                            }
                                        }
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    sliderBlock(title: "Шаги", value: "\(Int(stepsGoal.rounded()).formattedWithSpaces) шагов", binding: $stepsGoal, range: 2000...20000, step: 500, tint: accent)
                    sliderBlock(title: "Вода", value: String(format: "%.1f л", waterGoal), binding: $waterGoal, range: 1.0...5.0, step: 0.1, tint: .blue)
                    sliderBlock(title: "Сон", value: String(format: "%.1f ч", sleepGoal), binding: $sleepGoal, range: 5.0...10.0, step: 0.1, tint: .purple)
                    sliderBlock(title: "Калории", value: "\(Int(caloriesGoal.rounded()).formattedWithSpaces) ккал", binding: $caloriesGoal, range: 1200...4000, step: 50, tint: .orange)

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
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(Color(red: 0.97, green: 0.99, blue: 1.0))
            .navigationTitle("Мои цели")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func sliderBlock(title: String, value: String, binding: Binding<Double>, range: ClosedRange<Double>, step: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Spacer()
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(tint)
            }

            Slider(value: binding, in: range, step: step)
                .tint(tint)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white)
        )
    }
}

private extension Int {
    var formattedWithSpaces: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
        .environmentObject(LanguageManager())
}
