//
//  ProfileOnboardingView.swift
//  Bagyt
//
//  Premium medical profile onboarding
//  User profile · Goals · Personalized health baseline
//

import SwiftUI
import UIKit

// MARK: - Steps

private enum OnboardStep: Int, CaseIterable {
    case welcome = 0
    case gender
    case age
    case body
    case goal
    case dailyGoals
    case ready
}

// MARK: - Models

enum UserGender: String, CaseIterable {
    case male = "male"
    case female = "female"
    case other = "other"

    var label: String {
        switch self {
        case .male: return BagytL10n.tr("Мужской")
        case .female: return BagytL10n.tr("Женский")
        case .other: return BagytL10n.tr("Другой")
        }
    }

    var emoji: String {
        switch self {
        case .male: return "♂️"
        case .female: return "♀️"
        case .other: return "⚧️"
        }
    }

    var icon: String {
        switch self {
        case .male: return "figure.stand"
        case .female: return "figure.dress.line.vertical.figure"
        case .other: return "sparkles"
        }
    }

    var color: Color {
        switch self {
        case .male: return Color(red: 0.20, green: 0.55, blue: 0.95)
        case .female: return Color(red: 0.95, green: 0.35, blue: 0.65)
        case .other: return Color(red: 0.55, green: 0.35, blue: 0.95)
        }
    }
}

enum UserGoal: String, CaseIterable {
    case general = "general"
    case prevention = "prevention"
    case stressRelief = "stress_relief"
    case weightControl = "weight_control"
    case chronicDisease = "chronic_disease"

    var label: String {
        switch self {
        case .general: return BagytL10n.tr("Общее самочувствие")
        case .prevention: return BagytL10n.tr("Профилактика")
        case .stressRelief: return BagytL10n.tr("Снижение стресса")
        case .weightControl: return BagytL10n.tr("Контроль веса")
        case .chronicDisease: return BagytL10n.tr("Хронические болезни")
        }
    }

    var emoji: String {
        switch self {
        case .general: return "❤️"
        case .prevention: return "🛡️"
        case .stressRelief: return "🧠"
        case .weightControl: return "⚖️"
        case .chronicDisease: return "🏥"
        }
    }

    var icon: String {
        switch self {
        case .general: return "heart.text.square.fill"
        case .prevention: return "shield.fill"
        case .stressRelief: return "brain.head.profile"
        case .weightControl: return "scalemass.fill"
        case .chronicDisease: return "cross.case.fill"
        }
    }

    var desc: String {
        switch self {
        case .general: return BagytL10n.tr("Следить за состоянием, сном, активностью и настроением")
        case .prevention: return BagytL10n.tr("Замечать изменения раньше и поддерживать здоровые привычки")
        case .stressRelief: return BagytL10n.tr("Отслеживать стресс, энергию, сон и когнитивное состояние")
        case .weightControl: return BagytL10n.tr("Контролировать вес, активность, воду и дневные цели")
        case .chronicDisease: return BagytL10n.tr("Вести симптомы, визиты, заметки и контекст для врача")
        }
    }

    var color: Color {
        switch self {
        case .general: return Color(red: 0.055, green: 0.647, blue: 0.914)
        case .prevention: return Color(red: 0.10, green: 0.78, blue: 0.48)
        case .stressRelief: return Color(red: 0.55, green: 0.35, blue: 1.00)
        case .weightControl: return Color(red: 1.00, green: 0.65, blue: 0.10)
        case .chronicDisease: return Color(red: 1.00, green: 0.35, blue: 0.35)
        }
    }
}

// MARK: - ProfileOnboardingView

struct ProfileOnboardingView: View {
    @EnvironmentObject var appState: AppState

    let userName: String
    let onComplete: () -> Void

    @State private var step: OnboardStep = .welcome
    @State private var gender: UserGender = .male
    @State private var age: Int = 25
    @State private var weight: Double = 70
    @State private var height: Double = 170
    @State private var goal: UserGoal = .general
    @State private var stepsGoal: Int = 8000
    @State private var waterGoal: Double = 2.0
    @State private var sleepGoal: Double = 8.0
    @State private var caloriesGoal: Int = 2000

    @State private var appear = false
    @State private var cardAppear = false
    @State private var slideDir: AnyTransition = .identity

    private let accent = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)

    private let primaryText = Color(red: 0.06, green: 0.09, blue: 0.16)
    private let secondaryText = Color(red: 0.40, green: 0.55, blue: 0.65)
    private let mutedText = Color(red: 0.58, green: 0.70, blue: 0.78)
    private let cardFill = Color.white.opacity(0.82)
    private let softFill = Color.white.opacity(0.54)

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                if step != .welcome && step != .ready {
                    progressHeader
                        .padding(.horizontal, 24)
                        .padding(.top, 54)
                        .padding(.bottom, 8)
                }

                ZStack {
                    switch step {
                    case .welcome:
                        welcomeStep
                    case .gender:
                        genderStep
                    case .age:
                        ageStep
                    case .body:
                        bodyStep
                    case .goal:
                        goalStep
                    case .dailyGoals:
                        dailyGoalsStep
                    case .ready:
                        readyStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(slideDir)
                .animation(.spring(response: 0.48, dampingFraction: 0.82), value: step)

                if step != .welcome && step != .ready {
                    navButtons
                        .padding(.horizontal, 24)
                        .padding(.bottom, 38)
                }
            }
        }
        .onAppear {
            loadExistingProfile()
            withAnimation(.easeOut(duration: 0.45)) {
                appear = true
            }
            withAnimation(.easeOut(duration: 0.45).delay(0.12)) {
                cardAppear = true
            }
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            AnimatedGradientBackground()
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.white.opacity(0.38),
                    Color.white.opacity(0.10),
                    Color.white.opacity(0.26)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                LinearGradient(
                    colors: [
                        accent.opacity(0.20),
                        accent2.opacity(0.12),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 250)
                .ignoresSafeArea(edges: .top)

                Spacer()
            }
        }
    }

    // MARK: - Progress

    private var progressHeader: some View {
        VStack(spacing: 14) {
            HStack {
                Button {
                    prev()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(accent)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.76), in: Circle())
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.88), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(currentStepIndex)/\(totalInputSteps)")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(secondaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.70), in: Capsule())

                Spacer()

                Color.clear
                    .frame(width: 40, height: 40)
            }

            HStack(spacing: 7) {
                ForEach(1...totalInputSteps, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentStepIndex ? accent : Color.white.opacity(0.52))
                        .frame(height: 5)
                        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: step)
                }
            }
        }
    }

    private var currentStepIndex: Int {
        switch step {
        case .gender: return 1
        case .age: return 2
        case .body: return 3
        case .goal: return 4
        case .dailyGoals: return 5
        default: return 0
        }
    }

    private var totalInputSteps: Int { 5 }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 30)

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [accent, accent2],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 118, height: 118)
                        .shadow(color: accent.opacity(0.35), radius: 28, x: 0, y: 14)

                    Circle()
                        .strokeBorder(Color.white.opacity(0.34), lineWidth: 1.5)
                        .frame(width: 118, height: 118)

                    LottieView(animationName: "aiaia")
                        .frame(width: 112, height: 112)
                        .clipShape(Circle())
                }
                .scaleEffect(appear ? 1 : 0.78)
                .opacity(appear ? 1 : 0)

                VStack(spacing: 12) {
                    Text(String(format: BagytL10n.tr("Привет, %@"), firstName(userName)))
                        .font(.system(size: 31, weight: .black, design: .rounded))
                        .foregroundColor(primaryText)
                        .multilineTextAlignment(.center)

                    Text("Соберём базовый медицинский профиль, чтобы Bagyt точнее считал цели, индекс здоровья и рекомендации.")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    premiumFeatureRow(
                        icon: "heart.text.square.fill",
                        color: Color(red: 1.00, green: 0.35, blue: 0.35),
                        title: "Персональный индекс",
                        subtitle: "Цели, сон, активность и состояние в одной системе"
                    )

                    premiumFeatureRow(
                        icon: "brain.head.profile",
                        color: accent,
                        title: "Когнитивный контекст",
                        subtitle: "Настроение, стресс и энергия для умного анализа"
                    )

                    premiumFeatureRow(
                        icon: "shield.checkered",
                        color: Color(red: 0.10, green: 0.78, blue: 0.48),
                        title: "Медицинская структура",
                        subtitle: "Профиль будет доступен в настройках и целях"
                    )
                }
                .padding(.horizontal, 24)
                .opacity(cardAppear ? 1 : 0)
                .offset(y: cardAppear ? 0 : 12)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    go(to: .gender, direction: .forward)
                } label: {
                    primaryButtonLabel("Начать персонализацию", icon: "arrow.right")
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    saveAndComplete()
                } label: {
                    Text("Пропустить")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(secondaryText)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 42)
        }
    }

    private func premiumFeatureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .black))
                .foregroundColor(color)
                .frame(width: 46, height: 46)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(BagytL10n.tr(title))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(primaryText)

                Text(BagytL10n.tr(subtitle))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(cardBackground(cornerRadius: 19))
    }

    // MARK: - Gender

    private var genderStep: some View {
        VStack(spacing: 0) {
            stepHeader(
                eyebrow: "Профиль",
                title: "Укажите пол",
                subtitle: "Это помогает точнее рассчитывать нормы активности, сна и базовые показатели."
            )
            .padding(.top, 18)

            Spacer()

            HStack(spacing: 14) {
                ForEach(UserGender.allCases, id: \.self) { item in
                    genderCard(item)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func genderCard(_ item: UserGender) -> some View {
        let selected = gender == item

        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                gender = item
            }
        } label: {
            VStack(spacing: 13) {
                ZStack {
                    Circle()
                        .fill(selected ? item.color.opacity(0.16) : softFill)
                        .frame(width: 72, height: 72)
                        .overlay(
                            Circle()
                                .strokeBorder(selected ? item.color.opacity(0.85) : Color.white.opacity(0.80), lineWidth: 1.6)
                        )

                    Image(systemName: item.icon)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(selected ? item.color : secondaryText)
                }

                Text(item.label)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(selected ? item.color : secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(cardBackground(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(selected ? item.color.opacity(0.35) : Color.clear, lineWidth: 1.5)
            )
            .scaleEffect(selected ? 1.035 : 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Age

    private var ageStep: some View {
        VStack(spacing: 0) {
            stepHeader(
                eyebrow: "Базовые данные",
                title: "Ваш возраст",
                subtitle: "Возраст влияет на нормы сна, активности, пульса и восстановления."
            )
            .padding(.top, 18)

            Spacer()

            VStack(spacing: 22) {
                VStack(spacing: 0) {
                    Text("\(age)")
                        .font(.system(size: 96, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [accent, accent2],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: age)

                    Text(ageWord(age))
                        .font(.system(size: 21, weight: .black, design: .rounded))
                        .foregroundColor(secondaryText)
                }

                VStack(spacing: 16) {
                    Slider(
                        value: Binding(
                            get: { Double(age) },
                            set: { age = Int($0.rounded()) }
                        ),
                        in: 10...100,
                        step: 1
                    )
                    .tint(accent)

                    HStack {
                        Text("10 \(ageWord(10))")
                        Spacer()
                        Text("100 \(ageWord(100))")
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(mutedText)
                }
                .padding(18)
                .background(cardBackground(cornerRadius: 22))

                HStack(spacing: 9) {
                    ForEach([18, 24, 30, 38, 55], id: \.self) { value in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                                age = value
                            }
                        } label: {
                            Text("\(value)")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundColor(age == value ? .white : accent)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 9)
                                .background(age == value ? accent : accent.opacity(0.11), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Body

    private var bodyStep: some View {
        VStack(spacing: 0) {
            stepHeader(
                eyebrow: "Физиология",
                title: "Рост и вес",
                subtitle: "Эти данные нужны для расчёта ИМТ, калорийности и персональных ориентиров."
            )
            .padding(.top, 18)

            Spacer()

            VStack(spacing: 16) {
                bodyMetricCard(
                    icon: "scalemass.fill",
                    title: "Вес",
                    value: $weight,
                    range: 30...200,
                    unit: "кг",
                    color: accent
                )

                bodyMetricCard(
                    icon: "arrow.up.and.down",
                    title: "Рост",
                    value: $height,
                    range: 100...230,
                    unit: "см",
                    color: accent2
                )

                bmiCard
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func bodyMetricCard(
        icon: String,
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        unit: String,
        color: Color
    ) -> some View {
        VStack(spacing: 13) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.12), in: Circle())

                Text(BagytL10n.tr(title))
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(primaryText)

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(String(format: "%.0f", value.wrappedValue))
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(color)
                        .contentTransition(.numericText())
                    Text(BagytL10n.tr(unit))
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(color.opacity(0.72))
                }
            }

            Slider(value: value, in: range, step: 1)
                .tint(color)
        }
        .padding(17)
        .background(cardBackground(cornerRadius: 22))
    }

    private var bmiCard: some View {
        let bmi = weight / ((height / 100) * (height / 100))
        let color = bmiColor(bmi)

        return HStack(spacing: 14) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 18, weight: .black))
                .foregroundColor(color)
                .frame(width: 42, height: 42)
                .background(color.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Индекс массы тела")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(secondaryText)

                Text(String(format: "%.1f", bmi))
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(color)
            }

            Spacer()

            Text(bmiLabel(bmi))
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(color)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(color.opacity(0.12), in: Capsule())
        }
        .padding(16)
        .background(cardBackground(cornerRadius: 22))
    }

    // MARK: - Goal

    private var goalStep: some View {
        VStack(spacing: 0) {
            stepHeader(
                eyebrow: "Персонализация",
                title: "Главная цель",
                subtitle: "Bagyt будет подстраивать подсказки, индекс и акценты под ваш фокус."
            )
            .padding(.top, 18)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 11) {
                    ForEach(UserGoal.allCases, id: \.self) { item in
                        goalCard(item)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
        }
    }

    private func goalCard(_ item: UserGoal) -> some View {
        let selected = goal == item

        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.80)) {
                goal = item
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(selected ? .white : item.color)
                    .frame(width: 50, height: 50)
                    .background(selected ? item.color : item.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.label)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(primaryText)

                    Text(item.desc)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(secondaryText)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                ZStack {
                    Circle()
                        .strokeBorder(selected ? item.color : Color(red: 0.76, green: 0.86, blue: 0.92), lineWidth: 2)
                        .frame(width: 23, height: 23)
                    if selected {
                        Circle()
                            .fill(item.color)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(15)
            .background(cardBackground(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(selected ? item.color.opacity(0.34) : Color.clear, lineWidth: 1.4)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Daily Goals

    private var dailyGoalsStep: some View {
        VStack(spacing: 0) {
            stepHeader(
                eyebrow: "Дневные ориентиры",
                title: "Ваши цели",
                subtitle: "Их можно изменить позже в настройках профиля."
            )
            .padding(.top, 18)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 13) {
                    goalSliderCard(
                        icon: "figure.walk",
                        color: accent,
                        title: "Шаги в день",
                        subtitle: "Активность и общий тонус",
                        value: Binding(get: { Double(stepsGoal) }, set: { stepsGoal = Int($0.rounded()) }),
                        range: 1000...20000,
                        step: 500,
                        display: "\(stepsGoal.formattedWithSpaces) \(BagytL10n.tr("шагов"))"
                    )

                    goalSliderCard(
                        icon: "drop.fill",
                        color: Color(red: 0.18, green: 0.55, blue: 1.0),
                        title: "Вода",
                        subtitle: "Гидратация и самочувствие",
                        value: $waterGoal,
                        range: 0.5...5.0,
                        step: 0.1,
                        display: String(format: "%.1f %@", waterGoal, BagytL10n.tr("л"))
                    )

                    goalSliderCard(
                        icon: "moon.stars.fill",
                        color: Color(red: 0.55, green: 0.35, blue: 1.0),
                        title: "Сон",
                        subtitle: "Восстановление и энергия",
                        value: $sleepGoal,
                        range: 4.0...12.0,
                        step: 0.5,
                        display: String(format: "%.1f %@", sleepGoal, BagytL10n.tr("ч"))
                    )

                    goalSliderCard(
                        icon: "flame.fill",
                        color: Color(red: 1.0, green: 0.58, blue: 0.12),
                        title: "Калории",
                        subtitle: "Ориентир питания",
                        value: Binding(get: { Double(caloriesGoal) }, set: { caloriesGoal = Int($0.rounded()) }),
                        range: 1000...4000,
                        step: 50,
                        display: "\(caloriesGoal.formattedWithSpaces) \(BagytL10n.tr("ккал"))"
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
        }
    }

    private func goalSliderCard(
        icon: String,
        color: Color,
        title: String,
        subtitle: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        display: String
    ) -> some View {
        VStack(spacing: 13) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(BagytL10n.tr(title))
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(primaryText)

                    Text(BagytL10n.tr(subtitle))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(secondaryText)
                }

                Spacer()

                Text(display)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(color)
                    .contentTransition(.numericText())
            }

            Slider(value: value, in: range, step: step)
                .tint(color)
        }
        .padding(16)
        .background(cardBackground(cornerRadius: 22))
    }

    // MARK: - Ready

    private var readyStep: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 22)

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.10, green: 0.78, blue: 0.48), Color(red: 0.055, green: 0.647, blue: 0.914)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 106, height: 106)
                        .shadow(color: Color(red: 0.10, green: 0.78, blue: 0.48).opacity(0.35), radius: 24, x: 0, y: 12)

                    Image(systemName: "checkmark")
                        .font(.system(size: 45, weight: .black))
                        .foregroundColor(.white)
                }

                VStack(spacing: 11) {
                    Text("Профиль готов")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundColor(primaryText)

                    Text("Bagyt персонализирован под ваши данные. Теперь можно перейти в приложение.")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 28)

                VStack(spacing: 10) {
                    summaryRow(icon: "person.fill", color: accent, label: "Возраст", value: "\(age) \(ageWord(age))")
                    summaryRow(icon: "scalemass.fill", color: accent2, label: "Вес / рост", value: "\(Int(weight.rounded())) \(BagytL10n.tr("кг")) / \(Int(height.rounded())) \(BagytL10n.tr("см"))")
                    summaryRow(icon: gender.icon, color: gender.color, label: "Пол", value: gender.label)
                    summaryRow(icon: goal.icon, color: goal.color, label: "Цель", value: goal.label)
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            Button {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                saveAndComplete()
            } label: {
                primaryButtonLabel("Перейти в приложение", icon: "arrow.right")
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 42)
        }
    }

    private func summaryRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .black))
                .foregroundColor(color)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(BagytL10n.tr(label))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(secondaryText)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(13)
        .background(cardBackground(cornerRadius: 17))
    }

    // MARK: - Shared UI

    private func stepHeader(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 9) {
            Text(BagytL10n.tr(eyebrow).uppercased())
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(accent)
                .tracking(1.1)

            Text(BagytL10n.tr(title))
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(primaryText)
                .multilineTextAlignment(.center)

            Text(BagytL10n.tr(subtitle))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
    }

    private func primaryButtonLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Text(BagytL10n.tr(title))
                .font(.system(size: 17, weight: .black, design: .rounded))
            Image(systemName: icon)
                .font(.system(size: 15, weight: .black))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(Capsule())
        .shadow(color: accent.opacity(0.34), radius: 15, x: 0, y: 8)
    }

    private func cardBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.82), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.045), radius: 9, x: 0, y: 5)
    }

    // MARK: - Navigation

    private var navButtons: some View {
        HStack(spacing: 12) {
            Button {
                prev()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(accent)
                    .frame(width: 54, height: 54)
                    .background(Color.white.opacity(0.78), in: Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.88), lineWidth: 1))
                    .shadow(color: accent.opacity(0.10), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            Button {
                next()
            } label: {
                primaryButtonLabel(step == .dailyGoals ? "Готово" : "Далее", icon: step == .dailyGoals ? "checkmark" : "arrow.right")
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private func next() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        if step == .dailyGoals {
            go(to: .ready, direction: .forward)
            return
        }

        let all = OnboardStep.allCases
        guard let current = all.firstIndex(of: step), current + 1 < all.count else { return }
        go(to: all[current + 1], direction: .forward)
    }

    private func prev() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        let all = OnboardStep.allCases
        guard let current = all.firstIndex(of: step), current > 0 else { return }
        go(to: all[current - 1], direction: .backward)
    }

    private enum Direction {
        case forward
        case backward
    }

    private func go(to nextStep: OnboardStep, direction: Direction) {
        slideDir = direction == .forward
            ? .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity))
            : .asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity))

        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            step = nextStep
        }

        if nextStep == .ready {
            appear = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.easeOut(duration: 0.35)) {
                    appear = true
                }
            }
        }
    }

    // MARK: - Persistence

    private func loadExistingProfile() {
        let defaults = UserDefaults.standard

        if defaults.integer(forKey: "userAge") > 0 {
            age = defaults.integer(forKey: "userAge")
        }
        if defaults.double(forKey: "userWeight") > 0 {
            weight = defaults.double(forKey: "userWeight")
        }
        if defaults.double(forKey: "userHeight") > 0 {
            height = defaults.double(forKey: "userHeight")
        }
        if let savedGender = defaults.string(forKey: "userGender"),
           let value = UserGender(rawValue: savedGender) {
            gender = value
        }
        if let savedGoal = defaults.string(forKey: "userGoal"),
           let value = UserGoal(rawValue: savedGoal) {
            goal = value
        }
        if defaults.integer(forKey: "stepsGoal") > 0 {
            stepsGoal = defaults.integer(forKey: "stepsGoal")
        }
        if defaults.double(forKey: "waterGoal") > 0 {
            waterGoal = defaults.double(forKey: "waterGoal")
        }
        if defaults.double(forKey: "sleepGoal") > 0 {
            sleepGoal = defaults.double(forKey: "sleepGoal")
        }
        if defaults.integer(forKey: "caloriesGoal") > 0 {
            caloriesGoal = defaults.integer(forKey: "caloriesGoal")
        }
    }

    private func saveAndComplete() {
        saveProfileValue(age, forKey: "userAge")
        saveProfileValue(gender.rawValue, forKey: "userGender")
        saveProfileValue(weight, forKey: "userWeight")
        saveProfileValue(height, forKey: "userHeight")
        saveProfileValue(goal.rawValue, forKey: "userGoal")
        saveProfileValue(stepsGoal, forKey: "stepsGoal")
        saveProfileValue(waterGoal, forKey: "waterGoal")
        saveProfileValue(sleepGoal, forKey: "sleepGoal")
        saveProfileValue(caloriesGoal, forKey: "caloriesGoal")

        let store = UserProfileStore.shared
        store.age = age
        store.gender = gender.rawValue
        store.weight = weight
        store.height = height
        store.goal = goal.rawValue
        store.stepsGoal = stepsGoal
        store.waterGoal = waterGoal
        store.sleepGoal = sleepGoal
        store.caloriesGoal = caloriesGoal

        onComplete()
    }

    private func saveProfileValue(_ value: Any, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)

        let userId = appState.userToken ?? "guest"
        UserDefaults.standard.set(value, forKey: "\(key)_\(userId)")
    }

    // MARK: - Helpers

    private func firstName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.components(separatedBy: " ").first?.isEmpty == false
            ? (trimmed.components(separatedBy: " ").first ?? trimmed)
            : BagytL10n.tr("Друг")
    }

    private func ageWord(_ value: Int) -> String {
        let mod10 = value % 10
        let mod100 = value % 100

        if mod100 >= 11 && mod100 <= 14 {
            return BagytL10n.tr("лет")
        }

        if mod10 == 1 {
            return BagytL10n.tr("год")
        }

        if mod10 >= 2 && mod10 <= 4 {
            return BagytL10n.tr("года")
        }

        return BagytL10n.tr("лет")
    }

    private func bmiColor(_ bmi: Double) -> Color {
        switch bmi {
        case ..<18.5:
            return Color(red: 0.30, green: 0.60, blue: 0.95)
        case 18.5..<25:
            return Color(red: 0.10, green: 0.78, blue: 0.48)
        case 25..<30:
            return Color(red: 1.00, green: 0.65, blue: 0.10)
        default:
            return Color(red: 0.95, green: 0.25, blue: 0.25)
        }
    }

    private func bmiLabel(_ bmi: Double) -> String {
        switch bmi {
        case ..<18.5:
            return BagytL10n.tr("Недовес")
        case 18.5..<25:
            return BagytL10n.tr("Норма")
        case 25..<30:
            return BagytL10n.tr("Избыток")
        default:
            return BagytL10n.tr("Высокий")
        }
    }
}

// MARK: - Helpers

private extension Int {
    var formattedWithSpaces: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.locale = BagytL10n.currentLocale
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

// MARK: - Preview

#Preview {
    ProfileOnboardingView(userName: "Жантемир") {}
        .environmentObject(AppState())
        .environmentObject(LanguageManager())
}
