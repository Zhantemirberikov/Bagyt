import SwiftUI
import Combine
import UIKit
import HealthKit

// MARK: - HomeView

struct HomeView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lang: LanguageManager
    @StateObject private var health = HealthKitManager.shared

    // Подключаем настройку темной темы
    @AppStorage("isDarkModeEnabled") private var isDarkMode = false

    @State private var selectedTab: Int   = 0
    @State private var pulse              = false
    @State private var showProfileSheet   = false
    @State private var showAssistantSheet = false
    @State private var appear             = false
    
    // 👇 Новый стейт для открытия деталей индекса здоровья
    @State private var showIndexDetail    = false
    
    // Анимации фона и орба
    @State private var bgPhase            = false
    @State private var orbRing1           = false
    @State private var orbRing2           = false
    @State private var orbRing3           = false
    @State private var orbBob             = false
    @State private var orbOffset: CGSize  = .zero
    @State private var orbIsPressed       = false
    @State private var suppressOrbTapAfterDrag = false

    @State private var showSleepDetail    = false
    @State private var showPulseDetail    = false
    @State private var showStepsDetail    = false

    @State private var liquidDragX: CGFloat? = nil
    @State private var isLiquidDragging = false

    // Аватар из UserDefaults
    @State private var avatarImage: UIImage? = nil

    private let accent   = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2  = Color(red: 0.024, green: 0.714, blue: 0.831)
    
    // MARK: - Динамическая палитра (Светлая / Темная тема)
    private var baseBg: Color { isDarkMode ? Color(red: 0.04, green: 0.06, blue: 0.10) : Color(red: 0.94, green: 0.97, blue: 1.0) }
    private var primaryText: Color { isDarkMode ? .white : Color(red: 0.06, green: 0.09, blue: 0.16) }
    private var secondaryText: Color { isDarkMode ? Color.white.opacity(0.6) : Color(red: 0.4, green: 0.55, blue: 0.65) }
    private var cardBg: Color { isDarkMode ? Color(red: 0.1, green: 0.12, blue: 0.18).opacity(0.85) : Color.white.opacity(0.95) }
    private var cardStroke: Color { isDarkMode ? Color.white.opacity(0.1) : Color.white.opacity(0.8) }
    private var liquidBarBg: Color { isDarkMode ? Color.black.opacity(0.4) : Color.white.opacity(0.1) }
    private var iconTint: Color { isDarkMode ? .white : .black }

    var body: some View {
        ZStack(alignment: .bottom) {

            // ── Фон ──
            ZStack {
                // Базовый цвет подложки
                baseBg.ignoresSafeArea()
                
                AnimatedGradientBackground()
                    .opacity(isDarkMode ? 0.3 : 1.0) // Приглушаем светлый фон в темной теме
                
                Circle()
                    .fill(RadialGradient(colors: [accent.opacity(isDarkMode ? 0.15 : 0.30), .clear], center: .center, startRadius: 0, endRadius: 180))
                    .frame(width: 340, height: 340)
                    .offset(x: bgPhase ? -70 : 50, y: bgPhase ? -160 : -100)
                    .blur(radius: 45)
                    .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: bgPhase)
                Circle()
                    .fill(RadialGradient(colors: [accent2.opacity(isDarkMode ? 0.15 : 0.25), .clear], center: .center, startRadius: 0, endRadius: 150))
                    .frame(width: 280, height: 280)
                    .offset(x: bgPhase ? 120 : 50, y: bgPhase ? 80 : 180)
                    .blur(radius: 40)
                    .animation(.easeInOut(duration: 9).repeatForever(autoreverses: true).delay(1.5), value: bgPhase)
                Circle()
                    .fill(RadialGradient(colors: [accent.opacity(isDarkMode ? 0.10 : 0.20), .clear], center: .center, startRadius: 0, endRadius: 120))
                    .frame(width: 220, height: 220)
                    .offset(x: bgPhase ? -60 : 40, y: bgPhase ? 420 : 320)
                    .blur(radius: 35)
                    .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true).delay(0.8), value: bgPhase)
            }
            .ignoresSafeArea()

            // ── Контент ──
            VStack(spacing: 0) {
                if selectedTab == 0 {
                    topBar
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                ZStack {
                    switch selectedTab {
                    case 0: homeContent
                    case 1: JournalView().environmentObject(appState).environmentObject(lang)
                    case 2: HealthMetricsView()
                    case 3: MoodView()
                    default: homeContent
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Увеличенный отступ, чтобы контент не прятался за орбом при скролле
                Color.clear.frame(height: 140)
            }

            liquidBottomBar
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationBarHidden(true)
        .preferredColorScheme(isDarkMode ? .dark : .light) // Принудительно задаем системную тему
        .animation(.easeInOut(duration: 0.4), value: isDarkMode) // Плавный переход при смене темы
        .onAppear {
            pulse = true
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) { appear = true }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) { bgPhase = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { startOrbRings() }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true).delay(0.3)) { orbBob = true }
            health.requestAuthorization()
            
            // Мгновенная загрузка закэшированных данных пользователя при старте
            loadUserName()
            loadAvatar()
        }
        // Автообновление при логине/логауте
        .onChange(of: appState.userToken) { _ in
            loadUserName()
            loadAvatar()
        }
        .sheet(isPresented: $showAssistantSheet) {
            ChatView().environmentObject(appState).environmentObject(lang)
        }
        .sheet(isPresented: $showProfileSheet, onDismiss: {
            loadAvatar()
        }) {
            SettingsView().environmentObject(appState).environmentObject(lang)
        }
        .sheet(isPresented: $showSleepDetail) {
            SleepDetailView()
        }
        .sheet(isPresented: $showPulseDetail) {
            PulseDetailView()
        }
        .sheet(isPresented: $showStepsDetail) {
            StepsDetailView()
        }
        // 👇 Шторка детализации индекса
        .sheet(isPresented: $showIndexDetail) {
            HealthIndexDetailSheet(health: health)
                .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(greetingText())
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(primaryText)
                    .lineLimit(1).minimumScaleFactor(0.75)
                Text(localized("subtitle"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(secondaryText)
            }
            Spacer()
            Button { showProfileSheet.toggle() } label: {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [accent, accent2],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 46, height: 46)
                        .shadow(color: accent.opacity(isDarkMode ? 0.15 : 0.35), radius: 8, x: 0, y: 3)

                    if let img = avatarImage {
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(width: 46, height: 46)
                            .clipShape(Circle())
                    } else {
                        Text(initials(for: appState.userName))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }

    // MARK: - Home Content

    private var homeContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                healthIndexCard
                metricsRow
                cognitiveAnalysisCard
                quickActions
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 16)
        }
        // БУФЕРИЗАЦИЯ (PULL-TO-REFRESH)
        .refreshable {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            
            // Имитация загрузки и анализа данных ИИ (1.5 секунды)
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            
            await MainActor.run {
                loadUserName()
                loadAvatar()
                health.requestAuthorization() // Перезапрашиваем актуальные данные HealthKit
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
    }
    // Вытаскиваем сон строго за сегодняшний день
        private var todaySleepHours: Double {
            if let today = health.sleepWeek.first(where: { Calendar.current.isDateInToday($0.date) }) {
                return today.hours
            }
            return 0.0
        }
    // MARK: - Health Index Card

    private var healthIndex: Int {
        var score = 60
        let stepsGoal = UserDefaults.standard.integer(forKey: "stepsGoal").nonZero ?? 8000
        let stepsPct = min(Double(health.steps) / Double(stepsGoal), 1.0)
        score += Int(stepsPct * 20)
        if health.heartRate > 0 {
            score += (health.heartRate >= 60 && health.heartRate <= 80) ? 10 : 5
        } else {
            score += 7
        }
        let sleepGoal = UserDefaults.standard.double(forKey: "sleepGoal").nonZero ?? 8.0
        let sleepPct = todaySleepHours > 0 ? min(todaySleepHours / sleepGoal, 1.0) : 0.7
        score += Int(sleepPct * 10)
        return min(score, 100)
    }

    private var healthIndexLabel: String {
        switch healthIndex {
        case 90...100: return "Отличный показатель"
        case 75..<90:  return "Хорошее состояние"
        case 60..<75:  return "В пределах нормы"
        default:       return "Требует внимания"
        }
    }

    private var healthIndexIcon: String {
        switch healthIndex {
        case 90...100: return "waveform.path.ecg"
        case 75..<90:  return "checkmark.shield.fill"
        case 60..<75:  return "bolt.heart.fill"
        default:       return "exclamationmark.triangle.fill"
        }
    }

    // 👇 Обернули карточку в Button, чтобы сделать ее кликабельной
    private var healthIndexCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showIndexDetail = true
        } label: {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(LinearGradient(colors: [accent, accent2],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: accent.opacity(isDarkMode ? 0.15 : 0.38), radius: 20, x: 0, y: 10)
                
                // Премиальные блики внутри карточки
                Circle().fill(Color.white.opacity(0.08)).frame(width: 180, height: 180).offset(x: 50, y: -60)
                Circle().fill(Color.white.opacity(0.05)).frame(width: 100, height: 100).offset(x: -30, y: 70)

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("КОМПЛЕКСНЫЙ ИНДЕКС ЗДОРОВЬЯ")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                            .tracking(1.2)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(healthIndex)")
                                .font(.system(size: 64, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.5), value: healthIndex)
                            Text("/ 100")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.65))
                                .padding(.bottom, 8)
                        }
                        HStack(spacing: 8) {
                            Image(systemName: healthIndexIcon)
                                .font(.system(size: 12))
                            Text(healthIndexLabel)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                    }
                    Spacer()
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.15), lineWidth: 8).frame(width: 76, height: 76)
                        Circle().trim(from: 0, to: appear ? CGFloat(healthIndex) / 100.0 : 0)
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 76, height: 76).rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 1.4).delay(0.3), value: appear)
                            .animation(.spring(response: 0.8), value: healthIndex)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(pulse ? 1.08 : 0.95)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
                    }
                }.padding(24)
                
                // Стеклянный бордер
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .opacity(appear ? 1 : 0).offset(y: appear ? 0 : 18)
        .animation(.easeOut(duration: 0.5).delay(0.05), value: appear)
    }

    // MARK: - Metrics Row

    private var metricsRow: some View {
        HStack(spacing: 12) {
            let stepsGoal = UserDefaults.standard.integer(forKey: "stepsGoal").nonZero ?? 8000
            let sleepGoal = UserDefaults.standard.double(forKey: "sleepGoal").nonZero ?? 8.0

            metricCard(
                icon: "figure.walk",
                value: health.steps > 0 ? formatSteps(health.steps) : "—",
                unit: "Шагов",
                color: accent,
                progress: health.stepsProgress(goal: stepsGoal),
                onTap: { showStepsDetail = true }
            )

            metricCard(
                icon: "heart.fill",
                value: health.heartRate > 0 ? "\(health.heartRate)" : "—",
                unit: "Уд/мин",
                color: Color(red: 0.95, green: 0.25, blue: 0.35),
                progress: health.heartProgress(),
                onTap: { showPulseDetail = true }
            )

            metricCard(
                            icon: "moon.stars.fill",
                            value: todaySleepHours > 0 ? String(format: "%.1f", todaySleepHours) : "—",
                            unit: "Часов сна",
                            color: Color(red: 0.45, green: 0.35, blue: 0.90),
                            progress: todaySleepHours > 0 ? min(todaySleepHours / sleepGoal, 1.0) : 0.0,
                            onTap: { showSleepDetail = true }
                        )
        }
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 18)
        .animation(.easeOut(duration: 0.5).delay(0.10), value: appear)
    }

    private func formatSteps(_ s: Int) -> String {
        s >= 1000 ? String(format: "%.1f к", Double(s) / 1000) : "\(s)"
    }

    private func metricCard(
        icon: String,
        value: String,
        unit: String,
        color: Color,
        progress: Double,
        onTap: (() -> Void)?
    ) -> some View {
        let content = VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 5)
                    .frame(width: 48, height: 48)

                Circle()
                    .trim(from: 0, to: appear ? CGFloat(progress) : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.2).delay(0.4), value: appear)
                    .animation(.spring(response: 0.8), value: progress)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(color)
            }
            .shadow(color: color.opacity(isDarkMode ? 0.1 : 0.2), radius: 5, x: 0, y: 3)

            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(primaryText)
                    .contentTransition(.numericText())

                Text(unit.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(secondaryText)
                    .tracking(0.5)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(cardBg)
                .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.04), radius: 10, x: 0, y: 4)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(cardStroke, lineWidth: 1))
        )

        if let action = onTap {
            return AnyView(
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    action()
                }) { content }
                .buttonStyle(ScaleButtonStyle())
            )
        } else {
            return AnyView(content)
        }
    }

    // MARK: - Cognitive AI Card (Premium Insight)

    private var insightText: String {
        let stepsGoal = UserDefaults.standard.integer(forKey: "stepsGoal").nonZero ?? 8000
        if health.steps > 0 {
            let pct = Int(Double(health.steps) / Double(stepsGoal) * 100)
            if pct >= 100 { return "Отличная активность! Вы выполнили дневную норму шагов, так держать." }
            if pct >= 50  { return "Вы прошли больше половины пути. Небольшая прогулка поможет закрыть цель на сегодня." }
            return "Активность пока ниже обычного. Постарайтесь пройти еще \(stepsGoal - health.steps) шагов до конца дня."
        }
        if health.heartRate > 0 {
            let hr = health.heartRate
            if hr < 60 { return "Ваш пульс — \(hr) уд/мин. Зафиксировано хорошее состояние покоя и восстановления." }
            if hr <= 80 { return "Ваш пульс — \(hr) уд/мин. Сердечный ритм находится в пределах здоровой нормы." }
            return "Ваш пульс — \(hr) уд/мин. Показатели немного завышены, постарайтесь уделить время отдыху."
        }
        return "Включите синхронизацию с HealthKit для получения персональных рекомендаций о здоровье."
    }

    private var cognitiveAnalysisCard: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [accent, accent2],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 48, height: 48)
                    .shadow(color: accent.opacity(0.35), radius: 8, x: 0, y: 4)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("СВОДКА СОСТОЯНИЯ")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(accent)
                    .tracking(1.0)
                Text(insightText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(primaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(cardBg)
                .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.04), radius: 10, x: 0, y: 4)
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(cardStroke, lineWidth: 1))
        )
        .opacity(appear ? 1 : 0).offset(y: appear ? 0 : 18)
        .animation(.easeOut(duration: 0.5).delay(0.20), value: appear)
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(spacing: 12) {
            Button {
                showAssistantSheet = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [accent.opacity(0.15), accent2.opacity(0.1)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 50, height: 50)
                        Image(systemName: "stethoscope")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(accent)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI-Диагностика")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(primaryText)
                        Text("Спросите о симптомах")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(secondaryText.opacity(0.5))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(cardBg)
                        .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.04), radius: 10, x: 0, y: 4)
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(cardStroke, lineWidth: 1))
                )
            }
            .buttonStyle(ScaleButtonStyle())

            HStack(spacing: 12) {
                Button { withAnimation(.spring(response: 0.3)) { selectedTab = 2 } } label: {
                    actionMini(icon: "chart.bar.xaxis", color: accent, title: "Показатели", sub: "Вся статистика")
                }.buttonStyle(ScaleButtonStyle())
                
                Button { withAnimation(.spring(response: 0.3)) { selectedTab = 1 } } label: {
                    actionMini(icon: "book.pages.fill", color: Color(red:0.55,green:0.35,blue:1.0), title: "Дневник", sub: "Ваши записи")
                }.buttonStyle(ScaleButtonStyle())
            }
        }
        .opacity(appear ? 1 : 0).offset(y: appear ? 0 : 18)
        .animation(.easeOut(duration: 0.5).delay(0.25), value: appear)
    }

    private func actionMini(icon: String, color: Color, title: String, sub: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.12)).frame(width: 42, height: 42)
                Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(primaryText).lineLimit(1)
                Text(sub).font(.system(size: 11, weight: .medium))
                    .foregroundColor(secondaryText)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(cardBg)
                .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.04), radius: 10, x: 0, y: 4)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(cardStroke, lineWidth: 1))
        )
    }

    // MARK: - PERFECT LIQUID BOTTOM BAR

    private var liquidBottomBar: some View {
        GeometryReader { geo in
            let safeBottom = safeAreaBottomInset()
            let bottomInset = safeBottom > 0 ? safeBottom : 8
            let totalWidth = geo.size.width
            let outerMargin: CGFloat = 16
            let barWidth = totalWidth - (outerMargin * 2)
            let panelHeight: CGFloat = 90
            
            // Фиксированная математика для идеального центрирования
            let innerPadding: CGFloat = 16
            let orbGap: CGFloat = 92
            let slotWidth = (barWidth - (innerPadding * 2) - orbGap) / 4
            
            // Заранее считаем центры без использования функции
            let start = innerPadding + (slotWidth / 2)
            let centers: [Int: CGFloat] = [
                0: start,
                1: start + slotWidth,
                2: start + slotWidth * 2 + orbGap,
                3: start + slotWidth * 3 + orbGap
            ]

            let activeX = centers[selectedTab] ?? start
            let currentDragX = liquidDragX ?? activeX
            
            // Эффект "растягивания" при перетаскивании
            let distanceToActive = abs(currentDragX - activeX)
            let stretchAmount = isLiquidDragging ? min(distanceToActive * 0.25, 25) : 0
            let finalLensWidth = slotWidth + 14 + stretchAmount

            ZStack(alignment: .top) {
                // Стекло и иконки
                ZStack(alignment: .topLeading) {
                    
                    // 1. КРИСТАЛЬНО ЧИСТОЕ СТЕКЛО БАРА
                    ZStack {
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .fill(liquidBarBg)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 36, style: .continuous))
                        
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    stops: [
                                        .init(color: .white.opacity(0.8), location: 0),
                                        .init(color: .white.opacity(0.05), location: 0.3),
                                        .init(color: .white.opacity(0.05), location: 0.7),
                                        .init(color: .white.opacity(0.3), location: 1)
                                    ],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    }
                    .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.08), radius: 24, x: 0, y: 10)
                    .frame(width: barWidth, height: panelHeight)

                    // 2. ЖИДКАЯ ЛИНЗА (Кристалл + Искажение)
                    ZStack {
                        // Само стекло линзы
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.15))
                            .background(.ultraThinMaterial, in: Capsule())
                            
                        // Эффект хроматической аберрации (дисперсия света по краям)
                        Capsule(style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.cyan.opacity(0.5), location: 0.0),
                                        .init(color: Color.clear, location: 0.2),
                                        .init(color: Color.clear, location: 0.8),
                                        .init(color: Color.purple.opacity(0.5), location: 1.0)
                                    ],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                            .blur(radius: 2)
                            .blendMode(.plusLighter)

                        // Яркие белые блики
                        Capsule(style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    stops: [
                                        .init(color: .white, location: 0),
                                        .init(color: .white.opacity(0.0), location: 0.25),
                                        .init(color: .white.opacity(0.0), location: 0.75),
                                        .init(color: .white.opacity(0.6), location: 1)
                                    ],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    }
                    .shadow(color: Color.black.opacity(isDarkMode ? 0.5 : 0.12), radius: 10, x: 0, y: 6)
                    .shadow(color: Color.white.opacity(isDarkMode ? 0.1 : 0.3), radius: 12, x: -2, y: -2) // Внешний светлый блик сверху
                    .frame(width: finalLensWidth, height: 56)
                    .position(x: currentDragX, y: panelHeight / 2 - 8)
                    .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.7, blendDuration: 0.1), value: currentDragX)
                    .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.7, blendDuration: 0.1), value: stretchAmount)

                    // 3. ИКОНКИ
                    liquidTabItem(icon: "house.fill", label: localized("home"), index: 0, centerX: centers[0] ?? 0, lensX: currentDragX, slotWidth: slotWidth)
                    liquidTabItem(icon: "book.fill", label: localized("journal"), index: 1, centerX: centers[1] ?? 0, lensX: currentDragX, slotWidth: slotWidth)
                    liquidTabItem(icon: "waveform.path.ecg", label: localized("metrics"), index: 2, centerX: centers[2] ?? 0, lensX: currentDragX, slotWidth: slotWidth)
                    liquidTabItem(icon: "face.smiling.fill", label: "Настроение", index: 3, centerX: centers[3] ?? 0, lensX: currentDragX, slotWidth: slotWidth)
                }
                .frame(width: barWidth, height: panelHeight)
                .contentShape(Rectangle()) // Ограничиваем зону нажатия ТОЛЬКО самим баром!
                .gesture(
                    DragGesture(minimumDistance: 8) // Добавили дистанцию в 8 поинтов для защиты от случайных касаний
                        .onChanged { value in
                            if !isLiquidDragging {
                                UISelectionFeedbackGenerator().selectionChanged()
                                isLiquidDragging = true
                            }
                            
                            // Координаты теперь считаются исключительно внутри самого бара
                            let localX = value.location.x
                            liquidDragX = min(max(localX, innerPadding), barWidth - innerPadding)

                            if let next = nearestTab(to: liquidDragX ?? localX, centers: centers), next != selectedTab {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    selectedTab = next
                                }
                                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                            }
                        }
                        .onEnded { _ in
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                                isLiquidDragging = false
                                liquidDragX = nil
                            }
                        }
                )
                .padding(.bottom, bottomInset) // Отступ безопасной зоны (для пипки) перенесли СНАРУЖИ жеста
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                // ОБНОВЛЕННЫЙ LIQUID GLASS ORB
                liveOrb
                    .offset(y: -18)
            }
            .frame(height: panelHeight + bottomInset + 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 126 + safeAreaBottomInset())
    }

    // MARK: - Live Orb (LIQUID GLASS)

    private var liveOrb: some View {
        ZStack {
            // Светлые/стеклянные кольца пульсации
            Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.5).frame(width: 110, height: 110)
                .scaleEffect(orbRing3 ? 1.0 : 0.55).opacity(orbRing3 ? 0.0 : 0.7)
                .animation(.easeOut(duration: 1.9).repeatForever(autoreverses: false).delay(0.6), value: orbRing3)
            Circle().stroke(Color.white.opacity(0.4), lineWidth: 2).frame(width: 90, height: 90)
                .scaleEffect(orbRing2 ? 1.0 : 0.55).opacity(orbRing2 ? 0.0 : 0.85)
                .animation(.easeOut(duration: 1.9).repeatForever(autoreverses: false).delay(0.3), value: orbRing2)
            Circle().stroke(Color.white.opacity(0.5), lineWidth: 2.5).frame(width: 74, height: 74)
                .scaleEffect(orbRing1 ? 1.0 : 0.55).opacity(orbRing1 ? 0.0 : 1.0)
                .animation(.easeOut(duration: 1.9).repeatForever(autoreverses: false), value: orbRing1)

            Button {
                if suppressOrbTapAfterDrag {
                    suppressOrbTapAfterDrag = false
                    return
                }

                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring()) { showAssistantSheet = true }
            } label: {
                ZStack {
                    // 1. Основное стекло орба
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .background(.ultraThinMaterial, in: Circle())
                    
                    // 2. Хроматическая аберрация внутри орба
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.cyan.opacity(0.6), location: 0.0),
                                    .init(color: Color.clear, location: 0.3),
                                    .init(color: Color.clear, location: 0.7),
                                    .init(color: Color.purple.opacity(0.6), location: 1.0)
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 4
                        )
                        .blur(radius: 3)
                        .blendMode(.plusLighter)

                    // 3. Резкий белый контур (объем стекла)
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.9), location: 0),
                                    .init(color: .white.opacity(0.1), location: 0.3),
                                    .init(color: .white.opacity(0.1), location: 0.7),
                                    .init(color: .white.opacity(0.4), location: 1)
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                    
                    // 4. Твоя Lottie-анимация
                    LottieView(animationName: "aiaia").frame(width: 92, height: 92).clipShape(Circle())
                }
                .frame(width: 92, height: 92)
                .shadow(color: Color.black.opacity(isDarkMode ? 0.4 : 0.15), radius: 15, x: 0, y: 8)
                .shadow(color: Color.white.opacity(isDarkMode ? 0.1 : 0.3), radius: 10, x: -2, y: -2)
                .scaleEffect(orbIsPressed ? 0.93 : (pulse ? 1.04 : 0.98))
                .offset(y: orbBob ? -4 : 3)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: orbBob)
            }
            .buttonStyle(PlainButtonStyle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        orbOffset = CGSize(width: v.translation.width * 0.22,
                                           height: v.translation.height * 0.22)
                        orbIsPressed = true
                    }
                    .onEnded { v in
                        let horizontal = v.translation.width

                        if abs(horizontal) > 36 {
                            switchOrbTab(horizontal: horizontal)
                            suppressOrbTapAfterDrag = true

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                                suppressOrbTapAfterDrag = false
                            }
                        } else {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }

                        withAnimation(.interpolatingSpring(stiffness: 180, damping: 18)) {
                            orbOffset = .zero
                            orbIsPressed = false
                        }
                    }
            )
        }
        .offset(x: orbOffset.width, y: orbOffset.height)
    }

    private func startOrbRings() {
        orbRing1 = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { orbRing2 = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { orbRing3 = true }
    }

    private func nearestTab(to x: CGFloat, centers: [Int: CGFloat]) -> Int? {
        centers.min(by: { abs($0.value - x) < abs($1.value - x) })?.key
    }

    // Иконки с динамической реакцией на лупу
    private func liquidTabItem(
        icon: String,
        label: String,
        index: Int,
        centerX: CGFloat,
        lensX: CGFloat,
        slotWidth: CGFloat
    ) -> some View {
        let distance = abs(centerX - lensX)
        // Магнетизм: чем ближе лупа, тем больше иконка
        let liquidBoost = max(0, 1 - (distance / 60))
        let isSelected = selectedTab == index

        let iconScale = 1.0 + liquidBoost * 0.18
        let yLift = liquidBoost * 10
        
        let iconOpacity = isSelected ? 1.0 : 0.4 + liquidBoost * 0.4
        let labelOpacity = isSelected ? 0.9 : 0.3 + liquidBoost * 0.5

        return VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: isSelected ? .bold : .medium))
                .foregroundColor(iconTint.opacity(iconOpacity))
                .scaleEffect(iconScale)
                .offset(y: -yLift)

            Text(label)
                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                .foregroundColor(iconTint.opacity(labelOpacity))
                .scaleEffect(1 + liquidBoost * 0.05)
                .offset(y: -yLift * 0.4)
        }
        .frame(width: slotWidth, height: 90)
        .position(x: centerX, y: 90 / 2) // Центровка ровно по математике
        // Нажатие на иконку
        .onTapGesture {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                selectedTab = index
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func switchOrbTab(horizontal: CGFloat) {
        let orbTabs = [0, 1, 2]

        let currentIndex: Int
        if let index = orbTabs.firstIndex(of: selectedTab) {
            currentIndex = index
        } else {
            currentIndex = horizontal > 0 ? 0 : orbTabs.count - 1
        }

        let nextIndex: Int
        if horizontal > 0 {
            nextIndex = min(currentIndex + 1, orbTabs.count - 1)
        } else {
            nextIndex = max(currentIndex - 1, 0)
        }

        guard orbTabs[nextIndex] != selectedTab else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            selectedTab = orbTabs[nextIndex]
        }
    }

    private func safeAreaBottomInset() -> CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let window = scenes.first?.windows.first(where: \.isKeyWindow) {
            return window.safeAreaInsets.bottom
        }
        return 0
    }

    // MARK: - Avatar

    private func loadAvatar() {
        let key = "userAvatar_\(appState.userToken ?? "guest")"
        if let data = UserDefaults.standard.data(forKey: key),
           let img = UIImage(data: data) {
            avatarImage = img
        } else {
            avatarImage = nil
        }
    }
    
    // MARK: - User Name Cache

    private func loadUserName() {
        let nameKey = "userName_\(appState.userToken ?? "guest")"
        if let savedName = UserDefaults.standard.string(forKey: nameKey), !savedName.isEmpty {
            appState.userName = savedName
        } else {
            appState.userName = ""
        }
    }

    // MARK: - Helpers

    private func greetingText() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let g: String
        switch hour {
        case 5..<12:  g = localized("good_morning")
        case 12..<17: g = localized("good_afternoon")
        case 17..<22: g = localized("good_evening")
        default:      g = localized("good_night")
        }
        if let name = appState.userName, !name.isEmpty { return "\(g), \(name) 👋" }
        return "\(g)! 👋"
    }

    private func initials(for name: String?) -> String {
        let s = (name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? name! : "U"
        return s.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    private func localized(_ key: String) -> String {
        let l = lang.currentLanguage
        switch key {
        case "good_morning":   return ["kk":"Қайырлы таң","ru":"Доброе утро","en":"Good morning"][l.rawValue]!
        case "good_afternoon": return ["kk":"Қайырлы күн","ru":"Добрый день","en":"Good afternoon"][l.rawValue]!
        case "good_evening":   return ["kk":"Қайырлы кеш","ru":"Добрый вечер","en":"Good evening"][l.rawValue]!
        case "good_night":     return ["kk":"Қайырлы түн","ru":"Доброй ночи","en":"Good night"][l.rawValue]!
        case "subtitle":
            switch l { case .kk: return "AI серіктесіңіз дайын 🩺"
                       case .ru: return "Ваш AI-помощник готов 🩺"
                       default:  return "Your AI assistant is ready 🩺" }
        case "home":    return ["kk":"Басты","ru":"Главная","en":"Home"][l.rawValue]!
        case "journal": return ["kk":"Журнал","ru":"Журнал","en":"Journal"][l.rawValue]!
        case "metrics": return ["kk":"Метрики","ru":"Метрики","en":"Metrics"][l.rawValue]!
        case "profile": return ["kk":"Профиль","ru":"Профиль","en":"Profile"][l.rawValue]!
        case "ai_recommendations":
            switch l { case .kk: return "AI кеңестері"
                       case .ru: return "AI ассистент"
                       default:  return "AI Assistant" }
        case "ai_text":
            switch l { case .kk: return "Сұрақтарыңызды қойыңыз"
                       case .ru: return "Задайте любой вопрос"
                       default:  return "Ask anything" }
        case "health_metrics": return ["kk":"Метрики","ru":"Показатели","en":"Metrics"][l.rawValue]!
        default: return key
        }
    }
}

// MARK: - Extensions

extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}

extension Double {
    var nonZero: Double? { self == 0.0 ? nil : self }
}

// MARK: - ScaleButtonStyle

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - НОВЫЙ ЭКРАН: Детализация Индекса Здоровья

struct HealthIndexDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkModeEnabled") private var isDarkMode = false
    @ObservedObject var health: HealthKitManager

    private let accent  = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)
    
    private var baseBg: Color { isDarkMode ? Color(red: 0.04, green: 0.06, blue: 0.10) : Color(red: 0.94, green: 0.97, blue: 1.0) }
    private var cardBg: Color { isDarkMode ? Color.white.opacity(0.05) : Color.white.opacity(0.8) }
    private var primaryText: Color { isDarkMode ? .white : Color(red: 0.06, green: 0.09, blue: 0.16) }
    private var secondaryText: Color { isDarkMode ? .white.opacity(0.6) : Color(red: 0.5, green: 0.63, blue: 0.72) }
    private var todaySleepHours: Double {
            if let today = health.sleepWeek.first(where: { Calendar.current.isDateInToday($0.date) }) {
                return today.hours
            }
            return 0.0
        }
    // Расчеты баллов (вынесены отдельно для визуализации)
    private var stepsPoints: Int {
        let goal = UserDefaults.standard.integer(forKey: "stepsGoal").nonZero ?? 8000
        let pct = min(Double(health.steps) / Double(goal), 1.0)
        return Int(pct * 20)
    }
    
    private var hrPoints: Int {
        if health.heartRate > 0 {
            return (health.heartRate >= 60 && health.heartRate <= 80) ? 10 : 5
        }
        return 7 // Значение по умолчанию, если нет данных
    }
    
    private var sleepPoints: Int {
            let goal = UserDefaults.standard.double(forKey: "sleepGoal").nonZero ?? 8.0
            let pct = todaySleepHours > 0 ? min(todaySleepHours / goal, 1.0) : 0.7
            return Int(pct * 10)
        }
    
    private var totalScore: Int {
        min(60 + stepsPoints + hrPoints + sleepPoints, 100)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                baseBg.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // Заголовок с большим числом
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(isDarkMode ? 0.05 : 0.4), lineWidth: 12)
                                    .frame(width: 140, height: 140)
                                Circle()
                                    .trim(from: 0, to: CGFloat(totalScore) / 100.0)
                                    .stroke(
                                        LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing),
                                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                                    )
                                    .frame(width: 140, height: 140)
                                    .rotationEffect(.degrees(-90))
                                
                                VStack(spacing: 0) {
                                    Text("\(totalScore)")
                                        .font(.system(size: 48, weight: .black, design: .rounded))
                                        .foregroundColor(primaryText)
                                    Text("из 100")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(secondaryText)
                                }
                            }
                            .padding(.vertical, 16)
                            
                            Text("Ваш индекс формируется на основе базовых параметров и данных вашей активности за сегодня.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(secondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        
                        // Детализация баллов
                        VStack(spacing: 12) {
                            metricBreakdownRow(
                                icon: "person.fill", color: accent,
                                title: "Базовый уровень", points: 60, max: 60,
                                desc: "Стартовые баллы профиля"
                            )
                            metricBreakdownRow(
                                icon: "figure.walk", color: Color(red: 0.1, green: 0.78, blue: 0.48),
                                title: "Активность", points: stepsPoints, max: 20,
                                desc: "На основе дневной цели по шагам"
                            )
                            metricBreakdownRow(
                                icon: "heart.fill", color: Color(red: 0.95, green: 0.25, blue: 0.35),
                                title: "Пульс", points: hrPoints, max: 10,
                                desc: health.heartRate > 0 ? "Средний пульс в пределах нормы" : "Нет актуальных данных"
                            )
                            metricBreakdownRow(
                                icon: "moon.stars.fill", color: Color(red: 0.55, green: 0.35, blue: 1.0),
                                title: "Сон", points: sleepPoints, max: 10,
                                desc: "На основе времени отдыха"
                            )
                        }
                        
                        // Блок AI-совета
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(accent)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Как улучшить индекс?")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(primaryText)
                                Text("Чтобы достичь максимума, старайтесь ежедневно закрывать кольца активности и спать не менее 8 часов.")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(secondaryText)
                                    .lineSpacing(3)
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(accent.opacity(isDarkMode ? 0.1 : 0.05))
                                .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(accent.opacity(isDarkMode ? 0.2 : 0.1), lineWidth: 1))
                        )
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Детализация индекса")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(accent)
                }
            }
        }
    }
    
    private func metricBreakdownRow(icon: String, color: Color, title: String, points: Int, max: Int, desc: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                    Spacer()
                    Text("+\(points)")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(color)
                }
                
                // Мини-прогресс бар
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.06))
                            .frame(height: 6)
                        Capsule()
                            .fill(color)
                            .frame(width: max > 0 ? CGFloat(points) / CGFloat(max) * geo.size.width : 0, height: 6)
                    }
                }
                .frame(height: 6)
                .padding(.vertical, 2)
                
                Text(desc)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(secondaryText)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardBg)
                .background(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(isDarkMode ? Color.white.opacity(0.1) : .clear, lineWidth: 1))
        )
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
        .environmentObject(LanguageManager())
}
