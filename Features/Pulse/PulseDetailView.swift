import SwiftUI
import Combine
import UIKit
import HealthKit

struct PulseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PulseDetailViewModel()
    
    // Включаем темную тему
    @AppStorage("isDarkModeEnabled") private var isDarkMode = false

    private let accent = Color(red: 0.95, green: 0.25, blue: 0.25)
    private let accent2 = Color(red: 1.0, green: 0.42, blue: 0.38)
    private let accent3 = Color(red: 1.0, green: 0.72, blue: 0.72)
    private let bg = Color(red: 0.995, green: 0.95, blue: 0.96)
    
    // Динамическая палитра
    private var primaryText: Color { isDarkMode ? .white : Color(red: 0.16, green: 0.08, blue: 0.12) }
    private var secondaryText: Color { isDarkMode ? .white.opacity(0.6) : Color(red: 0.64, green: 0.50, blue: 0.56) }
    private var cardBg: Color { isDarkMode ? Color(red: 0.12, green: 0.08, blue: 0.10).opacity(0.85) : Color.white.opacity(0.92) }
    private var cardStroke: Color { isDarkMode ? Color.white.opacity(0.1) : .clear }

    var body: some View {
        ZStack {
            // Динамический фон
            LinearGradient(
                colors: isDarkMode
                    ? [Color(red: 0.08, green: 0.04, blue: 0.05), Color(red: 0.05, green: 0.02, blue: 0.03), Color(red: 0.04, green: 0.01, blue: 0.02)]
                    : [bg, Color.white, Color(red: 1.0, green: 0.97, blue: 0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        summaryCard
                        weekCard

                        if viewModel.selectedDay?.samples.isEmpty == false {
                            ecgCard
                            statsCard
                        } else {
                            emptyState
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear {
            viewModel.load()
        }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(isDarkMode ? Color.white.opacity(0.1) : Color.white.opacity(0.82))
                        .frame(width: 40, height: 40)
                        .shadow(color: accent.opacity(0.12), radius: 6, x: 0, y: 2)

                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isDarkMode ? .white.opacity(0.8) : Color(red: 0.45, green: 0.33, blue: 0.36))
                }
            }

            Spacer()

            VStack(spacing: 2) {
                Text("ПУЛЬС")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(accent.opacity(isDarkMode ? 0.9 : 0.75))
                    .tracking(1.5)

                Text(viewModel.titleText)
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

    private var summaryCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent, accent2],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: accent.opacity(isDarkMode ? 0.15 : 0.32), radius: 18, x: 0, y: 8)

            Circle()
                .fill(Color.white.opacity(0.09))
                .frame(width: 160, height: 160)
                .offset(x: 78, y: -44)

            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 96, height: 96)
                .offset(x: -60, y: 58)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("СРЕДНЯЯ ЧСС")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.76))
                        .tracking(1.0)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(viewModel.selectedDay?.averageText ?? "—")
                            .font(.system(size: 56, weight: .black))
                            .foregroundColor(.white)

                        Text("уд/мин")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.78))
                            .padding(.bottom, 7)
                    }

                    HStack(spacing: 16) {
                        infoPill(title: "Мин.", value: viewModel.selectedDay?.minShortText ?? "—")
                        infoPill(title: "Макс.", value: viewModel.selectedDay?.maxShortText ?? "—")
                        infoPill(title: "Тек.", value: viewModel.selectedDay?.latestShortText ?? "—")
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.17))
                        .frame(width: 68, height: 68)

                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(24)
        }
    }

    private func infoPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.72))

            Text(value)
                .font(.system(size: 14, weight: .black))
                .foregroundColor(.white)
        }
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("НЕДЕЛЬНАЯ СВОДКА")
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
                    ForEach(viewModel.week) { day in
                        Button {
                            viewModel.select(day)
                        } label: {
                            VStack(spacing: 6) {
                                Text(viewModel.shortWeekday(day.date))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(
                                        viewModel.isSelected(day)
                                        ? .white.opacity(0.86)
                                        : secondaryText
                                    )

                                Text(viewModel.dayNumber(day.date))
                                    .font(.system(size: 16, weight: .black))
                                    .foregroundColor(
                                        viewModel.isSelected(day)
                                        ? .white
                                        : primaryText
                                    )

                                Text(day.hasData ? day.averageText : "—")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(
                                        viewModel.isSelected(day)
                                        ? .white.opacity(0.86)
                                        : day.hasData
                                            ? accent
                                            : secondaryText.opacity(0.6)
                                    )
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 74)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        viewModel.isSelected(day)
                                        ? AnyShapeStyle(
                                            LinearGradient(
                                                colors: [accent, accent2],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        : AnyShapeStyle(isDarkMode ? Color.white.opacity(0.08) : Color(red: 0.99, green: 0.96, blue: 0.97))
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

    private var ecgCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ГРАФИК СЕРДЕЧНОГО РИТМА")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(secondaryText)
                .tracking(0.9)

            ZStack {
                // График всегда темный, чтобы выглядеть как медицинский монитор
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.15, green: 0.07, blue: 0.09),
                                Color(red: 0.10, green: 0.04, blue: 0.06),
                                Color(red: 0.08, green: 0.03, blue: 0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: accent.opacity(isDarkMode ? 0.1 : 0.24), radius: 20, x: 0, y: 10)

                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 220, height: 220)
                    .blur(radius: 30)
                    .offset(x: -120, y: -110)

                Circle()
                    .fill(accent3.opacity(0.12))
                    .frame(width: 170, height: 170)
                    .blur(radius: 24)
                    .offset(x: 130, y: 70)

                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Амплитуда ритма")
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(.white)

                            Text("Коснитесь графика для просмотра ЧСС в выбранный момент времени")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.66))
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(accent3)
                                    .frame(width: 8, height: 8)

                                Text("АНАЛИЗ ЧСС")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color.white.opacity(0.82))
                            }

                            Text(viewModel.selectedDay?.peakBadgeText ?? "Максимум не найден")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(accent3)
                        }
                    }

                    PulseInteractiveECGChart(
                        samples: viewModel.selectedDay?.samples ?? [],
                        accent: accent,
                        accent2: accent2,
                        accent3: accent3
                    )

                    HStack {
                        Text(viewModel.selectedDay?.startLabel ?? "00:00")
                        Spacer()
                        Text("06:00")
                        Spacer()
                        Text("12:00")
                        Spacer()
                        Text("18:00")
                        Spacer()
                        Text(viewModel.selectedDay?.endLabel ?? "23:59")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.40))
                }
                .padding(20)
            }
        }
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("КЛЮЧЕВЫЕ ПОКАЗАТЕЛИ")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(secondaryText)
                .tracking(0.9)

            VStack(spacing: 12) {
                statRow(icon: "heart.fill", color: accent, title: "Средняя ЧСС", value: viewModel.selectedDay?.averageFullText ?? "—")
                statRow(icon: "arrow.down.heart.fill", color: Color(red: 1.0, green: 0.55, blue: 0.55), title: "Мин. ЧСС", value: viewModel.selectedDay?.minFullText ?? "—")
                statRow(icon: "arrow.up.heart.fill", color: Color(red: 1.0, green: 0.40, blue: 0.40), title: "Макс. ЧСС", value: viewModel.selectedDay?.maxFullText ?? "—")
                statRow(icon: "bed.double.fill", color: Color(red: 0.75, green: 0.60, blue: 1.0), title: "ЧСС в покое", value: viewModel.restingHeartRateText)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(cardBg)
                    .shadow(color: isDarkMode ? .clear : accent.opacity(0.08), radius: 12, x: 0, y: 4)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(cardStroke, lineWidth: 1))
            )
        }
    }

    private func statRow(icon: String, color: Color, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(isDarkMode ? 0.2 : 0.12))
                    .frame(width: 42, height: 42)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(primaryText)
                Text("Данные телеметрии HealthKit")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(secondaryText)
            }

            Spacer()

            Text(value)
                .font(.system(size: 16, weight: .black))
                .foregroundColor(color)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash.fill")
                .font(.system(size: 46, weight: .light))
                .foregroundColor(accent.opacity(isDarkMode ? 0.6 : 0.35))

            Text("Нет данных телеметрии ЧСС")
                .font(.system(size: 18, weight: .black))
                .foregroundColor(primaryText)

            Text("Убедитесь, что Apple Watch или совместимое устройство синхронизирует измерения пульса с HealthKit.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(36)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardBg)
                .shadow(color: isDarkMode ? .clear : accent.opacity(0.08), radius: 12, x: 0, y: 4)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(cardStroke, lineWidth: 1))
        )
    }
}

private struct PulseInteractiveECGChart: View {
    let samples: [PulseDaySample]
    let accent: Color
    let accent2: Color
    let accent3: Color

    @State private var selectedIndex: Int?
    @AppStorage("isDarkModeEnabled") private var isDarkMode = false

    private var sortedSamples: [PulseDaySample] {
        samples.sorted { $0.date < $1.date }
    }

    private var minValue: Double {
        (sortedSamples.map(\.bpm).min() ?? 60) - 6
    }

    private var maxValue: Double {
        (sortedSamples.map(\.bpm).max() ?? 100) + 6
    }

    var body: some View {
        GeometryReader { geo in
            let points = makePoints(in: geo.size)
            let selectedPoint = currentPoint(from: points)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.025))

                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)
                        Spacer()
                    }
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                }
                .padding(.vertical, 10)

                HStack(spacing: geo.size.width / 8) {
                    ForEach(0..<8, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 1)
                    }
                }

                if points.count >= 2 {
                    fillPath(points: points, size: geo.size)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.24), accent.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    linePath(points: points)
                        .stroke(accent.opacity(0.22), style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                        .blur(radius: 8)

                    linePath(points: points)
                        .stroke(
                            LinearGradient(
                                colors: [accent2, accent3, Color.white],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                        )

                    ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                        if index % 3 == 0 {
                            Circle()
                                .fill(Color.white.opacity(0.82))
                                .frame(width: 3.5, height: 3.5)
                                .position(point)
                        }
                    }

                    if let selected = selectedPoint {
                        Rectangle()
                            .fill(accent3.opacity(0.45))
                            .frame(width: 1.5, height: geo.size.height)
                            .position(x: selected.point.x, y: geo.size.height / 2)

                        Circle()
                            .fill(Color.white)
                            .frame(width: 18, height: 18)
                            .shadow(color: accent3.opacity(0.7), radius: 12, x: 0, y: 0)
                            .position(selected.point)

                        Circle()
                            .stroke(accent3, lineWidth: 3)
                            .frame(width: 28, height: 28)
                            .position(selected.point)

                        selectionBubble(for: selected.sample, chartSize: geo.size)
                            .position(
                                x: min(max(selected.point.x, 64), geo.size.width - 64),
                                y: max(selected.point.y - 42, 26)
                            )
                    } else if let last = points.last, let sample = sortedSamples.last {
                        Circle()
                            .fill(accent3)
                            .frame(width: 12, height: 12)
                            .shadow(color: accent3.opacity(0.7), radius: 10, x: 0, y: 0)
                            .position(last)

                        selectionBubble(for: sample, chartSize: geo.size)
                            .position(
                                x: min(max(last.x, 64), geo.size.width - 64),
                                y: max(last.y - 42, 26)
                            )
                    }
                } else {
                    Text("Недостаточно замеров для формирования графика")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.58))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !points.isEmpty else { return }
                        selectedIndex = nearestIndex(to: value.location.x, points: points)
                    }
                    .onEnded { _ in }
            )
        }
        .frame(height: 250)
    }

    private func selectionBubble(for sample: PulseDaySample, chartSize: CGSize) -> some View {
        VStack(spacing: 4) {
            Text("\(Int(sample.bpm.rounded())) уд/мин")
                .font(.system(size: 11, weight: .black))
                .foregroundColor(isDarkMode ? .white : Color(red: 0.16, green: 0.08, blue: 0.12))

            Text(sample.timeText)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isDarkMode ? Color(red: 0.18, green: 0.12, blue: 0.14) : Color.white)
        )
        .shadow(color: accent.opacity(isDarkMode ? 0.5 : 0.25), radius: 12, x: 0, y: 6)
    }

    private func currentPoint(from points: [CGPoint]) -> (sample: PulseDaySample, point: CGPoint)? {
        guard let selectedIndex,
              selectedIndex >= 0,
              selectedIndex < points.count,
              selectedIndex < sortedSamples.count else {
            return nil
        }

        return (sortedSamples[selectedIndex], points[selectedIndex])
    }

    private func nearestIndex(to x: CGFloat, points: [CGPoint]) -> Int {
        points.enumerated().min { abs($0.element.x - x) < abs($1.element.x - x) }?.offset ?? 0
    }

    private func makePoints(in size: CGSize) -> [CGPoint] {
        guard !sortedSamples.isEmpty else { return [] }

        let start = sortedSamples.first?.date ?? Date()
        let end = sortedSamples.last?.date ?? Date().addingTimeInterval(1)
        let total = max(end.timeIntervalSince(start), 1)
        let range = max(maxValue - minValue, 1)

        return sortedSamples.map { sample in
            let x = CGFloat(sample.date.timeIntervalSince(start) / total) * size.width
            let progress = (sample.bpm - minValue) / range
            let y = size.height - CGFloat(progress) * (size.height - 28) - 14
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }

        path.move(to: first)

        if points.count == 2 {
            path.addLine(to: points[1])
            return path
        }

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let mid = CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2)

            path.addQuadCurve(to: mid, control: CGPoint(x: mid.x, y: previous.y))
            path.addQuadCurve(to: current, control: CGPoint(x: mid.x, y: current.y))
        }

        return path
    }

    private func fillPath(points: [CGPoint], size: CGSize) -> Path {
        var path = linePath(points: points)
        guard let last = points.last, let first = points.first else { return path }
        path.addLine(to: CGPoint(x: last.x, y: size.height))
        path.addLine(to: CGPoint(x: first.x, y: size.height))
        path.closeSubpath()
        return path
    }
}

private final class PulseDetailViewModel: ObservableObject {
    @Published var week: [PulseDay] = []
    @Published var selectedDay: PulseDay?
    @Published var restingHeartRate: Double = 0

    private let store = HKHealthStore()

    func load() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let readTypes: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
        ]

        store.requestAuthorization(toShare: [], read: readTypes) { [weak self] success, _ in
            guard success else { return }
            self?.fetchWeek()
            self?.fetchRestingHeartRate()
        }
    }

    func select(_ day: PulseDay) {
        selectedDay = day
    }

    func isSelected(_ day: PulseDay) -> Bool {
        guard let selectedDay else { return false }
        return Calendar.current.isDate(day.date, inSameDayAs: selectedDay.date)
    }

    var titleText: String {
        guard let selectedDay else { return BagytL10n.tr("Пульс") }
        if Calendar.current.isDateInToday(selectedDay.date) { return BagytL10n.tr("Сегодня") }
        if Calendar.current.isDateInYesterday(selectedDay.date) { return BagytL10n.tr("Вчера") }
        return fullDateFormatter.string(from: selectedDay.date)
    }

    var restingHeartRateText: String {
        restingHeartRate > 0 ? "\(Int(restingHeartRate.rounded())) \(BagytL10n.tr("уд/мин"))" : "—"
    }

    func shortWeekday(_ date: Date) -> String {
        shortWeekdayFormatter.string(from: date).uppercased()
    }

    func dayNumber(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    private func fetchWeek() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        let calendar = Self.weekCalendar
        let weekStart = currentWeekStart(calendar: calendar)
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? Date()

        let predicate = HKQuery.predicateForSamples(withStart: weekStart, end: weekEnd, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sort]
        ) { [weak self] _, samples, _ in
            guard let self else { return }

            let unit = HKUnit.count().unitDivided(by: .minute())
            let quantitySamples = (samples as? [HKQuantitySample]) ?? []

            let mapped: [PulseDaySample] = quantitySamples.map {
                PulseDaySample(date: $0.startDate, bpm: $0.quantity.doubleValue(for: unit))
            }

            let grouped = Dictionary(grouping: mapped) { calendar.startOfDay(for: $0.date) }

            let days: [PulseDay] = (0..<7).compactMap { index in
                guard let date = calendar.date(byAdding: .day, value: index, to: weekStart) else { return nil }
                let dayStart = calendar.startOfDay(for: date)
                let samples = (grouped[dayStart] ?? []).sorted { $0.date < $1.date }
                return PulseDay(date: dayStart, samples: samples)
            }

            let today = days.first(where: { Calendar.current.isDateInToday($0.date) && $0.hasData })
            let fallback = days.last(where: { $0.hasData })

            DispatchQueue.main.async {
                self.week = days
                self.selectedDay = today ?? fallback ?? days.last
            }
        }

        store.execute(query)
    }

    private func fetchRestingHeartRate() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return }

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: type,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sort]
        ) { [weak self] _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else { return }

            let unit = HKUnit.count().unitDivided(by: .minute())
            let value = sample.quantity.doubleValue(for: unit)

            DispatchQueue.main.async {
                self?.restingHeartRate = value
            }
        }

        store.execute(query)
    }

    private func currentWeekStart(calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let shift = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -shift, to: today) ?? today
    }

    private static var weekCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = BagytL10n.currentLocale
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    private var shortWeekdayFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = BagytL10n.currentLocale
        f.dateFormat = "EE"
        return f
    }

    private var dayFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = BagytL10n.currentLocale
        f.dateFormat = "d"
        return f
    }

    private var fullDateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = BagytL10n.currentLocale
        f.dateFormat = "d MMMM"
        return f
    }
}

private struct PulseDaySample: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let bpm: Double

    var timeText: String {
        let formatter = DateFormatter()
        formatter.locale = BagytL10n.currentLocale
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

private struct PulseDay: Identifiable, Hashable {
    let date: Date
    let samples: [PulseDaySample]

    var id: Date { date }
    var hasData: Bool { !samples.isEmpty }

    var average: Double {
        guard !samples.isEmpty else { return 0 }
        return samples.map(\.bpm).reduce(0, +) / Double(samples.count)
    }

    var minValue: Double {
        samples.map(\.bpm).min() ?? 0
    }

    var maxValue: Double {
        samples.map(\.bpm).max() ?? 0
    }

    var latestValue: Double {
        samples.last?.bpm ?? 0
    }

    var peakSample: PulseDaySample? {
        samples.max(by: { $0.bpm < $1.bpm })
    }

    var averageText: String {
        hasData ? "\(Int(average.rounded()))" : "—"
    }

    var averageFullText: String {
        hasData ? "\(Int(average.rounded())) \(BagytL10n.tr("уд/мин"))" : "—"
    }

    var minShortText: String {
        hasData ? "\(Int(minValue.rounded()))" : "—"
    }

    var maxShortText: String {
        hasData ? "\(Int(maxValue.rounded()))" : "—"
    }

    var latestShortText: String {
        hasData ? "\(Int(latestValue.rounded()))" : "—"
    }

    var minFullText: String {
        hasData ? "\(Int(minValue.rounded())) \(BagytL10n.tr("уд/мин"))" : "—"
    }

    var maxFullText: String {
        hasData ? "\(Int(maxValue.rounded())) \(BagytL10n.tr("уд/мин"))" : "—"
    }

    var peakBadgeText: String {
        guard let peakSample else { return BagytL10n.tr("Максимум не зафиксирован") }
        return String(format: BagytL10n.tr("Макс.: %d в %@"), Int(peakSample.bpm.rounded()), peakSample.timeText)
    }

    var startLabel: String {
        samples.first?.timeText ?? "00:00"
    }

    var endLabel: String {
        samples.last?.timeText ?? "23:59"
    }
}

#Preview {
    PulseDetailView()
}
