import SwiftUI

struct SleepDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var health = HealthKitManager.shared
    
    // Включаем темную тему
    @AppStorage("isDarkModeEnabled") private var isDarkMode = false
    
    // Состояние для автовыбора сегодняшнего дня при загрузке
    @State private var hasAutoSelectedToday = false

    private let accent = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let bg = Color(red: 0.878, green: 0.949, blue: 0.992)

    // Динамические цвета для темной и светлой темы
    private var primaryText: Color { isDarkMode ? .white : Color(red: 0.06, green: 0.09, blue: 0.16) }
    private var secondaryText: Color { isDarkMode ? Color.white.opacity(0.6) : Color(red: 0.4, green: 0.55, blue: 0.65) }
    private var cardBg: Color { isDarkMode ? Color(red: 0.1, green: 0.12, blue: 0.18).opacity(0.85) : Color.white.opacity(0.88) }
    private var cardStroke: Color { isDarkMode ? Color.white.opacity(0.1) : .clear }

    private let chartPhases: [HealthKitManager.SleepPhase] = [.rem, .core, .deep, .unspecified]

    private var selectedDay: HealthKitManager.SleepDay? {
        health.selectedSleepDay
    }

    private var selectedSamples: [HealthKitManager.SleepSample] {
        selectedDay?.segments ?? []
    }

    private var timeRange: (start: Date, end: Date)? {
        guard let start = selectedDay?.start, let end = selectedDay?.end else { return nil }
        return (start, end)
    }

    private var phaseMinutes: [HealthKitManager.SleepPhase: Int] {
        var result: [HealthKitManager.SleepPhase: Int] = [:]
        for phase in HealthKitManager.SleepPhase.allCases { result[phase] = 0 }
        for sample in selectedSamples {
            result[sample.phase, default: 0] += Int(sample.duration / 60)
        }
        return result
    }

    var body: some View {
        ZStack {
            // Динамический фон
            LinearGradient(
                colors: isDarkMode
                    ? [Color(red: 0.04, green: 0.06, blue: 0.10), Color(red: 0.06, green: 0.1, blue: 0.15), Color(red: 0.04, green: 0.06, blue: 0.10)]
                    : [bg, Color(red: 0.941, green: 0.976, blue: 1.0), bg],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        totalCard
                        weekSelectorCard

                        if selectedSamples.isEmpty {
                            emptyState
                        } else {
                            chartCard
                            phasesCard
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear {
            health.fetchAll()
        }
        // 👇 АВТОВЫБОР СЕГОДНЯШНЕГО ДНЯ
        .onChange(of: health.sleepWeek) { week in
            if !hasAutoSelectedToday, !week.isEmpty {
                if let today = week.first(where: { Calendar.current.isDateInToday($0.date) }) {
                    health.selectSleepDay(today)
                }
                hasAutoSelectedToday = true
            }
        }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(isDarkMode ? Color.white.opacity(0.1) : Color.white.opacity(0.75))
                        .frame(width: 40, height: 40)
                        .shadow(color: accent.opacity(0.12), radius: 6, x: 0, y: 2)

                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isDarkMode ? .white.opacity(0.8) : Color(red: 0.3, green: 0.45, blue: 0.6))
                }
            }

            Spacer()

            VStack(spacing: 2) {
                Text("СОН")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(accent.opacity(isDarkMode ? 0.9 : 0.7))
                    .tracking(1.5)

                Text(screenTitle)
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(primaryText)
            }

            Spacer()

            Color.clear
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var totalCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.20, green: 0.35, blue: 0.80),
                            Color(red: 0.40, green: 0.25, blue: 0.70)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(
                    color: Color(red: 0.20, green: 0.35, blue: 0.80).opacity(isDarkMode ? 0.15 : 0.35),
                    radius: 16, x: 0, y: 8
                )

            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 130, height: 130)
                .offset(x: 70, y: -40)

            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 80, height: 80)
                .offset(x: -60, y: 50)

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ОБЩЕЕ ВРЕМЯ")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.75))
                        .tracking(1.0)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        let totalHours = selectedDay?.hours ?? 0
                        let h = Int(totalHours)
                        let m = Int((totalHours - Double(h)) * 60)

                        Text("\(h)")
                            .font(.system(size: 56, weight: .black))
                            .foregroundColor(.white)

                        Text("ч")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.bottom, 6)

                        Text("\(m)")
                            .font(.system(size: 36, weight: .black))
                            .foregroundColor(.white)

                        Text("мин")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.bottom, 4)
                    }

                    if let range = timeRange {
                        HStack(spacing: 16) {
                            Label(fmtTime(range.start), systemImage: "moon.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))

                            Label(fmtTime(range.end), systemImage: "sun.max.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    } else {
                        Text("Нет сна за выбранный день")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 64, height: 64)

                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(24)
        }
    }

    private var weekSelectorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("НЕДЕЛЯ")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(secondaryText)
                .tracking(0.9)

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(cardBg)
                    .shadow(color: isDarkMode ? .clear : accent.opacity(0.08), radius: 12, x: 0, y: 4)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(cardStroke, lineWidth: 1))

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7),
                    spacing: 8
                ) {
                    ForEach(health.sleepWeek) { day in
                        Button {
                            health.selectSleepDay(day)
                        } label: {
                            VStack(spacing: 6) {
                                Text(weekdayShort(day.date))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(isSelected(day) ? .white.opacity(0.85) : secondaryText)

                                Text(dayNumber(day.date))
                                    .font(.system(size: 16, weight: .black))
                                    .foregroundColor(isSelected(day) ? .white : primaryText)

                                Text(day.hasData ? durationCompact(day.hours) : "—")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(isSelected(day) ? .white.opacity(0.85) : day.hasData ? accent : secondaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 74)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        isSelected(day)
                                        ? AnyShapeStyle(
                                            LinearGradient(
                                                colors: [accent, Color(red: 0.024, green: 0.714, blue: 0.831)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        : AnyShapeStyle(isDarkMode ? Color.white.opacity(0.08) : Color(red: 0.95, green: 0.98, blue: 1.0))
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
            }
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ФАЗЫ СНА")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(secondaryText)
                .tracking(0.9)

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(cardBg)
                    .shadow(color: isDarkMode ? .clear : accent.opacity(0.08), radius: 12, x: 0, y: 4)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(cardStroke, lineWidth: 1))

                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        ForEach(HealthKitManager.SleepPhase.allCases, id: \.self) { phase in
                            HStack(spacing: 5) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(phase.color)
                                    .frame(width: 12, height: 10)

                                Text(phase.shortLabel)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(secondaryText)
                            }
                        }
                        Spacer()
                    }

                    GeometryReader { geo in
                        if let range = timeRange {
                            let totalSeconds = max(range.end.timeIntervalSince(range.start), 1)
                            let laneHeight = (geo.size.height - 22) / CGFloat(chartPhases.count)

                            ZStack(alignment: .topLeading) {
                                timeGrid(
                                    range: range,
                                    width: geo.size.width,
                                    height: geo.size.height - 22,
                                    totalSec: totalSeconds
                                )

                                ForEach(Array(chartPhases.enumerated()), id: \.offset) { index, phase in
                                    let top = CGFloat(index) * laneHeight

                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(phase.color.opacity(isDarkMode ? 0.15 : 0.08))
                                        .frame(width: geo.size.width, height: laneHeight * 0.55)
                                        .offset(x: 0, y: top + laneHeight * 0.22)

                                    Text(phase.shortLabel)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(phase.color.opacity(0.7))
                                        .offset(x: 6, y: top + 2)
                                }

                                ForEach(selectedSamples) { sample in
                                    let x = CGFloat(sample.start.timeIntervalSince(range.start) / totalSeconds) * geo.size.width
                                    let width = max(CGFloat(sample.duration / totalSeconds) * geo.size.width, 4)
                                    let y = laneOffset(for: sample.phase, laneHeight: laneHeight)

                                    RoundedRectangle(cornerRadius: min(8, width / 2), style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [sample.phase.color.opacity(0.95), sample.phase.color],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: width, height: laneHeight * 0.55)
                                        .offset(x: x, y: y)
                                }
                            }
                        }
                    }
                    .frame(height: 180)
                }
                .padding(18)
            }
        }
    }

    private func timeGrid(range: (start: Date, end: Date), width: CGFloat, height: CGFloat, totalSec: TimeInterval) -> some View {
        let labels = makeHourLabels(start: range.start, end: range.end)

        return ZStack(alignment: .topLeading) {
            ForEach(labels, id: \.self) { date in
                let x = CGFloat(date.timeIntervalSince(range.start) / totalSec) * width

                Rectangle()
                    .fill(isDarkMode ? Color.white.opacity(0.1) : Color(red: 0.87, green: 0.92, blue: 0.96))
                    .frame(width: 1, height: height)
                    .offset(x: x, y: 0)

                Text(fmtHour(date))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(secondaryText)
                    .frame(width: 28)
                    .offset(x: x - 14, y: height + 2)
            }
        }
    }

    private var phasesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ДЕТАЛИ")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(secondaryText)
                .tracking(0.9)

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(cardBg)
                    .shadow(color: isDarkMode ? .clear : accent.opacity(0.08), radius: 12, x: 0, y: 4)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(cardStroke, lineWidth: 1))

                VStack(spacing: 0) {
                    let phases = HealthKitManager.SleepPhase.allCases
                    ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                        let minutes = phaseMinutes[phase] ?? 0
                        if minutes > 0 {
                            phaseRow(phase: phase, minutes: minutes)

                            if index < phases.count - 1 {
                                Divider()
                                    .background(isDarkMode ? Color.white.opacity(0.1) : .gray.opacity(0.2))
                                    .padding(.leading, 60)
                            }
                        }
                    }
                }
            }
        }
    }

    private func phaseRow(phase: HealthKitManager.SleepPhase, minutes: Int) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(phase.color.opacity(isDarkMode ? 0.2 : 0.14))
                    .frame(width: 38, height: 38)

                Image(systemName: phaseIcon(phase))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(phase.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(phase.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(primaryText)

                Text(phase.description)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(durationText(minutes: minutes))
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(phase.color)

                let totalMinutes = max(phaseMinutes.values.reduce(0, +), 1)
                let progress = CGFloat(minutes) / CGFloat(totalMinutes)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(phase.color.opacity(0.12))
                        .frame(width: 80, height: 4)

                    Capsule()
                        .fill(phase.color)
                        .frame(width: 80 * progress, height: 4)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(Color(red: 0.55, green: 0.35, blue: 1.0).opacity(isDarkMode ? 0.8 : 0.4))

            Text("Нет данных о сне")
                .font(.system(size: 18, weight: .black))
                .foregroundColor(primaryText)

            Text("Проверьте доступ к HealthKit и отслеживание сна на Apple Watch или iPhone. Выберите другой день недели, если сон был записан не сегодня.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardBg)
                .shadow(color: isDarkMode ? .clear : accent.opacity(0.08), radius: 12, x: 0, y: 4)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(cardStroke, lineWidth: 1))
        )
    }

    private func isSelected(_ day: HealthKitManager.SleepDay) -> Bool {
        guard let selectedDay else { return false }
        return Calendar.current.isDate(day.date, inSameDayAs: selectedDay.date)
    }

    private var screenTitle: String {
        guard let selectedDay else { return "Сон за неделю" }
        if Calendar.current.isDateInToday(selectedDay.date) { return "Сегодня" }
        if Calendar.current.isDateInYesterday(selectedDay.date) { return "Вчера" }
        return fullDayFormatter.string(from: selectedDay.date)
    }

    private func laneOffset(for phase: HealthKitManager.SleepPhase, laneHeight: CGFloat) -> CGFloat {
        let index = chartPhases.firstIndex(of: phase) ?? (chartPhases.count - 1)
        return CGFloat(index) * laneHeight + laneHeight * 0.22
    }

    private func makeHourLabels(start: Date, end: Date) -> [Date] {
        let calendar = Calendar.current
        let totalHours = max(end.timeIntervalSince(start) / 3600, 1)
        let step = totalHours > 10 ? 2 : 1

        var labels: [Date] = []
        var cursor = calendar.date(bySetting: .minute, value: 0, of: start) ?? start
        if cursor < start { cursor = calendar.date(byAdding: .hour, value: 1, to: cursor) ?? cursor }

        while cursor <= end {
            labels.append(cursor)
            cursor = calendar.date(byAdding: .hour, value: step, to: cursor) ?? cursor
        }
        return labels
    }

    private func weekdayShort(_ date: Date) -> String {
        weekdayFormatter.string(from: date).uppercased()
    }

    private func dayNumber(_ date: Date) -> String {
        dayNumberFormatter.string(from: date)
    }

    private func durationCompact(_ hours: Double) -> String {
        let totalMinutes = Int(hours * 60)
        if totalMinutes <= 0 { return "—" }

        let h = totalMinutes / 60
        let m = totalMinutes % 60

        if h > 0 && m > 0 { return "\(h)ч \(m)м" }
        if h > 0 { return "\(h)ч" }
        return "\(m)м"
    }

    private func durationText(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 { return "\(h)ч \(m)мин" }
        return "\(m) мин"
    }

    private func phaseIcon(_ phase: HealthKitManager.SleepPhase) -> String {
        switch phase {
        case .deep: return "zzz"
        case .rem: return "brain.head.profile"
        case .core: return "moon.fill"
        case .unspecified: return "moon.stars.fill"
        }
    }

    private func fmtTime(_ date: Date) -> String { timeFormatter.string(from: date) }
    private func fmtHour(_ date: Date) -> String { hourFormatter.string(from: date) }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter(); f.locale = Locale(identifier: "ru_RU"); f.dateFormat = "HH:mm"; return f
    }
    private var hourFormatter: DateFormatter {
        let f = DateFormatter(); f.locale = Locale(identifier: "ru_RU"); f.dateFormat = "HH"; return f
    }
    private var weekdayFormatter: DateFormatter {
        let f = DateFormatter(); f.locale = Locale(identifier: "ru_RU"); f.dateFormat = "EE"; return f
    }
    private var dayNumberFormatter: DateFormatter {
        let f = DateFormatter(); f.locale = Locale(identifier: "ru_RU"); f.dateFormat = "d"; return f
    }
    private var fullDayFormatter: DateFormatter {
        let f = DateFormatter(); f.locale = Locale(identifier: "ru_RU"); f.dateFormat = "d MMMM"; return f
    }
}

#Preview {
    SleepDetailView()
}
