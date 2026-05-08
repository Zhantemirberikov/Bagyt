//
//  MoodView.swift
//  Bagyt
//
//  Premium Mood Tracker
//  Project background · Light/Dark by Settings toggle · Fast UI · Per-user data
//

import SwiftUI
import Combine
import UIKit

// MARK: - Models

struct MoodRecord: Identifiable, Codable {
    var id: UUID
    var mood: Int
    var note: String
    var date: Date
    var energy: Int
    var stress: Int
    var sleepQuality: Int
    var tags: [String]

    init(
        id: UUID = UUID(),
        mood: Int,
        note: String = "",
        date: Date = Date(),
        energy: Int = 3,
        stress: Int = 3,
        sleepQuality: Int = 3,
        tags: [String] = []
    ) {
        self.id = id
        self.mood = mood
        self.note = note
        self.date = date
        self.energy = energy
        self.stress = stress
        self.sleepQuality = sleepQuality
        self.tags = tags
    }

    enum CodingKeys: String, CodingKey {
        case id, mood, note, date, energy, stress, sleepQuality, tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        mood = try container.decodeIfPresent(Int.self, forKey: .mood) ?? 3
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        energy = try container.decodeIfPresent(Int.self, forKey: .energy) ?? 3
        stress = try container.decodeIfPresent(Int.self, forKey: .stress) ?? 3
        sleepQuality = try container.decodeIfPresent(Int.self, forKey: .sleepQuality) ?? 3
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }
}

struct MoodTagOption: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let color: Color

    init(_ id: String, _ title: String, _ icon: String, _ color: Color) {
        self.id = id
        self.title = title
        self.icon = icon
        self.color = color
    }

    var localizedTitle: String {
        BagytL10n.tr(title)
    }
}

struct MoodInsight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let text: String
    let color: Color
}

// MARK: - ViewModel

final class MoodViewModel: ObservableObject {
    @Published var records: [MoodRecord] = []

    // Состояние формы
    @Published var todayMood: Int? = nil
    @Published var todayNote: String = ""
    @Published var todayEnergy: Int = 3
    @Published var todayStress: Int = 3
    @Published var todaySleepQuality: Int = 3
    @Published var selectedTags: Set<String> = []

    // Предрассчитанные метрики
    @Published private(set) var averageMood: Double = 0
    @Published private(set) var averageEnergy: Double = 0
    @Published private(set) var averageStress: Double = 0
    @Published private(set) var streak: Int = 0
    @Published private(set) var weeklyMoodDelta: Int = 0
    @Published private(set) var dominantTag: MoodTagOption? = nil
    @Published private(set) var insights: [MoodInsight] = []
    
    private let baseKey = "bagyt_mood_records"
    private var activeStorageKey = "bagyt_mood_records_guest"

    let tagOptions: [MoodTagOption] = [
        MoodTagOption("sleep", "Сон", "moon.zzz.fill", Color(red: 0.55, green: 0.35, blue: 1.00)),
        MoodTagOption("stress", "Стресс", "brain.head.profile", Color(red: 1.00, green: 0.48, blue: 0.16)),
        MoodTagOption("study", "Учеба", "book.fill", Color(red: 0.055, green: 0.647, blue: 0.914)),
        MoodTagOption("work", "Работа", "briefcase.fill", Color(red: 0.20, green: 0.62, blue: 1.00)),
        MoodTagOption("health", "Здоровье", "cross.case.fill", Color(red: 1.00, green: 0.34, blue: 0.34)),
        MoodTagOption("family", "Семья", "person.2.fill", Color(red: 1.00, green: 0.65, blue: 0.12)),
        MoodTagOption("sport", "Спорт", "figure.run", Color(red: 0.10, green: 0.78, blue: 0.48)),
        MoodTagOption("food", "Питание", "fork.knife", Color(red: 0.42, green: 0.76, blue: 0.30)),
        MoodTagOption("social", "Общение", "bubble.left.and.bubble.right.fill", Color(red: 0.72, green: 0.45, blue: 1.00))
    ]

    init() {
        configureUser(token: UserDefaults.standard.string(forKey: "userToken"))
    }

    var todayRecord: MoodRecord? {
        records.first { Calendar.current.isDateInToday($0.date) }
    }

    var last7Records: [MoodRecord] {
        recordsWithin(days: 7)
    }

    var last14Records: [MoodRecord] {
        recordsWithin(days: 14)
    }

    func configureUser(token: String?) {
        let key = storageKey(for: token)

        guard key != activeStorageKey else {
            load()
            syncTodayForm()
            return
        }

        activeStorageKey = key
        load()
        syncTodayForm()
    }

    func toggleTag(_ id: String) {
        if selectedTags.contains(id) {
            selectedTags.remove(id)
        } else {
            selectedTags.insert(id)
        }
    }

    func saveTodayMood() {
        guard let mood = todayMood else { return }

        let record = MoodRecord(
            mood: mood,
            note: todayNote.trimmingCharacters(in: .whitespacesAndNewlines),
            date: Date(),
            energy: todayEnergy,
            stress: todayStress,
            sleepQuality: todaySleepQuality,
            tags: Array(selectedTags)
        )

        if let index = records.firstIndex(where: { Calendar.current.isDateInToday($0.date) }) {
            records[index].mood = record.mood
            records[index].note = record.note
            records[index].energy = record.energy
            records[index].stress = record.stress
            records[index].sleepQuality = record.sleepQuality
            records[index].tags = record.tags
        } else {
            records.insert(record, at: 0)
        }

        records.sort { $0.date > $1.date }
        save()
        syncTodayForm()
    }

    func refreshLanguage() {
        recalculateMetrics()
    }

    func delete(record: MoodRecord) {
        records.removeAll { $0.id == record.id }

        if Calendar.current.isDateInToday(record.date) {
            resetTodayForm()
        }

        save()
    }

    func deleteAll() {
        records.removeAll()
        resetTodayForm()
        save()
    }

    func tagOption(for id: String) -> MoodTagOption? {
        tagOptions.first { $0.id == id }
    }

    private func recordsWithin(days: Int) -> [MoodRecord] {
        let start = Calendar.current.date(
            byAdding: .day,
            value: -(days - 1),
            to: Calendar.current.startOfDay(for: Date())
        ) ?? Date()

        return records
            .filter { $0.date >= start }
            .sorted { $0.date > $1.date }
    }

    private func syncTodayForm() {
        if let today = todayRecord {
            todayMood = today.mood
            todayNote = today.note
            todayEnergy = today.energy
            todayStress = today.stress
            todaySleepQuality = today.sleepQuality
            selectedTags = Set(today.tags)
        } else {
            resetTodayForm()
        }
        recalculateMetrics()
    }

    private func resetTodayForm() {
        todayMood = nil
        todayNote = ""
        todayEnergy = 3
        todayStress = 3
        todaySleepQuality = 3
        selectedTags = []
    }

    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: activeStorageKey)
        }
        recalculateMetrics()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: activeStorageKey),
              let saved = try? JSONDecoder().decode([MoodRecord].self, from: data) else {
            records = []
            return
        }

        records = saved.sorted { $0.date > $1.date }
        recalculateMetrics()
    }

    private func recalculateMetrics() {
        let cal = Calendar.current
        let last7 = recordsWithin(days: 7)
        let last14 = recordsWithin(days: 14)
        
        // Averages
        if !last7.isEmpty {
            averageMood = Double(last7.map(\.mood).reduce(0, +)) / Double(last7.count)
            averageEnergy = Double(last7.map(\.energy).reduce(0, +)) / Double(last7.count)
            averageStress = Double(last7.map(\.stress).reduce(0, +)) / Double(last7.count)
            
            let sorted7 = last7.sorted { $0.date < $1.date }
            if sorted7.count >= 2 {
                weeklyMoodDelta = (sorted7.last?.mood ?? 0) - (sorted7.first?.mood ?? 0)
            } else {
                weeklyMoodDelta = 0
            }
        } else {
            averageMood = 0; averageEnergy = 0; averageStress = 0; weeklyMoodDelta = 0
        }
        
        // Streak (Optimized with Set)
        var currentStreak = 0
        var dayToCheck = cal.startOfDay(for: Date())
        let uniqueRecordDays = Set(records.map { cal.startOfDay(for: $0.date) })
        
        if !uniqueRecordDays.contains(dayToCheck) {
            dayToCheck = cal.date(byAdding: .day, value: -1, to: dayToCheck) ?? dayToCheck
        }
        
        while uniqueRecordDays.contains(dayToCheck) {
            currentStreak += 1
            dayToCheck = cal.date(byAdding: .day, value: -1, to: dayToCheck) ?? dayToCheck
        }
        self.streak = currentStreak
        
        // Dominant Tag
        let ids = last14.flatMap(\.tags)
        if !ids.isEmpty {
            let counts = Dictionary(grouping: ids, by: { $0 }).mapValues(\.count)
            if let top = counts.max(by: { $0.value < $1.value })?.key {
                dominantTag = tagOptions.first { $0.id == top }
            } else { dominantTag = nil }
        } else {
            dominantTag = nil
        }
        
        // Insights Generation
        var newInsights: [MoodInsight] = []

        if averageMood >= 4 {
            newInsights.append(MoodInsight(
                icon: "sparkles",
                title: BagytL10n.tr("Хорошая динамика"),
                text: String(format: BagytL10n.tr("Среднее настроение за неделю %@/5. Продолжайте отмечать факторы дня."), String(format: "%.1f", averageMood)),
                color: Color(red: 0.10, green: 0.78, blue: 0.48)
            ))
        } else if averageMood > 0 && averageMood <= 2.7 {
            newInsights.append(MoodInsight(
                icon: "heart.text.square.fill",
                title: BagytL10n.tr("Нужен ресурс"),
                text: BagytL10n.tr("Настроение ниже обычного. Проверьте сон, стресс, нагрузку и симптомы в журнале."),
                color: Color(red: 1.00, green: 0.58, blue: 0.12)
            ))
        }

        if averageStress >= 4 {
            newInsights.append(MoodInsight(
                icon: "brain.head.profile",
                title: BagytL10n.tr("Стресс повышен"),
                text: String(format: BagytL10n.tr("Средний стресс %@/5. Заметки помогут ИИ найти повторяющиеся причины."), String(format: "%.1f", averageStress)),
                color: Color(red: 1.00, green: 0.48, blue: 0.16)
            ))
        }

        if let tag = dominantTag {
            newInsights.append(MoodInsight(
                icon: tag.icon,
                title: String(format: BagytL10n.tr("Частый фактор: %@"), tag.localizedTitle),
                text: BagytL10n.tr("Этот фактор часто встречается в последних записях. Сравните его с настроением и энергией."),
                color: tag.color
            ))
        }

        if streak >= 3 {
            newInsights.append(MoodInsight(
                icon: "flame.fill",
                title: String(format: BagytL10n.tr("Серия %d дней"), streak),
                text: BagytL10n.tr("Регулярные чек-ины делают когнитивный анализ Bagyt точнее."),
                color: Color(red: 1.00, green: 0.65, blue: 0.12)
            ))
        }

        if newInsights.isEmpty {
            newInsights.append(MoodInsight(
                icon: "waveform.path.ecg",
                title: BagytL10n.tr("Начните с чек-ина"),
                text: BagytL10n.tr("Отметьте настроение, энергию, стресс и пару факторов дня."),
                color: Color(red: 0.055, green: 0.647, blue: 0.914)
            ))
        }

        self.insights = Array(newInsights.prefix(3))
    }

    private func storageKey(for token: String?) -> String {
        let trimmed = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        let userId = (trimmed?.isEmpty == false) ? trimmed! : "guest"

        let safeUserId = Data(userId.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        return "\(baseKey)_\(safeUserId)"
    }
}

// MARK: - MoodView

struct MoodView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkModeEnabled") private var isDarkMode = false

    @StateObject private var vm = MoodViewModel()

    @State private var showSavedBadge = false
    @State private var showResetAlert = false
    @State private var expandedRecordId: UUID?
    @State private var appear = false

    @FocusState private var noteFocused: Bool

    private var palette: MoodPalette {
        moodPalette(vm.todayMood)
    }

    private var primaryText: Color {
        isDarkMode ? .white : Color(red: 0.10, green: 0.09, blue: 0.06)
    }

    private var secondaryText: Color {
        isDarkMode ? .white.opacity(0.64) : Color(red: 0.50, green: 0.44, blue: 0.34)
    }

    private var mutedText: Color {
        isDarkMode ? .white.opacity(0.42) : Color(red: 0.66, green: 0.58, blue: 0.44)
    }

    private var cardBg: Color {
        isDarkMode ? Color(red: 0.11, green: 0.10, blue: 0.08).opacity(0.86) : Color.white.opacity(0.91)
    }

    private var softCardBg: Color {
        isDarkMode ? Color.white.opacity(0.075) : Color(red: 1.0, green: 0.98, blue: 0.92).opacity(0.72)
    }

    private var cardStroke: Color {
        isDarkMode ? Color.white.opacity(0.10) : Color.white.opacity(0.78)
    }

    private var backgroundColors: [Color] {
        if isDarkMode {
            return [
                Color(red: 0.10, green: 0.08, blue: 0.04),
                Color(red: 0.06, green: 0.05, blue: 0.04),
                Color(red: 0.04, green: 0.04, blue: 0.04)
            ]
        }

        return [
            Color(red: 1.0, green: 0.96, blue: 0.82),
            Color.white,
            Color(red: 1.0, green: 0.98, blue: 0.91)
        ]
    }

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        totalCard
                        quickStatsRow
                        checkInCard
                        weekCard
                        smartContextCard
                        factorsCard
                        historyCard

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 10)
                }
            }

            if showSavedBadge {
                savedBadge
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(BagytL10n.tr("Готово")) {
                    noteFocused = false
                }
                .font(.system(size: 15, weight: .bold))
            }
        }
        .onAppear {
            vm.configureUser(token: appState.userToken)

            withAnimation(.easeOut(duration: 0.24)) {
                appear = true
            }
        }
        .onChange(of: appState.userToken) { _, token in
            vm.configureUser(token: token)
        }
        .onChange(of: lang.currentLanguage) { _, _ in
            vm.refreshLanguage()
        }
        .alert(BagytL10n.tr("Очистить историю?"), isPresented: $showResetAlert) {
            Button(BagytL10n.tr("Отмена"), role: .cancel) { }
            Button(BagytL10n.tr("Удалить все"), role: .destructive) {
                withAnimation(.easeOut(duration: 0.18)) {
                    vm.deleteAll()
                    expandedRecordId = nil
                }
            }
        } message: {
            Text(BagytL10n.tr("Все записи настроения этого пользователя будут удалены."))
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(isDarkMode ? Color.white.opacity(0.10) : Color.white.opacity(0.82))
                        .frame(width: 40, height: 40)
                        .shadow(color: palette.primary.opacity(isDarkMode ? 0.10 : 0.16), radius: 6, x: 0, y: 2)

                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isDarkMode ? .white.opacity(0.82) : Color(red: 0.43, green: 0.35, blue: 0.22))
                }
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text(BagytL10n.tr("НАСТРОЕНИЕ"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(palette.primary.opacity(isDarkMode ? 0.95 : 0.80))
                    .tracking(1.5)

                Text(BagytL10n.tr("Чек-ин состояния"))
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(primaryText)
            }

            Spacer()

            Button {
                noteFocused = false
                saveAndAnimate()
            } label: {
                ZStack {
                    Circle()
                        .fill(isDarkMode ? Color.white.opacity(0.10) : Color.white.opacity(0.82))
                        .frame(width: 40, height: 40)
                        .shadow(color: palette.primary.opacity(isDarkMode ? 0.10 : 0.16), radius: 6, x: 0, y: 2)

                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(vm.todayMood == nil ? mutedText : palette.primary)
                }
            }
            .buttonStyle(.plain)
            .disabled(vm.todayMood == nil)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Top Card

    private var totalCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [palette.primary, palette.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: palette.primary.opacity(isDarkMode ? 0.16 : 0.34), radius: 18, x: 0, y: 8)

            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 158, height: 158)
                .offset(x: 82, y: -48)

            Circle()
                .fill(Color.white.opacity(0.075))
                .frame(width: 96, height: 96)
                .offset(x: -62, y: 58)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(BagytL10n.tr("СОСТОЯНИЕ СЕГОДНЯ"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.78))
                        .tracking(1.0)

                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(vm.todayMood.map { "\($0)" } ?? "—")
                            .font(.system(size: 56, weight: .black))
                            .foregroundColor(.white)

                        Text("/5")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white.opacity(0.78))
                            .padding(.bottom, 8)
                    }

                    Text(BagytL10n.tr(vm.todayMood.map { moodLabel($0) } ?? "Выберите настроение"))
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.92))

                    HStack(spacing: 14) {
                        topInfoPill(title: "Энергия", value: "\(vm.todayEnergy)")
                        topInfoPill(title: "Стресс", value: "\(vm.todayStress)")
                        topInfoPill(title: "Сон", value: "\(vm.todaySleepQuality)")
                    }
                    .padding(.top, 2)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.17))
                        .frame(width: 72, height: 72)

                    Text(vm.todayMood.map { moodEmoji($0) } ?? "🙂")
                        .font(.system(size: 38))
                }
            }
            .padding(24)
        }
        .animation(.easeOut(duration: 0.20), value: vm.todayMood)
    }

    private func topInfoPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(BagytL10n.tr(title))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.72))

            Text(value)
                .font(.system(size: 15, weight: .black))
                .foregroundColor(.white)
        }
    }

    private var quickStatsRow: some View {
        HStack(spacing: 10) {
            statTile(
                icon: "flame.fill",
                value: "\(vm.streak)",
                title: "серия",
                color: Color(red: 1.00, green: 0.62, blue: 0.10)
            )

            statTile(
                icon: "chart.line.uptrend.xyaxis",
                value: vm.averageMood > 0 ? String(format: "%.1f", vm.averageMood) : "—",
                title: "среднее",
                color: palette.primary
            )

            statTile(
                icon: vm.weeklyMoodDelta >= 0 ? "arrow.up.right" : "arrow.down.right",
                value: deltaText(vm.weeklyMoodDelta),
                title: "динамика",
                color: vm.weeklyMoodDelta >= 0 ? Color(red: 0.10, green: 0.78, blue: 0.48) : Color(red: 1.00, green: 0.34, blue: 0.34)
            )
        }
    }

    private func statTile(icon: String, value: String, title: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .black))
                .foregroundColor(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(isDarkMode ? 0.18 : 0.12), in: Circle())

            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(primaryText)

            Text(BagytL10n.tr(title))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(cardBackground(cornerRadius: 20))
    }

    // MARK: - Check-In

    private var checkInCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                eyebrow: "БЫСТРЫЙ ЧЕК-ИН",
                title: todayDateString(),
                icon: "face.smiling.inverse",
                color: palette.primary
            )

            moodSelector
            clinicalSignalCard

            metricControl(
                title: "Энергия",
                valueText: energyLabel(vm.todayEnergy),
                icon: "bolt.fill",
                value: $vm.todayEnergy,
                color: Color(red: 0.10, green: 0.78, blue: 0.48),
                reversed: false
            )

            metricControl(
                title: "Стресс",
                valueText: stressLabel(vm.todayStress),
                icon: "brain.head.profile",
                value: $vm.todayStress,
                color: Color(red: 1.00, green: 0.46, blue: 0.12),
                reversed: true
            )

            metricControl(
                title: "Качество сна",
                valueText: sleepLabel(vm.todaySleepQuality),
                icon: "moon.stars.fill",
                value: $vm.todaySleepQuality,
                color: Color(red: 0.46, green: 0.38, blue: 1.00),
                reversed: false
            )

            tagPicker
            noteField
            saveButton
        }
        .padding(18)
        .background(cardBackground(cornerRadius: 24))
    }

    private var moodSelector: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { value in
                let selected = vm.todayMood == value
                let color = moodColor(value)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()

                    withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                        vm.todayMood = value
                    }
                } label: {
                    VStack(spacing: 7) {
                        Text(moodEmoji(value))
                            .font(.system(size: selected ? 28 : 23))
                            .frame(width: 48, height: 48)
                            .background(selected ? color.opacity(isDarkMode ? 0.24 : 0.16) : softCardBg, in: Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(selected ? color.opacity(0.95) : cardStroke, lineWidth: selected ? 1.6 : 1)
                            )
                            .shadow(color: selected ? color.opacity(isDarkMode ? 0.20 : 0.26) : .clear, radius: 10, x: 0, y: 5)

                        Text(moodShortLabel(value))
                            .font(.system(size: 10, weight: selected ? .black : .bold, design: .rounded))
                            .foregroundColor(selected ? color : mutedText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var clinicalSignalCard: some View {
        let signal = clinicalSignal

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: signal.icon)
                .font(.system(size: 15, weight: .black))
                .foregroundColor(signal.color)
                .frame(width: 38, height: 38)
                .background(signal.color.opacity(isDarkMode ? 0.18 : 0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(BagytL10n.tr(signal.title))
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(primaryText)

                Text(BagytL10n.tr(signal.text))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(13)
        .background(signal.color.opacity(isDarkMode ? 0.10 : 0.075), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(signal.color.opacity(isDarkMode ? 0.22 : 0.16), lineWidth: 1)
        )
    }

    private var clinicalSignal: (icon: String, title: String, text: String, color: Color) {
        guard let mood = vm.todayMood else {
            return (
                "sparkles",
                "Bagyt ждет чек-ин",
                "Выберите настроение, энергию, стресс и сон. Эти данные попадут в анализ и помогут ИИ видеть динамику, а не один случайный день.",
                palette.primary
            )
        }

        if mood <= 2 && vm.todayStress >= 4 {
            return (
                "exclamationmark.triangle.fill",
                "Сигнал перегрузки",
                "Низкое настроение вместе с высоким стрессом лучше отметить в журнале симптомов, особенно если это повторяется несколько дней.",
                Color(red: 1.00, green: 0.34, blue: 0.34)
            )
        }

        if vm.todaySleepQuality <= 2 && vm.todayEnergy <= 2 {
            return (
                "moon.zzz.fill",
                "Похоже на дефицит восстановления",
                "Сон и энергия сегодня просели. Bagyt будет учитывать это в анализе самочувствия и рекомендациях по нагрузке.",
                Color(red: 0.46, green: 0.38, blue: 1.00)
            )
        }

        if mood >= 4 && vm.todayEnergy >= 4 {
            return (
                "checkmark.seal.fill",
                "Хорошее состояние",
                "Сохраните факторы дня, чтобы потом понять, что именно поддерживает ресурс и стабильность.",
                Color(red: 0.10, green: 0.78, blue: 0.48)
            )
        }

        return (
            "waveform.path.ecg",
            "Нейтральный день",
            "Отметьте пару факторов и заметку. Так настроение станет полезным медицинским контекстом, а не отдельной игрушкой.",
            palette.primary
        )
    }

    private func metricControl(
        title: String,
        valueText: String,
        icon: String,
        value: Binding<Int>,
        color: Color,
        reversed: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(color)
                    .frame(width: 30, height: 30)
                    .background(color.opacity(isDarkMode ? 0.18 : 0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(BagytL10n.tr(title))
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(primaryText)

                    Text(BagytL10n.tr(valueText))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(secondaryText)
                }

                Spacer()

                Text("\(value.wrappedValue)/5")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(color)
            }

            HStack(spacing: 7) {
                ForEach(1...5, id: \.self) { index in
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()

                        withAnimation(.easeOut(duration: 0.14)) {
                            value.wrappedValue = index
                        }
                    } label: {
                        Capsule()
                            .fill(index <= value.wrappedValue ? color.opacity(reversed ? 0.58 : 0.95) : softCardBg)
                            .frame(maxWidth: .infinity)
                            .frame(height: 9)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(softCardBg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(cardStroke.opacity(0.68), lineWidth: 1)
        )
    }

    private var tagPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(BagytL10n.tr("Факторы дня"))
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(mutedText)
                .textCase(.uppercase)
                .tracking(0.8)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 94), spacing: 8)], spacing: 8) {
                ForEach(vm.tagOptions) { tag in
                    let selected = vm.selectedTags.contains(tag.id)

                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()

                        withAnimation(.easeOut(duration: 0.14)) {
                            vm.toggleTag(tag.id)
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: tag.icon)
                                .font(.system(size: 11, weight: .black))

                            Text(tag.localizedTitle)
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .foregroundColor(selected ? .white : tag.color)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(selected ? tag.color.opacity(0.92) : tag.color.opacity(isDarkMode ? 0.13 : 0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(selected ? Color.white.opacity(0.18) : tag.color.opacity(0.16), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(BagytL10n.tr("Заметка для ИИ"))
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(mutedText)
                .textCase(.uppercase)
                .tracking(0.8)

            ZStack(alignment: .topLeading) {
                if vm.todayNote.isEmpty {
                    Text(BagytL10n.tr("Например: головная боль, тревога, тренировка, мало сна..."))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(mutedText.opacity(0.78))
                        .padding(.top, 13)
                        .padding(.leading, 12)
                }

                TextEditor(text: $vm.todayNote)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(primaryText)
                    .frame(minHeight: 88)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .focused($noteFocused)
                    .colorScheme(isDarkMode ? .dark : .light)
            }
            .background(softCardBg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(cardStroke.opacity(0.70), lineWidth: 1)
            )
        }
    }

    private var saveButton: some View {
        Button {
            saveAndAnimate()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: vm.todayMood == nil ? "face.smiling" : "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .black))

                Text(BagytL10n.tr(vm.todayMood == nil ? "Выберите настроение" : "Сохранить состояние"))
                    .font(.system(size: 16, weight: .black, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: vm.todayMood == nil
                    ? [Color.gray.opacity(0.38), Color.gray.opacity(0.24)]
                    : [palette.primary, palette.secondary],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: vm.todayMood == nil ? .clear : palette.primary.opacity(isDarkMode ? 0.18 : 0.28), radius: 12, x: 0, y: 7)
        }
        .buttonStyle(.plain)
        .disabled(vm.todayMood == nil)
    }

    // MARK: - Week

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(BagytL10n.tr("НЕДЕЛЬНАЯ СВОДКА"))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(secondaryText)
                .tracking(0.9)

            VStack(spacing: 14) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                    ForEach(chartDays()) { day in
                        VStack(spacing: 6) {
                            Text(day.dayLabel)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(day.isToday ? .white.opacity(0.86) : secondaryText)

                            Text(day.mood.map { moodEmoji($0) } ?? "—")
                                .font(.system(size: 18))
                                .frame(height: 22)

                            Text(day.mood.map { "\($0)" } ?? " ")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(day.isToday ? .white : day.mood.map { moodColor($0) } ?? mutedText.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 76)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(day.isToday ? palette.primary : day.mood.map { moodColor($0).opacity(isDarkMode ? 0.18 : 0.11) } ?? softCardBg)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(day.isToday ? Color.white.opacity(0.18) : cardStroke.opacity(0.72), lineWidth: 1)
                        )
                    }
                }
                .transaction { transaction in
                    transaction.animation = nil
                }

                HStack(spacing: 10) {
                    weekMetric(title: "Настроение", value: vm.averageMood > 0 ? String(format: "%.1f", vm.averageMood) : "—", color: palette.primary)
                    weekMetric(title: "Энергия", value: vm.averageEnergy > 0 ? String(format: "%.1f", vm.averageEnergy) : "—", color: Color(red: 0.10, green: 0.78, blue: 0.48))
                    weekMetric(title: "Стресс", value: vm.averageStress > 0 ? String(format: "%.1f", vm.averageStress) : "—", color: Color(red: 1.00, green: 0.46, blue: 0.12))
                }
            }
            .padding(14)
            .background(cardBackground(cornerRadius: 20))
        }
    }

    private func weekMetric(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(BagytL10n.tr(title))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(secondaryText)

            Text(value)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(color.opacity(isDarkMode ? 0.12 : 0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Smart Context

    private var smartContextCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: "AI-КОНТЕКСТ",
                title: "Что запомнить Bagyt",
                icon: "sparkles",
                color: Color(red: 0.48, green: 0.38, blue: 1.00)
            )

            ForEach(Array(vm.insights.prefix(3))) { insight in
                insightRow(insight)
            }

            if let dominant = vm.dominantTag {
                HStack(spacing: 12) {
                    Image(systemName: dominant.icon)
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(dominant.color)
                        .frame(width: 38, height: 38)
                        .background(dominant.color.opacity(isDarkMode ? 0.18 : 0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(BagytL10n.tr("Главный фактор недели"))
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(primaryText)

                        Text(dominant.localizedTitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(secondaryText)
                    }

                    Spacer()
                }
                .padding(13)
                .background(dominant.color.opacity(isDarkMode ? 0.11 : 0.075), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .padding(18)
        .background(cardBackground(cornerRadius: 24))
    }

    private func insightRow(_ insight: MoodInsight) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.icon)
                .font(.system(size: 15, weight: .black))
                .foregroundColor(insight.color)
                .frame(width: 38, height: 38)
                .background(insight.color.opacity(isDarkMode ? 0.18 : 0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(BagytL10n.tr(insight.title))
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(primaryText)

                Text(BagytL10n.tr(insight.text))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(13)
        .background(softCardBg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Factors

    private var factorsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: "ФАКТОРЫ",
                title: "Связи и триггеры",
                icon: "circle.hexagongrid.fill",
                color: Color(red: 1.00, green: 0.62, blue: 0.10)
            )

            let rows = factorRows()

            if rows.isEmpty {
                Text(BagytL10n.tr("Отмечайте факторы дня. Здесь появятся связи между настроением, стрессом, сном, энергией и событиями."))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(secondaryText)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(softCardBg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                ForEach(rows, id: \.id) { row in
                    factorRow(row)
                }
            }
        }
        .padding(18)
        .background(cardBackground(cornerRadius: 24))
    }

    private func factorRow(_ row: FactorRow) -> some View {
        HStack(spacing: 12) {
            Image(systemName: row.option.icon)
                .font(.system(size: 14, weight: .black))
                .foregroundColor(row.option.color)
                .frame(width: 38, height: 38)
                .background(row.option.color.opacity(isDarkMode ? 0.18 : 0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(row.option.localizedTitle)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(primaryText)

                Text(String(format: BagytL10n.tr("%d раз · среднее %@/5"), row.count, String(format: "%.1f", row.averageMood)))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(secondaryText)
            }

            Spacer()

            Text(moodEmoji(Int(row.averageMood.rounded())))
                .font(.system(size: 20))
        }
        .padding(13)
        .background(softCardBg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - History

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionHeaderText(eyebrow: "ИСТОРИЯ", title: "Последние записи")

                Spacer()

                if !vm.records.isEmpty {
                    Button {
                        showResetAlert = true
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(Color(red: 1.00, green: 0.34, blue: 0.34))
                            .frame(width: 34, height: 34)
                            .background(Color(red: 1.00, green: 0.34, blue: 0.34).opacity(isDarkMode ? 0.15 : 0.10), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if vm.records.isEmpty {
                emptyHistory
            } else {
                ForEach(vm.records.prefix(12)) { record in
                    historyRow(record)
                }
            }
        }
        .padding(18)
        .background(cardBackground(cornerRadius: 24))
    }

    private var emptyHistory: some View {
        VStack(spacing: 13) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(palette.primary)
                .frame(width: 68, height: 68)
                .background(palette.primary.opacity(isDarkMode ? 0.16 : 0.11), in: Circle())

            Text(BagytL10n.tr("История пока пустая"))
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundColor(primaryText)

            Text(BagytL10n.tr("Первый чек-ин уже поможет анализу Bagyt лучше понимать ваше состояние."))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }

    private func historyRow(_ record: MoodRecord) -> some View {
        let expanded = expandedRecordId == record.id
        let color = moodColor(record.mood)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text(moodEmoji(record.mood))
                    .font(.system(size: 24))
                    .frame(width: 48, height: 48)
                    .background(color.opacity(isDarkMode ? 0.20 : 0.13), in: Circle())
                    .overlay(Circle().strokeBorder(color.opacity(0.24), lineWidth: 1))

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(moodLabel(record.mood))
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(primaryText)

                        Spacer()

                        Text(shortDateString(record.date))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(mutedText)
                    }

                    HStack(spacing: 8) {
                        smallSignal(icon: "bolt.fill", value: record.energy, color: Color(red: 0.10, green: 0.78, blue: 0.48))
                        smallSignal(icon: "brain.head.profile", value: record.stress, color: Color(red: 1.00, green: 0.46, blue: 0.12))
                        smallSignal(icon: "moon.stars.fill", value: record.sleepQuality, color: Color(red: 0.46, green: 0.38, blue: 1.00))
                    }

                    if !record.note.isEmpty {
                        Text(record.note)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(secondaryText)
                            .lineLimit(expanded ? nil : 2)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !record.tags.isEmpty {
                        tagRow(record.tags, limit: expanded ? 99 : 3)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.16)) {
                    expandedRecordId = expanded ? nil : record.id
                }
            }

            if expanded {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()

                    withAnimation(.easeOut(duration: 0.18)) {
                        vm.delete(record: record)
                        expandedRecordId = nil
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 13, weight: .bold))

                        Text(BagytL10n.tr("Удалить запись"))
                            .font(.system(size: 13, weight: .black, design: .rounded))
                    }
                    .foregroundColor(Color(red: 1.00, green: 0.34, blue: 0.34))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color(red: 1.00, green: 0.34, blue: 0.34).opacity(isDarkMode ? 0.15 : 0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(13)
        .background(softCardBg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(cardStroke.opacity(0.68), lineWidth: 1)
        )
    }

    private func smallSignal(icon: String, value: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .black))

            Text("\(value)")
                .font(.system(size: 11, weight: .black, design: .rounded))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color.opacity(isDarkMode ? 0.16 : 0.10), in: Capsule())
    }

    private func tagRow(_ ids: [String], limit: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(ids.prefix(limit)), id: \.self) { id in
                if let tag = vm.tagOption(for: id) {
                    HStack(spacing: 4) {
                        Image(systemName: tag.icon)
                            .font(.system(size: 9, weight: .black))

                        Text(tag.localizedTitle)
                            .font(.system(size: 10, weight: .black, design: .rounded))
                    }
                    .foregroundColor(tag.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(tag.color.opacity(isDarkMode ? 0.16 : 0.10), in: Capsule())
                }
            }

            if ids.count > limit {
                Text("+\(ids.count - limit)")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(mutedText)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Shared UI

    private var savedBadge: some View {
        HStack(spacing: 9) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .black))
                .foregroundColor(Color(red: 0.10, green: 0.78, blue: 0.48))

            Text(BagytL10n.tr("Состояние сохранено"))
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(primaryText)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(cardBg, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(cardStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isDarkMode ? 0.24 : 0.10), radius: 14, x: 0, y: 8)
        .padding(.top, 12)
    }

    private func sectionHeader(eyebrow: String, title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .black))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(isDarkMode ? 0.18 : 0.11), in: Circle())

            sectionHeaderText(eyebrow: eyebrow, title: title)

            Spacer()
        }
    }

    private func sectionHeaderText(eyebrow: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(BagytL10n.tr(eyebrow))
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(mutedText)
                .tracking(1.0)

            Text(BagytL10n.tr(title))
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundColor(primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
    }

    private func cardBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(cardBg)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(cardStroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isDarkMode ? 0.16 : 0.055), radius: 12, x: 0, y: 6)
    }

    // MARK: - Data Helpers

    private struct MoodPalette {
        let primary: Color
        let secondary: Color
    }

    private struct ChartDay: Identifiable {
        let id: Date
        let dayLabel: String
        let mood: Int?
        let isToday: Bool
    }

    private struct FactorRow {
        let id: String
        let option: MoodTagOption
        let count: Int
        let averageMood: Double
    }

    private func moodPalette(_ mood: Int?) -> MoodPalette {
        switch mood {
        case 1:
            return MoodPalette(primary: Color(red: 1.00, green: 0.34, blue: 0.34), secondary: Color(red: 0.92, green: 0.18, blue: 0.32))
        case 2:
            return MoodPalette(primary: Color(red: 1.00, green: 0.56, blue: 0.12), secondary: Color(red: 1.00, green: 0.38, blue: 0.12))
        case 4:
            return MoodPalette(primary: Color(red: 0.10, green: 0.78, blue: 0.48), secondary: Color(red: 0.02, green: 0.66, blue: 0.68))
        case 5:
            return MoodPalette(primary: Color(red: 0.055, green: 0.647, blue: 0.914), secondary: Color(red: 0.48, green: 0.38, blue: 1.00))
        default:
            return MoodPalette(primary: Color(red: 1.00, green: 0.72, blue: 0.10), secondary: Color(red: 1.00, green: 0.50, blue: 0.12))
        }
    }

    private func chartDays() -> [ChartDay] {
        let calendar = Calendar.current
        let labels = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"].map { BagytL10n.tr($0) }
        let today = calendar.startOfDay(for: Date())
        let recentRecords = vm.last14Records

        return (0..<7).compactMap { offset in
            guard let rawDay = calendar.date(byAdding: .day, value: -(6 - offset), to: today) else {
                return nil
            }

            let day = calendar.startOfDay(for: rawDay)
            let weekday = calendar.component(.weekday, from: day)
            let label = labels[max(0, (weekday + 5) % 7)]
            let record = recentRecords.first { calendar.isDate($0.date, inSameDayAs: day) }

            return ChartDay(id: day, dayLabel: label, mood: record?.mood, isToday: day == today)
        }
    }

    private func factorRows() -> [FactorRow] {
        let recent = vm.last14Records
        var rows: [FactorRow] = []

        for option in vm.tagOptions {
            let related = recent.filter { $0.tags.contains(option.id) }
            guard !related.isEmpty else { continue }

            let average = Double(related.map(\.mood).reduce(0, +)) / Double(related.count)
            rows.append(FactorRow(id: option.id, option: option, count: related.count, averageMood: average))
        }

        return rows
            .sorted {
                if $0.count == $1.count {
                    return $0.averageMood > $1.averageMood
                }
                return $0.count > $1.count
            }
            .prefix(4)
            .map { $0 }
    }

    private func saveAndAnimate() {
        guard vm.todayMood != nil else { return }

        noteFocused = false
        vm.saveTodayMood()

        UINotificationFeedbackGenerator().notificationOccurred(.success)

        withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
            showSavedBadge = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.18)) {
                showSavedBadge = false
            }
        }
    }

    // MARK: - Text Helpers

    private func moodEmoji(_ value: Int) -> String {
        ["😩", "😕", "😐", "😊", "🤩"][max(0, min(value - 1, 4))]
    }

    private func moodLabel(_ value: Int) -> String {
        ["Плохо", "Так себе", "Нормально", "Хорошо", "Отлично"].map { BagytL10n.tr($0) }[max(0, min(value - 1, 4))]
    }

    private func moodShortLabel(_ value: Int) -> String {
        ["Плохо", "Так себе", "Норм", "Хорошо", "Класс"].map { BagytL10n.tr($0) }[max(0, min(value - 1, 4))]
    }

    private func moodColor(_ value: Int) -> Color {
        switch value {
        case 1:
            return Color(red: 1.00, green: 0.34, blue: 0.34)
        case 2:
            return Color(red: 1.00, green: 0.56, blue: 0.12)
        case 4:
            return Color(red: 0.10, green: 0.78, blue: 0.48)
        case 5:
            return Color(red: 0.055, green: 0.647, blue: 0.914)
        default:
            return Color(red: 1.00, green: 0.72, blue: 0.10)
        }
    }

    private func energyLabel(_ value: Int) -> String {
        ["Очень низкая", "Низкая", "Средняя", "Высокая", "Максимум"].map { BagytL10n.tr($0) }[max(0, min(value - 1, 4))]
    }

    private func stressLabel(_ value: Int) -> String {
        ["Спокойно", "Легкий", "Средний", "Высокий", "Очень высокий"].map { BagytL10n.tr($0) }[max(0, min(value - 1, 4))]
    }

    private func sleepLabel(_ value: Int) -> String {
        ["Очень плохо", "Плохо", "Нормально", "Хорошо", "Отлично"].map { BagytL10n.tr($0) }[max(0, min(value - 1, 4))]
    }

    private func deltaText(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private func todayDateString() -> String {
        localizedDateString(Date(), format: "EEEE, d MMMM").capitalized
    }

    private func shortDateString(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return BagytL10n.tr("Сегодня") }
        if Calendar.current.isDateInYesterday(date) { return BagytL10n.tr("Вчера") }
        return localizedDateString(date, format: "d MMM")
    }

    private func localizedDateString(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        let rawLanguage = UserDefaults.standard.string(forKey: "language") ?? AppLanguage.kk.rawValue
        let language = AppLanguage(rawValue: rawLanguage) ?? .kk
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    private static let fullDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = BagytL10n.currentLocale
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = BagytL10n.currentLocale
        formatter.dateFormat = "d MMM"
        return formatter
    }()
}

#if false
private struct LegacyMoodView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("isDarkModeEnabled") private var isDarkMode = false

    @StateObject private var vm = MoodViewModel()

    @State private var showSavedBadge = false
    @State private var showResetAlert = false
    @State private var expandedRecordId: UUID? = nil
    @State private var appear = false

    @FocusState private var noteFocused: Bool

    private let accent = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)

    private var primaryText: Color {
        isDarkMode ? .white : Color(red: 0.06, green: 0.09, blue: 0.16)
    }

    private var secondaryText: Color {
        isDarkMode ? .white.opacity(0.64) : Color(red: 0.38, green: 0.52, blue: 0.62)
    }

    private var mutedText: Color {
        isDarkMode ? .white.opacity(0.42) : Color(red: 0.55, green: 0.66, blue: 0.74)
    }

    private var cardFill: Color {
        isDarkMode ? Color(red: 0.08, green: 0.10, blue: 0.16).opacity(0.72) : Color.white.opacity(0.74)
    }

    private var softCardFill: Color {
        isDarkMode ? Color.white.opacity(0.07) : Color.white.opacity(0.52)
    }

    private var cardStroke: Color {
        isDarkMode ? Color.white.opacity(0.11) : Color.white.opacity(0.72)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                // ГЛАВНОЕ ИСПРАВЛЕНИЕ ЛАГОВ: Используем один корневой LazyVStack
                LazyVStack(spacing: 16) {
                    heroCard
                    statsGrid
                    todayCheckInCard
                    weekChartCard
                    insightsCard
                    factorsCard

                    historyHeader
                        .padding(.top, 8)

                    if vm.records.isEmpty {
                        emptyHistory
                    } else {
                        ForEach(vm.records) { record in
                            historyRow(record)
                                .padding(.bottom, -4) // Сохраняем компактный отступ (12 вместо 16) между рядами истории
                        }
                    }

                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 10)
            }

            if showSavedBadge {
                savedBadge
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .onAppear {
            vm.configureUser(token: appState.userToken)

            withAnimation(.easeOut(duration: 0.28)) {
                appear = true
            }
        }
        .onChange(of: appState.userToken) { token in
            vm.configureUser(token: token)
        }
        .alert(BagytL10n.tr("Очистить историю?"), isPresented: $showResetAlert) {
            Button(BagytL10n.tr("Отмена"), role: .cancel) { }
            Button(BagytL10n.tr("Удалить все"), role: .destructive) {
                withAnimation(.easeOut(duration: 0.22)) {
                    vm.deleteAll()
                }
            }
        } message: {
            Text(BagytL10n.tr("Все записи настроения этого пользователя будут удалены. Это действие нельзя отменить."))
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(BagytL10n.tr("Настроение"))
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(primaryText)

                    Text(BagytL10n.tr("Когнитивный трекер состояния"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(secondaryText)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(radialMoodColor.opacity(isDarkMode ? 0.22 : 0.15))
                        .frame(width: 70, height: 70)

                    Circle()
                        .strokeBorder(radialMoodColor.opacity(0.35), lineWidth: 1)

                    Text(vm.todayMood.map { moodEmoji($0) } ?? "🙂")
                        .font(.system(size: 34))
                }
                .frame(width: 70, height: 70)
            }

            HStack(spacing: 10) {
                heroPill(icon: "flame.fill", title: "\(vm.streak)", subtitle: "серия")
                heroPill(icon: "chart.line.uptrend.xyaxis", title: vm.averageMood > 0 ? String(format: "%.1f", vm.averageMood) : "-", subtitle: "среднее")
                heroPill(icon: "calendar.badge.checkmark", title: "\(vm.records.count)", subtitle: "записей")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            isDarkMode ? Color.white.opacity(0.10) : Color.white.opacity(0.78),
                            isDarkMode ? Color.white.opacity(0.055) : Color.white.opacity(0.54)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(cardStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isDarkMode ? 0.22 : 0.07), radius: 16, x: 0, y: 10)
    }

    private var radialMoodColor: Color {
        if let mood = vm.todayMood {
            return moodColor(mood)
        }
        return accent
    }

    private func heroPill(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundColor(accent)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(primaryText)

                Text(BagytL10n.tr(subtitle))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(mutedText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(softCardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Stats

    private var statsGrid: some View {
        HStack(spacing: 10) {
            statCard(
                icon: "bolt.heart.fill",
                value: vm.averageEnergy > 0 ? String(format: "%.1f", vm.averageEnergy) : "-",
                label: "Энергия",
                color: Color(red: 0.12, green: 0.78, blue: 0.50)
            )

            statCard(
                icon: "brain.fill",
                value: vm.averageStress > 0 ? String(format: "%.1f", vm.averageStress) : "-",
                label: "Стресс",
                color: Color(red: 1.00, green: 0.50, blue: 0.16)
            )

            statCard(
                icon: vm.weeklyMoodDelta >= 0 ? "arrow.up.right" : "arrow.down.right",
                value: deltaText(vm.weeklyMoodDelta),
                label: "Динамика",
                color: vm.weeklyMoodDelta >= 0 ? Color(red: 0.10, green: 0.78, blue: 0.48) : Color(red: 1.00, green: 0.35, blue: 0.35)
            )
        }
    }

    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(color.opacity(isDarkMode ? 0.18 : 0.12))
                    .frame(width: 38, height: 38)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(color)
            }

            Text(value)
                .font(.system(size: 21, weight: .black, design: .rounded))
                .foregroundColor(primaryText)

            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(cardBackground(cornerRadius: 22))
    }

    // MARK: - Today Check-In

    private var todayCheckInCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(BagytL10n.tr("СЕГОДНЯ"))
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(mutedText)
                        .tracking(1.0)

                    Text(todayDateString())
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(primaryText)
                }

                Spacer()

                if vm.todayMood != nil {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(red: 0.10, green: 0.78, blue: 0.48))
                            .frame(width: 7, height: 7)

                        Text(BagytL10n.tr("Сохранено"))
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(Color(red: 0.10, green: 0.78, blue: 0.48))
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Color(red: 0.10, green: 0.78, blue: 0.48).opacity(isDarkMode ? 0.16 : 0.11), in: Capsule())
                }
            }

            moodSelector

            metricStepper(
                title: "Энергия",
                subtitle: energyLabel(vm.todayEnergy),
                icon: "bolt.fill",
                value: $vm.todayEnergy,
                color: Color(red: 0.12, green: 0.78, blue: 0.50),
                reversed: false
            )

            metricStepper(
                title: "Стресс",
                subtitle: stressLabel(vm.todayStress),
                icon: "brain.head.profile",
                value: $vm.todayStress,
                color: Color(red: 1.00, green: 0.50, blue: 0.16),
                reversed: true
            )

            metricStepper(
                title: "Качество сна",
                subtitle: sleepLabel(vm.todaySleepQuality),
                icon: "moon.stars.fill",
                value: $vm.todaySleepQuality,
                color: Color(red: 0.55, green: 0.35, blue: 1.00),
                reversed: false
            )

            tagPicker
            noteField
            saveButton
        }
        .padding(18)
        .background(cardBackground(cornerRadius: 26))
    }

    private var moodSelector: some View {
        HStack(spacing: 0) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()

                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        vm.todayMood = value
                    }
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(vm.todayMood == value ? moodColor(value).opacity(isDarkMode ? 0.20 : 0.14) : softCardFill)
                                .frame(width: vm.todayMood == value ? 56 : 47, height: vm.todayMood == value ? 56 : 47)
                                .overlay(
                                    Circle()
                                        .strokeBorder(vm.todayMood == value ? moodColor(value).opacity(0.80) : cardStroke, lineWidth: 1.3)
                                )

                            Text(moodEmoji(value))
                                .font(.system(size: vm.todayMood == value ? 29 : 22))
                        }

                        Text(moodShortLabel(value))
                            .font(.system(size: 10, weight: vm.todayMood == value ? .black : .bold, design: .rounded))
                            .foregroundColor(vm.todayMood == value ? moodColor(value) : mutedText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func metricStepper(
        title: String,
        subtitle: String,
        icon: String,
        value: Binding<Int>,
        color: Color,
        reversed: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(color)
                    .frame(width: 28, height: 28)
                    .background(color.opacity(isDarkMode ? 0.16 : 0.11), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(primaryText)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(secondaryText)
                }

                Spacer()

                Text("\(value.wrappedValue)/5")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(color)
            }

            HStack(spacing: 7) {
                ForEach(1...5, id: \.self) { index in
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.easeOut(duration: 0.16)) {
                            value.wrappedValue = index
                        }
                    } label: {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(index <= value.wrappedValue ? color.opacity(reversed ? 0.55 : 0.95) : softCardFill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 9)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(softCardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var tagPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(BagytL10n.tr("Факторы дня"))
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(mutedText)
                .textCase(.uppercase)
                .tracking(0.8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.tagOptions) { tag in
                        let selected = vm.selectedTags.contains(tag.id)

                        Button {
                            UISelectionFeedbackGenerator().selectionChanged()
                            withAnimation(.easeOut(duration: 0.16)) {
                                vm.toggleTag(tag.id)
                            }
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: tag.icon)
                                    .font(.system(size: 11, weight: .black))

                                Text(BagytL10n.tr(tag.title))
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                            }
                            .foregroundColor(selected ? .white : tag.color)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(selected ? tag.color.opacity(0.88) : tag.color.opacity(isDarkMode ? 0.14 : 0.10), in: Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(selected ? Color.white.opacity(0.16) : tag.color.opacity(0.18), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(BagytL10n.tr("Заметка"))
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(mutedText)
                .textCase(.uppercase)
                .tracking(0.8)

            ZStack(alignment: .topLeading) {
                if vm.todayNote.isEmpty {
                    Text(BagytL10n.tr("Что повлияло на ваше состояние сегодня?"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isDarkMode ? .white.opacity(0.28) : Color(red: 0.64, green: 0.74, blue: 0.80))
                        .padding(.top, 13)
                        .padding(.leading, 12)
                }

                TextEditor(text: $vm.todayNote)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(primaryText)
                    .frame(minHeight: 88)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .focused($noteFocused)
                    .colorScheme(isDarkMode ? .dark : .light)
            }
            .background(softCardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(cardStroke.opacity(0.75), lineWidth: 1)
            )
        }
    }

    private var saveButton: some View {
        Button {
            saveAndAnimate()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: vm.todayMood == nil ? "face.smiling" : "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .black))

                Text(BagytL10n.tr(vm.todayMood == nil ? "Выберите настроение" : "Сохранить чек-ин"))
                    .font(.system(size: 16, weight: .black, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: vm.todayMood == nil
                    ? [Color.gray.opacity(0.35), Color.gray.opacity(0.25)]
                    : [accent, accent2],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            .shadow(color: vm.todayMood == nil ? .clear : accent.opacity(isDarkMode ? 0.18 : 0.26), radius: 12, x: 0, y: 7)
        }
        .buttonStyle(.plain)
        .disabled(vm.todayMood == nil)
    }

    // MARK: - Week Chart

    private var weekChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                eyebrow: "НЕДЕЛЯ",
                title: "График состояния",
                icon: "chart.xyaxis.line",
                color: accent
            )

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(chartDays()) { item in
                    chartColumn(item)
                }
            }
            .frame(height: 128)

            HStack(spacing: 14) {
                chartLegend(color: Color(red: 0.12, green: 0.78, blue: 0.50), text: "хорошее")
                chartLegend(color: Color(red: 1.00, green: 0.65, blue: 0.12), text: "среднее")
                chartLegend(color: Color(red: 1.00, green: 0.35, blue: 0.35), text: "низкое")
                Spacer()
            }
        }
        .padding(18)
        .background(cardBackground(cornerRadius: 26))
    }

    private func chartColumn(_ item: ChartDay) -> some View {
        let mood = item.mood ?? 0
        let height = CGFloat(max(10, mood * 17))

        return VStack(spacing: 7) {
            Text(item.mood.map { moodEmoji($0) } ?? "·")
                .font(.system(size: 14))
                .foregroundColor(item.mood == nil ? mutedText : primaryText)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(softCardFill)
                    .frame(width: 28, height: 82)

                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(item.mood == nil ? mutedText.opacity(0.18) : moodColor(mood))
                    .frame(width: 28, height: item.mood == nil ? 10 : height)
            }

            Text(item.dayLabel)
                .font(.system(size: 11, weight: item.isToday ? .black : .bold, design: .rounded))
                .foregroundColor(item.isToday ? accent : mutedText)
        }
        .frame(maxWidth: .infinity)
    }

    private func chartLegend(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

            Text(BagytL10n.tr(text))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(mutedText)
        }
    }

    // MARK: - Insights

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: "AI-КОНТЕКСТ",
                title: "Наблюдения",
                icon: "sparkles",
                color: Color(red: 0.72, green: 0.45, blue: 1.00)
            )

            ForEach(vm.insights) { insight in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: insight.icon)
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(insight.color)
                        .frame(width: 36, height: 36)
                        .background(insight.color.opacity(isDarkMode ? 0.16 : 0.11), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(BagytL10n.tr(insight.title))
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(primaryText)

                        Text(BagytL10n.tr(insight.text))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(secondaryText)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(softCardFill, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
        }
        .padding(18)
        .background(cardBackground(cornerRadius: 26))
    }

    // MARK: - Factors

    private var factorsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: "ФАКТОРЫ",
                title: "Что чаще влияет",
                icon: "circle.hexagongrid.fill",
                color: Color(red: 1.00, green: 0.65, blue: 0.12)
            )

            let factors = factorRows()

            if factors.isEmpty {
                Text(BagytL10n.tr("Отмечайте факторы дня, и здесь появятся связи между настроением, стрессом, сном и событиями."))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(secondaryText)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(softCardFill, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            } else {
                ForEach(factors, id: \.id) { row in
                    factorRow(row)
                }
            }
        }
        .padding(18)
        .background(cardBackground(cornerRadius: 26))
    }

    private func factorRow(_ row: FactorRow) -> some View {
        HStack(spacing: 12) {
            Image(systemName: row.option.icon)
                .font(.system(size: 14, weight: .black))
                .foregroundColor(row.option.color)
                .frame(width: 36, height: 36)
                .background(row.option.color.opacity(isDarkMode ? 0.16 : 0.11), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(BagytL10n.tr(row.option.title))
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(primaryText)

                Text("\(row.count) \(BagytL10n.tr("раз")) · \(BagytL10n.tr("среднее настроение")) \(String(format: "%.1f", row.averageMood))/5")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(secondaryText)
            }

            Spacer()

            Text(moodEmoji(Int(row.averageMood.rounded())))
                .font(.system(size: 20))
        }
        .padding(12)
        .background(softCardFill, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    // MARK: - History Header
    
    private var historyHeader: some View {
        HStack {
            sectionHeaderText(eyebrow: "ИСТОРИЯ", title: "Последние записи")

            Spacer()

            if !vm.records.isEmpty {
                Button {
                    showResetAlert = true
                } label: {
                    Text(BagytL10n.tr("Очистить"))
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(Color(red: 1.00, green: 0.35, blue: 0.35))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(Color(red: 1.00, green: 0.35, blue: 0.35).opacity(isDarkMode ? 0.16 : 0.10), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 2)
    }

    private var emptyHistory: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(accent)
                .frame(width: 76, height: 76)
                .background(accent.opacity(isDarkMode ? 0.16 : 0.10), in: Circle())

            Text(BagytL10n.tr("История пока пустая"))
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(primaryText)

            Text(BagytL10n.tr("Первый чек-ин уже поможет Bagyt лучше понимать ваше состояние."))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 20)
        .background(cardBackground(cornerRadius: 26))
    }

    private func historyRow(_ record: MoodRecord) -> some View {
        let expanded = expandedRecordId == record.id

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 13) {
                ZStack {
                    Circle()
                        .fill(moodColor(record.mood).opacity(isDarkMode ? 0.18 : 0.12))
                        .frame(width: 48, height: 48)

                    Text(moodEmoji(record.mood))
                        .font(.system(size: 23))
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(moodLabel(record.mood))
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(primaryText)

                        Spacer()

                        Text(shortDateString(record.date))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(mutedText)
                    }

                    HStack(spacing: 10) {
                        smallSignal(icon: "bolt.fill", value: record.energy, color: Color(red: 0.12, green: 0.78, blue: 0.50))
                        smallSignal(icon: "brain.head.profile", value: record.stress, color: Color(red: 1.00, green: 0.50, blue: 0.16))
                        smallSignal(icon: "moon.stars.fill", value: record.sleepQuality, color: Color(red: 0.55, green: 0.35, blue: 1.00))
                    }

                    if !record.note.isEmpty {
                        Text(record.note)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(secondaryText)
                            .lineLimit(expanded ? nil : 2)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !record.tags.isEmpty {
                        tagRow(record.tags, limit: expanded ? 99 : 3)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.18)) {
                    expandedRecordId = expanded ? nil : record.id
                }
            }

            if expanded {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()

                    withAnimation(.easeOut(duration: 0.20)) {
                        vm.delete(record: record)
                        expandedRecordId = nil
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 13, weight: .bold))

                        Text(BagytL10n.tr("Удалить запись"))
                            .font(.system(size: 13, weight: .black, design: .rounded))
                    }
                    .foregroundColor(Color(red: 1.00, green: 0.35, blue: 0.35))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color(red: 1.00, green: 0.35, blue: 0.35).opacity(isDarkMode ? 0.16 : 0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(15)
        .background(cardBackground(cornerRadius: 22))
    }

    private func smallSignal(icon: String, value: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .black))

            Text("\(value)")
                .font(.system(size: 11, weight: .black, design: .rounded))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color.opacity(isDarkMode ? 0.16 : 0.10), in: Capsule())
    }

    private func tagRow(_ ids: [String], limit: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(ids.prefix(limit)), id: \.self) { id in
                if let tag = vm.tagOption(for: id) {
                    HStack(spacing: 4) {
                        Image(systemName: tag.icon)
                            .font(.system(size: 9, weight: .black))

                        Text(BagytL10n.tr(tag.title))
                            .font(.system(size: 10, weight: .black, design: .rounded))
                    }
                    .foregroundColor(tag.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(tag.color.opacity(isDarkMode ? 0.16 : 0.10), in: Capsule())
                }
            }

            if ids.count > limit {
                Text("+\(ids.count - limit)")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(mutedText)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Saved Badge

    private var savedBadge: some View {
        HStack(spacing: 9) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .black))
                .foregroundColor(Color(red: 0.10, green: 0.78, blue: 0.48))

            Text(BagytL10n.tr("Чек-ин сохранен"))
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(primaryText)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(cardFill, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(cardStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isDarkMode ? 0.24 : 0.10), radius: 14, x: 0, y: 8)
        .padding(.top, 12)
    }

    // MARK: - Shared UI

    private func cardBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(cardStroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isDarkMode ? 0.15 : 0.045), radius: 10, x: 0, y: 6)
    }

    private func sectionHeader(eyebrow: String, title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .black))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(isDarkMode ? 0.16 : 0.10), in: Circle())

            sectionHeaderText(eyebrow: eyebrow, title: title)

            Spacer()
        }
    }

    private func sectionHeaderText(eyebrow: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(BagytL10n.tr(eyebrow))
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(mutedText)
                .tracking(1.0)

            Text(BagytL10n.tr(title))
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundColor(primaryText)
        }
    }

    // MARK: - Data Helpers

    private struct ChartDay: Identifiable {
        let id = UUID()
        let date: Date
        let dayLabel: String
        let mood: Int?
        let isToday: Bool
    }

    private struct FactorRow {
        let id: String
        let option: MoodTagOption
        let count: Int
        let averageMood: Double
    }

    private func chartDays() -> [ChartDay] {
        let cal = Calendar.current
        let labels = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"].map { BagytL10n.tr($0) }
        let recentRecords = vm.last14Records // Оптимизация: ищем только по недавним записям

        return (0..<7).compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -(6 - offset), to: Date()) else {
                return nil
            }

            let weekday = cal.component(.weekday, from: day)
            let label = labels[max(0, (weekday + 5) % 7)]
            let record = recentRecords.first { cal.isDate($0.date, inSameDayAs: day) }

            return ChartDay(
                date: day,
                dayLabel: label,
                mood: record?.mood,
                isToday: cal.isDateInToday(day)
            )
        }
    }

    private func factorRows() -> [FactorRow] {
        let recent = vm.last14Records
        var rows: [FactorRow] = []

        for option in vm.tagOptions {
            let related = recent.filter { $0.tags.contains(option.id) }
            guard !related.isEmpty else { continue }

            let avg = Double(related.map(\.mood).reduce(0, +)) / Double(related.count)
            rows.append(FactorRow(id: option.id, option: option, count: related.count, averageMood: avg))
        }

        return rows
            .sorted {
                if $0.count == $1.count {
                    return $0.averageMood > $1.averageMood
                }
                return $0.count > $1.count
            }
            .prefix(4)
            .map { $0 }
    }

    private func saveAndAnimate() {
        guard vm.todayMood != nil else { return }

        noteFocused = false
        vm.saveTodayMood()

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            showSavedBadge = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            withAnimation(.easeOut(duration: 0.18)) {
                showSavedBadge = false
            }
        }
    }

    // MARK: - Text Helpers

    private func moodEmoji(_ value: Int) -> String {
        ["😩", "😕", "😐", "😊", "🤩"][max(0, min(value - 1, 4))]
    }

    private func moodLabel(_ value: Int) -> String {
        BagytL10n.tr(["Плохо", "Так себе", "Нормально", "Хорошо", "Отлично"][max(0, min(value - 1, 4))])
    }

    private func moodShortLabel(_ value: Int) -> String {
        BagytL10n.tr(["Плохо", "Так себе", "Норм", "Хорошо", "Класс"][max(0, min(value - 1, 4))])
    }

    private func moodColor(_ value: Int) -> Color {
        [
            Color(red: 1.00, green: 0.35, blue: 0.35),
            Color(red: 1.00, green: 0.58, blue: 0.12),
            Color(red: 0.055, green: 0.647, blue: 0.914),
            Color(red: 0.10, green: 0.78, blue: 0.48),
            Color(red: 0.55, green: 0.35, blue: 1.00)
        ][max(0, min(value - 1, 4))]
    }

    private func energyLabel(_ value: Int) -> String {
        BagytL10n.tr(["Очень низкая", "Низкая", "Средняя", "Высокая", "Максимум"][max(0, min(value - 1, 4))])
    }

    private func stressLabel(_ value: Int) -> String {
        BagytL10n.tr(["Спокойно", "Легкий", "Средний", "Высокий", "Очень высокий"][max(0, min(value - 1, 4))])
    }

    private func sleepLabel(_ value: Int) -> String {
        BagytL10n.tr(["Очень плохо", "Плохо", "Нормально", "Хорошо", "Отлично"][max(0, min(value - 1, 4))])
    }

    private func deltaText(_ value: Int) -> String {
        if value > 0 { return "+\(value)" }
        return "\(value)"
    }

    private func todayDateString() -> String {
        Self.fullDayFormatter.string(from: Date()).capitalized
    }

    private func shortDateString(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return BagytL10n.tr("Сегодня") }
        if Calendar.current.isDateInYesterday(date) { return BagytL10n.tr("Вчера") }
        return Self.shortDateFormatter.string(from: date)
    }

    private static let fullDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = BagytL10n.currentLocale
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = BagytL10n.currentLocale
        formatter.dateFormat = "d MMM"
        return formatter
    }()
}
#endif

// MARK: - Preview

#Preview {
    MoodView()
        .environmentObject(AppState())
}
