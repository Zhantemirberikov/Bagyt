//
//  StepsDetailView.swift
//  Bagyt
//
//  Created by Жантемир Бериков on 23.04.2026.
//

import SwiftUI
import Combine
import UIKit
import HealthKit

struct StepsDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = StepsDetailViewModel()

    // Включаем темную тему
    @AppStorage("isDarkModeEnabled") private var isDarkMode = false

    private let accent = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)
    private let accent3 = Color(red: 0.36, green: 0.90, blue: 1.0)
    private let bg = Color(red: 0.93, green: 0.98, blue: 1.0)

    // Динамическая палитра
    private var primaryText: Color { isDarkMode ? .white : Color(red: 0.05, green: 0.12, blue: 0.18) }
    private var secondaryText: Color { isDarkMode ? .white.opacity(0.6) : Color(red: 0.42, green: 0.60, blue: 0.68) }
    private var cardBg: Color { isDarkMode ? Color(red: 0.08, green: 0.12, blue: 0.16).opacity(0.85) : Color.white.opacity(0.92) }
    private var cardStroke: Color { isDarkMode ? Color.white.opacity(0.1) : .clear }

    var body: some View {
        ZStack {
            // Динамический фон
            LinearGradient(
                colors: isDarkMode
                    ? [Color(red: 0.04, green: 0.08, blue: 0.12), Color(red: 0.02, green: 0.05, blue: 0.08), Color(red: 0.01, green: 0.03, blue: 0.05)]
                    : [bg, Color.white, Color(red: 0.95, green: 0.99, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        totalCard
                        weekCard

                        if viewModel.selectedDay != nil {
                            hourlyCard
                            detailsCard
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
                        .foregroundColor(isDarkMode ? .white.opacity(0.8) : Color(red: 0.29, green: 0.45, blue: 0.55))
                }
            }

            Spacer()

            VStack(spacing: 2) {
                Text(BagytL10n.tr("ШАГИ"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(accent.opacity(isDarkMode ? 0.9 : 0.75))
                    .tracking(1.5)

                Text(viewModel.titleText)
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(primaryText)
            }

            Spacer()

            Color.clear.frame(width: 40, height: 40)
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
                        colors: [accent, accent2],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: accent.opacity(isDarkMode ? 0.15 : 0.32), radius: 18, x: 0, y: 8)

            Circle()
                .fill(Color.white.opacity(0.09))
                .frame(width: 150, height: 150)
                .offset(x: 76, y: -42)

            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 94, height: 94)
                .offset(x: -60, y: 56)

            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(BagytL10n.tr("СУММАРНО ШАГОВ"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.78))
                        .tracking(1.0)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(viewModel.selectedDay?.formattedSteps ?? "—")
                            .font(.system(size: 54, weight: .black))
                            .foregroundColor(.white)

                        Text(BagytL10n.tr("шагов"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.78))
                            .padding(.bottom, 6)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Text("\(BagytL10n.tr("Цель")) \(viewModel.goalText)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.88))

                            Text(viewModel.progressText)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.16))
                                .frame(width: 180, height: 8)

                            Capsule()
                                .fill(Color.white)
                                .frame(width: 180 * viewModel.progressValue, height: 8)
                        }
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 66, height: 66)

                    Image(systemName: "figure.walk.motion")
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(24)
        }
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(BagytL10n.tr("НЕДЕЛЬНАЯ СВОДКА"))
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

                                Text(day.steps > 0 ? day.compactSteps : "—")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(
                                        viewModel.isSelected(day)
                                        ? .white.opacity(0.86)
                                        : day.steps > 0
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
                                        : AnyShapeStyle(isDarkMode ? Color.white.opacity(0.08) : Color(red: 0.95, green: 0.99, blue: 1.0))
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

    private var hourlyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(BagytL10n.tr("ПОЧАСОВОЙ ГРАФИК АКТИВНОСТИ"))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(secondaryText)
                .tracking(0.9)

            ZStack {
                // График всегда темный
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.07, green: 0.16, blue: 0.22),
                                Color(red: 0.03, green: 0.11, blue: 0.19),
                                Color(red: 0.02, green: 0.09, blue: 0.17)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: accent.opacity(isDarkMode ? 0.1 : 0.22), radius: 20, x: 0, y: 10)

                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 220, height: 220)
                    .blur(radius: 30)
                    .offset(x: -110, y: -120)

                Circle()
                    .fill(accent3.opacity(0.12))
                    .frame(width: 180, height: 180)
                    .blur(radius: 26)
                    .offset(x: 120, y: 60)

                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(BagytL10n.tr("Динамика активности"))
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(.white)

                            Text(BagytL10n.tr("Коснитесь графика для просмотра количества шагов в выбранный час"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.66))
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(accent3)
                                    .frame(width: 8, height: 8)
                                Text(BagytL10n.tr("АНАЛИЗ ДАННЫХ"))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color.white.opacity(0.82))
                            }

                            Text(viewModel.bestHourBadgeText)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(accent3.opacity(0.95))
                        }
                    }

                    StepsInteractiveRhythmChart(
                        data: viewModel.hourly,
                        accent: accent,
                        accent2: accent2,
                        accent3: accent3
                    )

                    HStack {
                        Text("00")
                        Spacer()
                        Text("06")
                        Spacer()
                        Text("12")
                        Spacer()
                        Text("18")
                        Spacer()
                        Text("23")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.40))
                }
                .padding(20)
            }
        }
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(BagytL10n.tr("КЛЮЧЕВЫЕ ПОКАЗАТЕЛИ"))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(secondaryText)
                .tracking(0.9)

            VStack(spacing: 12) {
                detailRow(
                    icon: "flag.checkered.2.crossed",
                    color: accent,
                    title: "Выполнение дневной нормы",
                    value: viewModel.progressText
                )

                detailRow(
                    icon: "clock.fill",
                    color: Color(red: 0.22, green: 0.68, blue: 0.82),
                    title: "Пиковая активность",
                    value: viewModel.bestHourText
                )

                detailRow(
                    icon: "flame.fill",
                    color: Color(red: 1.0, green: 0.58, blue: 0.22),
                    title: "Часы активности (≥250)",
                    value: viewModel.activeHoursText
                )

                detailRow(
                    icon: "chart.bar.fill",
                    color: Color(red: 0.36, green: 0.58, blue: 0.96),
                    title: "Среднее значение за неделю",
                    value: viewModel.weekAverageText
                )
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

    private func detailRow(icon: String, color: Color, title: String, value: String) -> some View {
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
                Text(BagytL10n.tr("Данные телеметрии HealthKit"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(secondaryText)
            }

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .black))
                .foregroundColor(color)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.walk.motion")
                .font(.system(size: 46, weight: .light))
                .foregroundColor(accent.opacity(isDarkMode ? 0.6 : 0.35))

            Text(BagytL10n.tr("Нет данных телеметрии активности"))
                .font(.system(size: 18, weight: .black))
                .foregroundColor(primaryText)

            Text(BagytL10n.tr("Убедитесь, что Apple Watch или совместимое устройство синхронизирует измерения активности с HealthKit."))
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

private struct StepsInteractiveRhythmChart: View {
    let data: [HourlySteps]
    let accent: Color
    let accent2: Color
    let accent3: Color

    @State private var selectedIndex: Int?
    @AppStorage("isDarkModeEnabled") private var isDarkMode = false

    private var maxSteps: Double {
        Double(max(data.map(\.steps).max() ?? 1, 1))
    }

    private var peakHour: HourlySteps? {
        data.max(by: { $0.steps < $1.steps })
    }

    var body: some View {
        GeometryReader { geo in
            let chartHeight = geo.size.height
            let chartWidth = geo.size.width
            let spacing: CGFloat = 4
            let count = max(data.count, 1)
            let barWidth = max((chartWidth - spacing * CGFloat(count - 1)) / CGFloat(count), 6)
            let selected = currentSelection(barWidth: barWidth, spacing: spacing, size: geo.size)

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.02))

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

                if let peakHour,
                   peakHour.steps > 0,
                   let peakIndex = data.firstIndex(where: { $0.id == peakHour.id }) {
                    let x = CGFloat(peakIndex) * (barWidth + spacing) + barWidth / 2

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accent3.opacity(0.0), accent3.opacity(0.22), accent3.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: max(barWidth + 12, 18), height: chartHeight)
                        .offset(x: x - max(barWidth + 12, 18) / 2)
                        .blur(radius: 6)
                }

                if let selected {
                    Rectangle()
                        .fill(accent3.opacity(0.42))
                        .frame(width: 1.5, height: chartHeight)
                        .position(x: selected.x, y: chartHeight / 2)
                }

                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(Array(data.enumerated()), id: \.element.id) { index, hour in
                        let ratio = CGFloat(Double(hour.steps) / maxSteps)
                        let baseHeight: CGFloat = 8
                        let barHeight = hour.steps > 0
                            ? max(baseHeight + ratio * (chartHeight - 52), 14)
                            : 4
                        let isSelected = selected?.index == index

                        ZStack(alignment: .top) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .frame(width: barWidth, height: chartHeight - 18)

                            VStack(spacing: 0) {
                                Spacer(minLength: 0)

                                ZStack(alignment: .top) {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: hour.steps > 0
                                                    ? [accent3, accent2, accent]
                                                    : [Color.white.opacity(0.12), Color.white.opacity(0.08)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(width: barWidth, height: barHeight)
                                        .shadow(
                                            color: hour.steps > 0
                                                ? (isSelected ? accent3.opacity(0.8) : accent3.opacity(0.45))
                                                : .clear,
                                            radius: isSelected ? 16 : 10,
                                            x: 0,
                                            y: 0
                                        )
                                        .scaleEffect(x: isSelected ? 1.08 : 1.0, y: 1.0)

                                    if hour.steps > 0 {
                                        Capsule()
                                            .fill(Color.white.opacity(0.90))
                                            .frame(width: max(barWidth - 4, 3), height: 4)
                                            .blur(radius: 0.5)
                                            .padding(.top, 4)
                                    }
                                }
                            }
                        }
                    }
                }

                rhythmLine(in: CGSize(width: chartWidth, height: chartHeight), barWidth: barWidth, spacing: spacing)
                    .stroke(accent3.opacity(0.18), style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                    .blur(radius: 8)

                rhythmLine(in: CGSize(width: chartWidth, height: chartHeight), barWidth: barWidth, spacing: spacing)
                    .stroke(
                        LinearGradient(
                            colors: [accent2.opacity(0.8), accent3, Color.white.opacity(0.92)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )

                if let selected {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                        .shadow(color: accent3.opacity(0.7), radius: 12, x: 0, y: 0)
                        .position(x: selected.x, y: selected.y)

                    Circle()
                        .stroke(accent3, lineWidth: 3)
                        .frame(width: 28, height: 28)
                        .position(x: selected.x, y: selected.y)

                    selectionBubble(for: selected.hour)
                        .position(
                            x: min(max(selected.x, 70), chartWidth - 70),
                            y: max(selected.y - 42, 26)
                        )
                } else if let peakHour,
                          peakHour.steps > 0,
                          let peakIndex = data.firstIndex(where: { $0.id == peakHour.id }) {
                    let x = CGFloat(peakIndex) * (barWidth + spacing) + barWidth / 2
                    let y = yPosition(for: peakHour.steps, height: chartHeight)

                    Circle()
                        .fill(accent3)
                        .frame(width: 12, height: 12)
                        .shadow(color: accent3.opacity(0.7), radius: 10, x: 0, y: 0)
                        .position(x: x, y: y)

                    selectionBubble(for: peakHour)
                        .position(
                            x: min(max(x, 70), chartWidth - 70),
                            y: max(y - 42, 26)
                        )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        selectedIndex = nearestIndex(
                            to: value.location.x,
                            barWidth: barWidth,
                            spacing: spacing
                        )
                    }
            )
        }
        .frame(height: 250)
    }

    private func selectionBubble(for hour: HourlySteps) -> some View {
        VStack(spacing: 4) {
            Text("\(hour.steps.formattedWithSeparator) \(BagytL10n.tr("шагов"))")
                .font(.system(size: 11, weight: .black))
                .foregroundColor(isDarkMode ? .white : Color(red: 0.02, green: 0.12, blue: 0.18))

            Text(hour.displayRangeText)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isDarkMode ? Color(red: 0.12, green: 0.18, blue: 0.24) : Color.white)
        )
        .shadow(color: accent3.opacity(isDarkMode ? 0.5 : 0.25), radius: 12, x: 0, y: 6)
    }

    private func currentSelection(barWidth: CGFloat, spacing: CGFloat, size: CGSize) -> (index: Int, hour: HourlySteps, x: CGFloat, y: CGFloat)? {
        guard let selectedIndex,
              selectedIndex >= 0,
              selectedIndex < data.count else {
            return nil
        }

        let hour = data[selectedIndex]
        let x = CGFloat(selectedIndex) * (barWidth + spacing) + barWidth / 2
        let y = yPosition(for: hour.steps, height: size.height)
        return (selectedIndex, hour, x, y)
    }

    private func nearestIndex(to x: CGFloat, barWidth: CGFloat, spacing: CGFloat) -> Int {
        let step = barWidth + spacing
        let raw = Int(round((x - barWidth / 2) / step))
        return min(max(raw, 0), max(data.count - 1, 0))
    }

    private func yPosition(for steps: Int, height: CGFloat) -> CGFloat {
        let ratio = CGFloat(Double(steps) / maxSteps)
        let barHeight = steps > 0
            ? max(8 + ratio * (height - 52), 14)
            : 4
        return height - barHeight
    }

    private func rhythmLine(in size: CGSize, barWidth: CGFloat, spacing: CGFloat) -> Path {
        var points: [CGPoint] = []

        for (index, item) in data.enumerated() {
            let x = CGFloat(index) * (barWidth + spacing) + barWidth / 2
            let y = yPosition(for: item.steps, height: size.height)
            points.append(CGPoint(x: x, y: y))
        }

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
}

private final class StepsDetailViewModel: ObservableObject {
    @Published var week: [StepsDay] = []
    @Published var selectedDay: StepsDay?
    @Published var hourly: [HourlySteps] = []

    private let store = HKHealthStore()

    private var goal: Int {
        let saved = UserProfileStore.shared.stepsGoal
        return saved > 0 ? saved : 8000
    }

    func load() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let readTypes: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .stepCount)!
        ]

        store.requestAuthorization(toShare: [], read: readTypes) { [weak self] success, _ in
            guard success else { return }
            self?.fetchWeek()
        }
    }

    func select(_ day: StepsDay) {
        selectedDay = day
        fetchHourly(for: day.date)
    }

    func isSelected(_ day: StepsDay) -> Bool {
        guard let selectedDay else { return false }
        return Calendar.current.isDate(day.date, inSameDayAs: selectedDay.date)
    }

    var titleText: String {
        guard let selectedDay else { return BagytL10n.tr("Двигательная активность") }
        if Calendar.current.isDateInToday(selectedDay.date) { return BagytL10n.tr("Сегодня") }
        if Calendar.current.isDateInYesterday(selectedDay.date) { return BagytL10n.tr("Вчера") }
        return fullDateFormatter.string(from: selectedDay.date)
    }

    var goalText: String {
        goal.formattedWithSeparator
    }

    var progressValue: CGFloat {
        guard let selectedDay else { return 0 }
        return min(CGFloat(selectedDay.steps) / CGFloat(goal), 1)
    }

    var progressText: String {
        guard let selectedDay else { return "0%" }
        let pct = Int((Double(selectedDay.steps) / Double(goal)) * 100)
        return "\(max(pct, 0))%"
    }

    var bestHourText: String {
        guard let best = hourly.max(by: { $0.steps < $1.steps }), best.steps > 0 else { return "—" }
        return "\(best.shortHour) · \(best.steps.formattedWithSeparator)"
    }

    var bestHourBadgeText: String {
        guard let best = hourly.max(by: { $0.steps < $1.steps }), best.steps > 0 else { return BagytL10n.tr("Максимум не зафиксирован") }
        return String(format: BagytL10n.tr("Макс.: %@"), best.shortHour)
    }

    var activeHoursText: String {
        let count = hourly.filter { $0.steps >= 250 }.count
        return count > 0 ? "\(count) \(BagytL10n.tr("ч"))" : "—"
    }

    var weekAverageText: String {
        let values = week.map(\.steps).filter { $0 > 0 }
        guard !values.isEmpty else { return "—" }
        let avg = values.reduce(0, +) / values.count
        return avg.formattedWithSeparator
    }

    func shortWeekday(_ date: Date) -> String {
        shortWeekdayFormatter.string(from: date).uppercased()
    }

    func dayNumber(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    private func fetchWeek() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        let calendar = Self.weekCalendar
        let weekStart = currentWeekStart(calendar: calendar)
        let queryEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? Date()

        var interval = DateComponents()
        interval.day = 1

        let query = HKStatisticsCollectionQuery(
            quantityType: type,
            quantitySamplePredicate: HKQuery.predicateForSamples(withStart: weekStart, end: queryEnd, options: .strictStartDate),
            options: .cumulativeSum,
            anchorDate: weekStart,
            intervalComponents: interval
        )

        query.initialResultsHandler = { [weak self] _, results, _ in
            guard let self, let results else { return }

            var days: [StepsDay] = []

            for offset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { continue }
                let statistic = results.statistics(for: date)
                let steps = Int(statistic?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                days.append(StepsDay(date: date, steps: steps))
            }

            let today = days.first(where: { Calendar.current.isDateInToday($0.date) })
            let fallback = days.last

            DispatchQueue.main.async {
                self.week = days
                self.selectedDay = today ?? fallback
                if let selected = self.selectedDay {
                    self.fetchHourly(for: selected.date)
                }
            }
        }

        store.execute(query)
    }

    private func fetchHourly(for date: Date) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date

        var interval = DateComponents()
        interval.hour = 1

        let query = HKStatisticsCollectionQuery(
            quantityType: type,
            quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate),
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: interval
        )

        query.initialResultsHandler = { [weak self] _, results, _ in
            guard let results else { return }

            var data: [HourlySteps] = []

            for hour in 0..<24 {
                guard let bucketDate = calendar.date(byAdding: .hour, value: hour, to: start) else { continue }
                let statistic = results.statistics(for: bucketDate)
                let value = Int(statistic?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                data.append(HourlySteps(date: bucketDate, steps: value))
            }

            DispatchQueue.main.async {
                self?.hourly = data
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

private struct StepsDay: Identifiable, Hashable {
    let date: Date
    let steps: Int

    var id: Date { date }

    var formattedSteps: String {
        steps.formattedWithSeparator
    }

    var compactSteps: String {
        if steps >= 1000 {
            let value = Double(steps) / 1000
            return String(format: "%.1fк", value)
        }
        return "\(steps)"
    }
}

private struct HourlySteps: Identifiable, Hashable {
    let date: Date
    let steps: Int

    var id: Date { date }

    var shortHour: String {
        let formatter = DateFormatter()
        formatter.locale = BagytL10n.currentLocale
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    var displayRangeText: String {
        let formatter = DateFormatter()
        formatter.locale = BagytL10n.currentLocale
        formatter.dateFormat = "HH:mm"

        let end = Calendar.current.date(byAdding: .hour, value: 1, to: date) ?? date
        return "\(formatter.string(from: date)) - \(formatter.string(from: end))"
    }
}

private extension Int {
    var formattedWithSeparator: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.locale = BagytL10n.currentLocale
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

#Preview {
    StepsDetailView()
}
