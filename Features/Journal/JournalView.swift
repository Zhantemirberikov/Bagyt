//
//  JournalView.swift
//  Bagyt
//
//  Premium optimized Journal
//  Fast glass timeline · Per-user storage · AI-ready health notes
//

import SwiftUI
import Combine
import UIKit

// MARK: - Models

enum JournalCategory: String, CaseIterable, Codable {
    case symptom   = "Симптом"
    case sleep     = "Сон"
    case visit     = "Визит"
    case activity  = "Активность"
    case mood      = "Настроение"
    case note      = "Заметка"

    var icon: String {
        switch self {
        case .symptom:  return "cross.circle.fill"
        case .sleep:    return "moon.stars.fill"
        case .visit:    return "stethoscope"
        case .activity: return "figure.run"
        case .mood:     return "face.smiling.fill"
        case .note:     return "note.text"
        }
    }

    var emoji: String {
        switch self {
        case .symptom:  return "😣"
        case .sleep:    return "😴"
        case .visit:    return "🏥"
        case .activity: return "🏋️"
        case .mood:     return "😊"
        case .note:     return "📝"
        }
    }

    var color: Color {
        switch self {
        case .symptom:  return Color(red: 1.00, green: 0.35, blue: 0.35)
        case .sleep:    return Color(red: 0.55, green: 0.35, blue: 1.00)
        case .visit:    return Color(red: 0.055, green: 0.647, blue: 0.914)
        case .activity: return Color(red: 0.10, green: 0.78, blue: 0.48)
        case .mood:     return Color(red: 1.00, green: 0.65, blue: 0.10)
        case .note:     return Color(red: 0.40, green: 0.60, blue: 0.80)
        }
    }

    var bgColor: Color { color.opacity(0.12) }

    var title: String {
        BagytL10n.tr(rawValue)
    }
}

struct JournalEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var body: String
    var category: JournalCategory
    var date: Date = Date()
    var mood: Int? = nil
    var severity: Int? = nil
}

struct JournalInsight {
    let title: String
    let body: String
    let icon: String
    let color: Color
}

// MARK: - ViewModel

final class JournalViewModel: ObservableObject {
    @Published var entries: [JournalEntry] = []
    @Published var selectedFilter: JournalCategory? = nil
    @Published var searchText: String = ""

    private let baseKey = "bagyt_journal_entries"
    private var activeStorageKey = "bagyt_journal_entries_guest"

    init() {
        configureUser(token: UserDefaults.standard.string(forKey: "userToken"))
    }

    var filtered: [JournalEntry] {
        var result = entries

        if let filter = selectedFilter {
            result = result.filter { $0.category == filter }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(query) ||
                $0.body.localizedCaseInsensitiveContains(query)
            }
        }

        return result.sorted { $0.date > $1.date }
    }

    var entriesLast7Days: [JournalEntry] {
        let start = Calendar.current.date(
            byAdding: .day,
            value: -6,
            to: Calendar.current.startOfDay(for: Date())
        ) ?? Date()

        return entries.filter { $0.date >= start }
    }

    var symptomsLast7Days: Int {
        entriesLast7Days.filter { $0.category == .symptom }.count
    }

    var averageMood: Double? {
        let moods = entriesLast7Days.compactMap(\.mood)
        guard !moods.isEmpty else { return nil }
        return Double(moods.reduce(0, +)) / Double(moods.count)
    }

    var weeklyBuckets: [(date: Date, count: Int)] {
        let cal = Calendar.current

        return (0..<7).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let start = cal.startOfDay(for: date)
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? date
            let count = entries.filter { $0.date >= start && $0.date < end }.count
            return (date, count)
        }
    }

    var smartInsight: JournalInsight {
        if let highSeverity = entriesLast7Days
            .filter({ $0.category == .symptom })
            .compactMap(\.severity)
            .max(), highSeverity >= 7 {
            return JournalInsight(
                title: BagytL10n.tr("Высокая выраженность"),
                body: String(format: BagytL10n.tr("Есть симптом на %d/10. Добавьте триггеры, лекарства и что помогло — так ИИ точнее увидит картину."), highSeverity),
                icon: "waveform.path.ecg.rectangle.fill",
                color: JournalCategory.symptom.color
            )
        }

        if symptomsLast7Days >= 3 {
            return JournalInsight(
                title: BagytL10n.tr("Симптомы повторяются"),
                body: String(format: BagytL10n.tr("%d симптома за 7 дней. Уже можно искать связь со сном, активностью и настроением."), symptomsLast7Days),
                icon: "sparkles",
                color: Color(red: 0.055, green: 0.647, blue: 0.914)
            )
        }

        if let averageMood, averageMood <= 2.8 {
            return JournalInsight(
                title: BagytL10n.tr("Настроение ниже обычного"),
                body: String(format: BagytL10n.tr("Средняя оценка %@/5. Отмечайте сон, стресс и энергию рядом с симптомами."), String(format: "%.1f", averageMood)),
                icon: "brain.head.profile",
                color: JournalCategory.mood.color
            )
        }

        return JournalInsight(
            title: BagytL10n.tr("Журнал готов к анализу"),
            body: BagytL10n.tr("Симптомы, сон, настроение и визиты в одном месте помогают ИИ давать более точный контекст."),
            icon: "sparkle.magnifyingglass",
            color: Color(red: 0.024, green: 0.714, blue: 0.831)
        )
    }

    func configureUser(token: String?) {
        let newKey = storageKey(for: token)

        guard newKey != activeStorageKey else {
            load()
            return
        }

        activeStorageKey = newKey
        selectedFilter = nil
        searchText = ""
        load()
    }

    func add(_ entry: JournalEntry) {
        entries.append(entry)
        save()
    }

    func delete(_ entry: JournalEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: activeStorageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: activeStorageKey),
              let saved = try? JSONDecoder().decode([JournalEntry].self, from: data) else {
            entries = []
            return
        }

        entries = saved
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

    static func demoEntries() -> [JournalEntry] {
        let cal = Calendar.current
        return [
            JournalEntry(
                title: BagytL10n.tr("Головная боль"),
                body: BagytL10n.tr("Болит с утра, давящая, слева. Приняла ибупрофен."),
                category: .symptom,
                date: Date(),
                severity: 6
            ),
            JournalEntry(
                title: BagytL10n.tr("Хороший сон"),
                body: BagytL10n.tr("Спал 8 часов, никаких пробуждений. Чувствую себя отлично."),
                category: .sleep,
                date: cal.date(byAdding: .hour, value: -14, to: Date())!,
                mood: 5
            ),
            JournalEntry(
                title: BagytL10n.tr("Визит к терапевту"),
                body: BagytL10n.tr("Назначен витамин D 2000 МЕ и магний B6 курсом 1 месяц."),
                category: .visit,
                date: cal.date(byAdding: .day, value: -2, to: Date())!
            )
        ]
    }
}

// MARK: - Main View

struct JournalView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lang: LanguageManager
    @StateObject private var vm = JournalViewModel()

    @AppStorage("isDarkModeEnabled") private var isDarkMode = false

    @State private var showAddSheet = false
    @State private var selectedEntry: JournalEntry? = nil
    @State private var showSearch = false
    @State private var appear = false

    private let accent = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)

    private var primaryText: Color { isDarkMode ? .white : Color(red: 0.06, green: 0.09, blue: 0.16) }
    private var secondaryText: Color { isDarkMode ? Color.white.opacity(0.64) : Color(red: 0.38, green: 0.52, blue: 0.62) }
    private var panelFill: Color { isDarkMode ? Color.white.opacity(0.075) : Color.white.opacity(0.78) }
    private var panelStroke: Color { isDarkMode ? Color.white.opacity(0.10) : Color.white.opacity(0.70) }
    private var floatingAddButtonBottomPadding: CGFloat {
        safeAreaBottomInset() + 112
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.clear
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                    intelligenceCard
                    weeklyPulse
                    filterChips
                    if showSearch { searchBar }
                    entriesList
                    Spacer(minLength: 150)
                }
                .padding(.top, 4)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 8)
            }

            addButton
        }
        .sheet(isPresented: $showAddSheet) {
            AddEntrySheet(vm: vm)
                .preferredColorScheme(isDarkMode ? .dark : .light)
        }
        .sheet(item: $selectedEntry) { entry in
            EntryDetailSheet(entry: entry, vm: vm)
                .preferredColorScheme(isDarkMode ? .dark : .light)
        }
        .onAppear {
            vm.configureUser(token: appState.userToken)

            withAnimation(.easeOut(duration: 0.28)) {
                appear = true
            }
        }
        .onChange(of: appState.userToken) { newToken in
            vm.configureUser(token: newToken)
        }
    }

    private var headerSection: some View {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(BagytL10n.tr("Журнал здоровья"))
                        .font(.system(size: 31, weight: .black, design: .rounded))
                        .foregroundColor(primaryText)
                
            
        
                Text(String(format: BagytL10n.tr("%d записей · %d симптомов за неделю"), vm.entries.count, vm.symptomsLast7Days))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(secondaryText)
            }

            Spacer(minLength: 8)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeOut(duration: 0.22)) {
                    showSearch.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(showSearch ? accent : panelFill)
                        .overlay(Circle().strokeBorder(panelStroke, lineWidth: 1))
                        .shadow(color: Color.black.opacity(isDarkMode ? 0.12 : 0.06), radius: 8, x: 0, y: 4)

                    Image(systemName: showSearch ? "xmark" : "magnifyingglass")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(showSearch ? .white : (isDarkMode ? .white : accent))
                }
                .frame(width: 46, height: 46)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var intelligenceCard: some View {
        let insight = vm.smartInsight

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(insight.color.opacity(isDarkMode ? 0.20 : 0.14))
                        .frame(width: 54, height: 54)

                    Image(systemName: insight.icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(insight.color)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(insight.title)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(primaryText)

                    Text(insight.body)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(secondaryText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                intelligenceMetric(title: "7 дней", value: "\(vm.entriesLast7Days.count)", icon: "calendar.badge.clock", color: accent)
                intelligenceMetric(title: "Симптомы", value: "\(vm.symptomsLast7Days)", icon: "cross.case.fill", color: JournalCategory.symptom.color)
                intelligenceMetric(title: "Настроение", value: moodMetricText, icon: "face.smiling.fill", color: JournalCategory.mood.color)
            }
        }
        .padding(18)
        .background(cardBackground(cornerRadius: 28))
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private var moodMetricText: String {
        guard let averageMood = vm.averageMood else { return "-" }
        return String(format: "%.1f", averageMood)
    }

    private func intelligenceMetric(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .black))

                Text(BagytL10n.tr(title))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(color)

            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(color.opacity(isDarkMode ? 0.13 : 0.10))
        )
    }

    private var weeklyPulse: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(BagytL10n.tr("Пульс недели"))
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(primaryText)

                    Text(BagytL10n.tr("Активность записей по дням"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(secondaryText)
                }

                Spacer()

                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(accent)
                    .frame(width: 36, height: 36)
                    .background(accent.opacity(isDarkMode ? 0.18 : 0.12), in: Circle())
            }

            HStack(alignment: .bottom, spacing: 9) {
                ForEach(Array(vm.weeklyBuckets.enumerated()), id: \.offset) { _, bucket in
                    weeklyBar(date: bucket.date, count: bucket.count, maxCount: maxWeeklyCount)
                }
            }
            .frame(height: 78)
        }
        .padding(16)
        .background(cardBackground(cornerRadius: 24))
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private var maxWeeklyCount: Int {
        max(vm.weeklyBuckets.map(\.count).max() ?? 1, 1)
    }

    private func weeklyBar(date: Date, count: Int, maxCount: Int) -> some View {
        let height = CGFloat(max(8, Int((Double(count) / Double(maxCount)) * 48)))
        let isToday = Calendar.current.isDateInToday(date)

        return VStack(spacing: 7) {
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.045))
                    .frame(width: 26, height: 50)

                Capsule()
                    .fill(count > 0 ? accent : secondaryText.opacity(0.18))
                    .frame(width: 26, height: height)
            }

            Text(shortWeekday(date))
                .font(.system(size: 10, weight: isToday ? .black : .bold, design: .rounded))
                .foregroundColor(isToday ? accent : secondaryText)
                .frame(width: 32)
        }
        .frame(maxWidth: .infinity)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                filterChip(
                    label: "Все",
                    icon: "square.grid.2x2.fill",
                    count: vm.entries.count,
                    isSelected: vm.selectedFilter == nil
                ) {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.easeOut(duration: 0.18)) {
                        vm.selectedFilter = nil
                    }
                }

                ForEach(JournalCategory.allCases, id: \.self) { category in
                    filterChip(
                        label: category.title,
                        icon: category.icon,
                        count: vm.entries.filter { $0.category == category }.count,
                        isSelected: vm.selectedFilter == category,
                        color: category.color
                    ) {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.easeOut(duration: 0.18)) {
                            vm.selectedFilter = vm.selectedFilter == category ? nil : category
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 16)
    }

    private func filterChip(
        label: String,
        icon: String,
        count: Int,
        isSelected: Bool,
        color: Color = Color(red: 0.055, green: 0.647, blue: 0.914),
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .black))

                Text(BagytL10n.tr(label))
                    .font(.system(size: 13, weight: .black, design: .rounded))

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background((isSelected ? Color.white : color).opacity(isSelected ? 0.22 : 0.13), in: Capsule())
                }
            }
            .foregroundColor(isSelected ? .white : (isDarkMode ? .white.opacity(0.86) : color))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(isSelected ? color : color.opacity(isDarkMode ? 0.16 : 0.12))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.white.opacity(0.20) : color.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: isSelected ? color.opacity(0.18) : .clear, radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var searchBar: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(accent)

            TextField(BagytL10n.tr("Поиск по записям..."), text: $vm.searchText)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(primaryText)
                .colorScheme(isDarkMode ? .dark : .light)

            if !vm.searchText.isEmpty {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    vm.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(secondaryText)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(cardBackground(cornerRadius: 19))
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var entriesList: some View {
        LazyVStack(spacing: 0) {
            if vm.filtered.isEmpty {
                emptyState
            } else {
                ForEach(groupedSections, id: \.key) { section in
                    timelineHeader(section.key)

                    ForEach(Array(section.entries.enumerated()), id: \.element.id) { index, entry in
                        JournalEntryCard(
                            entry: entry,
                            isLastInGroup: index == section.entries.count - 1,
                            isDarkMode: isDarkMode,
                            onDelete: {
                                withAnimation(.easeOut(duration: 0.22)) {
                                    vm.delete(entry)
                                }
                            }
                        )
                        .padding(.horizontal, 20)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedEntry = entry
                        }
                    }
                }
            }
        }
    }

    private func timelineHeader(_ key: String) -> some View {
        HStack {
            Text(key)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(isDarkMode ? .white.opacity(0.68) : Color(red: 0.48, green: 0.61, blue: 0.70))
                .textCase(.uppercase)
                .tracking(0.9)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(accent.opacity(isDarkMode ? 0.18 : 0.10))
                    .frame(width: 96, height: 96)

                Image(systemName: "book.closed.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(accent)
            }

            Text(BagytL10n.tr(vm.searchText.isEmpty ? "Нет записей" : "Ничего не найдено"))
                .font(.system(size: 19, weight: .black, design: .rounded))
                .foregroundColor(primaryText)

            Text(BagytL10n.tr(vm.searchText.isEmpty ? "Нажмите +, чтобы добавить первую запись" : "Попробуйте другой запрос или фильтр"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 64)
        .padding(.horizontal, 30)
    }

    private var addButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showAddSheet = true
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(isDarkMode ? 0.12 : 0.24))
                    .background(.ultraThinMaterial, in: Circle())

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(isDarkMode ? 0.34 : 0.58),
                                accent.opacity(isDarkMode ? 0.18 : 0.14),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 72
                        )
                    )
                    .blendMode(.screen)

                Circle()
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.95), location: 0),
                                .init(color: .white.opacity(0.16), location: 0.42),
                                .init(color: accent2.opacity(0.42), location: 1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.6
                    )

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(0.42),
                                Color.purple.opacity(0.30),
                                Color.white.opacity(0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .blur(radius: 4)
                    .opacity(0.72)

                Capsule()
                    .fill(Color.white.opacity(0.78))
                    .frame(width: 24, height: 4)
                    .rotationEffect(.degrees(-24))
                    .offset(x: -12, y: -18)
                    .blur(radius: 0.4)

                Image(systemName: "plus")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundColor(isDarkMode ? .white : Color(red: 0.05, green: 0.09, blue: 0.14))
                    .shadow(color: .white.opacity(isDarkMode ? 0.12 : 0.55), radius: 3, x: -1, y: -1)
                    .shadow(color: .black.opacity(isDarkMode ? 0.34 : 0.16), radius: 2, x: 0, y: 1)
            }
            .frame(width: 64, height: 64)
            .compositingGroup()
            .shadow(color: Color.black.opacity(isDarkMode ? 0.34 : 0.13), radius: 16, x: 0, y: 9)
            .shadow(color: accent.opacity(isDarkMode ? 0.18 : 0.25), radius: 20, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 24)
        .padding(.bottom, floatingAddButtonBottomPadding)
        .scaleEffect(appear ? 1 : 0.1)
        .animation(.spring(response: 0.42, dampingFraction: 0.72).delay(0.12), value: appear)
    }

    private func cardBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(panelFill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(panelStroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isDarkMode ? 0.13 : 0.045), radius: 10, x: 0, y: 5)
    }

    private var groupedSections: [(key: String, entries: [JournalEntry])] {
        let grouped = Dictionary(grouping: vm.filtered) { sectionKey(for: $0.date) }

        return grouped
            .map { key, entries in
                (key: key, entries: entries.sorted { $0.date > $1.date })
            }
            .sorted {
                let dateA = $0.entries.first?.date ?? .distantPast
                let dateB = $1.entries.first?.date ?? .distantPast
                return dateA > dateB
            }
    }

    private func sectionKey(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return BagytL10n.tr("Сегодня") }
        if Calendar.current.isDateInYesterday(date) { return BagytL10n.tr("Вчера") }

        let formatter = DateFormatter()
        formatter.locale = BagytL10n.currentLocale
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }

    private func shortWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = BagytL10n.currentLocale
        formatter.dateFormat = "EE"
        return formatter.string(from: date).replacingOccurrences(of: ".", with: "")
    }

    private func safeAreaBottomInset() -> CGFloat {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) else {
            return 0
        }

        return window.safeAreaInsets.bottom
    }
}

// MARK: - Entry Card

struct JournalEntryCard: View {
    let entry: JournalEntry
    let isLastInGroup: Bool
    let isDarkMode: Bool
    let onDelete: () -> Void

    private var primaryText: Color {
        isDarkMode ? .white : Color(red: 0.06, green: 0.09, blue: 0.16)
    }

    private var secondaryText: Color {
        isDarkMode ? .white.opacity(0.66) : Color(red: 0.38, green: 0.52, blue: 0.62)
    }

    private var cardFill: Color {
        isDarkMode ? Color.white.opacity(0.075) : Color.white.opacity(0.78)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            timelineRail
            entryCard
        }
    }

    private var timelineRail: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(isDarkMode ? Color.black.opacity(0.32) : Color.white.opacity(0.92))
                    .frame(width: 34, height: 34)

                Circle()
                    .stroke(entry.category.color.opacity(0.55), lineWidth: 3)
                    .frame(width: 34, height: 34)

                Text(entry.category.emoji)
                    .font(.system(size: 16))
            }
            .padding(.top, 6)

            if !isLastInGroup {
                Rectangle()
                    .fill(isDarkMode ? Color.white.opacity(0.10) : Color.black.opacity(0.06))
                    .frame(width: 2)
                    .padding(.top, 5)
            }
        }
    }

    private var entryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.title)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(primaryText)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Image(systemName: entry.category.icon)
                            .font(.system(size: 10, weight: .black))

                        Text(entry.category.title)
                            .font(.system(size: 11, weight: .black, design: .rounded))
                    }
                    .foregroundColor(entry.category.color)
                }

                Spacer(minLength: 8)

                Text(timeString(entry.date))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(isDarkMode ? .white.opacity(0.48) : Color(red: 0.62, green: 0.72, blue: 0.80))
                    .lineLimit(1)
            }

            if !entry.body.isEmpty {
                Text(entry.body)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(secondaryText)
                    .lineLimit(3)
                    .lineSpacing(3)
            }

            if entry.mood != nil || entry.severity != nil {
                HStack(spacing: 10) {
                    if let mood = entry.mood {
                        miniBadge(icon: moodEmoji(mood), text: "\(mood)/5", color: Color(red: 1.0, green: 0.65, blue: 0.10))
                    }

                    if let severity = entry.severity {
                        miniBadge(icon: "⚕️", text: "\(severity)/10", color: entry.category.color)
                    }

                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(isDarkMode ? Color.white.opacity(0.10) : Color.white.opacity(0.70), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isDarkMode ? 0.14 : 0.045), radius: 8, x: 0, y: 4)
        .padding(.bottom, isLastInGroup ? 18 : 12)
        .contextMenu {
            Button(role: .destructive) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onDelete()
            } label: {
                Label(BagytL10n.tr("Удалить запись"), systemImage: "trash")
            }
        }
    }

    private func miniBadge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(icon)
                .font(.system(size: 13))

            Text(text)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(color)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(color.opacity(isDarkMode ? 0.16 : 0.11), in: Capsule())
    }

    private func timeString(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return Self.todayFormatter.string(from: date)
        }

        return Self.fullFormatter.string(from: date)
    }

    private func moodEmoji(_ value: Int) -> String {
        ["😩", "😕", "😐", "😊", "🤩"][max(1, min(5, value)) - 1]
    }

    private static let todayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let fullFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = BagytL10n.currentLocale
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter
    }()
}

// MARK: - Add Entry Sheet

struct AddEntrySheet: View {
    @ObservedObject var vm: JournalViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkModeEnabled") private var isDarkMode = false

    @State private var title = ""
    @State private var bodyText = ""
    @State private var category = JournalCategory.symptom
    @State private var mood = 3
    @State private var hasMood = false
    @State private var severity = 4
    @State private var entryDate = Date()
    @State private var showValidation = false

    @FocusState private var titleFocused: Bool

    private let accent = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)

    private var baseBg: Color { isDarkMode ? Color(red: 0.04, green: 0.06, blue: 0.10) : Color(red: 0.94, green: 0.97, blue: 1.0) }
    private var cardBg: Color { isDarkMode ? Color.white.opacity(0.075) : Color.white.opacity(0.84) }
    private var primaryText: Color { isDarkMode ? .white : Color(red: 0.06, green: 0.09, blue: 0.16) }
    private var secondaryText: Color { isDarkMode ? .white.opacity(0.60) : Color(red: 0.48, green: 0.61, blue: 0.70) }

    var body: some View {
        NavigationStack {
            ZStack {
                baseBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        categoryPicker
                        quickTemplates
                        titleField
                        bodyField
                        severitySection
                        moodSection
                        dateCard
                        saveButton
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle(BagytL10n.tr("Новая запись"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(BagytL10n.tr("Отмена")) { dismiss() }
                        .foregroundColor(accent)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
            }
            .onAppear { titleFocused = true }
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionLabel("Категория")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(JournalCategory.allCases, id: \.self) { cat in
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.easeOut(duration: 0.18)) {
                            category = cat
                            if cat == .mood { hasMood = true }
                        }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(category == cat ? cat.color : (isDarkMode ? Color.white.opacity(0.075) : cat.bgColor))
                                    .frame(height: 54)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .strokeBorder(category == cat ? Color.white.opacity(0.26) : Color.white.opacity(isDarkMode ? 0.08 : 0.45), lineWidth: 1)
                                    )

                                Image(systemName: cat.icon)
                                    .font(.system(size: 21, weight: .bold))
                                    .foregroundColor(category == cat ? .white : cat.color)
                            }

                            Text(cat.title)
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(category == cat ? cat.color : secondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var quickTemplates: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Быстрые подсказки")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(templateSuggestions, id: \.title) { suggestion in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            applyTemplate(suggestion)
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: suggestion.icon)
                                    .font(.system(size: 12, weight: .black))

                                Text(suggestion.title)
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                            }
                            .foregroundColor(category.color)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .background(category.color.opacity(isDarkMode ? 0.16 : 0.11), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Заголовок")

            TextField(BagytL10n.tr("Например: Головная боль"), text: $title)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(primaryText)
                .focused($titleFocused)
                .colorScheme(isDarkMode ? .dark : .light)
                .padding(16)
                .background(fieldBackground(cornerRadius: 19, border: showValidation && title.trimmingCharacters(in: .whitespaces).isEmpty ? Color.red.opacity(0.5) : nil))
        }
    }

    private var bodyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Описание")

            ZStack(alignment: .topLeading) {
                if bodyText.isEmpty {
                    Text(placeholderForCategory)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isDarkMode ? .white.opacity(0.30) : Color(red: 0.66, green: 0.77, blue: 0.84))
                        .padding(.top, 16)
                        .padding(.leading, 13)
                }

                TextEditor(text: $bodyText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(primaryText)
                    .frame(minHeight: 118)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(8)
                    .colorScheme(isDarkMode ? .dark : .light)
            }
            .background(fieldBackground(cornerRadius: 19))
        }
    }

    @ViewBuilder
    private var severitySection: some View {
        if category == .symptom {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    sectionLabel("Сила симптома")
                    Spacer()
                    Text("\(severity)/10")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(category.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(category.color.opacity(isDarkMode ? 0.18 : 0.12), in: Capsule())
                }

                Slider(
                    value: Binding(
                        get: { Double(severity) },
                        set: { severity = Int($0.rounded()) }
                    ),
                    in: 1...10,
                    step: 1
                )
                .tint(category.color)

                HStack {
                    Text(BagytL10n.tr("Легко"))
                    Spacer()
                    Text(BagytL10n.tr("Сильно"))
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(secondaryText)
            }
            .padding(18)
            .background(fieldBackground(cornerRadius: 20))
        }
    }

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionLabel("Настроение")
                Spacer()
                Toggle("", isOn: $hasMood)
                    .tint(accent)
                    .labelsHidden()
            }

            if hasMood {
                HStack(spacing: 0) {
                    ForEach(1...5, id: \.self) { value in
                        Button {
                            UISelectionFeedbackGenerator().selectionChanged()
                            withAnimation(.easeOut(duration: 0.18)) {
                                mood = value
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Text(moodEmoji(value))
                                    .font(.system(size: mood == value ? 37 : 26))

                                Circle()
                                    .fill(mood == value ? Color(red: 1.0, green: 0.65, blue: 0.10) : (isDarkMode ? Color.white.opacity(0.12) : Color.black.opacity(0.06)))
                                    .frame(width: 7, height: 7)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 10)
            }
        }
        .padding(18)
        .background(fieldBackground(cornerRadius: 20))
    }

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Дата и время")

            DatePicker("", selection: $entryDate, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(accent)
                .colorScheme(isDarkMode ? .dark : .light)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(fieldBackground(cornerRadius: 20))
    }

    private var saveButton: some View {
        Button { save() } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .bold))

                Text(BagytL10n.tr("Сохранить запись"))
                    .font(.system(size: 17, weight: .black, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
            .shadow(color: accent.opacity(0.28), radius: 12, x: 0, y: 7)
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    private func fieldBackground(cornerRadius: CGFloat, border: Color? = nil) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(cardBg)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(border ?? Color.white.opacity(isDarkMode ? 0.10 : 0.58), lineWidth: border == nil ? 1 : 1.5)
            )
            .shadow(color: Color.black.opacity(isDarkMode ? 0.10 : 0.04), radius: 8, x: 0, y: 4)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(BagytL10n.tr(text))
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundColor(secondaryText)
            .textCase(.uppercase)
            .tracking(1.0)
    }

    private var placeholderForCategory: String {
        switch category {
        case .symptom:  return BagytL10n.tr("Где болит, когда началось, что усиливает, что помогло...")
        case .sleep:    return BagytL10n.tr("Сколько часов, были ли пробуждения, как чувствуете себя утром...")
        case .visit:    return BagytL10n.tr("Что сказал врач, назначения, дозировки, следующие шаги...")
        case .activity: return BagytL10n.tr("Тип активности, длительность, пульс, самочувствие после...")
        case .mood:     return BagytL10n.tr("Что повлияло на настроение, уровень стресса, энергия...")
        case .note:     return BagytL10n.tr("Любая важная заметка о здоровье...")
        }
    }

    private var templateSuggestions: [(title: String, icon: String, body: String)] {
        switch category {
        case .symptom:
            return [
                (BagytL10n.tr("Боль"), "bolt.heart.fill", String(format: BagytL10n.tr("Локализация: \nНачалось: \nСила: %d/10\nЧто усиливает: \nЧто помогло: "), severity)),
                (BagytL10n.tr("Лекарство"), "pills.fill", BagytL10n.tr("Препарат: \nДозировка: \nВремя приема: \nЭффект: ")),
                (BagytL10n.tr("Триггер"), "exclamationmark.triangle.fill", BagytL10n.tr("Возможный триггер: \nЕда/сон/стресс: \nРеакция организма: "))
            ]
        case .sleep:
            return [
                (BagytL10n.tr("8 часов"), "moon.zzz.fill", BagytL10n.tr("Сон: 8 часов\nПробуждения: нет\nСамочувствие утром: ")),
                (BagytL10n.tr("Плохой сон"), "bed.double.fill", BagytL10n.tr("Сон: \nПробуждения: \nПричина: \nЭнергия утром: ")),
                (BagytL10n.tr("Режим"), "clock.fill", BagytL10n.tr("Лег спать: \nПроснулся: \nЭкран перед сном: "))
            ]
        case .visit:
            return [
                (BagytL10n.tr("Назначение"), "doc.text.fill", BagytL10n.tr("Врач: \nНазначение: \nДозировка: \nКонтроль: ")),
                (BagytL10n.tr("Анализы"), "testtube.2", BagytL10n.tr("Анализ: \nРезультат: \nКомментарий врача: ")),
                (BagytL10n.tr("Вопросы"), "questionmark.circle.fill", BagytL10n.tr("Что спросить: \nЧто уточнить: \nЧто беспокоит: "))
            ]
        case .activity:
            return [
                (BagytL10n.tr("Тренировка"), "figure.run", BagytL10n.tr("Активность: \nДлительность: \nПульс: \nСамочувствие после: ")),
                (BagytL10n.tr("Прогулка"), "figure.walk", BagytL10n.tr("Шаги/время: \nТемп: \nЭнергия после: ")),
                (BagytL10n.tr("Восстановление"), "heart.fill", BagytL10n.tr("Нагрузка: \nУсталость: \nБоль/напряжение: "))
            ]
        case .mood:
            return [
                (BagytL10n.tr("Стресс"), "brain.head.profile", BagytL10n.tr("Стресс: \nПричина: \nЭнергия: \nЧто помогло: ")),
                (BagytL10n.tr("Хороший день"), "sun.max.fill", BagytL10n.tr("Что получилось: \nЭнергия: \nНастроение: ")),
                (BagytL10n.tr("Усталость"), "battery.25", BagytL10n.tr("Усталость: \nСон: \nАппетит: \nПланы на отдых: "))
            ]
        case .note:
            return [
                (BagytL10n.tr("Заметка"), "note.text", BagytL10n.tr("Важно: \nКонтекст: \nЧто сделать дальше: ")),
                (BagytL10n.tr("Питание"), "fork.knife", BagytL10n.tr("Еда: \nВремя: \nРеакция: ")),
                (BagytL10n.tr("Самочувствие"), "heart.text.square.fill", BagytL10n.tr("Общее состояние: \nЭнергия: \nНаблюдения: "))
            ]
        }
    }

    private func applyTemplate(_ suggestion: (title: String, icon: String, body: String)) {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            title = suggestion.title
        }

        if bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            bodyText = suggestion.body
        } else {
            bodyText += "\n\n" + suggestion.body
        }
    }

    private func moodEmoji(_ value: Int) -> String {
        ["😩", "😕", "😐", "😊", "🤩"][max(1, min(5, value)) - 1]
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            withAnimation(.easeOut(duration: 0.18)) {
                showValidation = true
            }
            return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        vm.add(
            JournalEntry(
                title: trimmedTitle,
                body: bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category,
                date: entryDate,
                mood: hasMood ? mood : nil,
                severity: category == .symptom ? severity : nil
            )
        )

        dismiss()
    }
}

// MARK: - Entry Detail Sheet

struct EntryDetailSheet: View {
    let entry: JournalEntry
    @ObservedObject var vm: JournalViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkModeEnabled") private var isDarkMode = false

    private let accent = Color(red: 0.055, green: 0.647, blue: 0.914)

    private var baseBg: Color { isDarkMode ? Color(red: 0.04, green: 0.06, blue: 0.10) : Color(red: 0.94, green: 0.97, blue: 1.0) }
    private var cardBg: Color { isDarkMode ? Color.white.opacity(0.075) : Color.white.opacity(0.84) }
    private var primaryText: Color { isDarkMode ? .white : Color(red: 0.06, green: 0.09, blue: 0.16) }
    private var secondaryText: Color { isDarkMode ? .white.opacity(0.62) : Color(red: 0.48, green: 0.61, blue: 0.70) }

    var body: some View {
        NavigationStack {
            ZStack {
                baseBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        heroIcon
                        titleBlock

                        detailCard(icon: "calendar", label: "Дата и время") {
                            Text(fullDateString(entry.date))
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundColor(primaryText)
                        }

                        if !entry.body.isEmpty {
                            detailCard(icon: "text.alignleft", label: "Описание") {
                                Text(entry.body)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.82) : Color(red: 0.30, green: 0.42, blue: 0.52))
                                    .lineSpacing(6)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        if entry.mood != nil || entry.severity != nil {
                            healthSignals
                        }

                        aiContextCard
                        shareCard
                        deleteButton
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                }
            }
            .navigationTitle(BagytL10n.tr("Запись"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(BagytL10n.tr("Готово")) { dismiss() }
                        .foregroundColor(accent)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                }
            }
        }
    }

    private var heroIcon: some View {
        ZStack {
            Circle()
                .fill(entry.category.color.opacity(isDarkMode ? 0.20 : 0.15))
                .frame(width: 108, height: 108)

            Circle()
                .strokeBorder(Color.white.opacity(isDarkMode ? 0.18 : 0.70), lineWidth: 2)
                .frame(width: 108, height: 108)

            Text(entry.category.emoji)
                .font(.system(size: 50))
                .shadow(color: entry.category.color.opacity(0.32), radius: 8, x: 0, y: 4)
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 12) {
            Text(entry.title)
                .font(.system(size: 27, weight: .black, design: .rounded))
                .foregroundColor(primaryText)
                .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                Image(systemName: entry.category.icon)
                    .font(.system(size: 13, weight: .black))

                Text(entry.category.title)
                    .font(.system(size: 13, weight: .black, design: .rounded))
            }
            .foregroundColor(entry.category.color)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(entry.category.color.opacity(isDarkMode ? 0.19 : 0.14), in: Capsule())
        }
    }

    private var healthSignals: some View {
        detailCard(icon: "waveform.path.ecg", label: "Сигналы") {
            VStack(spacing: 14) {
                if let severity = entry.severity {
                    signalRow(
                        title: "Сила симптома",
                        value: "\(severity)/10",
                        color: entry.category.color,
                        filled: severity,
                        total: 10
                    )
                }

                if let mood = entry.mood {
                    HStack(spacing: 12) {
                        Text(moodEmoji(mood))
                            .font(.system(size: 32))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(moodLabel(mood))
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundColor(primaryText)

                            Text(String(format: BagytL10n.tr("Настроение %d/5"), mood))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(secondaryText)
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            ForEach(1...5, id: \.self) { index in
                                Circle()
                                    .fill(index <= mood ? Color(red: 1.0, green: 0.65, blue: 0.10) : (isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.06)))
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                }
            }
        }
    }

    private var aiContextCard: some View {
        detailCard(icon: "sparkles", label: "Контекст для ИИ") {
            Text(aiContextText)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isDarkMode ? .white.opacity(0.80) : Color(red: 0.30, green: 0.42, blue: 0.52))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var shareCard: some View {
        ShareLink(item: shareText) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .bold))

                Text(BagytL10n.tr("Поделиться записью"))
                    .font(.system(size: 16, weight: .black, design: .rounded))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .black))
                    .opacity(0.55)
            }
            .foregroundColor(accent)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(accent.opacity(isDarkMode ? 0.15 : 0.10))
            )
        }
    }

    private var deleteButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            vm.delete(entry)
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .bold))

                Text(BagytL10n.tr("Удалить запись"))
                    .font(.system(size: 16, weight: .black, design: .rounded))
            }
            .foregroundColor(Color(red: 0.95, green: 0.25, blue: 0.25))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(red: 1.0, green: 0.35, blue: 0.35).opacity(isDarkMode ? 0.14 : 0.10))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color(red: 0.95, green: 0.25, blue: 0.25).opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }

    @ViewBuilder
    private func detailCard<Content: View>(icon: String, label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(accent)

                Text(BagytL10n.tr(label))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(secondaryText)
                    .textCase(.uppercase)
                    .tracking(1.0)
            }

            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(isDarkMode ? 0.10 : 0.58), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(isDarkMode ? 0.12 : 0.04), radius: 8, x: 0, y: 4)
        )
    }

    private func signalRow(title: String, value: String, color: Color, filled: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(BagytL10n.tr(title))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(primaryText)

                Spacer()

                Text(value)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(color)
            }

            HStack(spacing: 5) {
                ForEach(1...total, id: \.self) { index in
                    Capsule()
                        .fill(index <= filled ? color : (isDarkMode ? Color.white.opacity(0.10) : Color.black.opacity(0.06)))
                        .frame(height: 7)
                }
            }
        }
    }

    private var aiContextText: String {
        switch entry.category {
        case .symptom:
            return BagytL10n.tr("Для точного разбора симптома полезны: локализация, начало, сила, температура, лекарства, питание, сон и похожие эпизоды.")
        case .sleep:
            return BagytL10n.tr("Сон помогает связать усталость, настроение, головную боль и активность. Чем чаще отмечается сон, тем точнее видны закономерности.")
        case .visit:
            return BagytL10n.tr("Назначения врача, дозировки и результаты анализов лучше хранить рядом с симптомами, чтобы не терять медицинский контекст.")
        case .activity:
            return BagytL10n.tr("Активность может влиять на пульс, сон, боль и настроение. Записи помогают отличать полезную нагрузку от перегруза.")
        case .mood:
            return BagytL10n.tr("Настроение связано со сном, стрессом, питанием и симптомами. Такие записи особенно полезны для когнитивной части приложения.")
        case .note:
            return BagytL10n.tr("Свободные заметки закрывают детали, которые не попали в категории: питание, стресс, лекарства, вопросы врачу или необычные реакции.")
        }
    }

    private var shareText: String {
        var parts = [
            BagytL10n.tr("Bagyt · Журнал здоровья"),
            entry.title,
            "\(BagytL10n.tr("Категория")): \(entry.category.title)",
            String(format: BagytL10n.tr("Дата: %@"), fullDateString(entry.date))
        ]

        if let severity = entry.severity {
            parts.append(String(format: BagytL10n.tr("Сила симптома: %@"), "\(severity)/10"))
        }

        if let mood = entry.mood {
            parts.append(String(format: BagytL10n.tr("Настроение: %@"), "\(mood)/5"))
        }

        if !entry.body.isEmpty {
            parts.append(String(format: BagytL10n.tr("Описание: %@"), entry.body))
        }

        return parts.joined(separator: "\n")
    }

    private func fullDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = BagytL10n.currentLocale
        formatter.dateFormat = "EEEE, d MMMM yyyy · HH:mm"
        return formatter.string(from: date).capitalized
    }

    private func moodEmoji(_ value: Int) -> String {
        ["😩", "😕", "😐", "😊", "🤩"][max(1, min(5, value)) - 1]
    }

    private func moodLabel(_ value: Int) -> String {
        BagytL10n.tr(["Плохо", "Так себе", "Нормально", "Хорошо", "Отлично"][max(1, min(5, value)) - 1])
    }
}

// MARK: - Preview

#Preview {
    JournalView()
        .environmentObject(AppState())
        .environmentObject(LanguageManager())
}
