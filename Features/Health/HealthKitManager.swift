import SwiftUI
import Combine
import UIKit
import HealthKit

final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    @Published var steps: Int = 0
    @Published var heartRate: Int = 0
    @Published var sleep: Double = 0
    @Published var isAuthorized = false

    @Published var sleepSamples: [SleepSample] = []
    @Published var sleepWeek: [SleepDay] = []
    @Published var selectedSleepDay: SleepDay?
    @Published var homeSleepDay: SleepDay?

    private let store = HKHealthStore()
    private let sleepClusterGap: TimeInterval = 2 * 60 * 60

    private let readTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    ]

    private init() {}

    struct SleepSample: Identifiable, Hashable {
        let id = UUID()
        let start: Date
        let end: Date
        let phase: SleepPhase

        var duration: TimeInterval {
            end.timeIntervalSince(start)
        }

        var hours: Double {
            duration / 3600
        }
    }

    struct SleepDay: Identifiable, Hashable {
        let date: Date
        let start: Date?
        let end: Date?
        let totalSleep: TimeInterval
        let segments: [SleepSample]

        var id: Date { date }
        var hours: Double { totalSleep / 3600 }
        var hasData: Bool { !segments.isEmpty }
    }

    enum SleepPhase: Int, CaseIterable, Hashable {
        case deep
        case rem
        case core
        case unspecified

        var title: String {
            switch self {
            case .deep: return "Глубокий сон"
            case .rem: return "REM сон"
            case .core: return "Лёгкий сон"
            case .unspecified: return "Сон"
            }
        }

        var shortLabel: String {
            switch self {
            case .deep: return "Глубокий"
            case .rem: return "REM"
            case .core: return "Лёгкий"
            case .unspecified: return "Сон"
            }
        }

        var description: String {
            switch self {
            case .deep: return "Восстановление организма"
            case .rem: return "Сновидения, память"
            case .core: return "Основная часть сна"
            case .unspecified: return "Стадия сна без точной фазы"
            }
        }

        var color: Color {
            switch self {
            case .deep:
                return Color(red: 0.20, green: 0.35, blue: 0.80)
            case .rem:
                return Color(red: 0.55, green: 0.35, blue: 1.0)
            case .core:
                return Color(red: 0.40, green: 0.65, blue: 0.95)
            case .unspecified:
                return Color(red: 0.29, green: 0.56, blue: 0.92)
            }
        }

        var priority: Int {
            switch self {
            case .deep: return 4
            case .rem: return 3
            case .core: return 2
            case .unspecified: return 1
            }
        }
    }

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        store.requestAuthorization(toShare: [], read: readTypes) { [weak self] success, _ in
            DispatchQueue.main.async {
                self?.isAuthorized = success
                if success {
                    self?.fetchAll()
                }
            }
        }
    }

    func fetchAll() {
        fetchSteps()
        fetchHeartRate()
        fetchSleepWeek()
    }

    func selectSleepDay(_ day: SleepDay) {
        selectedSleepDay = day
        sleepSamples = day.segments
    }

    private func fetchSteps() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        let query = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, result, _ in
            DispatchQueue.main.async {
                self?.steps = Int(result?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
            }
        }

        store.execute(query)
    }

    private func fetchHeartRate() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: type,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sort]
        ) { [weak self] _, results, _ in
            DispatchQueue.main.async {
                guard let sample = results?.first as? HKQuantitySample else { return }
                self?.heartRate = Int(sample.quantity.doubleValue(for: HKUnit(from: "count/min")))
            }
        }

        store.execute(query)
    }

    private func fetchSleepWeek() {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        let calendar = Self.weekCalendar
        let week = currentWeekInterval(calendar: calendar)

        guard
            let queryStart = calendar.date(byAdding: .day, value: -1, to: week.start),
            let queryEnd = calendar.date(byAdding: .day, value: 1, to: week.end)
        else { return }

        let predicate = HKQuery.predicateForSamples(withStart: queryStart, end: queryEnd, options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sort]
        ) { [weak self] _, results, _ in
            guard let self else { return }

            let rawSamples = (results as? [HKCategorySample]) ?? []
            let stageSamples = rawSamples.compactMap(self.makeSleepSample(from:))

            let grouped = Dictionary(grouping: stageSamples) {
                self.sleepBucketDate(for: $0, calendar: calendar)
            }

            let days: [SleepDay] = (0..<7).compactMap { offset in
                guard let day = calendar.date(byAdding: .day, value: offset, to: week.start) else { return nil }
                let dayStart = calendar.startOfDay(for: day)
                return self.buildSleepDay(for: dayStart, rawSamples: grouped[dayStart] ?? [])
            }

            let todaySleep = days.first {
                Calendar.current.isDateInToday($0.date) && $0.hasData
            }

            let fallbackSleep = days
                .filter(\.hasData)
                .sorted { $0.date > $1.date }
                .first

            let homeDay = todaySleep ?? fallbackSleep
            let selection = self.resolveSelection(in: days) ?? homeDay

            DispatchQueue.main.async {
                self.sleepWeek = days
                self.homeSleepDay = homeDay
                self.sleep = homeDay?.hours ?? 0

                if let selection {
                    self.selectedSleepDay = selection
                    self.sleepSamples = selection.segments
                } else {
                    self.selectedSleepDay = nil
                    self.sleepSamples = []
                }
            }
        }

        store.execute(query)
    }

    private func makeSleepSample(from sample: HKCategorySample) -> SleepSample? {
        guard let phase = mapPhase(value: sample.value) else { return nil }
        guard sample.endDate > sample.startDate else { return nil }

        return SleepSample(
            start: sample.startDate,
            end: sample.endDate,
            phase: phase
        )
    }

    private func mapPhase(value: Int) -> SleepPhase? {
        if #available(iOS 16.0, *) {
            switch value {
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                return .deep
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                return .rem
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                return .core
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                return .unspecified
            case HKCategoryValueSleepAnalysis.asleep.rawValue:
                return .unspecified
            default:
                return nil
            }
        } else {
            return value == HKCategoryValueSleepAnalysis.asleep.rawValue ? .unspecified : nil
        }
    }

    private func buildSleepDay(for day: Date, rawSamples: [SleepSample]) -> SleepDay {
        let normalized = normalize(samples: rawSamples)
        let primarySegments = dominantCluster(from: normalized)
        let total = primarySegments.reduce(0) { $0 + $1.duration }

        return SleepDay(
            date: day,
            start: primarySegments.first?.start,
            end: primarySegments.last?.end,
            totalSleep: total,
            segments: primarySegments
        )
    }

    private func normalize(samples: [SleepSample]) -> [SleepSample] {
        guard !samples.isEmpty else { return [] }

        let boundaries = Array(Set(samples.flatMap { [$0.start, $0.end] })).sorted()
        guard boundaries.count > 1 else { return [] }

        var result: [SleepSample] = []

        for index in 0..<(boundaries.count - 1) {
            let start = boundaries[index]
            let end = boundaries[index + 1]
            guard end > start else { continue }

            let active = samples.filter { $0.start < end && $0.end > start }
            guard let chosen = active.max(by: { $0.phase.priority < $1.phase.priority }) else { continue }

            if let last = result.last,
               last.phase == chosen.phase,
               abs(last.end.timeIntervalSince(start)) < 1 {
                result[result.count - 1] = SleepSample(start: last.start, end: end, phase: chosen.phase)
            } else {
                result.append(SleepSample(start: start, end: end, phase: chosen.phase))
            }
        }

        return result
    }

    private func dominantCluster(from samples: [SleepSample]) -> [SleepSample] {
        guard let first = samples.first else { return [] }

        var clusters: [[SleepSample]] = [[first]]

        for sample in samples.dropFirst() {
            guard let last = clusters[clusters.count - 1].last else { continue }

            if sample.start.timeIntervalSince(last.end) <= sleepClusterGap {
                clusters[clusters.count - 1].append(sample)
            } else {
                clusters.append([sample])
            }
        }

        return clusters.max { totalDuration($0) < totalDuration($1) } ?? []
    }

    private func totalDuration(_ samples: [SleepSample]) -> TimeInterval {
        samples.reduce(0) { $0 + $1.duration }
    }

    private func sleepBucketDate(for sample: SleepSample, calendar: Calendar) -> Date {
        calendar.startOfDay(for: sample.end)
    }

    private func resolveSelection(in days: [SleepDay]) -> SleepDay? {
        if let current = selectedSleepDay,
           let sameDay = days.first(where: { Calendar.current.isDate($0.date, inSameDayAs: current.date) }) {
            return sameDay
        }

        return days
            .filter(\.hasData)
            .sorted { $0.date > $1.date }
            .first
    }

    private func currentWeekInterval(calendar: Calendar) -> DateInterval {
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: startOfToday)
        let shift = (weekday + 5) % 7
        let weekStart = calendar.date(byAdding: .day, value: -shift, to: startOfToday) ?? startOfToday
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? now
        return DateInterval(start: weekStart, end: weekEnd)
    }

    private static var weekCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ru_RU")
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    func stepsProgress(goal: Int = 8000) -> Double {
        min(Double(steps) / Double(goal), 1.0)
    }

    func heartProgress() -> Double {
        heartRate > 0 ? min(Double(heartRate) / 120.0, 1.0) : 0.68
    }

    func sleepProgress(goal: Double = 8.0) -> Double {
        sleep > 0 ? min(sleep / goal, 1.0) : 0.0
    }
}

struct HealthIndexBreakdown {
    let basePoints: Int
    let stepsPoints: Int
    let heartPoints: Int
    let sleepPoints: Int
    let score: Int
    let stepsGoal: Int
    let sleepGoal: Double
    let sleepHours: Double
    let hasHeartRateData: Bool
    let hasSleepData: Bool

    var label: String {
        switch score {
        case 90...100: return "Отличный показатель"
        case 75..<90:  return "Хорошее состояние"
        case 60..<75:  return "В пределах нормы"
        default:       return "Требует внимания"
        }
    }

    var shortLabel: String {
        switch score {
        case 90...100: return "Отлично"
        case 75..<90:  return "Хорошо"
        case 60..<75:  return "Норма"
        default:       return "Внимание"
        }
    }

    var icon: String {
        switch score {
        case 90...100: return "waveform.path.ecg"
        case 75..<90:  return "checkmark.shield.fill"
        case 60..<75:  return "bolt.heart.fill"
        default:       return "exclamationmark.triangle.fill"
        }
    }
}

enum HealthIndexCalculator {
    static func make(from health: HealthKitManager) -> HealthIndexBreakdown {
        let stepsGoal = UserDefaults.standard.integer(forKey: "stepsGoal")
        let sleepGoal = UserDefaults.standard.double(forKey: "sleepGoal")

        return make(
            steps: health.steps,
            heartRate: health.heartRate,
            sleepHours: health.homeSleepDay?.hours ?? health.sleep,
            stepsGoal: stepsGoal > 0 ? stepsGoal : 8000,
            sleepGoal: sleepGoal > 0 ? sleepGoal : 8.0
        )
    }

    static func make(
        steps: Int,
        heartRate: Int,
        sleepHours: Double,
        stepsGoal: Int,
        sleepGoal: Double
    ) -> HealthIndexBreakdown {
        let safeStepsGoal = max(stepsGoal, 1)
        let safeSleepGoal = max(sleepGoal, 0.1)
        let normalizedSteps = max(steps, 0)
        let normalizedSleep = max(sleepHours, 0)

        let stepsRatio = min(Double(normalizedSteps) / Double(safeStepsGoal), 1.0)
        let stepsPoints = Int(stepsRatio * 20)

        let heartPoints: Int
        if heartRate > 0 {
            heartPoints = (60...80).contains(heartRate) ? 10 : 5
        } else {
            heartPoints = 7
        }

        let sleepRatio = normalizedSleep > 0 ? min(normalizedSleep / safeSleepGoal, 1.0) : 0.7
        let sleepPoints = Int(sleepRatio * 10)
        let basePoints = 60
        let score = min(basePoints + stepsPoints + heartPoints + sleepPoints, 100)

        return HealthIndexBreakdown(
            basePoints: basePoints,
            stepsPoints: stepsPoints,
            heartPoints: heartPoints,
            sleepPoints: sleepPoints,
            score: score,
            stepsGoal: safeStepsGoal,
            sleepGoal: safeSleepGoal,
            sleepHours: normalizedSleep,
            hasHeartRateData: heartRate > 0,
            hasSleepData: normalizedSleep > 0
        )
    }
}
