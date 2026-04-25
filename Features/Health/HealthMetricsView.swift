//
//  HealthMetricsView.swift
//  Bagyt
//
//  Redesigned with full Bagyt Premium design system:
//  Real Apple HealthKit Data · Dynamic Averages · Settings Goals · Dark Mode
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
    
    // MARK: - Local Water State
    // todayWater - Вода за сегодня
    // displayWater - Вода для отображения (за сегодня или среднее за неделю/месяц)
    // tempWater - Временная переменная для WaterView (чтобы не фризило при спаме кнопок)
    @State private var todayWater: Double   = 0
    @State private var displayWater: Double = 0
    @State private var tempWater: Double    = 0
    
    @State private var score: Int           = 0
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
    private let accent  = Color(red: 0.055, green: 0.647, blue: 0.914) // #0EA5E9
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831) // #06B6D4
    
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

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerCard
                    periodPicker
                    ecgCard
                    metricsGrid
                    ringSection
                    insightCard
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
            recalculateWaterStats() // Загрузка воды и расчет средних значений
            loadRealHealthData()
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) { animateRings = true }
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) { animateECG  = true }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulseBeat = true }
        }
        .onChange(of: selectedPeriod) { _ in
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                recalculateWaterStats() // Пересчитываем воду (день/неделя/месяц)
                loadRealHealthData() // Перезагружаем средние значения из Apple Health
            }
        }
        .sheet(isPresented: $showWater, onDismiss: {
            // КОГДА ЗАКРЫВАЕМ ОКНО ВОДЫ: сохраняем результаты и перерисовываем UI
            todayWater = tempWater
            saveTodayWater(todayWater)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                recalculateWaterStats()
                updateScore()
            }
        }) {
            WaterView(consumed: $tempWater)
                .preferredColorScheme(isDarkMode ? .dark : .light)
        }
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
                        Text("Ваше здоровье")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                            .textCase(.uppercase).tracking(1.0)
                        Text(periodSubtitleString())
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.2), lineWidth: 5).frame(width: 58, height: 58)
                        Circle().trim(from: 0, to: animateRings ? CGFloat(score) / 100 : 0)
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .frame(width: 58, height: 58).rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 1.2).delay(0.2), value: animateRings)
                            .animation(.spring(response: 0.8), value: score)
                        Text("\(score)").font(.system(size: 16, weight: .black, design: .rounded)).foregroundColor(.white)
                    }
                }

                Spacer(minLength: 16)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(score)").font(.system(size: 64, weight: .black, design: .rounded)).foregroundColor(.white)
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
                    selectedPeriod = i
                } label: {
                    Text(periods[i])
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
                            Text(selectedPeriod == 0 ? "Сегодня в среднем" : "В среднем за \(periods[selectedPeriod].lowercased())")
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

    // MARK: - Metrics Grid

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
            
            // Вода (Динамическая метрика: Сегодня / В среднем)
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
                    tempWater = todayWater // Передаем только воду за СЕГОДНЯ в WaterView
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
                    Text(insight.isEmpty ? "Ваш пульс в пределах нормы, а активность приближается к цели. Так держать!" : insight)
                        .font(.system(size: 14, weight: .medium)).foregroundColor(primaryText).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
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
                    Text(unit).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(secondaryText)
                }
                Text(label).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(secondaryText)
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
                Text(target).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(secondaryText)
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
                Text(label).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(primaryText)
                Text(value).font(.system(size: 12, weight: .medium)).foregroundColor(secondaryText)
            }
        }
    }

    private func miniStat(icon: String, value: String, unit: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundColor(color).font(.system(size: 12))
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.system(size: 16, weight: .black, design: .rounded)).foregroundColor(.white).contentTransition(.numericText())
                Text(unit).font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.7))
            }
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
        
        // Оставляем старые ключи для обратной совместимости
        UserDefaults.standard.set(todayStr, forKey: "bagyt_water_date")
        UserDefaults.standard.set(amount, forKey: "bagyt_water_consumed")
    }
    
    private func recalculateWaterStats() {
        var history = UserDefaults.standard.dictionary(forKey: "bagyt_water_history") as? [String: Double] ?? [:]
        
        // Миграция старых данных (если словарь пустой, забираем старые сохранения)
        if history.isEmpty {
            let oldDate = UserDefaults.standard.string(forKey: "bagyt_water_date") ?? ""
            let oldAmount = UserDefaults.standard.double(forKey: "bagyt_water_consumed")
            if !oldDate.isEmpty {
                history[oldDate] = oldAmount
                UserDefaults.standard.set(history, forKey: "bagyt_water_history")
            }
        }
        
        let todayStr = getDayString(for: Date())
        todayWater = history[todayStr] ?? 0.0 // Данные за сегодня
        
        // Рассчитываем значение для отображения
        if selectedPeriod == 0 { // День
            displayWater = todayWater
        } else {
            let days = selectedPeriod == 1 ? 7 : 30
            var sum = 0.0
            let cal = Calendar.current
            let now = Date()
            
            for i in 0..<days {
                if let d = cal.date(byAdding: .day, value: -i, to: now) {
                    let dStr = getDayString(for: d)
                    sum += history[dStr] ?? 0.0
                }
            }
            displayWater = sum / Double(days) // Среднее значение
        }
    }

    // MARK: - REAL HealthKit Data Loading

    private func loadRealHealthData() {
        guard HKHealthStore.isHealthDataAvailable() else {
            insight = "Apple Health недоступен на этом устройстве."
            return
        }
        
        let typesToRead: Set = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, _ in
            if success {
                fetchRealMetrics()
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
        case 1: // Неделя
            startDate = cal.date(byAdding: .day, value: -7, to: now)!
            daysDivisor = 7.0
        case 2: // Месяц
            startDate = cal.date(byAdding: .day, value: -30, to: now)!
            daysDivisor = 30.0
        default: // Сегодня
            startDate = cal.startOfDay(for: now)
            daysDivisor = 1.0
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        
        // 1. Шаги
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let stepQuery = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            let sum = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
            DispatchQueue.main.async { self.steps = sum / daysDivisor; self.updateScore() }
        }
        healthStore.execute(stepQuery)
        
        // 2. Калории
        let calType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let calQuery = HKStatisticsQuery(quantityType: calType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            let sum = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
            DispatchQueue.main.async { self.calories = sum / daysDivisor; self.updateScore() }
        }
        healthStore.execute(calQuery)
        
        // 3. Пульс
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let hrQuery = HKStatisticsQuery(quantityType: hrType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, _ in
            let avg = result?.averageQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? 0
            DispatchQueue.main.async { self.heartRate = avg; self.updateScore(); self.updateInsight() }
        }
        healthStore.execute(hrQuery)
        
        // 4. Сон
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let sleepQuery = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            var totalSleep: Double = 0
            if let sleepSamples = samples as? [HKCategorySample] {
                for sample in sleepSamples {
                    if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                       sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                       sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                       sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                        totalSleep += sample.endDate.timeIntervalSince(sample.startDate)
                    }
                }
            }
            let hours = (totalSleep / 3600.0) / daysDivisor
            DispatchQueue.main.async { self.sleepHours = hours; self.updateScore() }
        }
        healthStore.execute(sleepQuery)
    }

    private func updateScore() {
        let s = min(steps / stepsGoal, 1) * 40
        let c = min(calories / caloriesGoal, 1) * 30
        let hrScore = (heartRate >= 60 && heartRate <= 80) ? 30.0 : (heartRate > 0 ? 15.0 : 0.0)
        withAnimation(.easeOut(duration: 0.8)) {
            score = Int(s + c + hrScore)
        }
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

    private func periodSubtitleString() -> String {
        switch selectedPeriod {
        case 1: return "За последние 7 дней"
        case 2: return "За последние 30 дней"
        default: return "Показатели за сегодня"
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
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}


// MARK: - Preview
#Preview {
    HealthMetricsView()
        .environmentObject(AppState())
        .environmentObject(LanguageManager())
}
