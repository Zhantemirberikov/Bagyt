//
//  HealthMetricsView.swift
//  Bagyt
//
//  Redesigned with full Bagyt design system:
//  Glass cards · Accent #0EA5E9 · Animated rings · ECG · Insights
//

import SwiftUI

// MARK: - HealthMetricsView

struct HealthMetricsView: View {

    // MARK: - State
    @State private var showWater = false
    @State private var steps: Double        = 0
    @State private var heartRate: Double    = 0
    @State private var calories: Double     = 0
    @State private var distance: Double     = 0
    @State private var sleepHours: Double   = 0
    @State private var water: Double        = 1.8
    @State private var oxygen: Double       = 0
    @State private var score: Int           = 0
    @State private var insight: String      = ""
    @State private var animateRings         = false
    @State private var animateECG           = false
    @State private var pulseBeat            = false
    @State private var selectedPeriod       = 0

    private let periods = ["День", "Неделя", "Месяц"]

    // Bagyt palette
    private let accent  = Color(red: 0.055, green: 0.647, blue: 0.914) // #0EA5E9
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831) // #06B6D4

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                headerCard
                periodPicker
                ecgCard
                metricsGrid
                ringSection
                insightCard
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .onAppear {
            loadData()
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) { animateRings = true }
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) { animateECG  = true }
            withAnimation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true)
            ) { pulseBeat = true }
            
        }
        .sheet(isPresented: $showWater) {   // ← добавь это
            WaterView()
        }
    }
    

    // MARK: - Header Card (Health Index)

    private var headerCard: some View {
        ZStack(alignment: .topLeading) {
            // Background gradient
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent, accent2],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: accent.opacity(0.45), radius: 20, x: 0, y: 10)

            // Decorative circles
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 160, height: 160)
                .offset(x: -40, y: -60)

            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 100, height: 100)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: 30, y: 30)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ваше здоровье")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .textCase(.uppercase)
                            .tracking(0.8)
                        Text(todayString())
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.65))
                    }
                    Spacer()
                    // Score ring
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 5)
                            .frame(width: 58, height: 58)
                        Circle()
                            .trim(from: 0, to: animateRings ? CGFloat(score) / 100 : 0)
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .frame(width: 58, height: 58)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 1.2).delay(0.4), value: animateRings)
                        Text("\(score)")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.white)
                    }
                }

                Spacer(minLength: 12)

                // Big index number
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(score)")
                        .font(.system(size: 64, weight: .black))
                        .foregroundColor(.white)
                    Text("/100")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.bottom, 6)
                }

                // Status pill
                HStack(spacing: 6) {
                    Image(systemName: scoreIcon)
                        .font(.system(size: 11, weight: .bold))
                    Text(scoreLabel)
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.2))
                .clipShape(Capsule())

                Spacer(minLength: 8)

                // Mini metrics row
                HStack(spacing: 0) {
                    miniStat(icon: "heart.fill",   value: "\(Int(heartRate))", unit: "уд/м",  color: Color(red: 1, green: 0.35, blue: 0.35))
                    Divider().frame(height: 28).background(Color.white.opacity(0.25)).padding(.horizontal, 14)
                    miniStat(icon: "figure.walk",  value: "\(stepsFormatted)", unit: "шаг",   color: .white)
                    Divider().frame(height: 28).background(Color.white.opacity(0.25)).padding(.horizontal, 14)
                    miniStat(icon: "moon.fill",    value: String(format: "%.1f", sleepHours), unit: "ч сна", color: Color(red: 0.6, green: 0.5, blue: 1.0))
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        HStack(spacing: 0) {
            ForEach(0..<periods.count, id: \.self) { i in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedPeriod = i }
                } label: {
                    Text(periods[i])
                        .font(.system(size: 14, weight: selectedPeriod == i ? .bold : .medium))
                        .foregroundColor(selectedPeriod == i ? .white : Color(red: 0.4, green: 0.55, blue: 0.65))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Group {
                                if selectedPeriod == i {
                                    LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                } else {
                                    Color.clear
                                }
                            }
                        )
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.93, green: 0.97, blue: 1.0))
                .shadow(color: accent.opacity(0.1), radius: 6, x: 0, y: 3)
        )
    }

    // MARK: - ECG / Pulse Card

    private var ecgCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 1, green: 0.9, blue: 0.9))
                                .frame(width: 36, height: 36)
                            Image(systemName: "heart.fill")
                                .foregroundColor(Color(red: 0.95, green: 0.25, blue: 0.25))
                                .font(.system(size: 16))
                                .scaleEffect(pulseBeat ? 1.18 : 0.92)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Пульс")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.55, blue: 0.65))
                            Text("Сейчас")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(red: 0.6, green: 0.72, blue: 0.78))
                        }
                    }
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(Int(heartRate > 0 ? heartRate : 68))")
                            .font(.system(size: 36, weight: .black))
                            .foregroundColor(Color(red: 0.95, green: 0.25, blue: 0.25))
                        Text("уд/мин")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(red: 0.6, green: 0.72, blue: 0.78))
                            .padding(.bottom, 4)
                    }
                }

                // ECG Line (animated)
                ECGLineView(animate: animateECG)
                    .frame(height: 56)
                    .clipped()

                // Zone indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(red: 0.1, green: 0.85, blue: 0.55))
                        .frame(width: 7, height: 7)
                    Text("Зона покоя · норма 60–100 уд/мин")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(red: 0.4, green: 0.55, blue: 0.65))
                }
            }
        }
    }

    // MARK: - Metrics Grid (4 cards)

    private var metricsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            metricCard(
                icon: "figure.walk",
                label: "Шаги",
                value: stepsFormatted,
                unit: "шаг",
                progress: min(steps / 10000, 1),
                target: "Цель: 10 000",
                gradientColors: [accent, accent2],
                iconBg: accent.opacity(0.12),
                iconColor: accent
            )
            metricCard(
                icon: "flame.fill",
                label: "Калории",
                value: "\(Int(calories > 0 ? calories : 1840))",
                unit: "ккал",
                progress: min((calories > 0 ? calories : 1840) / 2200, 1),
                target: "Цель: 2 200",
                gradientColors: [Color(red: 1.0, green: 0.45, blue: 0.1), Color(red: 0.98, green: 0.28, blue: 0.28)],
                iconBg: Color(red: 1.0, green: 0.45, blue: 0.1).opacity(0.12),
                iconColor: Color(red: 1.0, green: 0.45, blue: 0.1)
            )
            metricCard(
                icon: "moon.stars.fill",
                label: "Сон",
                value: sleepHours > 0 ? String(format: "%.1f", sleepHours) : "7.2",
                unit: "часа",
                progress: min((sleepHours > 0 ? sleepHours : 7.2) / 8.0, 1),
                target: "Цель: 8 часов",
                gradientColors: [Color(red: 0.55, green: 0.35, blue: 1.0), Color(red: 0.35, green: 0.55, blue: 1.0)],
                iconBg: Color(red: 0.55, green: 0.35, blue: 1.0).opacity(0.12),
                iconColor: Color(red: 0.55, green: 0.35, blue: 1.0)
            )
            metricCard(
                icon: "drop.fill",
                label: "Вода",
                value: String(format: "%.1f", water),
                unit: "литра",
                progress: min(water / 2.5, 1),
                target: "Цель: 2.5 л",
                gradientColors: [Color(red: 0.024, green: 0.714, blue: 0.831), Color(red: 0.12, green: 0.56, blue: 0.95)],
                iconBg: accent2.opacity(0.12),
                iconColor: accent2
            )
            .onTapGesture { showWater = true }
        }
    }

    // MARK: - Ring Section

    private var ringSection: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("Активность")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))

                HStack(spacing: 0) {
                    // Concentric rings
                    ZStack {
                        // Ring 3 – water (outer)
                        ringArc(
                            progress: animateRings ? min(water / 2.5, 1) : 0,
                            radius: 58,
                            color: accent2,
                            delay: 0.2
                        )
                        // Ring 2 – sleep
                        ringArc(
                            progress: animateRings ? min((sleepHours > 0 ? sleepHours : 7.2) / 8.0, 1) : 0,
                            radius: 44,
                            color: Color(red: 0.55, green: 0.35, blue: 1.0),
                            delay: 0.35
                        )
                        // Ring 1 – steps (inner)
                        ringArc(
                            progress: animateRings ? min(steps > 0 ? steps / 10000 : 0.84, 1) : 0,
                            radius: 30,
                            color: Color(red: 1.0, green: 0.45, blue: 0.1),
                            delay: 0.5
                        )
                    }
                    .frame(width: 134, height: 134)

                    Spacer()

                    // Legend
                    VStack(alignment: .leading, spacing: 14) {
                        ringLegend(color: accent2,
                                   label: "Вода",
                                   value: String(format: "%.1f / 2.5 л", water))
                        ringLegend(color: Color(red: 0.55, green: 0.35, blue: 1.0),
                                   label: "Сон",
                                   value: "\(sleepHours > 0 ? String(format:"%.1f",sleepHours) : "7.2") / 8 ч")
                        ringLegend(color: Color(red: 1.0, green: 0.45, blue: 0.1),
                                   label: "Шаги",
                                   value: "\(stepsFormatted) / 10K")
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Insight Card

    private var insightCard: some View {
        glassCard {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 44, height: 44)
                    Text("⭐")
                        .font(.system(size: 20))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("ИНСАЙТ ДНЯ")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(accent)
                        .tracking(1.2)
                    Text(insight.isEmpty ? "Сегодня ваш пульс на 8% ниже среднего — хороший знак восстановления организма." : insight)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(red: 0.3, green: 0.42, blue: 0.52))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Reusable Components

    @ViewBuilder
    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.82))
                .shadow(color: accent.opacity(0.10), radius: 16, x: 0, y: 6)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(accent.opacity(0.13), lineWidth: 1)
            content()
        }
    }

    private func metricCard(
        icon: String,
        label: String,
        value: String,
        unit: String,
        progress: Double,
        target: String,
        gradientColors: [Color],
        iconBg: Color,
        iconColor: Color
    ) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.85))
                .shadow(color: gradientColors[0].opacity(0.12), radius: 12, x: 0, y: 5)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(gradientColors[0].opacity(0.15), lineWidth: 1)

            VStack(alignment: .leading, spacing: 12) {
                // Icon + percent
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(iconBg)
                            .frame(width: 36, height: 36)
                        Image(systemName: icon)
                            .foregroundColor(iconColor)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(gradientColors[0])
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(gradientColors[0].opacity(0.1))
                        .clipShape(Capsule())
                }

                // Value
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(value)
                            .font(.system(size: 26, weight: .black))
                            .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
                        Text(unit)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(red: 0.55, green: 0.67, blue: 0.75))
                            .padding(.bottom, 3)
                    }
                    Text(label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 0.4, green: 0.55, blue: 0.65))
                }

                // Progress bar
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(gradientColors[0].opacity(0.10))
                                .frame(height: 6)
                            Capsule()
                                .fill(
                                    LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: animateRings ? geo.size.width * CGFloat(progress) : 0, height: 6)
                                .animation(.easeOut(duration: 1.0).delay(0.5), value: animateRings)
                        }
                    }
                    .frame(height: 6)

                    Text(target)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(red: 0.65, green: 0.75, blue: 0.82))
                }
            }
            .padding(16)
        }
    }

    private func ringArc(progress: Double, radius: CGFloat, color: Color, delay: Double) -> some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.1), lineWidth: 10)
                .frame(width: radius * 2, height: radius * 2)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .frame(width: radius * 2, height: radius * 2)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1.2).delay(delay), value: animateRings)
        }
    }

    private func ringLegend(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 14, height: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
                Text(value)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(red: 0.5, green: 0.63, blue: 0.72))
            }
        }
    }

    private func miniStat(icon: String, value: String, unit: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 12))
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(.white)
                Text(unit)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() {
        HealthManager.shared.requestAccess { success in
            if success {
                HealthManager.shared.fetchSteps      { steps      = $0; updateScore(); updateInsight() }
                HealthManager.shared.fetchHeartRate  { heartRate  = $0 }
                HealthManager.shared.fetchCalories   { calories   = $0; updateScore() }
                HealthManager.shared.fetchDistance   { distance   = $0; updateScore() }
                HealthManager.shared.fetchSleep      { sleepHours = $0 }
                HealthManager.shared.fetchOxygen     { oxygen     = $0 * 100 }
            } else {
                // Fallback demo data when HealthKit is unavailable (simulator)
                steps      = 8420
                heartRate  = 68
                calories   = 1840
                distance   = 5.4
                sleepHours = 7.2
                oxygen     = 98
                updateScore()
                updateInsight()
            }
        }
    }

    private func updateScore() {
        let s = min(steps    / 10000, 1) * 40
        let c = min(calories / 2200,  1) * 30
        let d = min(distance / 10,    1) * 30
        withAnimation(.easeOut(duration: 0.8)) {
            score = Int(s + c + d)
        }
    }

    private func updateInsight() {
        if heartRate > 100 {
            insight = "⚠️ Пульс повышен. Рекомендую отдохнуть и выпить воды."
        } else if steps < 3000 {
            insight = "🚶 Сегодня мало активности. Попробуйте прогуляться 20–30 минут."
        } else if sleepHours < 6 {
            insight = "😴 Недостаточно сна. Постарайтесь лечь пораньше сегодня."
        } else {
            insight = "💪 Отличный день! Ваши показатели в норме — продолжайте в том же духе."
        }
    }

    // MARK: - Helpers

    private var stepsFormatted: String {
        let s = steps > 0 ? steps : 8420
        return s >= 1000 ? String(format: "%.1fk", s / 1000) : "\(Int(s))"
    }

    private var scoreIcon: String {
        switch score {
        case 80...100: return "crown.fill"
        case 60...79:  return "bolt.fill"
        case 40...59:  return "face.smiling"
        default:       return "exclamationmark.triangle.fill"
        }
    }

    private var scoreLabel: String {
        switch score {
        case 80...100: return "Отлично"
        case 60...79:  return "Хорошо"
        case 40...59:  return "Средне"
        default:       return "Требует внимания"
        }
    }

    private func todayString() -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ru_RU")
        fmt.dateFormat = "EEEE, d MMMM"
        return fmt.string(from: Date()).capitalized
    }
}

// MARK: - ECG Line View

struct ECGLineView: View {
    let animate: Bool

    // ECG path points (normalized 0–1 on both axes)
    private let points: [CGPoint] = [
        CGPoint(x: 0.00, y: 0.50),
        CGPoint(x: 0.06, y: 0.50),
        CGPoint(x: 0.09, y: 0.50),
        CGPoint(x: 0.11, y: 0.10), // P wave up
        CGPoint(x: 0.13, y: 0.50),
        CGPoint(x: 0.17, y: 0.50),
        CGPoint(x: 0.19, y: 0.65), // Q dip
        CGPoint(x: 0.21, y: 0.02), // R spike up
        CGPoint(x: 0.23, y: 0.88), // S dip
        CGPoint(x: 0.26, y: 0.50),
        CGPoint(x: 0.30, y: 0.50),
        CGPoint(x: 0.33, y: 0.32), // T wave
        CGPoint(x: 0.36, y: 0.50),
        CGPoint(x: 0.43, y: 0.50),

        CGPoint(x: 0.46, y: 0.50),
        CGPoint(x: 0.49, y: 0.10),
        CGPoint(x: 0.51, y: 0.50),
        CGPoint(x: 0.55, y: 0.50),
        CGPoint(x: 0.57, y: 0.65),
        CGPoint(x: 0.59, y: 0.02),
        CGPoint(x: 0.61, y: 0.88),
        CGPoint(x: 0.64, y: 0.50),
        CGPoint(x: 0.68, y: 0.50),
        CGPoint(x: 0.71, y: 0.32),
        CGPoint(x: 0.74, y: 0.50),
        CGPoint(x: 0.83, y: 0.50),

        CGPoint(x: 0.86, y: 0.50),
        CGPoint(x: 0.89, y: 0.10),
        CGPoint(x: 0.91, y: 0.50),
        CGPoint(x: 0.95, y: 0.50),
        CGPoint(x: 0.97, y: 0.65),
        CGPoint(x: 0.985, y: 0.02),
        CGPoint(x: 1.00, y: 0.50),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Glow / fill under ECG
                Path { path in
                    let mapped = points.map { CGPoint(x: $0.x * w, y: $0.y * h) }
                    guard let first = mapped.first else { return }
                    path.move(to: CGPoint(x: first.x, y: h))
                    path.addLine(to: first)
                    for pt in mapped.dropFirst() { path.addLine(to: pt) }
                    path.addLine(to: CGPoint(x: mapped.last!.x, y: h))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.25, blue: 0.25).opacity(0.12),
                            Color(red: 0.95, green: 0.25, blue: 0.25).opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // ECG line
                Path { path in
                    let mapped = points.map { CGPoint(x: $0.x * w, y: $0.y * h) }
                    guard let first = mapped.first else { return }
                    path.move(to: first)
                    for pt in mapped.dropFirst() { path.addLine(to: pt) }
                }
                .trim(from: 0, to: animate ? 1 : 0)
                .stroke(
                    Color(red: 0.95, green: 0.25, blue: 0.25),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                )
                .animation(.easeInOut(duration: 1.8).delay(0.3), value: animate)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(red: 0.94, green: 0.97, blue: 1.0).ignoresSafeArea()
        HealthMetricsView()
    }
}
