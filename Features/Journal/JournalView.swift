//
//  JournalView.swift
//  Bagyt
//
//  Full redesign — Bagyt design system
//  Glass cards · Filters · Add entry sheet · Detail view
//

import SwiftUI
import Combine

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
}

struct JournalEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var body: String
    var category: JournalCategory
    var date: Date = Date()
    var mood: Int? = nil          // 1–5, optional
}

// MARK: - ViewModel

final class JournalViewModel: ObservableObject {
    
    
    @Published var entries: [JournalEntry] = []
    @Published var selectedFilter: JournalCategory? = nil
    @Published var searchText: String = ""

    private let key = "bagyt_journal_entries"

    init() { load() }

    var filtered: [JournalEntry] {
        var result = entries
        if let f = selectedFilter { result = result.filter { $0.category == f } }
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.body.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result.sorted { $0.date > $1.date }
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
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([JournalEntry].self, from: data) {
            entries = saved
        } else {
            entries = Self.demoEntries()
        }
    }

    static func demoEntries() -> [JournalEntry] {
        let cal = Calendar.current
        return [
            JournalEntry(title: "Головная боль",
                         body: "Болит с утра, давящая, слева. Приняла ибупрофен.",
                         category: .symptom,
                         date: Date()),
            JournalEntry(title: "Хороший сон",
                         body: "Спал 8 часов, никаких пробуждений. Чувствую себя отлично.",
                         category: .sleep,
                         date: cal.date(byAdding: .hour, value: -14, to: Date())!,
                         mood: 5),
            JournalEntry(title: "Визит к терапевту",
                         body: "Назначен витамин D 2000 МЕ и магний B6 курсом 1 месяц.",
                         category: .visit,
                         date: cal.date(byAdding: .day, value: -2, to: Date())!),
            JournalEntry(title: "Спортзал",
                         body: "Тренировка 45 мин, пульс макс 142. Кардио + силовые.",
                         category: .activity,
                         date: cal.date(byAdding: .day, value: -3, to: Date())!,
                         mood: 4),
            JournalEntry(title: "Настроение упало",
                         body: "Чувствую усталость и раздражительность. Постараюсь лечь пораньше.",
                         category: .mood,
                         date: cal.date(byAdding: .day, value: -4, to: Date())!,
                         mood: 2),
            JournalEntry(title: "Аллергия на цветение",
                         body: "Заложен нос, слезятся глаза. Принял цетиризин 10 мг.",
                         category: .symptom,
                         date: cal.date(byAdding: .day, value: -5, to: Date())!),
        ]
    }
}

// MARK: - Main View

struct JournalView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lang: LanguageManager
    @StateObject private var vm = JournalViewModel()

    @State private var showAddSheet  = false
    @State private var selectedEntry: JournalEntry? = nil
    @State private var showSearch    = false
    @State private var appear        = false

    private let accent  = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Background
            Color(red: 0.937, green: 0.969, blue: 1.0)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                    statsStrip
                    filterChips
                    if showSearch { searchBar }
                    entriesList
                    Spacer(minLength: 110)
                }
            }

            // FAB
            addButton
        }
        .sheet(isPresented: $showAddSheet) {
            AddEntrySheet(vm: vm)
        }
        .sheet(item: $selectedEntry) { entry in
            EntryDetailSheet(entry: entry, vm: vm)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appear = true }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Журнал здоровья")
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
                Text("\(vm.entries.count) записей")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(red: 0.5, green: 0.63, blue: 0.72))
            }
            Spacer()
            Button {
                withAnimation(.spring(response: 0.35)) { showSearch.toggle() }
            } label: {
                ZStack {
                    Circle()
                        .fill(showSearch ? accent : Color.white)
                        .frame(width: 40, height: 40)
                        .shadow(color: accent.opacity(0.18), radius: 8, x: 0, y: 3)
                    Image(systemName: showSearch ? "xmark" : "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(showSearch ? .white : accent)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    // MARK: - Stats Strip

    private var statsStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(JournalCategory.allCases, id: \.self) { cat in
                    let count = vm.entries.filter { $0.category == cat }.count
                    if count > 0 {
                        statChip(cat: cat, count: count)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 14)
    }

    private func statChip(cat: JournalCategory, count: Int) -> some View {
        HStack(spacing: 7) {
            Text(cat.emoji)
                .font(.system(size: 14))
            Text("\(count)")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(cat.color)
            Text(cat.rawValue)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(cat.color.opacity(0.8))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(cat.bgColor)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(cat.color.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "Все", icon: "square.grid.2x2.fill", isSelected: vm.selectedFilter == nil) {
                    withAnimation(.spring(response: 0.3)) { vm.selectedFilter = nil }
                }
                ForEach(JournalCategory.allCases, id: \.self) { cat in
                    filterChip(label: cat.rawValue, icon: cat.icon, isSelected: vm.selectedFilter == cat, color: cat.color) {
                        withAnimation(.spring(response: 0.3)) {
                            vm.selectedFilter = vm.selectedFilter == cat ? nil : cat
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
        isSelected: Bool,
        color: Color = Color(red: 0.055, green: 0.647, blue: 0.914),
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(colors: [color, color.opacity(0.75)], startPoint: .leading, endPoint: .trailing)
                    } else {
                        color.opacity(0.08)
                    }
                }
            )
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? Color.clear : color.opacity(0.2), lineWidth: 1))
            .shadow(color: isSelected ? color.opacity(0.3) : .clear, radius: 6, x: 0, y: 3)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(accent)
            TextField("Поиск по записям...", text: $vm.searchText)
                .font(.system(size: 15))
                .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
            if !vm.searchText.isEmpty {
                Button { vm.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(red: 0.6, green: 0.72, blue: 0.78))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: accent.opacity(0.1), radius: 8, x: 0, y: 3)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Entries List

    private var entriesList: some View {
        LazyVStack(spacing: 12) {
            if vm.filtered.isEmpty {
                emptyState
            } else {
                ForEach(groupedKeys, id: \.self) { key in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(key)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(red: 0.5, green: 0.63, blue: 0.72))
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .padding(.horizontal, 20)
                            .padding(.top, 4)

                        ForEach(grouped[key] ?? []) { entry in
                            JournalEntryCard(entry: entry)
                                .padding(.horizontal, 20)
                                .onTapGesture { selectedEntry = entry }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        withAnimation { vm.delete(entry) }
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                }
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.08))
                    .frame(width: 90, height: 90)
                Text("📋")
                    .font(.system(size: 40))
            }
            Text("Нет записей")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(red: 0.3, green: 0.42, blue: 0.52))
            Text("Нажмите + чтобы добавить\nпервую запись в журнал")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(red: 0.55, green: 0.67, blue: 0.75))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }

    // MARK: - FAB

    private var addButton: some View {
        Button { showAddSheet = true } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 58, height: 58)
                    .shadow(color: accent.opacity(0.45), radius: 16, x: 0, y: 8)
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding(.trailing, 24)
        .padding(.bottom, 104)
        .scaleEffect(appear ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.65).delay(0.3), value: appear)
    }

    // MARK: - Grouping helpers

    private var grouped: [String: [JournalEntry]] {
        Dictionary(grouping: vm.filtered) { sectionKey(for: $0.date) }
    }

    private var groupedKeys: [String] {
        grouped.keys.sorted {
            let dateA = grouped[$0]?.first?.date ?? .distantPast
            let dateB = grouped[$1]?.first?.date ?? .distantPast
            return dateA > dateB
        }
    }

    private func sectionKey(for date: Date) -> String {
        if Calendar.current.isDateInToday(date)     { return "Сегодня" }
        if Calendar.current.isDateInYesterday(date) { return "Вчера" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ru_RU")
        fmt.dateFormat = "d MMMM"
        return fmt.string(from: date)
    }
}

// MARK: - Entry Card

struct JournalEntryCard: View {
    let entry: JournalEntry
    @State private var pressed = false

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.88))
                .shadow(color: entry.category.color.opacity(0.10), radius: 12, x: 0, y: 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(entry.category.color.opacity(0.14), lineWidth: 1)
                )

            // Left accent stripe
            RoundedRectangle(cornerRadius: 3)
                .fill(entry.category.color)
                .frame(width: 4)
                .padding(.vertical, 12)
                .padding(.leading, 12)

            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(entry.category.bgColor)
                        .frame(width: 46, height: 46)
                    Text(entry.category.emoji)
                        .font(.system(size: 22))
                }
                .padding(.leading, 20)

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(entry.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
                            .lineLimit(1)
                        Spacer()
                        // Category badge
                        Text(entry.category.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(entry.category.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(entry.category.bgColor)
                            .clipShape(Capsule())
                    }

                    if !entry.body.isEmpty {
                        Text(entry.body)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(red: 0.4, green: 0.55, blue: 0.65))
                            .lineLimit(2)
                            .lineSpacing(2)
                    }

                    HStack(spacing: 8) {
                        Text(timeString(entry.date))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(red: 0.65, green: 0.75, blue: 0.82))

                        if let mood = entry.mood {
                            HStack(spacing: 3) {
                                ForEach(1...5, id: \.self) { i in
                                    Circle()
                                        .fill(i <= mood
                                              ? Color(red: 1.0, green: 0.65, blue: 0.10)
                                              : Color(red: 0.88, green: 0.92, blue: 0.95))
                                        .frame(width: 6, height: 6)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 14)
                .padding(.trailing, 16)
            }
        }
        .scaleEffect(pressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3), value: pressed)
        .onLongPressGesture(minimumDuration: 0, pressing: { p in pressed = p }, perform: {})
    }

    private func timeString(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"
            return fmt.string(from: date)
        }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ru_RU")
        fmt.dateFormat = "d MMM, HH:mm"
        return fmt.string(from: date)
    }
}

// MARK: - Add Entry Sheet

struct AddEntrySheet: View {
    @ObservedObject var vm: JournalViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title         = ""
    @State private var body_text     = ""
    @State private var category      = JournalCategory.symptom
    @State private var mood: Int     = 3
    @State private var hasMood       = false
    @State private var showValidation = false

    @FocusState private var titleFocused: Bool

    private let accent  = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    categoryPicker
                    titleField
                    bodyField
                    moodSection
                    dateCard
                    saveButton
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(Color(red: 0.937, green: 0.969, blue: 1.0).ignoresSafeArea())
            .navigationTitle("Новая запись")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { dismiss() }
                        .foregroundColor(accent)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .onAppear { titleFocused = true }
        }
    }

    // Category grid
    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Категория")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(JournalCategory.allCases, id: \.self) { cat in
                    Button {
                        withAnimation(.spring(response: 0.3)) { category = cat }
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(category == cat ? cat.color : cat.bgColor)
                                    .frame(height: 44)
                                Image(systemName: cat.icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(category == cat ? .white : cat.color)
                            }
                            Text(cat.rawValue)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(category == cat ? cat.color : Color(red: 0.5, green: 0.63, blue: 0.72))
                        }
                    }
                    .shadow(color: category == cat ? cat.color.opacity(0.25) : .clear, radius: 6, x: 0, y: 3)
                }
            }
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Заголовок")
            HStack {
                TextField("Например: Головная боль", text: $title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
                    .focused($titleFocused)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.88))
                    .shadow(color: accent.opacity(0.08), radius: 8, x: 0, y: 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(showValidation && title.isEmpty ? Color.red.opacity(0.45) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
    }

    private var bodyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Описание")
            ZStack(alignment: .topLeading) {
                if body_text.isEmpty {
                    Text("Опишите подробнее...")
                        .font(.system(size: 15))
                        .foregroundColor(Color(red: 0.7, green: 0.8, blue: 0.85))
                        .padding(.top, 15)
                        .padding(.leading, 15)
                }
                TextEditor(text: $body_text)
                    .font(.system(size: 15))
                    .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
                    .frame(minHeight: 90)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(8)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.88))
                    .shadow(color: accent.opacity(0.08), radius: 8, x: 0, y: 3)
            )
        }
    }

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionLabel("Настроение")
                Spacer()
                Toggle("", isOn: $hasMood).tint(accent).labelsHidden()
            }
            if hasMood {
                HStack(spacing: 0) {
                    ForEach(1...5, id: \.self) { i in
                        Button {
                            withAnimation(.spring(response: 0.3)) { mood = i }
                        } label: {
                            VStack(spacing: 6) {
                                Text(moodEmoji(i))
                                    .font(.system(size: mood == i ? 32 : 24))
                                    .animation(.spring(response: 0.3), value: mood)
                                Circle()
                                    .fill(mood == i
                                          ? Color(red: 1.0, green: 0.65, blue: 0.10)
                                          : Color(red: 0.88, green: 0.92, blue: 0.95))
                                    .frame(width: 6, height: 6)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.vertical, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.88))
                .shadow(color: accent.opacity(0.08), radius: 8, x: 0, y: 3)
        )
    }

    private var dateCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar")
                .foregroundColor(accent)
                .font(.system(size: 15))
            Text(fullDateString())
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.88))
                .shadow(color: accent.opacity(0.08), radius: 8, x: 0, y: 3)
        )
    }

    private var saveButton: some View {
        Button { save() } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 18))
                Text("Сохранить запись").font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: accent.opacity(0.35), radius: 12, x: 0, y: 6)
        }
        .padding(.top, 4)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(Color(red: 0.5, green: 0.63, blue: 0.72))
            .textCase(.uppercase)
            .tracking(0.8)
    }

    private func moodEmoji(_ v: Int) -> String { ["😩","😕","😐","😊","🤩"][v-1] }

    private func fullDateString() -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ru_RU")
        fmt.dateFormat = "EEEE, d MMMM · HH:mm"
        return fmt.string(from: Date()).capitalized
    }

    private func save() {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            withAnimation { showValidation = true }
            return
        }
        vm.add(JournalEntry(
            title:    title.trimmingCharacters(in: .whitespaces),
            body:     body_text.trimmingCharacters(in: .whitespaces),
            category: category,
            date:     Date(),
            mood:     hasMood ? mood : nil
        ))
        dismiss()
    }
}

// MARK: - Entry Detail Sheet

struct EntryDetailSheet: View {
    let entry: JournalEntry
    @ObservedObject var vm: JournalViewModel
    @Environment(\.dismiss) private var dismiss

    private let accent  = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Hero icon
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [entry.category.color.opacity(0.15), entry.category.color.opacity(0.04)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 90, height: 90)
                        Text(entry.category.emoji).font(.system(size: 44))
                    }
                    .padding(.top, 8)

                    // Title + badge
                    VStack(spacing: 8) {
                        Text(entry.title)
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
                            .multilineTextAlignment(.center)
                        HStack(spacing: 6) {
                            Image(systemName: entry.category.icon).font(.system(size: 11, weight: .bold))
                            Text(entry.category.rawValue).font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(entry.category.color)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(entry.category.bgColor).clipShape(Capsule())
                    }

                    // Date
                    detailCard(icon: "calendar", label: "Дата и время") {
                        Text(fullDateString(entry.date))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
                    }

                    // Body
                    if !entry.body.isEmpty {
                        detailCard(icon: "text.alignleft", label: "Описание") {
                            Text(entry.body)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(red: 0.3, green: 0.42, blue: 0.52))
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // Mood
                    if let mood = entry.mood {
                        detailCard(icon: "face.smiling.fill", label: "Настроение") {
                            HStack(spacing: 10) {
                                Text(moodEmoji(mood)).font(.system(size: 28))
                                Text(moodLabel(mood))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
                                Spacer()
                                HStack(spacing: 4) {
                                    ForEach(1...5, id: \.self) { i in
                                        Circle()
                                            .fill(i <= mood
                                                  ? Color(red: 1.0, green: 0.65, blue: 0.10)
                                                  : Color(red: 0.88, green: 0.92, blue: 0.95))
                                            .frame(width: 9, height: 9)
                                    }
                                }
                            }
                        }
                    }

                    // Delete
                    Button {
                        vm.delete(entry); dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "trash").font(.system(size: 15, weight: .semibold))
                            Text("Удалить запись").font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(Color(red: 0.95, green: 0.25, blue: 0.25))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color(red: 0.95, green: 0.25, blue: 0.25).opacity(0.2), lineWidth: 1))
                    }
                    .padding(.top, 4)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
            .background(Color(red: 0.937, green: 0.969, blue: 1.0).ignoresSafeArea())
            .navigationTitle("Запись")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                        .foregroundColor(accent).font(.system(size: 16, weight: .semibold))
                }
            }
        }
    }

    @ViewBuilder
    private func detailCard<Content: View>(icon: String, label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundColor(accent)
                Text(label).font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(red: 0.5, green: 0.63, blue: 0.72))
                    .textCase(.uppercase).tracking(0.8)
            }
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.88))
                .shadow(color: accent.opacity(0.08), radius: 10, x: 0, y: 4)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(accent.opacity(0.1), lineWidth: 1))
        )
    }

    private func fullDateString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ru_RU")
        fmt.dateFormat = "EEEE, d MMMM yyyy · HH:mm"
        return fmt.string(from: date).capitalized
    }

    private func moodEmoji(_ v: Int) -> String { ["😩","😕","😐","😊","🤩"][v-1] }
    private func moodLabel(_ v: Int) -> String  { ["Плохо","Так себе","Нормально","Хорошо","Отлично"][v-1] }
}

// MARK: - Preview

#Preview {
    JournalView()
        .environmentObject(AppState())
        .environmentObject(LanguageManager())
}
