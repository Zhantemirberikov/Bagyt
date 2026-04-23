//
//  MoodView.swift
//  Bagyt
//
//  Full redesign — Bagyt design system
//  Трекер настроения · График недели · Заметки · Паттерны
//

import SwiftUI
import Combine

// MARK: - Models

struct MoodRecord: Identifiable, Codable {
    var id: UUID     = UUID()
    var mood: Int            // 1–5
    var note: String         = ""
    var date: Date           = Date()
    var energy: Int          = 3    // 1–5
    var tags: [String]       = []
}

// MARK: - ViewModel

final class MoodViewModel: ObservableObject {
        
    @Published var records: [MoodRecord] = []
    @Published var todayMood: Int?       = nil
    @Published var todayNote: String     = ""
    @Published var todayEnergy: Int      = 3

    private static let saveKey = "bagyt_mood_records"

    init() {
        let loaded: [MoodRecord]
        if let data = UserDefaults.standard.data(forKey: Self.saveKey),
           let saved = try? JSONDecoder().decode([MoodRecord].self, from: data) {
            loaded = saved
        } else {
            loaded = MoodViewModel.demoRecords()
        }

        self.records     = loaded
        self.todayMood   = nil
        self.todayNote   = ""
        self.todayEnergy = 3

        if let today = loaded.first(where: { Calendar.current.isDateInToday($0.date) }) {
            self.todayMood   = today.mood
            self.todayEnergy = today.energy
            self.todayNote   = today.note
        }
    }

    var todayRecord: MoodRecord? {
        records.first { Calendar.current.isDateInToday($0.date) }
    }

    var last7: [MoodRecord] {
        let cal = Calendar.current
        return (0..<7).compactMap { offset -> MoodRecord? in
            guard let day = cal.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            return records.first { cal.isDate($0.date, inSameDayAs: day) }
        }.reversed()
    }

    var averageMood: Double {
        let r = records.prefix(7).filter { _ in true }
        guard !r.isEmpty else { return 0 }
        return Double(r.map(\.mood).reduce(0, +)) / Double(r.count)
    }

    var streak: Int {
        let cal = Calendar.current
        var count = 0
        var day = Date()
        while true {
            if records.first(where: { cal.isDate($0.date, inSameDayAs: day) }) != nil {
                count += 1
                day = cal.date(byAdding: .day, value: -1, to: day)!
            } else { break }
        }
        return count
    }

    func saveTodayMood() {
        guard let mood = todayMood else { return }
        if let idx = records.firstIndex(where: { Calendar.current.isDateInToday($0.date) }) {
            records[idx].mood   = mood
            records[idx].note   = todayNote
            records[idx].energy = todayEnergy
        } else {
            records.insert(MoodRecord(mood: mood, note: todayNote, date: Date(), energy: todayEnergy), at: 0)
        }
        // Сортируем записи по дате на всякий случай
        records.sort { $0.date > $1.date }
        save()
    }
    
    // Новая функция удаления одной записи
    func delete(record: MoodRecord) {
        if let idx = records.firstIndex(where: { $0.id == record.id }) {
            let deleted = records[idx]
            records.remove(at: idx)
            
            // Если удалили сегодняшнюю запись, сбрасываем форму
            if Calendar.current.isDateInToday(deleted.date) {
                todayMood = nil
                todayNote = ""
                todayEnergy = 3
            }
            save()
        }
    }
    
    // Новая функция очистки всей истории
    func deleteAll() {
        records.removeAll()
        todayMood = nil
        todayNote = ""
        todayEnergy = 3
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: Self.saveKey)
        }
    }

    static func demoRecords() -> [MoodRecord] {
        let cal = Calendar.current
        let moods = [4, 3, 5, 4, 2, 4, 3]
        let notes = [
            "Хорошее начало недели",
            "Немного устал после пар, но в целом окей",
            "Отличный день! Тренировка прошла супер, встретился с друзьями",
            "Продуктивный день, закрыл пару сложных задач",
            "Плохо спал, голова болит с самого утра",
            "Восстановился после болезни, чувствую прилив сил",
            "Спокойный домашний день"
        ]
        return moods.enumerated().compactMap { i, mood in
            guard let date = cal.date(byAdding: .day, value: -(6 - i), to: Date()) else { return nil }
            return MoodRecord(mood: mood, note: notes[i], date: date, energy: mood)
        }
    }
}

// MARK: - MoodView

struct MoodView: View {

    @StateObject private var vm = MoodViewModel()
    @State private var showNoteField    = false
    @State private var showSavedBadge   = false
    
    // Новые стейты для интерактива
    @State private var expandedRecordId: UUID? = nil
    @State private var showResetAlert   = false
    
    @FocusState private var noteFocused: Bool

    private let accent  = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)
    private let moodGold = Color(red: 1.0, green: 0.65, blue: 0.10)

    var body: some View {
        ZStack(alignment: .top) {
            
            // 👇 ПРОЗРАЧНЫЙ ФОН (пропускает AnimatedGradientBackground из HomeView)
            Color.clear.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    headerCard
                    statsStrip
                    todayCard
                    weekChart
                    patternsCard
                    historyList
                    Spacer(minLength: 110)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }

            // Saved badge
            if showSavedBadge {
                savedBadge
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        // Alert для подтверждения очистки
        .alert("Очистить историю?", isPresented: $showResetAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Удалить все", role: .destructive) {
                withAnimation { vm.deleteAll() }
            }
        } message: {
            Text("Вы уверены, что хотите полностью удалить все записи? Это действие нельзя отменить.")
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.55, green: 0.35, blue: 1.0),
                             Color(red: 0.35, green: 0.45, blue: 1.0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .shadow(color: Color(red: 0.55, green: 0.35, blue: 1.0).opacity(0.4), radius: 20, x: 0, y: 10)

            Circle().fill(Color.white.opacity(0.07)).frame(width: 150, height: 150).offset(x: -40, y: -60)
            Circle().fill(Color.white.opacity(0.05)).frame(width: 90, height: 90)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).offset(x: 25, y: 25)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("НАСТРОЕНИЕ")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.75))
                            .tracking(1.0)
                        Text("Ежедневный трекер")
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    // Today emoji big
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 62, height: 62)
                        Text(vm.todayMood != nil ? moodEmoji(vm.todayMood!) : "🙂")
                            .font(.system(size: 32))
                    }
                }

                // Streak
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.1))
                        .font(.system(size: 13))
                    Text("\(vm.streak) дней подряд")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    if vm.averageMood > 0 {
                        HStack(spacing: 5) {
                            Text("Среднее:")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                            Text(String(format: "%.1f", vm.averageMood))
                                .font(.system(size: 13, weight: .black))
                                .foregroundColor(.white)
                            Text(moodEmoji(Int(vm.averageMood.rounded())))
                                .font(.system(size: 14))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(24)
        }
    }

    // MARK: - Stats Strip

    private var statsStrip: some View {
        HStack(spacing: 10) {
            statMini(
                icon: "chart.line.uptrend.xyaxis",
                value: vm.averageMood > 0 ? String(format: "%.1f", vm.averageMood) : "—",
                label: "Среднее",
                color: Color(red: 0.55, green: 0.35, blue: 1.0)
            )
            statMini(
                icon: "flame.fill",
                value: "\(vm.streak)",
                label: "Дней подряд",
                color: Color(red: 1.0, green: 0.55, blue: 0.1)
            )
            statMini(
                icon: "calendar.badge.checkmark",
                value: "\(vm.records.count)",
                label: "Записей",
                color: accent
            )
        }
    }

    private func statMini(icon: String, value: String, label: String, color: Color) -> some View {
        glassCard {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(color.opacity(0.12)).frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(color)
                }
                Text(value)
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(red: 0.5, green: 0.63, blue: 0.72))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Today Card

    private var todayCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 18) {

                // Title
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("КАК ВЫ СЕГОДНЯ?")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(red: 0.5, green: 0.63, blue: 0.72))
                            .tracking(0.8)
                        Text(todayDateString())
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
                    }
                    Spacer()
                    if vm.todayMood != nil {
                        HStack(spacing: 4) {
                            Circle().fill(Color(red: 0.1, green: 0.78, blue: 0.48)).frame(width: 7, height: 7)
                            Text("Сохранено")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(red: 0.1, green: 0.78, blue: 0.48))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color(red: 0.1, green: 0.78, blue: 0.48).opacity(0.1))
                        .clipShape(Capsule())
                    }
                }

                // Mood selector
                HStack(spacing: 0) {
                    ForEach(1...5, id: \.self) { i in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                                vm.todayMood = i
                                showNoteField = true
                            }
                            let gen = UIImpactFeedbackGenerator(style: .medium)
                            gen.impactOccurred()
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(vm.todayMood == i
                                              ? moodColor(i).opacity(0.15)
                                              : Color.white.opacity(0.5)) // Прозрачный белый для стеклянного эффекта
                                        .frame(width: vm.todayMood == i ? 54 : 46,
                                               height: vm.todayMood == i ? 54 : 46)
                                        .overlay(
                                            Circle().strokeBorder(
                                                vm.todayMood == i ? moodColor(i) : Color.clear,
                                                lineWidth: 2
                                            )
                                        )
                                    Text(moodEmoji(i))
                                        .font(.system(size: vm.todayMood == i ? 28 : 22))
                                }
                                .animation(.spring(response: 0.3), value: vm.todayMood)

                                Text(moodShortLabel(i))
                                    .font(.system(size: 10, weight: vm.todayMood == i ? .bold : .medium))
                                    .foregroundColor(vm.todayMood == i
                                                     ? moodColor(i)
                                                     : Color(red: 0.6, green: 0.72, blue: 0.78))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }

                // Energy level
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Уровень энергии")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(red: 0.3, green: 0.42, blue: 0.52))
                        Spacer()
                        Text(energyLabel(vm.todayEnergy))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(accent)
                    }
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { i in
                            Button {
                                withAnimation(.spring(response: 0.3)) { vm.todayEnergy = i }
                            } label: {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(i <= vm.todayEnergy ? accent : Color.white.opacity(0.6)) // Прозрачный белый
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 8)
                                    .animation(.spring(response: 0.3), value: vm.todayEnergy)
                            }
                        }
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.5)) // Стекло для подложки энергии
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // Note field
                if showNoteField {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Заметка (необязательно)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(red: 0.5, green: 0.63, blue: 0.72))
                            .tracking(0.5)

                        ZStack(alignment: .topLeading) {
                            if vm.todayNote.isEmpty {
                                Text("Что повлияло на ваше настроение?")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(red: 0.7, green: 0.8, blue: 0.85))
                                    .padding(.top, 10)
                                    .padding(.leading, 4)
                            }
                            TextEditor(text: $vm.todayNote)
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
                                .frame(minHeight: 72)
                                .scrollContentBackground(.hidden)
                                .focused($noteFocused)
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.5)) // Стекло для текстового поля
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Save button
                if vm.todayMood != nil {
                    Button { saveAndAnimate() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 17))
                            Text("Сохранить настроение")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.55, green: 0.35, blue: 1.0), accent],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color(red: 0.55, green: 0.35, blue: 1.0).opacity(0.35), radius: 10, x: 0, y: 5)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(20)
        }
    }

    // MARK: - Week Chart

    private var weekChart: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("НЕДЕЛЯ")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(red: 0.5, green: 0.63, blue: 0.72))
                            .tracking(0.8)
                        Text("График настроения")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
                    }
                    Spacer()
                    // Mini legend
                    HStack(spacing: 12) {
                        ForEach([("😩",1),("😊",4),("🤩",5)], id: \.1) { item in
                            HStack(spacing: 4) {
                                Text(item.0).font(.system(size: 12))
                                Text("\(item.1)").font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(red: 0.5, green: 0.63, blue: 0.72))
                            }
                        }
                    }
                }

                // Bar chart
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(chartDays(), id: \.date) { item in
                        VStack(spacing: 6) {
                            // Emoji on top of bar
                            if let mood = item.mood {
                                Text(moodEmoji(mood))
                                    .font(.system(size: 14))
                            } else {
                                Text("·")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(red: 0.7, green: 0.8, blue: 0.85))
                            }

                            // Bar
                            GeometryReader { geo in
                                VStack {
                                    Spacer()
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(item.mood != nil
                                              ? LinearGradient(
                                                colors: [moodColor(item.mood!), moodColor(item.mood!).opacity(0.6)],
                                                startPoint: .top, endPoint: .bottom)
                                              : LinearGradient(
                                                colors: [Color.white.opacity(0.6), Color.white.opacity(0.6)], // Полупрозрачные пустые бары
                                                startPoint: .top, endPoint: .bottom))
                                        .frame(height: item.mood != nil ? CGFloat(item.mood!) / 5 * geo.size.height : 12)
                                }
                            }
                            .frame(height: 80)

                            // Day label
                            Text(item.dayLabel)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(item.isToday
                                                 ? Color(red: 0.55, green: 0.35, blue: 1.0)
                                                 : Color(red: 0.6, green: 0.72, blue: 0.78))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Patterns Card

    private var patternsCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("ПАТТЕРНЫ")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(red: 0.5, green: 0.63, blue: 0.72))
                    .tracking(0.8)

                let patterns = buildPatterns()
                ForEach(patterns, id: \.title) { p in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(p.color.opacity(0.12))
                                .frame(width: 38, height: 38)
                            Text(p.emoji).font(.system(size: 18))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
                            Text(p.subtitle)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(red: 0.5, green: 0.63, blue: 0.72))
                        }
                        Spacer()
                        Text(p.badge)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(p.color)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(p.color.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - History List

    private var historyList: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // Заголовок с кнопкой "Очистить"
            HStack {
                Text("ИСТОРИЯ")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(red: 0.5, green: 0.63, blue: 0.72))
                    .tracking(0.8)
                    .padding(.leading, 4)
                
                Spacer()
                
                if !vm.records.isEmpty {
                    Button(action: { showResetAlert = true }) {
                        Text("Очистить все")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(red: 0.95, green: 0.25, blue: 0.25))
                    }
                    .padding(.trailing, 4)
                }
            }

            // Используем LazyVStack для плавного скролла всех записей
            LazyVStack(spacing: 12) {
                ForEach(vm.records) { record in
                    glassCard {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .top, spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(moodColor(record.mood).opacity(0.12))
                                        .frame(width: 46, height: 46)
                                    Text(moodEmoji(record.mood))
                                        .font(.system(size: 22))
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(moodLabel(record.mood))
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
                                        Spacer()
                                        Text(shortDateString(record.date))
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(Color(red: 0.6, green: 0.72, blue: 0.78))
                                    }
                                    
                                    if !record.note.isEmpty {
                                        Text(record.note)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(Color(red: 0.4, green: 0.55, blue: 0.65))
                                            // Если развернуто - показываем всё, иначе 2 строки
                                            .lineLimit(expandedRecordId == record.id ? nil : 2)
                                            .animation(.easeInOut(duration: 0.3), value: expandedRecordId)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    
                                    // Energy dots
                                    HStack(spacing: 4) {
                                        Text("Энергия:")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(Color(red: 0.6, green: 0.72, blue: 0.78))
                                        ForEach(1...5, id: \.self) { i in
                                            Circle()
                                                .fill(i <= record.energy ? accent : Color.white.opacity(0.5)) // Прозрачные точки
                                                .frame(width: 6, height: 6)
                                        }
                                    }
                                    .padding(.top, 2)
                                }
                            }
                            .contentShape(Rectangle()) // Чтобы весь блок кликался
                            .onTapGesture {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    if expandedRecordId == record.id {
                                        expandedRecordId = nil
                                    } else {
                                        expandedRecordId = record.id
                                    }
                                }
                            }
                            
                            // Расширенная зона: кнопка "Удалить"
                            if expandedRecordId == record.id {
                                Button(action: {
                                    withAnimation(.spring()) {
                                        vm.delete(record: record)
                                        expandedRecordId = nil
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 14))
                                        Text("Удалить запись")
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                    .foregroundColor(Color(red: 0.95, green: 0.25, blue: 0.25))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color(red: 0.95, green: 0.25, blue: 0.25).opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .padding(.top, 14)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
    }

    // MARK: - Saved Badge

    private var savedBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color(red: 0.1, green: 0.78, blue: 0.48))
            Text("Настроение сохранено!")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.9))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
        )
        .padding(.top, 12)
    }

    // MARK: - Glass Card
    
    // 👇 Измененный glassCard для пропускания фона
    @ViewBuilder
    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.65))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: accent.opacity(0.09), radius: 14, x: 0, y: 5)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.8), lineWidth: 1)
            content()
        }
    }

    // MARK: - Helpers

    private func saveAndAnimate() {
        noteFocused = false
        vm.saveTodayMood()
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        withAnimation(.spring()) { showSavedBadge = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeOut) { showSavedBadge = false }
        }
    }

    private func moodEmoji(_ v: Int) -> String {
        ["😩","😕","😐","😊","🤩"][max(0, min(v-1, 4))]
    }
    private func moodLabel(_ v: Int) -> String {
        ["Плохо","Так себе","Нормально","Хорошо","Отлично"][max(0, min(v-1, 4))]
    }
    private func moodShortLabel(_ v: Int) -> String {
        ["Плохо","Так себе","Норм","Хорошо","Класс!"][max(0, min(v-1, 4))]
    }
    private func moodColor(_ v: Int) -> Color {
        [Color(red: 0.95, green: 0.25, blue: 0.25),
         Color(red: 1.0, green: 0.55, blue: 0.1),
         Color(red: 0.055, green: 0.647, blue: 0.914),
         Color(red: 0.1, green: 0.78, blue: 0.48),
         Color(red: 0.55, green: 0.35, blue: 1.0)][max(0, min(v-1, 4))]
    }
    private func energyLabel(_ v: Int) -> String {
        ["Очень низкая","Низкая","Средняя","Высокая","Максимум"][max(0, min(v-1, 4))]
    }

    private func todayDateString() -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ru_RU")
        fmt.dateFormat = "EEEE, d MMMM"
        return fmt.string(from: Date()).capitalized
    }

    private func shortDateString(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Сегодня" }
        if Calendar.current.isDateInYesterday(date) { return "Вчера" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ru_RU")
        fmt.dateFormat = "d MMM"
        return fmt.string(from: date)
    }

    // Chart data
    private struct ChartDay {
        let date: Date
        let dayLabel: String
        let mood: Int?
        let isToday: Bool
    }

    private func chartDays() -> [ChartDay] {
        let cal = Calendar.current
        let days = ["Пн","Вт","Ср","Чт","Пт","Сб","Вс"]
        return (0..<7).compactMap { offset -> ChartDay? in
            guard let day = cal.date(byAdding: .day, value: -(6 - offset), to: Date()) else { return nil }
            let weekday = cal.component(.weekday, from: day)
            let label = days[max(0, (weekday + 5) % 7)]
            let record = vm.records.first { cal.isDate($0.date, inSameDayAs: day) }
            return ChartDay(date: day, dayLabel: label, mood: record?.mood, isToday: cal.isDateInToday(day))
        }
    }

    // Pattern analysis
    private struct Pattern {
        let emoji: String
        let title: String
        let subtitle: String
        let badge: String
        let color: Color
    }

    private func buildPatterns() -> [Pattern] {
        let avg = vm.averageMood
        var patterns: [Pattern] = []

        if avg >= 4 {
            patterns.append(Pattern(emoji: "🌟", title: "Позитивная неделя",
                                    subtitle: "Ваше настроение выше среднего",
                                    badge: "Отлично", color: Color(red: 0.1, green: 0.78, blue: 0.48)))
        } else if avg > 0 && avg < 3 {
            patterns.append(Pattern(emoji: "💤", title: "Нужен отдых",
                                    subtitle: "Уделите внимание восстановлению",
                                    badge: "Внимание", color: Color(red: 1.0, green: 0.55, blue: 0.1)))
        }

        if vm.streak >= 3 {
            patterns.append(Pattern(emoji: "🔥", title: "Серия \(vm.streak) дней",
                                    subtitle: "Продолжайте отслеживать каждый день",
                                    badge: "+\(vm.streak) дней", color: Color(red: 1.0, green: 0.55, blue: 0.1)))
        }

        patterns.append(Pattern(emoji: "📊", title: "Всего записей: \(vm.records.count)",
                                subtitle: "Чем больше данных — тем точнее анализ",
                                badge: "Данные", color: accent))
        return patterns
    }
}

// MARK: - Preview

#Preview {
    MoodView()
}
