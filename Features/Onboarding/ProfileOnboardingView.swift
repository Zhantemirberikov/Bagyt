//
//  ProfileOnboardingView.swift
//  Bagyt
//
//  Показывается один раз после регистрации.
//  Данные сохраняются в UserDefaults и могут быть
//  отредактированы позже в SettingsView.
//

import SwiftUI

// MARK: - Шаги онбординга

private enum OnboardStep: Int, CaseIterable {
    case welcome    = 0
    case gender     = 1
    case age        = 2
    case body       = 3
    case goal       = 4
    case dailyGoals = 5
    case ready      = 6
}

// MARK: - Модели

enum UserGender: String, CaseIterable {
    case male   = "male"
    case female = "female"
    case other  = "other"

    var label : String { ["male":"Мужской","female":"Женский","other":"Другой"][rawValue]! }
    var emoji : String { ["male":"♂️","female":"♀️","other":"⚧️"][rawValue]! }
    var color : Color  {
        switch self {
        case .male:   return Color(red:0.20,green:0.55,blue:0.95)
        case .female: return Color(red:0.95,green:0.35,blue:0.65)
        case .other:  return Color(red:0.55,green:0.35,blue:0.95)
        }
    }
}

enum UserGoal: String, CaseIterable {
    case loseWeight   = "lose_weight"
    case gainWeight   = "gain_weight"
    case keepFit      = "keep_fit"
    case stressRelief = "stress_relief"
    case general      = "general"

    var label: String {
        switch self {
        case .loseWeight:   return "Похудеть"
        case .gainWeight:   return "Набрать массу"
        case .keepFit:      return "Поддерживать форму"
        case .stressRelief: return "Снизить стресс"
        case .general:      return "Общее здоровье"
        }
    }
    var emoji: String {
        switch self {
        case .loseWeight:   return "🔥"
        case .gainWeight:   return "💪"
        case .keepFit:      return "⚡️"
        case .stressRelief: return "🧘"
        case .general:      return "❤️"
        }
    }
    var desc: String {
        switch self {
        case .loseWeight:   return "Снижение веса и жировой массы"
        case .gainWeight:   return "Набор мышечной массы"
        case .keepFit:      return "Сохранение текущей формы"
        case .stressRelief: return "Расслабление и восстановление"
        case .general:      return "Общее улучшение самочувствия"
        }
    }
}

// MARK: - ProfileOnboardingView

struct ProfileOnboardingView: View {
    @EnvironmentObject var appState: AppState

    let userName: String
    let onComplete: () -> Void

    @State private var step       : OnboardStep = .welcome
    @State private var gender     : UserGender  = .male
    @State private var age        : Int         = 25
    @State private var weight     : Double      = 70
    @State private var height     : Double      = 170
    @State private var goal       : UserGoal    = .general
    @State private var stepsGoal  : Int         = 8000
    @State private var waterGoal  : Double      = 2.0
    @State private var sleepGoal  : Double      = 8.0
    @State private var caloriesGoal: Int        = 2000
    @State private var appear     = false
    @State private var slideDir   : AnyTransition = .identity

    private let accent  = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)
    private let bg      = Color(red: 0.878, green: 0.949, blue: 0.992)

    var body: some View {
        ZStack {
            AnimatedGradientBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                // Прогресс-бар (кроме welcome и ready)
                if step != .welcome && step != .ready {
                    progressBar
                        .padding(.horizontal, 24)
                        .padding(.top, 56)
                        .padding(.bottom, 8)
                }

                // Контент шага
                ZStack {
                    switch step {
                    case .welcome    : welcomeStep
                    case .gender     : genderStep
                    case .age        : ageStep
                    case .body       : bodyStep
                    case .goal       : goalStep
                    case .dailyGoals : dailyGoalsStep
                    case .ready      : readyStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(slideDir)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: step)

                // Кнопки навигации
                if step != .welcome && step != .ready {
                    navButtons
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            // Загружаем существующие данные если редактируем
            let ud = UserDefaults.standard
            if ud.integer(forKey: "userAge") > 0      { age    = ud.integer(forKey: "userAge") }
            if ud.double(forKey: "userWeight")  > 0   { weight = ud.double(forKey: "userWeight") }
            if ud.double(forKey: "userHeight")  > 0   { height = ud.double(forKey: "userHeight") }
            if let g = ud.string(forKey: "userGender"), let gv = UserGender(rawValue: g) { gender = gv }
            if let gl = ud.string(forKey: "userGoal"), let gv = UserGoal(rawValue: gl)   { goal   = gv }
            if ud.integer(forKey: "stepsGoal")    > 0 { stepsGoal    = ud.integer(forKey: "stepsGoal") }
            if ud.double(forKey: "waterGoal")     > 0 { waterGoal    = ud.double(forKey: "waterGoal") }
            if ud.double(forKey: "sleepGoal")     > 0 { sleepGoal    = ud.double(forKey: "sleepGoal") }
            if ud.integer(forKey: "caloriesGoal") > 0 { caloriesGoal = ud.integer(forKey: "caloriesGoal") }
            withAnimation(.easeOut(duration: 0.6)) { appear = true }
        }
    }

    // MARK: - Прогресс-бар

    private var progressBar: some View {
        let steps = [OnboardStep.gender, .age, .body, .goal]
        let current = steps.firstIndex(of: step) ?? 0
        return HStack(spacing: 6) {
            ForEach(0..<steps.count, id: \.self) { i in
                Capsule()
                    .fill(i <= current ? accent : Color.white.opacity(0.45))
                    .frame(height: 4)
                    .animation(.spring(response: 0.4), value: step)
            }
        }
    }

    // MARK: - Навигация

    private var navButtons: some View {
        HStack(spacing: 12) {
            // Назад
            Button {
                prev()
            } label: {
                ZStack {
                    Circle().fill(Color.white.opacity(0.75)).frame(width: 52, height: 52)
                        .shadow(color: accent.opacity(0.12), radius: 8, x: 0, y: 3)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(accent)
                }
            }

            // Далее
            Button { next() } label: {
                HStack(spacing: 10) {
                    Text(step == .goal ? "Готово" : "Далее")
                        .font(.system(size: 17, weight: .bold))
                    Image(systemName: step == .goal ? "checkmark" : "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(Capsule())
                .shadow(color: accent.opacity(0.38), radius: 14, x: 0, y: 6)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    // MARK: - Шаг 0: Приветствие

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                // Большой орб
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(red:0.03,green:0.50,blue:0.78),
                                     Color(red:0.01,green:0.38,blue:0.65)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 110, height: 110)
                        .shadow(color: accent.opacity(0.45), radius: 30, x: 0, y: 12)
                    LottieView(animationName: "aiaia")
                        .frame(width: 110, height: 110)
                        .clipShape(Circle())
                }
                .scaleEffect(appear ? 1.0 : 0.5)
                .opacity(appear ? 1.0 : 0.0)
                .animation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.1), value: appear)

                VStack(spacing: 12) {
                    Text("Привет, \(firstName(userName))! 👋")
                        .font(.system(size: 30, weight: .black))
                        .foregroundColor(Color(red:0.06,green:0.09,blue:0.16))
                        .multilineTextAlignment(.center)

                    Text("Я помогу составить вашу\nличную программу здоровья.\nЭто займёт меньше минуты.")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Color(red:0.4,green:0.55,blue:0.65))
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                }
                .opacity(appear ? 1.0 : 0.0)
                .offset(y: appear ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.3), value: appear)

                // 3 фичи
                VStack(spacing: 12) {
                    featureRow(icon: "heart.text.square.fill", color: Color(red:0.95,green:0.25,blue:0.25),
                               text: "Персональный индекс здоровья")
                    featureRow(icon: "brain.head.profile", color: accent,
                               text: "AI-советы под ваши цели")
                    featureRow(icon: "chart.line.uptrend.xyaxis", color: Color(red:0.1,green:0.78,blue:0.48),
                               text: "Отслеживание прогресса")
                }
                .padding(.horizontal, 8)
                .opacity(appear ? 1.0 : 0.0)
                .offset(y: appear ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.5), value: appear)
            }
            .padding(.horizontal, 28)

            Spacer()

            // Кнопка начать
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    step = .gender
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                HStack(spacing: 10) {
                    Text("Начать персонализацию")
                        .font(.system(size: 17, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing))
                .clipShape(Capsule())
                .shadow(color: accent.opacity(0.40), radius: 16, x: 0, y: 7)
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 24)

            Button {
                saveAndComplete()
            } label: {
                Text("Пропустить")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(red:0.5,green:0.63,blue:0.72))
            }
            .padding(.top, 12)
            .padding(.bottom, 44)
        }
    }

    private func featureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
            }
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(red:0.2,green:0.3,blue:0.4))
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.80))
                .shadow(color: accent.opacity(0.08), radius: 8, x: 0, y: 3)
        )
    }

    // MARK: - Шаг 1: Пол

    private var genderStep: some View {
        VStack(spacing: 0) {
            stepHeader(
                title: "Ваш пол",
                subtitle: "Это поможет точнее рассчитать\nваши нормы здоровья"
            )
            .padding(.top, 20)

            Spacer()

            HStack(spacing: 16) {
                ForEach(UserGender.allCases, id: \.self) { g in
                    genderCard(g)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func genderCard(_ g: UserGender) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { gender = g }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(gender == g ? g.color.opacity(0.15) : Color.white.opacity(0.6))
                        .frame(width: 72, height: 72)
                        .overlay(
                            Circle().strokeBorder(
                                gender == g ? g.color : Color.clear, lineWidth: 2
                            )
                        )
                    Text(g.emoji)
                        .font(.system(size: 32))
                }
                Text(g.label)
                    .font(.system(size: 14, weight: gender == g ? .bold : .medium))
                    .foregroundColor(gender == g ? g.color : Color(red:0.4,green:0.55,blue:0.65))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(gender == g ? g.color.opacity(0.08) : Color.white.opacity(0.80))
                    .shadow(color: gender == g ? g.color.opacity(0.20) : Color.black.opacity(0.05),
                            radius: gender == g ? 12 : 6, x: 0, y: 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(gender == g ? g.color.opacity(0.30) : Color.white.opacity(0.8), lineWidth: 1.5)
                    )
            )
            .scaleEffect(gender == g ? 1.04 : 1.0)
            .animation(.spring(response: 0.3), value: gender)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Шаг 2: Возраст

    private var ageStep: some View {
        VStack(spacing: 0) {
            stepHeader(
                title: "Ваш возраст",
                subtitle: "Возраст влияет на нормы\nпульса, сна и активности"
            )
            .padding(.top, 20)

            Spacer()

            VStack(spacing: 32) {
                // Большая цифра
                Text("\(age)")
                    .font(.system(size: 96, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [accent, accent2],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: age)

                Text("лет")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(red:0.5,green:0.63,blue:0.72))
                    .offset(y: -24)

                // Слайдер
                VStack(spacing: 16) {
                    Slider(value: Binding(
                        get: { Double(age) },
                        set: { age = Int($0) }
                    ), in: 10...100, step: 1)
                    .tint(accent)
                    .padding(.horizontal, 8)

                    HStack {
                        Text("10").font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(red:0.6,green:0.72,blue:0.78))
                        Spacer()
                        Text("100").font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(red:0.6,green:0.72,blue:0.78))
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, -12)

                // Быстрые кнопки возраста
                HStack(spacing: 10) {
                    ForEach([18, 25, 30, 40, 55], id: \.self) { a in
                        Button {
                            withAnimation(.spring(response: 0.3)) { age = a }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text("\(a)")
                                .font(.system(size: 14, weight: age == a ? .bold : .medium))
                                .foregroundColor(age == a ? .white : accent)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(
                                    Capsule().fill(age == a ? accent : accent.opacity(0.10))
                                )
                        }
                    }
                }
            }

            Spacer()
        }
    }

    // MARK: - Шаг 3: Рост и вес

    private var bodyStep: some View {
        VStack(spacing: 0) {
            stepHeader(
                title: "Рост и вес",
                subtitle: "Используется для расчёта\nИМТ и калорийности"
            )
            .padding(.top, 20)

            Spacer()

            VStack(spacing: 28) {
                // Вес
                bodyCard(
                    icon: "scalemass.fill",
                    title: "Вес",
                    value: $weight,
                    range: 30...200,
                    unit: "кг",
                    color: accent
                )

                // Рост
                bodyCard(
                    icon: "arrow.up.and.down",
                    title: "Рост",
                    value: $height,
                    range: 100...230,
                    unit: "см",
                    color: accent2
                )

                // ИМТ
                let bmi = weight / ((height/100) * (height/100))
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Индекс массы тела (ИМТ)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(red:0.5,green:0.63,blue:0.72))
                        Text(String(format: "%.1f", bmi))
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(bmiColor(bmi))
                    }
                    Spacer()
                    Text(bmiLabel(bmi))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(bmiColor(bmi))
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Capsule().fill(bmiColor(bmi).opacity(0.12)))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.80))
                        .shadow(color: accent.opacity(0.07), radius: 6, x: 0, y: 2)
                )
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func bodyCard(icon: String, title: String, value: Binding<Double>,
                          range: ClosedRange<Double>, unit: String, color: Color) -> some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(color)
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(red:0.2,green:0.3,blue:0.4))
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(String(format: "%.0f", value.wrappedValue))
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(color)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: value.wrappedValue)
                    Text(unit)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color.opacity(0.7))
                }
            }

            Slider(value: value, in: range, step: 1)
                .tint(color)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.82))
                .shadow(color: color.opacity(0.10), radius: 8, x: 0, y: 3)
        )
    }

    // MARK: - Шаг 4: Цель

    private var goalStep: some View {
        VStack(spacing: 0) {
            stepHeader(
                title: "Ваша цель",
                subtitle: "Bagyt адаптирует советы\nпод вашу цель"
            )
            .padding(.top, 20)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(UserGoal.allCases, id: \.self) { g in
                        goalCard(g)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
    }

    private func goalCard(_ g: UserGoal) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { goal = g }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(goal == g ? accent.opacity(0.15) : Color(red:0.93,green:0.97,blue:1.0))
                        .frame(width: 52, height: 52)
                    Text(g.emoji).font(.system(size: 26))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(g.label)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(red:0.06,green:0.09,blue:0.16))
                    Text(g.desc)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(red:0.45,green:0.58,blue:0.68))
                }
                Spacer()
                ZStack {
                    Circle()
                        .strokeBorder(goal == g ? accent : Color(red:0.78,green:0.88,blue:0.93), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if goal == g {
                        Circle().fill(accent).frame(width: 12, height: 12)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(goal == g ? accent.opacity(0.06) : Color.white.opacity(0.82))
                    .shadow(color: goal == g ? accent.opacity(0.15) : Color.black.opacity(0.05),
                            radius: goal == g ? 10 : 5, x: 0, y: 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(goal == g ? accent.opacity(0.25) : Color.white.opacity(0.8), lineWidth: 1.5)
                    )
            )
            .scaleEffect(goal == g ? 1.02 : 1.0)
            .animation(.spring(response: 0.3), value: goal)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Шаг 5: Дневные цели

    private var dailyGoalsStep: some View {
        VStack(spacing: 0) {
            stepHeader(
                title: "Дневные цели",
                subtitle: "Bagyt будет отслеживать\nваш прогресс каждый день"
            )
            .padding(.top, 20)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    // Шаги
                    goalSliderCard(
                        icon: "figure.walk", iconColor: accent,
                        title: "Шаги в день",
                        subtitle: "Рекомендовано ВОЗ: 8 000–10 000",
                        value: Binding(get: { Double(stepsGoal) }, set: { stepsGoal = Int($0) }),
                        range: 1000...20000, step: 500,
                        display: "\(stepsGoal) шаг"
                    )

                    // Вода
                    goalSliderCard(
                        icon: "drop.fill", iconColor: Color(red:0.20,green:0.60,blue:0.95),
                        title: "Вода в день",
                        subtitle: "Рекомендовано: 1.5–2.5 литра",
                        value: $waterGoal,
                        range: 0.5...5.0, step: 0.1,
                        display: String(format: "%.1f л", waterGoal)
                    )

                    // Сон
                    goalSliderCard(
                        icon: "moon.stars.fill", iconColor: Color(red:0.55,green:0.35,blue:1.0),
                        title: "Сон",
                        subtitle: "Рекомендовано: 7–9 часов",
                        value: $sleepGoal,
                        range: 4.0...12.0, step: 0.5,
                        display: String(format: "%.1f ч", sleepGoal)
                    )

                    // Калории
                    goalSliderCard(
                        icon: "flame.fill", iconColor: Color(red:0.95,green:0.40,blue:0.15),
                        title: "Калории в день",
                        subtitle: "Среднее для взрослого: 1800–2500",
                        value: Binding(get: { Double(caloriesGoal) }, set: { caloriesGoal = Int($0) }),
                        range: 1000...4000, step: 50,
                        display: "\(caloriesGoal) ккал"
                    )
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
    }

    private func goalSliderCard(icon: String, iconColor: Color, title: String, subtitle: String,
                                 value: Binding<Double>, range: ClosedRange<Double>, step: Double,
                                 display: String) -> some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(iconColor.opacity(0.12)).frame(width: 36, height: 36)
                        Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                            .foregroundColor(iconColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(red:0.06,green:0.09,blue:0.16))
                        Text(subtitle).font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(red:0.5,green:0.63,blue:0.72))
                    }
                }
                Spacer()
                Text(display)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(iconColor)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: value.wrappedValue)
            }
            Slider(value: value, in: range, step: step).tint(iconColor)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.85))
                .shadow(color: iconColor.opacity(0.10), radius: 8, x: 0, y: 3)
        )
    }

    // MARK: - Шаг 6: Готово

    private var readyStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                // Анимированная галочка
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(red:0.1,green:0.78,blue:0.48), Color(red:0.05,green:0.65,blue:0.38)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 100, height: 100)
                        .shadow(color: Color(red:0.1,green:0.78,blue:0.48).opacity(0.40), radius: 24, x: 0, y: 10)
                    Image(systemName: "checkmark")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(appear ? 1.0 : 0.3)
                .opacity(appear ? 1.0 : 0.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.55).delay(0.1), value: appear)

                VStack(spacing: 12) {
                    Text("Профиль готов! 🎉")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(Color(red:0.06,green:0.09,blue:0.16))

                    Text("Bagyt персонализирован под вас.\nДавайте начнём путь к здоровью!")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red:0.4,green:0.55,blue:0.65))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .opacity(appear ? 1.0 : 0.0)
                .offset(y: appear ? 0 : 15)
                .animation(.easeOut(duration: 0.5).delay(0.35), value: appear)

                // Сводка профиля
                VStack(spacing: 10) {
                    summaryRow(icon: "person.fill",        color: accent,
                               label: "Возраст",  value: "\(age) лет")
                    summaryRow(icon: "scalemass.fill",     color: accent2,
                               label: "Вес / Рост",
                               value: "\(Int(weight)) кг / \(Int(height)) см")
                    summaryRow(icon: gender.color == Color(red:0.20,green:0.55,blue:0.95)
                               ? "person.fill" : "person.fill",
                               color: gender.color,
                               label: "Пол", value: gender.label)
                    summaryRow(icon: "target",             color: Color(red:0.95,green:0.55,blue:0.10),
                               label: "Цель",    value: goal.label)
                }
                .padding(.horizontal, 8)
                .opacity(appear ? 1.0 : 0.0)
                .offset(y: appear ? 0 : 15)
                .animation(.easeOut(duration: 0.5).delay(0.5), value: appear)
            }
            .padding(.horizontal, 28)

            Spacer()

            Button {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                saveAndComplete()
            } label: {
                HStack(spacing: 10) {
                    Text("Перейти в приложение")
                        .font(.system(size: 17, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing))
                .clipShape(Capsule())
                .shadow(color: accent.opacity(0.40), radius: 16, x: 0, y: 7)
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 44)
            .opacity(appear ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.5).delay(0.65), value: appear)
        }
    }

    private func summaryRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.12)).frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(red:0.5,green:0.63,blue:0.72))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(red:0.06,green:0.09,blue:0.16))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.80))
                .shadow(color: accent.opacity(0.06), radius: 6, x: 0, y: 2)
        )
    }

    // MARK: - Общий заголовок шага

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 26, weight: .black))
                .foregroundColor(Color(red:0.06,green:0.09,blue:0.16))
            Text(subtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(red:0.45,green:0.58,blue:0.68))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Навигация шагов

    private func next() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let all = OnboardStep.allCases
        guard let cur = all.firstIndex(of: step), cur + 1 < all.count else { return }
        slideDir = .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal:   .move(edge: .leading).combined(with: .opacity)
        )
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            step = all[cur + 1]
        }
        if step == .ready { appear = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { appear = true } }
    }

    private func prev() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let all = OnboardStep.allCases
        guard let cur = all.firstIndex(of: step), cur > 0 else { return }
        slideDir = .asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal:   .move(edge: .trailing).combined(with: .opacity)
        )
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            step = all[cur - 1]
        }
    }

    // MARK: - Сохранение

    private func saveAndComplete() {
        // Сохраняем в UserDefaults
        UserDefaults.standard.set(age,              forKey: "userAge")
        UserDefaults.standard.set(gender.rawValue,  forKey: "userGender")
        UserDefaults.standard.set(weight,           forKey: "userWeight")
        UserDefaults.standard.set(height,           forKey: "userHeight")
        UserDefaults.standard.set(goal.rawValue,    forKey: "userGoal")
        UserDefaults.standard.set(stepsGoal,        forKey: "stepsGoal")
        UserDefaults.standard.set(waterGoal,        forKey: "waterGoal")
        UserDefaults.standard.set(sleepGoal,        forKey: "sleepGoal")
        UserDefaults.standard.set(caloriesGoal,     forKey: "caloriesGoal")
        // Обновляем shared store — SettingsView обновится мгновенно
        let store = UserProfileStore.shared
        store.age          = age
        store.gender       = gender.rawValue
        store.weight       = weight
        store.height       = height
        store.goal         = goal.rawValue
        store.stepsGoal    = stepsGoal
        store.waterGoal    = waterGoal
        store.sleepGoal    = sleepGoal
        store.caloriesGoal = caloriesGoal
        onComplete()
    }

    // MARK: - Helpers

    private func firstName(_ name: String) -> String {
        name.components(separatedBy: " ").first ?? name
    }

    private func bmiColor(_ bmi: Double) -> Color {
        switch bmi {
        case ..<18.5: return Color(red:0.30,green:0.60,blue:0.95)
        case 18.5..<25: return Color(red:0.1,green:0.78,blue:0.48)
        case 25..<30: return Color(red:1.0,green:0.65,blue:0.10)
        default:      return Color(red:0.95,green:0.25,blue:0.25)
        }
    }

    private func bmiLabel(_ bmi: Double) -> String {
        switch bmi {
        case ..<18.5: return "Недовес"
        case 18.5..<25: return "Норма"
        case 25..<30: return "Избыток"
        default:      return "Ожирение"
        }
    }
}

#Preview {
    ProfileOnboardingView(userName: "Жантемир") {}
        .environmentObject(AppState())
        .environmentObject(LanguageManager())
}
