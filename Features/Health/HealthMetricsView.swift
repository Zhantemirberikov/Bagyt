//
//  HealthMetricsView.swift
//  Bagyt
//
//  Redesigned with full Bagyt Premium design system:
//  Real Apple HealthKit Data · Dynamic Averages · Settings Goals · Dark Mode
//  + All Apple Watch metrics: HRV, SpO2, Respiratory, Temperature, Noise,
//    Stand Hours, Exercise Minutes, VO2Max, Blood Pressure, Mindful Minutes, Falls
//

import SwiftUI
import HealthKit

// MARK: - HealthMetricsView

struct HealthMetricsView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lang: LanguageManager
    
    @AppStorage("isDarkModeEnabled") private var isDarkMode = false

    // MARK: - State (Real Health Data)
    @State private var showWater = false
    @State private var steps: Double        = 0
    @State private var heartRate: Double    = 0
    @State private var calories: Double     = 0
    @State private var sleepHours: Double   = 0
    
    // MARK: - Extended Apple Watch Metrics
    @State private var hrv: Double          = 0   // мс
    @State private var spo2: Double         = 0   // %
    @State private var respiratoryRate: Double = 0 // вд/мин
    @State private var wristTemp: Double    = 0   // °C (отклонение)
    @State private var standHours: Double   = 0   // ч
    @State private var exerciseMinutes: Double = 0 // мин
    @State private var vo2Max: Double       = 0   // мл/кг/мин
    @State private var systolic: Double     = 0   // мм рт.ст.
    @State private var diastolic: Double    = 0   // мм рт.ст.
    @State private var mindfulMinutes: Double = 0 // мин
    @State private var noiseExposure: Double = 0  // дБ
    @State private var walkingSpeed: Double  = 0  // м/с
    @State private var walkingDoubleSupportPct: Double = 0 // %
    @State private var stairAscentSpeed: Double = 0 // м/с
    @State private var bodyFat: Double      = 0   // %
    @State private var bmi: Double          = 0
    @State private var bodyMass: Double     = 0   // кг
    @State private var leanBodyMass: Double = 0   // кг
    @State private var distanceWalking: Double = 0 // км
    @State private var flightsClimbed: Double = 0  // этажей
    @State private var cyclingDistance: Double = 0 // км
    @State private var basalEnergy: Double  = 0   // ккал
    @State private var peripheralPerfIndex: Double = 0 // % (ИПП)
    @State private var cardioFitness: Double = 0  // уд/мин (восст.)

    // MARK: - Local Water State
    @State private var todayWater: Double   = 0
    @State private var displayWater: Double = 0
    @State private var tempWater: Double    = 0
    
    @State private var insight: String      = ""
    
    // Детальные экраны
    @State private var showSleepDetail      = false
    @State private var showPulseDetail      = false
    @State private var showStepsDetail      = false

    // Animations
    @State private var animateRings         = false
    @State private var animateECG           = false
    @State private var pulseBeat            = false
    @State private var selectedPeriod       = 0

    private let periods = ["День", "Неделя", "Месяц"]
    
    // HealthKit Store
    private let healthStore = HKHealthStore()

    // Bagyt Premium Palette
    private let accent  = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)
    
    // Dynamic Colors
    private var primaryText: Color { isDarkMode ? .white : Color(red: 0.06, green: 0.09, blue: 0.16) }
    private var secondaryText: Color { isDarkMode ? Color.white.opacity(0.6) : Color(red: 0.4, green: 0.55, blue: 0.65) }
    private var cardBg: Color { isDarkMode ? Color(red: 0.1, green: 0.12, blue: 0.18).opacity(0.5) : Color.white.opacity(0.6) }
    private var cardStroke: Color { isDarkMode ? Color.white.opacity(0.1) : Color.white.opacity(0.8) }
    private var pickerBg: Color { isDarkMode ? Color.white.opacity(0.08) : Color.white.opacity(0.85) }

    // MARK: - Dynamic Goals from Settings
    private var stepsGoal: Double { let g = UserDefaults.standard.double(forKey: "stepsGoal"); return g > 0 ? g : 8000 }
    private var caloriesGoal: Double { let g = UserDefaults.standard.double(forKey: "caloriesGoal"); return g > 0 ? g : 2200 }
    private var sleepGoal: Double { let g = UserDefaults.standard.double(forKey: "sleepGoal"); return g > 0 ? g : 8.0 }
    private var waterGoal: Double { let g = UserDefaults.standard.double(forKey: "waterGoal"); return g > 0 ? g : 2.5 }

    private var healthIndexBreakdown: HealthIndexBreakdown {
        HealthIndexCalculator.make(
            steps: Int(steps.rounded()),
            heartRate: Int(heartRate.rounded()),
            sleepHours: sleepHours,
            stepsGoal: Int(stepsGoal),
            sleepGoal: sleepGoal
        )
    }

    private var healthIndex: Int {
        healthIndexBreakdown.score
    }

    private var healthIndexPeriodSubtitle: String {
        switch selectedPeriod {
        case 1: return BagytL10n.tr("Средний индекс за неделю")
        case 2: return BagytL10n.tr("Средний индекс за месяц")
        default: return BagytL10n.tr("Индекс за сегодня")
        }
    }

    private var heartPeriodSubtitle: String {
        switch selectedPeriod {
        case 1: return BagytL10n.tr("В среднем за неделю")
        case 2: return BagytL10n.tr("В среднем за месяц")
        default: return BagytL10n.tr("Сегодня в среднем")
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerCard
                    periodPicker
                    ecgCard
                    
                    // ── Основные метрики ──────────────────────────────────
                    metricsGrid
                    ringSection
                    insightCard
                    
                    // ── Сердце и кровообращение ───────────────────────────
                    sectionHeader("❤️ Сердце и кровообращение")
                    heartSectionGrid
                    
                    // ── Дыхание и кислород ───────────────────────────────
                    sectionHeader("🫁 Дыхание и кислород")
                    breathSectionGrid
                    
                    // ── Активность и фитнес ───────────────────────────────
                    sectionHeader("🏃 Активность и фитнес")
                    activitySectionGrid
                    
                    // ── Тело и состав ─────────────────────────────────────
                    sectionHeader("⚖️ Тело и состав")
                    bodySectionGrid
                    
                    // ── Окружающая среда и осознанность ──────────────────
                    sectionHeader("🧠 Среда и осознанность")
                    mindSectionGrid
                    
                    Spacer(minLength: 140)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .refreshable {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                recalculateWaterStats()
                loadRealHealthData()
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear {
            recalculateWaterStats()
            loadRealHealthData()
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) { animateRings = true }
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) { animateECG  = true }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulseBeat = true }
        }
        .onChange(of: selectedPeriod) { _ in
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                recalculateWaterStats()
                loadRealHealthData()
            }
        }
        .sheet(isPresented: $showWater, onDismiss: {
            todayWater = tempWater
            saveTodayWater(todayWater)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                recalculateWaterStats()
            }
        }) {
            WaterView(consumed: $tempWater)
                .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
    
    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(BagytL10n.tr(title))
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundColor(primaryText)
            Spacer()
        }
        .padding(.top, 4)
    }
    
    // MARK: - Header Card (Health Index)

    private var headerCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: accent.opacity(isDarkMode ? 0.2 : 0.45), radius: 20, x: 0, y: 10)

            Circle().fill(Color.white.opacity(0.08)).frame(width: 160, height: 160).offset(x: -40, y: -60)
            Circle().fill(Color.white.opacity(0.05)).frame(width: 100, height: 100)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).offset(x: 30, y: 30)
            
            RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Color.white.opacity(0.2), lineWidth: 1)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Комплексный индекс здоровья")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                            .textCase(.uppercase).tracking(1.0)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                        Text(healthIndexPeriodSubtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                    Spacer()
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.2), lineWidth: 5).frame(width: 58, height: 58)
                        Circle().trim(from: 0, to: animateRings ? CGFloat(healthIndex) / 100 : 0)
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .frame(width: 58, height: 58).rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 1.2).delay(0.2), value: animateRings)
                            .animation(.spring(response: 0.8), value: healthIndex)
                        Text("\(healthIndex)")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.8), value: healthIndex)
                    }
                }

                Spacer(minLength: 16)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(healthIndex)")
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.8), value: healthIndex)
                    Text("/100").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.7)).padding(.bottom, 6)
                }

                HStack(spacing: 6) {
                    Image(systemName: scoreIcon).font(.system(size: 11, weight: .bold))
                    Text(scoreLabel).font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white).padding(.horizontal, 14).padding(.vertical, 6)
                .background(Color.white.opacity(0.2)).clipShape(Capsule())

                Spacer(minLength: 12)

                HStack(spacing: 0) {
                    miniStat(icon: "heart.fill",   value: heartRate > 0 ? "\(Int(heartRate))" : "—", unit: "уд/м",  color: Color(red: 1, green: 0.35, blue: 0.35))
                    Divider().frame(height: 28).background(Color.white.opacity(0.25)).padding(.horizontal, 14)
                    miniStat(icon: "figure.walk",  value: steps > 0 ? stepsFormatted : "—", unit: "шаг",   color: .white)
                    Divider().frame(height: 28).background(Color.white.opacity(0.25)).padding(.horizontal, 14)
                    miniStat(icon: "moon.fill",    value: sleepHours > 0 ? String(format: "%.1f", sleepHours) : "—", unit: "ч сна", color: Color(red: 0.6, green: 0.5, blue: 1.0))
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
                    selectedPeriod = i
                } label: {
                    Text(BagytL10n.tr(periods[i]))
                        .font(.system(size: 14, weight: selectedPeriod == i ? .bold : .semibold, design: .rounded))
                        .foregroundColor(selectedPeriod == i ? .white : secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Group {
                                if selectedPeriod == i {
                                    LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .shadow(color: accent.opacity(isDarkMode ? 0.3 : 0.2), radius: 6, x: 0, y: 3)
                                } else {
                                    Color.clear
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(pickerBg)
                .background(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(cardStroke, lineWidth: 1))
                .shadow(color: Color.black.opacity(isDarkMode ? 0.2 : 0.05), radius: 8, x: 0, y: 3)
        )
    }

    // MARK: - ECG / Pulse Card

    private var ecgCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color(red: 1, green: 0.25, blue: 0.25).opacity(0.12)).frame(width: 40, height: 40)
                            Image(systemName: "heart.fill").foregroundColor(Color(red: 0.95, green: 0.25, blue: 0.25))
                                .font(.system(size: 18)).scaleEffect(pulseBeat ? 1.15 : 0.9)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Пульс").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(primaryText)
                            Text(heartPeriodSubtitle)
                                .font(.system(size: 12, weight: .medium)).foregroundColor(secondaryText)
                        }
                    }
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(Int(heartRate > 0 ? heartRate : 0))")
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundColor(Color(red: 0.95, green: 0.25, blue: 0.25))
                            .contentTransition(.numericText())
                        Text("уд/м").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(secondaryText).padding(.bottom, 4)
                    }
                }

                ECGLineView(animate: animateECG).frame(height: 60).clipped()

                HStack(spacing: 6) {
                    Circle().fill(Color(red: 0.1, green: 0.85, blue: 0.55)).frame(width: 8, height: 8)
                    Text("Зона покоя · норма 60–100 уд/мин").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(secondaryText)
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
    }

    // MARK: - Metrics Grid (Original 4 cards)

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            metricCard(
                icon: "figure.walk", label: "Шаги", value: stepsFormatted, unit: "шагов",
                progress: min(steps / stepsGoal, 1), target: "Цель: \(Int(stepsGoal).formattedWithSpaces)",
                gradientColors: [accent, accent2], iconBg: accent.opacity(0.12), iconColor: accent,
                onTap: { showStepsDetail = true }
            )
            metricCard(
                icon: "flame.fill", label: "Калории", value: "\(Int(calories).formattedWithSpaces)", unit: "ккал",
                progress: min(calories / caloriesGoal, 1), target: "Цель: \(Int(caloriesGoal).formattedWithSpaces)",
                gradientColors: [Color(red: 1.0, green: 0.45, blue: 0.1), Color(red: 0.98, green: 0.28, blue: 0.28)],
                iconBg: Color(red: 1.0, green: 0.45, blue: 0.1).opacity(0.12), iconColor: Color(red: 1.0, green: 0.45, blue: 0.1),
                onTap: nil
            )
            metricCard(
                icon: "moon.stars.fill", label: "Сон", value: String(format: "%.1f", sleepHours), unit: "часа",
                progress: min(sleepHours / sleepGoal, 1), target: "Цель: \(String(format: "%.1f", sleepGoal)) ч",
                gradientColors: [Color(red: 0.55, green: 0.35, blue: 1.0), Color(red: 0.35, green: 0.55, blue: 1.0)],
                iconBg: Color(red: 0.55, green: 0.35, blue: 1.0).opacity(0.12), iconColor: Color(red: 0.55, green: 0.35, blue: 1.0),
                onTap: { showSleepDetail = true }
            )
            metricCard(
                icon: "drop.fill",
                label: selectedPeriod == 0 ? "Вода (Сегодня)" : "Вода (В среднем)",
                value: String(format: "%.1f", displayWater / 1000),
                unit: "литра",
                progress: min((displayWater / 1000) / waterGoal, 1),
                target: "Цель: \(String(format: "%.1f", waterGoal)) л",
                gradientColors: [Color(red: 0.024, green: 0.714, blue: 0.831), Color(red: 0.12, green: 0.56, blue: 0.95)],
                iconBg: accent2.opacity(0.12), iconColor: accent2,
                onTap: {
                    tempWater = todayWater
                    showWater = true
                }
            )
        }
    }

    // MARK: - Ring Section

    private var ringSection: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 18) {
                Text(selectedPeriod == 0 ? "Активность сегодня" : "Средняя активность")
                    .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(primaryText)

                HStack(spacing: 0) {
                    ZStack {
                        ringArc(progress: animateRings ? min((displayWater / 1000) / waterGoal, 1) : 0, radius: 64, color: accent2, delay: 0.1)
                        ringArc(progress: animateRings ? min(sleepHours / sleepGoal, 1) : 0, radius: 48, color: Color(red: 0.55, green: 0.35, blue: 1.0), delay: 0.25)
                        ringArc(progress: animateRings ? min(steps / stepsGoal, 1) : 0, radius: 32, color: Color(red: 1.0, green: 0.45, blue: 0.1), delay: 0.4)
                    }.frame(width: 140, height: 140)

                    Spacer()

                    VStack(alignment: .leading, spacing: 16) {
                        ringLegend(color: accent2, label: "Вода", value: "\(String(format: "%.1f", displayWater / 1000)) / \(String(format: "%.1f", waterGoal)) л")
                        ringLegend(color: Color(red: 0.55, green: 0.35, blue: 1.0), label: "Сон", value: "\(String(format:"%.1f", sleepHours)) / \(String(format:"%.1f", sleepGoal)) ч")
                        ringLegend(color: Color(red: 1.0, green: 0.45, blue: 0.1), label: "Шаги", value: "\(stepsFormatted) / \(Int(stepsGoal / 1000))K")
                    }
                }
            }.padding(22)
        }
    }

    // MARK: - Insight Card

    private var insightCard: some View {
        glassCard {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 48, height: 48)
                        .shadow(color: accent.opacity(isDarkMode ? 0.3 : 0.2), radius: 8, x: 0, y: 4)
                    Image(systemName: "sparkles").font(.system(size: 22, weight: .semibold)).foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("AI ИНСАЙТ").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(accent).tracking(1.2)
                    Text(insight.isEmpty ? BagytL10n.tr("Ваш пульс в пределах нормы, а активность приближается к цели. Так держать!") : BagytL10n.tr(insight))
                        .font(.system(size: 14, weight: .medium)).foregroundColor(primaryText).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - ── НОВЫЕ СЕКЦИИ ─────────────────────────────────────────────

    // MARK: Сердце и кровообращение (HRV, SpO2, АД, ИПП)

    private var heartSectionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            // ВСР (HRV)
            simpleMetricCard(
                icon: "waveform.path.ecg",
                label: "Вариабельность ритма",
                value: hrv > 0 ? "\(Int(hrv))" : "—",
                unit: "мс",
                note: "ВСР · норма 20–100 мс",
                gradientColors: [Color(red: 0.95, green: 0.25, blue: 0.25), Color(red: 0.75, green: 0.12, blue: 0.45)],
                iconBg: Color(red: 0.95, green: 0.25, blue: 0.25).opacity(0.12),
                iconColor: Color(red: 0.95, green: 0.25, blue: 0.25)
            )
            // SpO2
            simpleMetricCard(
                icon: "lungs.fill",
                label: "Кислород крови",
                value: spo2 > 0 ? "\(Int(spo2))" : "—",
                unit: "%",
                note: "SpO₂ · норма ≥ 95%",
                gradientColors: [Color(red: 0.12, green: 0.56, blue: 0.95), Color(red: 0.024, green: 0.714, blue: 0.831)],
                iconBg: Color(red: 0.12, green: 0.56, blue: 0.95).opacity(0.12),
                iconColor: Color(red: 0.12, green: 0.56, blue: 0.95)
            )
            // Артериальное давление
            bpCard
            // Индекс перфузии (ИПП)
            simpleMetricCard(
                icon: "dot.radiowaves.left.and.right",
                label: "Индекс перфузии",
                value: peripheralPerfIndex > 0 ? String(format: "%.1f", peripheralPerfIndex) : "—",
                unit: "%",
                note: "ИПП · норма 0.5–20%",
                gradientColors: [Color(red: 0.8, green: 0.2, blue: 0.6), Color(red: 0.55, green: 0.1, blue: 0.75)],
                iconBg: Color(red: 0.8, green: 0.2, blue: 0.6).opacity(0.12),
                iconColor: Color(red: 0.8, green: 0.2, blue: 0.6)
            )
        }
    }

    // Отдельная карточка для АД (два значения)
    private var bpCard: some View {
        let red = Color(red: 0.95, green: 0.25, blue: 0.25)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(red.opacity(0.12)).frame(width: 40, height: 40)
                    Image(systemName: "heart.circle.fill")
                        .foregroundColor(red).font(.system(size: 18, weight: .semibold))
                }
                Spacer()
                Text("АД")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(red)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(red.opacity(0.12)).clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(systolic > 0 ? "\(Int(systolic))/\(Int(diastolic))" : "—")
                        .font(.system(size: systolic > 0 ? 26 : 28, weight: .black, design: .rounded))
                        .foregroundColor(primaryText)
                        .contentTransition(.numericText())
                    if systolic > 0 {
                        Text("мм рт.ст.").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(secondaryText)
                    }
                }
                Text("Артериальное давление")
                    .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(secondaryText)
            }

            Spacer(minLength: 0)

            Text("норма 120/80 мм рт.ст.")
                .font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(secondaryText)
        }
        .padding(18).frame(maxWidth: .infinity, minHeight: 180)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(cardBg).background(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.05), radius: 12, x: 0, y: 5)
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(cardStroke, lineWidth: 1))
        )
    }

    // MARK: Дыхание и кислород (ЧД, температура запястья)

    private var breathSectionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            simpleMetricCard(
                icon: "wind",
                label: "Частота дыхания",
                value: respiratoryRate > 0 ? "\(Int(respiratoryRate))" : "—",
                unit: "вд/мин",
                note: "норма 12–20 вд/мин",
                gradientColors: [Color(red: 0.024, green: 0.714, blue: 0.831), Color(red: 0.12, green: 0.56, blue: 0.95)],
                iconBg: accent2.opacity(0.12),
                iconColor: accent2
            )
            simpleMetricCard(
                icon: "thermometer.medium",
                label: "Температура тела",
                value: wristTemp != 0 ? String(format: "%+.1f", wristTemp) : "—",
                unit: "°C",
                note: "Отклонение от базовой",
                gradientColors: [Color(red: 1.0, green: 0.6, blue: 0.1), Color(red: 0.98, green: 0.3, blue: 0.1)],
                iconBg: Color(red: 1.0, green: 0.6, blue: 0.1).opacity(0.12),
                iconColor: Color(red: 1.0, green: 0.6, blue: 0.1)
            )
        }
    }

    // MARK: Активность и фитнес (Минуты упражнений, Стояние, VO2Max, Дистанция, Велосипед, Этажи, Скорость ходьбы, Двойная опора)

    private var activitySectionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            metricCard(
                icon: "figure.run",
                label: "Мин. упражнений",
                value: exerciseMinutes > 0 ? "\(Int(exerciseMinutes))" : "—",
                unit: "мин",
                progress: min(exerciseMinutes / 30, 1),
                target: "Цель: 30 мин/день",
                gradientColors: [Color(red: 0.1, green: 0.78, blue: 0.48), Color(red: 0.024, green: 0.714, blue: 0.831)],
                iconBg: Color(red: 0.1, green: 0.78, blue: 0.48).opacity(0.12),
                iconColor: Color(red: 0.1, green: 0.78, blue: 0.48),
                onTap: nil
            )
            metricCard(
                icon: "figure.stand",
                label: "Часы стояния",
                value: standHours > 0 ? "\(Int(standHours))" : "—",
                unit: "ч",
                progress: min(standHours / 12, 1),
                target: "Цель: 12 ч/день",
                gradientColors: [Color(red: 0.4, green: 0.8, blue: 0.3), Color(red: 0.1, green: 0.78, blue: 0.48)],
                iconBg: Color(red: 0.4, green: 0.8, blue: 0.3).opacity(0.12),
                iconColor: Color(red: 0.4, green: 0.8, blue: 0.3),
                onTap: nil
            )
            metricCard(
                icon: "lungs",
                label: "VO₂ Макс",
                value: vo2Max > 0 ? String(format: "%.1f", vo2Max) : "—",
                unit: "мл/кг/мин",
                progress: min(vo2Max / 60, 1),
                target: "Отлично: > 50",
                gradientColors: [Color(red: 0.55, green: 0.35, blue: 1.0), Color(red: 0.35, green: 0.55, blue: 1.0)],
                iconBg: Color(red: 0.55, green: 0.35, blue: 1.0).opacity(0.12),
                iconColor: Color(red: 0.55, green: 0.35, blue: 1.0),
                onTap: nil
            )
            metricCard(
                icon: "map.fill",
                label: "Дистанция",
                value: distanceWalking > 0 ? String(format: "%.1f", distanceWalking / 1000) : "—",
                unit: "км",
                progress: min((distanceWalking / 1000) / 8.0, 1),
                target: "Цель: 8 км/день",
                gradientColors: [accent, accent2],
                iconBg: accent.opacity(0.12),
                iconColor: accent,
                onTap: nil
            )
            metricCard(
                icon: "bicycle",
                label: "На велосипеде",
                value: cyclingDistance > 0 ? String(format: "%.1f", cyclingDistance / 1000) : "—",
                unit: "км",
                progress: min((cyclingDistance / 1000) / 20.0, 1),
                target: "Цель: 20 км",
                gradientColors: [Color(red: 1.0, green: 0.75, blue: 0.1), Color(red: 1.0, green: 0.45, blue: 0.1)],
                iconBg: Color(red: 1.0, green: 0.75, blue: 0.1).opacity(0.12),
                iconColor: Color(red: 1.0, green: 0.75, blue: 0.1),
                onTap: nil
            )
            metricCard(
                icon: "stairs",
                label: "Пролёты лестниц",
                value: flightsClimbed > 0 ? "\(Int(flightsClimbed))" : "—",
                unit: "эт.",
                progress: min(flightsClimbed / 10, 1),
                target: "Цель: 10 эт./день",
                gradientColors: [Color(red: 0.98, green: 0.45, blue: 0.3), Color(red: 0.95, green: 0.25, blue: 0.25)],
                iconBg: Color(red: 0.98, green: 0.45, blue: 0.3).opacity(0.12),
                iconColor: Color(red: 0.98, green: 0.45, blue: 0.3),
                onTap: nil
            )
            simpleMetricCard(
                icon: "figure.walk.motion",
                label: "Скорость ходьбы",
                value: walkingSpeed > 0 ? String(format: "%.1f", walkingSpeed * 3.6) : "—",
                unit: "км/ч",
                note: "норма 4–6 км/ч",
                gradientColors: [Color(red: 0.2, green: 0.7, blue: 0.5), Color(red: 0.024, green: 0.714, blue: 0.831)],
                iconBg: Color(red: 0.2, green: 0.7, blue: 0.5).opacity(0.12),
                iconColor: Color(red: 0.2, green: 0.7, blue: 0.5)
            )
            simpleMetricCard(
                icon: "figure.walk.diamond",
                label: "Двойная опора",
                value: walkingDoubleSupportPct > 0 ? "\(Int(walkingDoubleSupportPct))" : "—",
                unit: "%",
                note: "Симметрия шага · < 30%",
                gradientColors: [Color(red: 0.5, green: 0.3, blue: 0.9), Color(red: 0.35, green: 0.55, blue: 1.0)],
                iconBg: Color(red: 0.5, green: 0.3, blue: 0.9).opacity(0.12),
                iconColor: Color(red: 0.5, green: 0.3, blue: 0.9)
            )
            simpleMetricCard(
                icon: "arrow.up.stairs",
                label: "Скорость подъёма",
                value: stairAscentSpeed > 0 ? String(format: "%.2f", stairAscentSpeed) : "—",
                unit: "м/с",
                note: "Лестница · норма > 0.5",
                gradientColors: [Color(red: 0.9, green: 0.5, blue: 0.1), Color(red: 0.98, green: 0.28, blue: 0.28)],
                iconBg: Color(red: 0.9, green: 0.5, blue: 0.1).opacity(0.12),
                iconColor: Color(red: 0.9, green: 0.5, blue: 0.1)
            )
            simpleMetricCard(
                icon: "flame",
                label: "Базальный обмен",
                value: basalEnergy > 0 ? "\(Int(basalEnergy))" : "—",
                unit: "ккал",
                note: "Покоевые калории",
                gradientColors: [Color(red: 0.98, green: 0.28, blue: 0.28), Color(red: 0.8, green: 0.1, blue: 0.5)],
                iconBg: Color(red: 0.98, green: 0.28, blue: 0.28).opacity(0.12),
                iconColor: Color(red: 0.98, green: 0.28, blue: 0.28)
            )
        }
    }

    // MARK: Тело и состав (Масса, ИМТ, % жира, Мышечная масса)

    private var bodySectionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            simpleMetricCard(
                icon: "scalemass.fill",
                label: "Масса тела",
                value: bodyMass > 0 ? String(format: "%.1f", bodyMass) : "—",
                unit: "кг",
                note: "Последнее измерение",
                gradientColors: [Color(red: 0.3, green: 0.6, blue: 1.0), Color(red: 0.055, green: 0.647, blue: 0.914)],
                iconBg: Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.12),
                iconColor: Color(red: 0.3, green: 0.6, blue: 1.0)
            )
            simpleMetricCard(
                icon: "person.fill",
                label: "Индекс массы тела",
                value: bmi > 0 ? String(format: "%.1f", bmi) : "—",
                unit: "ИМТ",
                note: bmiLabel,
                gradientColors: bmiGradient,
                iconBg: bmiGradient[0].opacity(0.12),
                iconColor: bmiGradient[0]
            )
            simpleMetricCard(
                icon: "drop.triangle.fill",
                label: "Жировая масса",
                value: bodyFat > 0 ? String(format: "%.1f", bodyFat) : "—",
                unit: "%",
                note: "Норма муж: 8–24%",
                gradientColors: [Color(red: 1.0, green: 0.5, blue: 0.1), Color(red: 0.98, green: 0.28, blue: 0.28)],
                iconBg: Color(red: 1.0, green: 0.5, blue: 0.1).opacity(0.12),
                iconColor: Color(red: 1.0, green: 0.5, blue: 0.1)
            )
            simpleMetricCard(
                icon: "figure.strengthtraining.traditional",
                label: "Мышечная масса",
                value: leanBodyMass > 0 ? String(format: "%.1f", leanBodyMass) : "—",
                unit: "кг",
                note: "Тощая масса тела",
                gradientColors: [Color(red: 0.1, green: 0.78, blue: 0.48), Color(red: 0.4, green: 0.8, blue: 0.3)],
                iconBg: Color(red: 0.1, green: 0.78, blue: 0.48).opacity(0.12),
                iconColor: Color(red: 0.1, green: 0.78, blue: 0.48)
            )
        }
    }

    // MARK: Среда и осознанность (Шум, Осознанность)

    private var mindSectionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            simpleMetricCard(
                icon: "ear.fill",
                label: "Уровень шума",
                value: noiseExposure > 0 ? "\(Int(noiseExposure))" : "—",
                unit: "дБ",
                note: noiseExposure > 80 ? "⚠️ Риск для слуха" : "Безопасный уровень",
                gradientColors: noiseExposure > 80
                    ? [Color(red: 0.95, green: 0.25, blue: 0.25), Color(red: 1.0, green: 0.45, blue: 0.1)]
                    : [Color(red: 0.3, green: 0.7, blue: 0.4), Color(red: 0.024, green: 0.714, blue: 0.831)],
                iconBg: (noiseExposure > 80 ? Color(red: 0.95, green: 0.25, blue: 0.25) : Color(red: 0.3, green: 0.7, blue: 0.4)).opacity(0.12),
                iconColor: noiseExposure > 80 ? Color(red: 0.95, green: 0.25, blue: 0.25) : Color(red: 0.3, green: 0.7, blue: 0.4)
            )
            metricCard(
                icon: "brain.head.profile",
                label: "Осознанность",
                value: mindfulMinutes > 0 ? "\(Int(mindfulMinutes))" : "—",
                unit: "мин",
                progress: min(mindfulMinutes / 10, 1),
                target: "Цель: 10 мин/день",
                gradientColors: [Color(red: 0.55, green: 0.35, blue: 1.0), Color(red: 0.8, green: 0.2, blue: 0.6)],
                iconBg: Color(red: 0.55, green: 0.35, blue: 1.0).opacity(0.12),
                iconColor: Color(red: 0.55, green: 0.35, blue: 1.0),
                onTap: nil
            )
        }
    }

    // MARK: - Reusable Components

    @ViewBuilder
    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(cardBg).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.05), radius: 16, x: 0, y: 6)
            RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(cardStroke, lineWidth: 1)
            content()
        }
    }

    // Карточка с прогрессом (оригинальная)
    private func metricCard(
        icon: String, label: String, value: String, unit: String, progress: Double, target: String,
        gradientColors: [Color], iconBg: Color, iconColor: Color, onTap: (() -> Void)? = nil
    ) -> some View {
        let content = VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(iconBg).frame(width: 40, height: 40)
                    Image(systemName: icon).foregroundColor(iconColor).font(.system(size: 18, weight: .semibold))
                }
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(gradientColors[0])
                    .padding(.horizontal, 8).padding(.vertical, 4).background(gradientColors[0].opacity(0.12)).clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value).font(.system(size: 28, weight: .black, design: .rounded)).foregroundColor(primaryText).contentTransition(.numericText())
                    Text(BagytL10n.tr(unit)).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(secondaryText)
                }
                Text(BagytL10n.tr(label)).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(secondaryText)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05)).frame(height: 6)
                        Capsule()
                            .fill(LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing))
                            .frame(width: animateRings ? geo.size.width * CGFloat(progress) : 0, height: 6)
                            .animation(.easeOut(duration: 1.0).delay(0.2), value: animateRings)
                    }
                }.frame(height: 6)
                Text(localizedMetricText(target)).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(secondaryText)
            }
        }
        .padding(18).frame(maxWidth: .infinity, minHeight: 180)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(cardBg).background(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.05), radius: 12, x: 0, y: 5)
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(cardStroke, lineWidth: 1))
        )

        if let action = onTap {
            return AnyView(
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    action()
                }) { content }.buttonStyle(ScaleButtonStyle())
            )
        } else {
            return AnyView(content)
        }
    }

    // Простая карточка без прогресс-бара (для новых метрик без цели)
    private func simpleMetricCard(
        icon: String, label: String, value: String, unit: String, note: String,
        gradientColors: [Color], iconBg: Color, iconColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(iconBg).frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .foregroundColor(iconColor).font(.system(size: 18, weight: .semibold))
                }
                Spacer()
                // Цветная точка-индикатор вместо %
                Circle()
                    .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 10, height: 10)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(primaryText)
                        .contentTransition(.numericText())
                    Text(BagytL10n.tr(unit))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(secondaryText)
                }
                Text(BagytL10n.tr(label))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(secondaryText)
            }

            Spacer(minLength: 0)

            Text(localizedMetricText(note))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(secondaryText)
                .lineLimit(2)
        }
        .padding(18).frame(maxWidth: .infinity, minHeight: 180)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(cardBg).background(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.05), radius: 12, x: 0, y: 5)
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(cardStroke, lineWidth: 1))
        )
    }

    private func ringArc(progress: Double, radius: CGFloat, color: Color, delay: Double) -> some View {
        ZStack {
            Circle().stroke(isDarkMode ? Color.white.opacity(0.05) : color.opacity(0.1), lineWidth: 12).frame(width: radius * 2, height: radius * 2)
            Circle().trim(from: 0, to: CGFloat(progress)).stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .frame(width: radius * 2, height: radius * 2).rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1.2).delay(delay), value: animateRings)
                .animation(.spring(response: 0.6), value: progress)
        }
    }

    private func ringLegend(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Circle().fill(color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(BagytL10n.tr(label)).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(primaryText)
                Text(localizedMetricText(value)).font(.system(size: 12, weight: .medium)).foregroundColor(secondaryText)
            }
        }
    }

    private func miniStat(icon: String, value: String, unit: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundColor(color).font(.system(size: 12))
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.system(size: 16, weight: .black, design: .rounded)).foregroundColor(.white).contentTransition(.numericText())
                Text(BagytL10n.tr(unit)).font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.7))
            }
        }
    }

    private func localizedMetricText(_ text: String) -> String {
        let direct = BagytL10n.tr(text)
        if direct != text { return direct }

        if text.hasPrefix("Цель: ") {
            return "\(BagytL10n.tr("Цель")): \(text.dropFirst(6))"
        }

        return text
    }

    // MARK: - ИМТ хелперы
    private var bmiLabel: String {
        if bmi <= 0 { return BagytL10n.tr("Нет данных") }
        switch bmi {
        case ..<18.5: return BagytL10n.tr("Дефицит веса")
        case 18.5..<25: return BagytL10n.tr("Норма")
        case 25..<30: return BagytL10n.tr("Избыточный вес")
        default: return BagytL10n.tr("Ожирение")
        }
    }

    private var bmiGradient: [Color] {
        if bmi <= 0 { return [Color.gray, Color.gray.opacity(0.6)] }
        switch bmi {
        case ..<18.5: return [Color(red: 0.12, green: 0.56, blue: 0.95), Color(red: 0.024, green: 0.714, blue: 0.831)]
        case 18.5..<25: return [Color(red: 0.1, green: 0.78, blue: 0.48), Color(red: 0.4, green: 0.8, blue: 0.3)]
        case 25..<30: return [Color(red: 1.0, green: 0.6, blue: 0.1), Color(red: 1.0, green: 0.45, blue: 0.1)]
        default: return [Color(red: 0.95, green: 0.25, blue: 0.25), Color(red: 0.8, green: 0.1, blue: 0.1)]
        }
    }
    
    // MARK: - LOCAL Water Logic (History & Averages)
    
    private func getDayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func saveTodayWater(_ amount: Double) {
        let todayStr = getDayString(for: Date())
        var history = UserDefaults.standard.dictionary(forKey: "bagyt_water_history") as? [String: Double] ?? [:]
        history[todayStr] = amount
        UserDefaults.standard.set(history, forKey: "bagyt_water_history")
        UserDefaults.standard.set(todayStr, forKey: "bagyt_water_date")
        UserDefaults.standard.set(amount, forKey: "bagyt_water_consumed")
    }
    
    private func recalculateWaterStats() {
        var history = UserDefaults.standard.dictionary(forKey: "bagyt_water_history") as? [String: Double] ?? [:]
        if history.isEmpty {
            let oldDate = UserDefaults.standard.string(forKey: "bagyt_water_date") ?? ""
            let oldAmount = UserDefaults.standard.double(forKey: "bagyt_water_consumed")
            if !oldDate.isEmpty {
                history[oldDate] = oldAmount
                UserDefaults.standard.set(history, forKey: "bagyt_water_history")
            }
        }
        let todayStr = getDayString(for: Date())
        todayWater = history[todayStr] ?? 0.0
        if selectedPeriod == 0 {
            displayWater = todayWater
        } else {
            let days = selectedPeriod == 1 ? 7 : 30
            var sum = 0.0
            let cal = Calendar.current
            let now = Date()
            for i in 0..<days {
                if let d = cal.date(byAdding: .day, value: -i, to: now) {
                    sum += history[getDayString(for: d)] ?? 0.0
                }
            }
            displayWater = sum / Double(days)
        }
    }

    // MARK: - REAL HealthKit Data Loading

    private func loadRealHealthData() {
        guard HKHealthStore.isHealthDataAvailable() else {
            insight = "Apple Health недоступен на этом устройстве."
            return
        }
        
        var typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            // Новые типы
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
            HKObjectType.quantityType(forIdentifier: .appleStandTime)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.quantityType(forIdentifier: .vo2Max)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
            HKObjectType.quantityType(forIdentifier: .leanBodyMass)!,
            HKObjectType.quantityType(forIdentifier: .bodyMassIndex)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .flightsClimbed)!,
            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .environmentalAudioExposure)!,
            HKObjectType.quantityType(forIdentifier: .walkingSpeed)!,
            HKObjectType.quantityType(forIdentifier: .walkingDoubleSupportPercentage)!,
            HKObjectType.quantityType(forIdentifier: .stairAscentSpeed)!,
            HKObjectType.categoryType(forIdentifier: .mindfulSession)!,
        ]
        
        // wristTemperature доступна только с iOS 17 / watchOS 10
        if #available(iOS 17.0, *) {
            if let tempType = HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
                typesToRead.insert(tempType)
            }
        }
        // bloodPressure — это корреляция, запрашиваем отдельно
        if let sysType = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic),
           let diaType = HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic) {
            typesToRead.insert(sysType)
            typesToRead.insert(diaType)
        }
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, _ in
            if success {
                fetchRealMetrics()
                fetchExtendedMetrics()
            } else {
                DispatchQueue.main.async {
                    insight = "Нет доступа к данным. Пожалуйста, разрешите доступ к Apple Health в настройках."
                }
            }
        }
    }
    
    private func fetchRealMetrics() {
        let cal = Calendar.current
        let now = Date()
        var startDate: Date
        let daysDivisor: Double
        
        switch selectedPeriod {
        case 1:
            startDate = cal.date(byAdding: .day, value: -7, to: now)!
            daysDivisor = 7.0
        case 2:
            startDate = cal.date(byAdding: .day, value: -30, to: now)!
            daysDivisor = 30.0
        default:
            startDate = cal.startOfDay(for: now)
            daysDivisor = 1.0
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        
        // Шаги
        fetchSum(.stepCount, unit: .count(), predicate: predicate, divisor: daysDivisor) { self.steps = $0; self.updateInsight() }
        // Калории
        fetchSum(.activeEnergyBurned, unit: .kilocalorie(), predicate: predicate, divisor: daysDivisor) { self.calories = $0 }
        // Пульс
        fetchAvg(.heartRate, unit: HKUnit(from: "count/min"), predicate: predicate) { self.heartRate = $0; self.updateInsight() }
        
        // Сон
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let sleepQuery = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            var totalSleep: Double = 0
            if let s = samples as? [HKCategorySample] {
                for sample in s {
                    if [HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                        HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                        HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                        HKCategoryValueSleepAnalysis.asleepREM.rawValue].contains(sample.value) {
                        totalSleep += sample.endDate.timeIntervalSince(sample.startDate)
                    }
                }
            }
            let hours = (totalSleep / 3600.0) / daysDivisor
            DispatchQueue.main.async { self.sleepHours = hours; self.updateInsight() }
        }
        healthStore.execute(sleepQuery)
    }

    // MARK: Расширенные метрики Apple Watch

    private func fetchExtendedMetrics() {
        let cal = Calendar.current
        let now = Date()
        var startDate: Date
        let daysDivisor: Double
        
        switch selectedPeriod {
        case 1:
            startDate = cal.date(byAdding: .day, value: -7, to: now)!
            daysDivisor = 7.0
        case 2:
            startDate = cal.date(byAdding: .day, value: -30, to: now)!
            daysDivisor = 30.0
        default:
            startDate = cal.startOfDay(for: now)
            daysDivisor = 1.0
        }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)

        // ВСР (HRV)
        fetchAvg(.heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli), predicate: predicate) { self.hrv = $0 }
        // SpO2
        fetchAvg(.oxygenSaturation, unit: .percent(), predicate: predicate) { self.spo2 = $0 * 100 }
        // ЧД
        fetchAvg(.respiratoryRate, unit: HKUnit(from: "count/min"), predicate: predicate) { self.respiratoryRate = $0 }
        // Стояние
        fetchSum(.appleStandTime, unit: .minute(), predicate: predicate, divisor: daysDivisor * 60) { self.standHours = $0 }
        // Упражнения
        fetchSum(.appleExerciseTime, unit: .minute(), predicate: predicate, divisor: daysDivisor) { self.exerciseMinutes = $0 }
        // VO2Max
        fetchAvg(.vo2Max, unit: HKUnit(from: "ml/kg*min"), predicate: predicate) { self.vo2Max = $0 }
        // Дистанция ходьба/бег
        fetchSum(.distanceWalkingRunning, unit: .meter(), predicate: predicate, divisor: daysDivisor) { self.distanceWalking = $0 }
        // Дистанция велосипед
        fetchSum(.distanceCycling, unit: .meter(), predicate: predicate, divisor: daysDivisor) { self.cyclingDistance = $0 }
        // Этажи
        fetchSum(.flightsClimbed, unit: .count(), predicate: predicate, divisor: daysDivisor) { self.flightsClimbed = $0 }
        // Базальный обмен
        fetchSum(.basalEnergyBurned, unit: .kilocalorie(), predicate: predicate, divisor: daysDivisor) { self.basalEnergy = $0 }
        // Шум
        fetchAvg(.environmentalAudioExposure, unit: HKUnit.decibelAWeightedSoundPressureLevel(), predicate: predicate) { self.noiseExposure = $0 }
        // Скорость ходьбы
        fetchAvg(.walkingSpeed, unit: HKUnit(from: "m/s"), predicate: predicate) { self.walkingSpeed = $0 }
        // Двойная опора
        fetchAvg(.walkingDoubleSupportPercentage, unit: .percent(), predicate: predicate) { self.walkingDoubleSupportPct = $0 * 100 }
        // Скорость подъёма по лестнице
        fetchAvg(.stairAscentSpeed, unit: HKUnit(from: "m/s"), predicate: predicate) { self.stairAscentSpeed = $0 }
        // Масса тела (последнее значение)
        fetchLatest(.bodyMass, unit: .gramUnit(with: .kilo)) { self.bodyMass = $0 }
        // ИМТ
        fetchLatest(.bodyMassIndex, unit: .count()) { self.bmi = $0 }
        // % жира
        fetchLatest(.bodyFatPercentage, unit: .percent()) { self.bodyFat = $0 * 100 }
        // Мышечная масса
        fetchLatest(.leanBodyMass, unit: .gramUnit(with: .kilo)) { self.leanBodyMass = $0 }
        
        // Температура запястья (iOS 17+)
        if #available(iOS 17.0, *) {
            fetchAvg(.appleSleepingWristTemperature, unit: .degreeCelsius(), predicate: predicate) { self.wristTemp = $0 }
        }
        
        // Артериальное давление
        fetchAvg(.bloodPressureSystolic, unit: HKUnit.millimeterOfMercury(), predicate: predicate) { self.systolic = $0 }
        fetchAvg(.bloodPressureDiastolic, unit: HKUnit.millimeterOfMercury(), predicate: predicate) { self.diastolic = $0 }
        
        // Осознанность (mindful)
        let mindType = HKObjectType.categoryType(forIdentifier: .mindfulSession)!
        let mindQuery = HKSampleQuery(sampleType: mindType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            var total = 0.0
            if let s = samples as? [HKCategorySample] {
                for sample in s { total += sample.endDate.timeIntervalSince(sample.startDate) }
            }
            DispatchQueue.main.async { self.mindfulMinutes = (total / 60.0) / daysDivisor }
        }
        healthStore.execute(mindQuery)
    }

    // MARK: - HealthKit Query Helpers

    private func fetchSum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, predicate: NSPredicate, divisor: Double, completion: @escaping (Double) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return }
        let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, r, _ in
            let v = (r?.sumQuantity()?.doubleValue(for: unit) ?? 0) / max(divisor, 1)
            DispatchQueue.main.async { completion(v) }
        }
        healthStore.execute(q)
    }

    private func fetchAvg(_ id: HKQuantityTypeIdentifier, unit: HKUnit, predicate: NSPredicate, completion: @escaping (Double) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return }
        let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, r, _ in
            let v = r?.averageQuantity()?.doubleValue(for: unit) ?? 0
            DispatchQueue.main.async { completion(v) }
        }
        healthStore.execute(q)
    }

    private func fetchLatest(_ id: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping (Double) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
            let v = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit) ?? 0
            DispatchQueue.main.async { completion(v) }
        }
        healthStore.execute(q)
    }

    private func updateInsight() {
        if heartRate > 100 {
            insight = "⚠️ Средний пульс повышен. Рекомендую больше отдыхать и следить за восстановлением."
        } else if steps > 0 && steps < 3000 {
            insight = "🚶 В среднем за этот период мало активности. Добавьте вечерние прогулки, чтобы улучшить кровообращение."
        } else if sleepHours > 0 && sleepHours < 6 {
            insight = "😴 Вы спите меньше нормы. Недостаток сна снижает иммунитет и когнитивные функции."
        } else if steps >= 8000 {
            insight = "💪 Отличные показатели! Вы поддерживаете здоровый баланс активности и отдыха."
        } else {
            insight = "Синхронизация завершена. Чтобы получить точный анализ, носите телефон или часы с собой."
        }
    }

    // MARK: - Helpers

    private var stepsFormatted: String {
        let s = steps > 0 ? steps : 0
        return s >= 1000 ? String(format: "%.1fk", s / 1000) : "\(Int(s))"
    }

    private var scoreIcon: String {
        healthIndexBreakdown.icon
    }

    private var scoreLabel: String {
        healthIndexBreakdown.shortLabel
    }
}

// MARK: - ECG Line View

struct ECGLineView: View {
    let animate: Bool

    private let points: [CGPoint] = [
        CGPoint(x: 0.00, y: 0.50), CGPoint(x: 0.06, y: 0.50), CGPoint(x: 0.09, y: 0.50),
        CGPoint(x: 0.11, y: 0.10), CGPoint(x: 0.13, y: 0.50), CGPoint(x: 0.17, y: 0.50),
        CGPoint(x: 0.19, y: 0.65), CGPoint(x: 0.21, y: 0.02), CGPoint(x: 0.23, y: 0.88),
        CGPoint(x: 0.26, y: 0.50), CGPoint(x: 0.30, y: 0.50), CGPoint(x: 0.33, y: 0.32),
        CGPoint(x: 0.36, y: 0.50), CGPoint(x: 0.43, y: 0.50), CGPoint(x: 0.46, y: 0.50),
        CGPoint(x: 0.49, y: 0.10), CGPoint(x: 0.51, y: 0.50), CGPoint(x: 0.55, y: 0.50),
        CGPoint(x: 0.57, y: 0.65), CGPoint(x: 0.59, y: 0.02), CGPoint(x: 0.61, y: 0.88),
        CGPoint(x: 0.64, y: 0.50), CGPoint(x: 0.68, y: 0.50), CGPoint(x: 0.71, y: 0.32),
        CGPoint(x: 0.74, y: 0.50), CGPoint(x: 0.83, y: 0.50), CGPoint(x: 0.86, y: 0.50),
        CGPoint(x: 0.89, y: 0.10), CGPoint(x: 0.91, y: 0.50), CGPoint(x: 0.95, y: 0.50),
        CGPoint(x: 0.97, y: 0.65), CGPoint(x: 0.985, y: 0.02), CGPoint(x: 1.00, y: 0.50),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
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
                        colors: [Color(red: 0.95, green: 0.25, blue: 0.25).opacity(0.15), Color.clear],
                        startPoint: .top, endPoint: .bottom
                    )
                )

                Path { path in
                    let mapped = points.map { CGPoint(x: $0.x * w, y: $0.y * h) }
                    guard let first = mapped.first else { return }
                    path.move(to: first)
                    for pt in mapped.dropFirst() { path.addLine(to: pt) }
                }
                .trim(from: 0, to: animate ? 1 : 0)
                .stroke(
                    Color(red: 0.95, green: 0.25, blue: 0.25),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )
                .animation(.easeInOut(duration: 1.8).delay(0.3), value: animate)
            }
        }
    }
}

// MARK: - Numeric Format Extension
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
    HealthMetricsView()
        .environmentObject(AppState())
        .environmentObject(LanguageManager())
}
