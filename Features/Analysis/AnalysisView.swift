//
//  AnalysisView.swift
//  Bagyt
//

import SwiftUI
import UIKit

struct AnalysisView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lang: LanguageManager
    @ObservedObject private var health = HealthKitManager.shared

    @AppStorage("isDarkModeEnabled") private var isDarkMode = false

    @State private var selectedSection: AnalysisSection = .medical
    @State private var medicalItems: [AnalysisMedicalItem] = []
    @State private var aiFindings: [BagytAIFinding] = []
    @State private var journalEntries: [JournalEntry] = []
    @State private var moodRecords: [MoodRecord] = []
    @State private var sheetMode: AnalysisMedicalSheetMode?
    @State private var showMoodSheet = false
    @State private var appear = false

    private let accent = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)
    private let success = Color(red: 0.10, green: 0.78, blue: 0.48)
    private let warning = Color(red: 1.0, green: 0.62, blue: 0.14)
    private let danger = Color(red: 0.95, green: 0.25, blue: 0.32)
    private let violet = Color(red: 0.55, green: 0.35, blue: 1.0)

    private var baseBg: Color {
        isDarkMode ? Color(red: 0.04, green: 0.06, blue: 0.10) : Color(red: 0.94, green: 0.97, blue: 1.0)
    }

    private var primaryText: Color {
        isDarkMode ? .white : Color(red: 0.06, green: 0.09, blue: 0.16)
    }

    private var secondaryText: Color {
        isDarkMode ? .white.opacity(0.64) : Color(red: 0.40, green: 0.55, blue: 0.65)
    }

    private var cardBg: Color {
        isDarkMode ? Color(red: 0.08, green: 0.11, blue: 0.17) : Color.white
    }

    private var stroke: Color {
        isDarkMode ? Color.white.opacity(0.10) : Color.white.opacity(0.68)
    }

    var body: some View {
        ZStack {
            baseBg.ignoresSafeArea()

            AnimatedGradientBackground()
                .opacity(isDarkMode ? 0.30 : 1.0)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header
                    sectionPicker

                    switch selectedSection {
                    case .medical:
                        medicalContent
                    case .anamnesis:
                        anamnesisContent
                    case .risks:
                        risksContent
                    case .doctor:
                        doctorContent
                    }

                    Spacer(minLength: 150)
                }
                .padding(.top, 8)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 8)
                .animation(.easeOut(duration: 0.28), value: appear)
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear {
            reloadAll()
            appear = true
        }
        .onChange(of: appState.userToken) { _, _ in
            reloadAll()
        }
        .sheet(item: $sheetMode) { mode in
            AnalysisMedicalItemSheet(mode: mode, isDarkMode: isDarkMode) { item in
                saveMedicalItem(item)
            }
        }
        .sheet(isPresented: $showMoodSheet) {
            MoodView()
                .environmentObject(appState)
                .environmentObject(lang)
                .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Анализ")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(primaryText)

                Text(headerSubtitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                reloadAll()
            } label: {
                ZStack {
                    Circle()
                        .fill(cardBg)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().strokeBorder(stroke, lineWidth: 1))
                        .shadow(color: Color.black.opacity(isDarkMode ? 0.20 : 0.07), radius: 10, x: 0, y: 5)

                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(accent)
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(AnalysisPressStyle())
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 2)
    }

    private var headerSubtitle: String {
        let allergy = items(for: .allergy).count
        let meds = items(for: .medication).count
        let conditions = items(for: .condition).count

        if medicalItems.isEmpty {
            return "Медкарта, риски и готовая сводка для врача"
        }

        return "\(allergy) аллергий · \(meds) лекарств · \(conditions) диагнозов · \(aiFindings.count) AI-заметок"
    }

    // MARK: - Picker

    private var sectionPicker: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8), count: AnalysisSection.allCases.count),
            spacing: 8
        ) {
            ForEach(AnalysisSection.allCases, id: \.self) { section in
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                        selectedSection = section
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: section.icon)
                            .font(.system(size: 12, weight: .black))
                        Text(section.title)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .foregroundColor(selectedSection == section ? .white : secondaryText)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(cardBg)

                        if selectedSection == section {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing))
                        }
                    }
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(selectedSection == section ? Color.white.opacity(0.22) : stroke, lineWidth: 1)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Medical Card

    private var medicalContent: some View {
        VStack(spacing: 16) {
            medicalHeroCard
            moodShortcutCard
            quickAddGrid
            medicalInventory
            importantContextCard
        }
    }

    private var medicalHeroCard: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [clinicalStatus.color, accent2], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: clinicalStatus.color.opacity(isDarkMode ? 0.16 : 0.30), radius: 18, x: 0, y: 10)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 176, height: 176)
                .offset(x: 54, y: -64)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 52, height: 52)
                        Image(systemName: clinicalStatus.icon)
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Карта пациента")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.78))
                            .tracking(0.9)
                        Text(clinicalStatus.title)
                            .font(.system(size: 23, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(clinicalStatus.subtitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.78))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    profileChip(title: "Аллергии", value: "\(items(for: .allergy).count)")
                    profileChip(title: "Лекарства", value: "\(items(for: .medication).count)")
                    profileChip(title: "Диагнозы", value: "\(items(for: .condition).count)")
                }
            }
            .padding(22)
        }
        .padding(.horizontal, 20)
    }

    private func profileChip(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.74))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var moodShortcutCard: some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            showMoodSheet = true
        } label: {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [Color(red: 1.0, green: 0.70, blue: 0.16), warning], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 54, height: 54)
                    Image(systemName: "face.smiling.fill")
                        .font(.system(size: 23, weight: .black))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Дневник настроения")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(primaryText)

                    Text(moodShortcutText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(secondaryText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(warning)
                    .frame(width: 32, height: 32)
                    .background(warning.opacity(isDarkMode ? 0.16 : 0.10), in: Circle())
            }
            .padding(16)
            .background(analysisCard(cornerRadius: 24))
        }
        .buttonStyle(AnalysisPressStyle())
        .padding(.horizontal, 20)
    }

    private var quickAddGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Быстро добавить", icon: "plus.app.fill")

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                ForEach(AnalysisMedicalCategory.allCases, id: \.self) { category in
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        sheetMode = AnalysisMedicalSheetMode(category: category)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(category.color.opacity(isDarkMode ? 0.16 : 0.11))
                                    .frame(width: 42, height: 42)
                                Image(systemName: category.icon)
                                    .font(.system(size: 17, weight: .black))
                                    .foregroundColor(category.color)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.title)
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundColor(primaryText)
                                    .lineLimit(1)
                                Text(category.shortHint)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(secondaryText)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(analysisCard(cornerRadius: 20))
                    }
                    .buttonStyle(AnalysisPressStyle())
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var medicalInventory: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Медицинская карта", icon: "folder.fill.badge.person.crop")

            ForEach(AnalysisMedicalCategory.allCases, id: \.self) { category in
                medicalCategoryBlock(category)
            }
        }
        .padding(.horizontal, 20)
    }

    private func medicalCategoryBlock(_ category: AnalysisMedicalCategory) -> some View {
        let categoryItems = items(for: category)

        return VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 9) {
                Image(systemName: category.icon)
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(category.color)

                Text(category.title)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(primaryText)

                Spacer()

                Text("\(categoryItems.count)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(category.color)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(category.color.opacity(isDarkMode ? 0.16 : 0.10), in: Capsule())
            }

            if categoryItems.isEmpty {
                Button {
                    sheetMode = AnalysisMedicalSheetMode(category: category)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(category.color)
                        Text(category.emptyText)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(secondaryText)
                        Spacer()
                    }
                    .padding(13)
                    .background(
                        category.color.opacity(isDarkMode ? 0.09 : 0.055),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            } else {
                ForEach(categoryItems) { item in
                    medicalItemRow(item)
                }
            }
        }
        .padding(15)
        .background(analysisCard(cornerRadius: 22))
    }

    private func medicalItemRow(_ item: AnalysisMedicalItem) -> some View {
        HStack(alignment: .top, spacing: 11) {
            VStack(spacing: 0) {
                Circle()
                    .fill(item.importance.color)
                    .frame(width: 9, height: 9)
                    .padding(.top, 6)
                Rectangle()
                    .fill(item.importance.color.opacity(0.18))
                    .frame(width: 2)
            }

            Button {
                sheetMode = AnalysisMedicalSheetMode(category: item.category, item: item)
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.title)
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(primaryText)
                            .lineLimit(2)

                        Text(item.importance.title)
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundColor(item.importance.color)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(item.importance.color.opacity(isDarkMode ? 0.16 : 0.10), in: Capsule())

                        Spacer(minLength: 0)
                    }

                    if !item.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(item.detail)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(secondaryText)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(Self.shortDateFormatter.string(from: item.updatedAt))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(secondaryText.opacity(0.82))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                deleteMedicalItem(item)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(secondaryText)
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(isDarkMode ? 0.04 : 0.42), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(isDarkMode ? Color.white.opacity(0.035) : Color.white.opacity(0.50))
        )
    }

    private var importantContextCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Почему это важно", icon: "shield.lefthalf.filled")

            VStack(spacing: 10) {
                contextRow(
                    icon: "exclamationmark.triangle.fill",
                    title: "Аллергии видны врачу сразу",
                    text: "Если пользователь поделится сводкой, аллергии и противопоказания попадут в верх отчета.",
                    color: danger
                )

                contextRow(
                    icon: "pills.fill",
                    title: "Лекарства дают контекст симптомам",
                    text: "Bagyt сможет отличать самочувствие само по себе от возможной реакции на препарат.",
                    color: violet
                )

                contextRow(
                    icon: "stethoscope",
                    title: "Диагнозы меняют интерпретацию",
                    text: "Один и тот же пульс или симптом имеет разный смысл при разных хронических состояниях.",
                    color: accent
                )
            }
        }
        .padding(.horizontal, 20)
    }

    private func contextRow(icon: String, title: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .black))
                .foregroundColor(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(isDarkMode ? 0.16 : 0.10), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(primaryText)
                Text(text)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(secondaryText)
                    .lineSpacing(3)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(analysisCard(cornerRadius: 18))
    }

    // MARK: - Anamnesis

    private var anamnesisContent: some View {
        VStack(spacing: 16) {
            anamnesisHeroCard
            aiMemoryCard
            moodAnamnesisCard
            clinicalStoryCard
        }
    }

    private var anamnesisHeroCard: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [violet, accent], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: violet.opacity(isDarkMode ? 0.16 : 0.28), radius: 18, x: 0, y: 10)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 168, height: 168)
                .offset(x: 54, y: -64)

            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 52, height: 52)
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Анамнез Bagyt")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.78))
                            .tracking(0.9)
                        Text("Память о здоровье")
                            .font(.system(size: 23, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("Здесь собираются факты из медкарты, журнала, настроения и AI-чата. Это не диагноз, а умная история обращений.")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.80))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    profileChip(title: "AI-заметки", value: "\(aiFindings.count)")
                    profileChip(title: "Симптомы", value: "\(symptomsLast14.count)")
                    profileChip(title: "Настроение", value: "\(moodLast7.count)")
                }
            }
            .padding(22)
        }
        .padding(.horizontal, 20)
    }

    private var aiMemoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("AI-гипотезы из чата", icon: "sparkle.magnifyingglass")

            if aiFindings.isEmpty {
                emptyPanel(
                    icon: "bubble.left.and.text.bubble.right.fill",
                    title: "Память чата пока пустая",
                    text: "Когда Bagyt в чате обсудит симптом и возможные причины, краткая заметка появится здесь и попадет в будущий контекст AI."
                )
            } else {
                ForEach(aiFindings.prefix(6)) { finding in
                    aiFindingRow(finding)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func aiFindingRow(_ finding: BagytAIFinding) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: finding.redFlags.isEmpty ? "brain.head.profile" : "exclamationmark.triangle.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(finding.redFlags.isEmpty ? violet : danger)
                    .frame(width: 36, height: 36)
                    .background((finding.redFlags.isEmpty ? violet : danger).opacity(isDarkMode ? 0.16 : 0.10), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(finding.title)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(primaryText)
                        .lineLimit(2)
                    Text(Self.shortDateFormatter.string(from: finding.createdAt))
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(secondaryText)
                }

                Spacer(minLength: 0)

                Button(role: .destructive) {
                    deleteAIFinding(finding)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(secondaryText)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(isDarkMode ? 0.04 : 0.42), in: Circle())
                }
                .buttonStyle(.plain)
            }

            Text(finding.summary)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(secondaryText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if !finding.hypotheses.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Возможные причины, не диагноз")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(violet)
                        .tracking(0.4)

                    ForEach(finding.hypotheses.prefix(3), id: \.self) { item in
                        bulletText(item, color: violet)
                    }
                }
            }

            if !finding.redFlags.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Красные флаги")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(danger)
                        .tracking(0.4)

                    ForEach(finding.redFlags.prefix(2), id: \.self) { item in
                        bulletText(item, color: danger)
                    }
                }
            }
        }
        .padding(15)
        .background(analysisCard(cornerRadius: 20))
    }

    private var moodAnamnesisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Настроение как часть анамнеза", icon: "face.smiling.fill")

                Button {
                    showMoodSheet = true
                } label: {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(accent)
                        .frame(width: 30, height: 30)
                        .background(accent.opacity(isDarkMode ? 0.15 : 0.09), in: Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: mentalContext.icon)
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(mentalContext.color)
                    .frame(width: 36, height: 36)
                    .background(mentalContext.color.opacity(isDarkMode ? 0.16 : 0.10), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(mentalContext.title)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(primaryText)
                    Text("\(mentalContext.text) Поэтому дневник настроения лучше оставить здесь, как часть анамнеза и фона симптомов.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(secondaryText)
                        .lineSpacing(3)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(analysisCard(cornerRadius: 18))
        }
        .padding(.horizontal, 20)
    }

    private var clinicalStoryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Клиническая история", icon: "clock.badge.fill")

            if recentClinicalEntries.isEmpty {
                emptyPanel(
                    icon: "book.closed.fill",
                    title: "История пока короткая",
                    text: "Журнал симптомов, визитов и заметок будет собирать хронологию, а AI-чат будет добавлять интерпретацию."
                )
            } else {
                ForEach(recentClinicalEntries.prefix(4)) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: entry.category.icon)
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(entry.category.color)
                            .frame(width: 34, height: 34)
                            .background(entry.category.color.opacity(isDarkMode ? 0.16 : 0.10), in: Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.title)
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundColor(primaryText)
                            Text("\(entry.category.rawValue) · \(Self.shortDateFormatter.string(from: entry.date))")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(secondaryText)
                            if !entry.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(entry.body)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(secondaryText)
                                    .lineLimit(2)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(13)
                    .background(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(isDarkMode ? Color.white.opacity(0.035) : Color.white.opacity(0.50))
                    )
                }
            }
        }
        .padding(18)
        .background(analysisCard(cornerRadius: 26))
        .padding(.horizontal, 20)
    }

    private func bulletText(_ text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
                .padding(.top, 6)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(secondaryText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Risks

    private var risksContent: some View {
        VStack(spacing: 16) {
            clinicalAlertsCard
            symptomFocusCard
            riskMatrixCard
            mentalContextCard
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private var clinicalAlertsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Медицинские сигналы", icon: "waveform.path.ecg.rectangle.fill")

            ForEach(clinicalAlerts) { alert in
                HStack(alignment: .top, spacing: 13) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(alert.severity.color.opacity(isDarkMode ? 0.16 : 0.10))
                            .frame(width: 45, height: 45)
                        Image(systemName: alert.icon)
                            .font(.system(size: 17, weight: .black))
                            .foregroundColor(alert.severity.color)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 7) {
                            Text(alert.title)
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundColor(primaryText)
                            Text(alert.severity.title)
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .foregroundColor(alert.severity.color)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(alert.severity.color.opacity(isDarkMode ? 0.16 : 0.10), in: Capsule())
                        }

                        Text(alert.text)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(secondaryText)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(15)
                .background(analysisCard(cornerRadius: 20))
            }
        }
        .padding(.horizontal, 20)
    }

    private var symptomFocusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Симптомы")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(primaryText)
                    Text("Последние 14 дней из журнала")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(secondaryText)
                }

                Spacer()

                Text("\(symptomsLast14.count)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(danger)
            }

            if symptomsLast14.isEmpty {
                emptyPanel(
                    icon: "checkmark.shield.fill",
                    title: "Симптомы не отмечены",
                    text: "Если появится боль, температура, одышка или необычная реакция, лучше записать это в журнал."
                )
            } else {
                ForEach(symptomsLast14.prefix(5)) { entry in
                    symptomRow(entry)
                }
            }
        }
        .padding(18)
        .background(analysisCard(cornerRadius: 26))
        .padding(.horizontal, 20)
    }

    private func symptomRow(_ entry: JournalEntry) -> some View {
        let severity = entry.severity ?? 0
        let level = Double(max(severity, 1)) / 10.0
        let color = severity >= 8 ? danger : severity >= 5 ? warning : accent

        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                Text(entry.title)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(primaryText)
                    .lineLimit(2)

                Spacer()

                Text(severity > 0 ? "\(severity)/10" : "без оценки")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.055))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(level))
                }
            }
            .frame(height: 6)

            if !entry.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(entry.body)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(secondaryText)
                    .lineLimit(2)
            }
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isDarkMode ? Color.white.opacity(0.035) : Color.white.opacity(0.50))
        )
    }

    private var riskMatrixCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Матрица факторов", icon: "list.bullet.clipboard.fill")

            ForEach(riskFactors) { factor in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: factor.icon)
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(factor.color)
                        .frame(width: 34, height: 34)
                        .background(factor.color.opacity(isDarkMode ? 0.16 : 0.10), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(factor.title)
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(primaryText)
                        Text(factor.text)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(secondaryText)
                            .lineSpacing(3)
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isDarkMode ? Color.white.opacity(0.035) : Color.white.opacity(0.48))
                )
            }
        }
        .padding(18)
        .background(analysisCard(cornerRadius: 26))
        .padding(.horizontal, 20)
    }

    private var mentalContextCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Психоэмоциональный контекст", icon: "brain.head.profile")

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: mentalContext.icon)
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(mentalContext.color)
                    .frame(width: 34, height: 34)
                    .background(mentalContext.color.opacity(isDarkMode ? 0.16 : 0.10), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(mentalContext.title)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(primaryText)
                    Text(mentalContext.text)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(secondaryText)
                        .lineSpacing(3)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(analysisCard(cornerRadius: 18))
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Doctor

    private var doctorContent: some View {
        VStack(spacing: 16) {
            doctorSummaryCard
            visitPrepCard
            timelineCard
        }
    }

    private var doctorSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 50, height: 50)
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Сводка для врача")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundColor(primaryText)
                    Text("Аллергии, лекарства, диагнозы и последние симптомы")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(secondaryText)
                        .lineLimit(2)
                }

                Spacer()
            }

            Text(doctorSummary)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(isDarkMode ? .white.opacity(0.78) : Color(red: 0.25, green: 0.35, blue: 0.44))
                .lineSpacing(4)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isDarkMode ? Color.black.opacity(0.22) : Color.white.opacity(0.58))
                )
                .lineLimit(17)

            ShareLink(item: doctorSummary) {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .black))
                    Text("Поделиться сводкой")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .black))
                }
                .foregroundColor(.white)
                .padding(.vertical, 15)
                .padding(.horizontal, 17)
                .background(
                    LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 19, style: .continuous)
                )
            }
        }
        .padding(18)
        .background(analysisCard(cornerRadius: 26))
        .padding(.horizontal, 20)
    }

    private var visitPrepCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Подготовка к приему", icon: "checklist.checked")

            ForEach(visitChecklist, id: \.self) { item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: item.isReady ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 17, weight: .black))
                        .foregroundColor(item.isReady ? success : secondaryText)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(primaryText)
                        Text(item.text)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(secondaryText)
                            .lineSpacing(3)
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(analysisCard(cornerRadius: 18))
            }
        }
        .padding(.horizontal, 20)
    }

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Последние события", icon: "calendar.badge.clock")

            if recentClinicalEntries.isEmpty {
                emptyPanel(
                    icon: "book.closed.fill",
                    title: "Пока нет клинических записей",
                    text: "Добавляйте симптомы, визиты и назначения в журнал, чтобы отчет был полезнее."
                )
            } else {
                ForEach(recentClinicalEntries.prefix(5)) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: entry.category.icon)
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(entry.category.color)
                            .frame(width: 34, height: 34)
                            .background(entry.category.color.opacity(isDarkMode ? 0.16 : 0.10), in: Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.title)
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundColor(primaryText)
                            Text("\(entry.category.rawValue) · \(Self.shortDateFormatter.string(from: entry.date))")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(secondaryText)
                            if !entry.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(entry.body)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(secondaryText)
                                    .lineLimit(2)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(13)
                    .background(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(isDarkMode ? Color.white.opacity(0.035) : Color.white.opacity(0.50))
                    )
                }
            }
        }
        .padding(18)
        .background(analysisCard(cornerRadius: 26))
        .padding(.horizontal, 20)
    }

    // MARK: - Derived Data

    private var symptomsLast14: [JournalEntry] {
        journalEntries
            .filter { $0.date >= startDate(days: 14) && $0.category == .symptom }
            .sorted { $0.date > $1.date }
    }

    private var recentClinicalEntries: [JournalEntry] {
        journalEntries
            .filter { [.symptom, .visit, .sleep, .note].contains($0.category) }
            .sorted { $0.date > $1.date }
    }

    private var moodLast7: [MoodRecord] {
        moodRecords.filter { $0.date >= startDate(days: 7) }
    }

    private var averageMood: Double? {
        average(moodLast7.map { Double($0.mood) })
    }

    private var averageStress: Double? {
        average(moodLast7.map { Double($0.stress) })
    }

    private var sleepHours: Double {
        health.homeSleepDay?.hours ?? health.sleep
    }

    private var clinicalStatus: AnalysisClinicalStatus {
        if hasCriticalSignal {
            return .urgent
        }

        if medicalItems.isEmpty || !health.isAuthorized && journalEntries.count < 2 {
            return .incomplete
        }

        if clinicalAlerts.contains(where: { $0.severity == .attention }) {
            return .watch
        }

        return .stable
    }

    private var hasCriticalSignal: Bool {
        if let severe = symptomsLast14.compactMap(\.severity).max(), severe >= 8 {
            return true
        }

        if health.heartRate >= 120 || (health.heartRate > 0 && health.heartRate <= 45) {
            return true
        }

        return false
    }

    private var clinicalAlerts: [AnalysisClinicalAlert] {
        var alerts: [AnalysisClinicalAlert] = []

        if let severe = symptomsLast14.compactMap(\.severity).max(), severe >= 8 {
            alerts.append(.init(
                severity: .critical,
                icon: "exclamationmark.triangle.fill",
                title: "Сильный симптом",
                text: "В журнале есть симптом силой \(severe)/10. Если он сохраняется, усиливается или сопровождается одышкой, болью в груди, слабостью или высокой температурой, лучше обратиться за медицинской помощью."
            ))
        }

        if health.heartRate >= 120 {
            alerts.append(.init(
                severity: .critical,
                icon: "heart.fill",
                title: "Высокий пульс",
                text: "Последний пульс \(health.heartRate) уд/мин. Важно учитывать нагрузку, стресс, температуру и лекарства. При плохом самочувствии это повод не откладывать консультацию."
            ))
        } else if health.heartRate > 0 && health.heartRate <= 45 {
            alerts.append(.init(
                severity: .critical,
                icon: "heart.fill",
                title: "Низкий пульс",
                text: "Последний пульс \(health.heartRate) уд/мин. Если есть слабость, головокружение или обмороки, лучше обсудить это с врачом."
            ))
        }

        if items(for: .allergy).isEmpty {
            alerts.append(.init(
                severity: .info,
                icon: "allergens.fill",
                title: "Аллергии не заполнены",
                text: "Это не значит, что аллергий нет. Заполненная аллергологическая карта делает отчет врачу гораздо безопаснее."
            ))
        }

        if items(for: .medication).isEmpty {
            alerts.append(.init(
                severity: .info,
                icon: "pills.fill",
                title: "Лекарства не указаны",
                text: "Добавьте постоянные препараты, витамины и то, что принимаете по необходимости. Это особенно важно при новых симптомах."
            ))
        }

        if symptomsLast14.count >= 3 {
            alerts.append(.init(
                severity: .attention,
                icon: "waveform.path.ecg.rectangle.fill",
                title: "Повтор симптомов",
                text: "\(symptomsLast14.count) симптома за 14 дней. Стоит посмотреть, повторяются ли они после еды, нагрузки, недосыпа или приема лекарств."
            ))
        }

        if sleepHours > 0 && sleepHours < 5.5 {
            alerts.append(.init(
                severity: .attention,
                icon: "moon.zzz.fill",
                title: "Недосып как фактор",
                text: "Последний сон около \(String(format: "%.1f", sleepHours)) ч. Это не диагноз, но недосып может усиливать головную боль, усталость и сердцебиение."
            ))
        }

        if alerts.isEmpty {
            alerts.append(.init(
                severity: .stable,
                icon: "checkmark.shield.fill",
                title: "Критичных сигналов нет",
                text: "Сейчас Bagyt не видит явных красных флагов. Продолжайте вести медкарту и журнал, чтобы анализ был точнее."
            ))
        }

        return alerts
    }

    private var riskFactors: [AnalysisRiskFactor] {
        var factors: [AnalysisRiskFactor] = [
            .init(
                icon: "allergens.fill",
                title: "Аллергологический риск",
                text: items(for: .allergy).isEmpty
                    ? "Аллергии пока не заполнены. Это один из самых важных блоков перед назначениями."
                    : "Заполнено: \(items(for: .allergy).map(\.title).joined(separator: ", ")).",
                color: items(for: .allergy).isEmpty ? warning : success
            ),
            .init(
                icon: "pills.fill",
                title: "Лекарственная нагрузка",
                text: items(for: .medication).isEmpty
                    ? "Постоянные лекарства не указаны."
                    : "\(items(for: .medication).count) активных записей. Проверяйте дозировки и реакции в журнале.",
                color: items(for: .medication).isEmpty ? secondaryText : violet
            ),
            .init(
                icon: "cross.case.fill",
                title: "Хронический фон",
                text: items(for: .condition).isEmpty
                    ? "Диагнозы не указаны. При хронических состояниях анализ должен учитывать базовый фон."
                    : "Указано: \(items(for: .condition).map(\.title).joined(separator: ", ")).",
                color: items(for: .condition).isEmpty ? secondaryText : accent
            )
        ]

        if health.heartRate > 0 {
            factors.append(.init(
                icon: "heart.text.square.fill",
                title: "Пульс как клинический контекст",
                text: "Последнее значение: \(health.heartRate) уд/мин. Оно учитывается только как сигнал, а не как отдельный индекс здоровья.",
                color: heartRateColor
            ))
        }

        if sleepHours > 0 {
            factors.append(.init(
                icon: "bed.double.fill",
                title: "Восстановление",
                text: "Сон: \(String(format: "%.1f", sleepHours)) ч. В анализе это фактор риска для симптомов, а не копия вкладки метрик.",
                color: sleepHours < 5.5 ? warning : success
            ))
        }

        return factors
    }

    private var mentalContext: AnalysisRiskFactor {
        if let stress = averageStress, stress >= 4 {
            return .init(
                icon: "brain.head.profile",
                title: "Высокий стресс как фон",
                text: "Средний стресс за неделю \(String(format: "%.1f", stress))/5. Это не главный медицинский блок, но он может усиливать симптомы и сон.",
                color: warning
            )
        }

        if let mood = averageMood, mood <= 2.2 {
            return .init(
                icon: "face.dashed.fill",
                title: "Настроение снижено",
                text: "Среднее настроение \(String(format: "%.1f", mood))/5. Bagyt учитывает это как фон, но не строит весь анализ вокруг настроения.",
                color: warning
            )
        }

        return .init(
            icon: "checkmark.circle.fill",
            title: "Фон без явного сигнала",
            text: moodLast7.isEmpty ? "Настроение можно отмечать, но это дополнительный контекст, а не центр медицинского анализа." : "Психоэмоциональные записи есть, критичного сигнала по ним сейчас нет.",
            color: success
        )
    }

    private var moodShortcutText: String {
        if moodLast7.isEmpty {
            return "Открыть дневник настроения и добавить запись. Эти данные будут учитываться в анамнезе как фон."
        }

        var parts = ["\(moodLast7.count) записей за неделю"]

        if let averageMood {
            parts.append("настроение \(String(format: "%.1f", averageMood))/5")
        }

        if let averageStress {
            parts.append("стресс \(String(format: "%.1f", averageStress))/5")
        }

        return parts.joined(separator: " · ")
    }

    private var visitChecklist: [AnalysisVisitChecklistItem] {
        [
            .init(
                title: "Аллергии и противопоказания",
                text: items(for: .allergy).isEmpty ? "Добавьте хотя бы известные аллергии или отметьте, что их нет." : "Заполнено \(items(for: .allergy).count) записей.",
                isReady: !items(for: .allergy).isEmpty
            ),
            .init(
                title: "Текущие лекарства",
                text: items(for: .medication).isEmpty ? "Укажите названия, дозировки и как часто принимаете." : "Список лекарств попадет в сводку.",
                isReady: !items(for: .medication).isEmpty
            ),
            .init(
                title: "Симптомы с датами",
                text: symptomsLast14.isEmpty ? "Если симптомов нет, ничего добавлять не нужно." : "\(symptomsLast14.count) записей уже есть.",
                isReady: !symptomsLast14.isEmpty
            ),
            .init(
                title: "Ключевые показатели",
                text: health.isAuthorized ? "HealthKit подключен: пульс, сон и активность будут в отчете." : "Можно подключить HealthKit, чтобы врачу было проще увидеть динамику.",
                isReady: health.isAuthorized
            ),
            .init(
                title: "AI-анамнез",
                text: aiFindings.isEmpty ? "После медицинского вопроса в чате Bagyt сохранит краткую заметку сюда." : "\(aiFindings.count) AI-заметок уже сохранено.",
                isReady: !aiFindings.isEmpty
            )
        ]
    }

    private var doctorSummary: String {
        var lines: [String] = [
            "Bagyt · медицинская сводка",
            "Дата: \(Self.fullDateFormatter.string(from: Date()))",
            "",
            "Статус: \(clinicalStatus.title)",
            clinicalStatus.subtitle,
            ""
        ]

        appendMedicalBlock(title: "Аллергии", category: .allergy, to: &lines)
        appendMedicalBlock(title: "Лекарства", category: .medication, to: &lines)
        appendMedicalBlock(title: "Диагнозы / хронические состояния", category: .condition, to: &lines)
        appendMedicalBlock(title: "Важные заметки", category: .careNote, to: &lines)

        lines.append("Показатели:")
        lines.append("- Пульс: \(health.heartRate > 0 ? "\(health.heartRate) уд/мин" : "нет данных")")
        lines.append("- Сон: \(sleepHours > 0 ? String(format: "%.1f ч", sleepHours) : "нет данных")")
        lines.append("- Шаги сегодня: \(health.steps > 0 ? "\(health.steps)" : "нет данных")")
        lines.append("")

        lines.append("Симптомы за 14 дней:")
        if symptomsLast14.isEmpty {
            lines.append("- Не отмечены")
        } else {
            symptomsLast14.prefix(7).forEach { entry in
                let severity = entry.severity.map { ", \($0)/10" } ?? ""
                lines.append("- \(Self.shortDateFormatter.string(from: entry.date)): \(entry.title)\(severity)")
            }
        }

        lines.append("")
        lines.append("AI-анамнез из чата:")
        if aiFindings.isEmpty {
            lines.append("- Нет сохраненных AI-заметок")
        } else {
            aiFindings.prefix(5).forEach { finding in
                lines.append("- \(Self.shortDateFormatter.string(from: finding.createdAt)): \(finding.title)")
                lines.append("  \(finding.summary)")
                if !finding.hypotheses.isEmpty {
                    lines.append("  Возможные причины, не диагноз: \(finding.hypotheses.prefix(3).joined(separator: "; "))")
                }
            }
        }

        lines.append("")
        lines.append("Важно: сводка не является диагнозом и не заменяет консультацию врача.")
        return lines.joined(separator: "\n")
    }

    private var heartRateColor: Color {
        if health.heartRate >= 120 || (health.heartRate > 0 && health.heartRate <= 45) {
            return danger
        }
        return success
    }

    // MARK: - Loading

    private func reloadAll() {
        loadLocalData()
        loadMedicalItems()
        loadAIFindings()

        if !health.isAuthorized {
            health.requestAuthorization()
        } else {
            health.fetchAll()
        }
    }

    private func loadAIFindings() {
        let token = appState.userToken ?? UserDefaults.standard.string(forKey: "userToken")
        aiFindings = BagytMemoryStore.shared.loadFindings(token: token)
    }

    private func loadLocalData() {
        let token = appState.userToken ?? UserDefaults.standard.string(forKey: "userToken")
        journalEntries = loadJournalEntries(token: token)
        moodRecords = loadMoodRecords(token: token)
    }

    private func loadMedicalItems() {
        let key = medicalStorageKey()
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode([AnalysisMedicalItem].self, from: data) else {
            medicalItems = []
            return
        }

        medicalItems = saved.sorted { lhs, rhs in
            if lhs.category.sortOrder == rhs.category.sortOrder {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.category.sortOrder < rhs.category.sortOrder
        }
    }

    private func saveMedicalItem(_ item: AnalysisMedicalItem) {
        var updated = item
        updated.updatedAt = Date()

        if let index = medicalItems.firstIndex(where: { $0.id == updated.id }) {
            medicalItems[index] = updated
        } else {
            medicalItems.append(updated)
        }

        persistMedicalItems()
    }

    private func deleteMedicalItem(_ item: AnalysisMedicalItem) {
        medicalItems.removeAll { $0.id == item.id }
        persistMedicalItems()
    }

    private func deleteAIFinding(_ finding: BagytAIFinding) {
        let token = appState.userToken ?? UserDefaults.standard.string(forKey: "userToken")
        BagytMemoryStore.shared.deleteFinding(id: finding.id, token: token)
        loadAIFindings()
    }

    private func persistMedicalItems() {
        medicalItems.sort { lhs, rhs in
            if lhs.category.sortOrder == rhs.category.sortOrder {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.category.sortOrder < rhs.category.sortOrder
        }

        if let data = try? JSONEncoder().encode(medicalItems) {
            UserDefaults.standard.set(data, forKey: medicalStorageKey())
        }
    }

    private func loadJournalEntries(token: String?) -> [JournalEntry] {
        let keys = [
            scopedKey(base: "bagyt_journal_entries", token: token),
            "bagyt_journal_entries"
        ]

        for key in keys {
            if let data = UserDefaults.standard.data(forKey: key),
               let decoded = try? JSONDecoder().decode([JournalEntry].self, from: data) {
                return decoded
            }
        }

        #if DEBUG
        return JournalViewModel.demoEntries()
        #else
        return []
        #endif
    }

    private func loadMoodRecords(token: String?) -> [MoodRecord] {
        let keys = [
            scopedKey(base: "bagyt_mood_records", token: token),
            "bagyt_mood_records"
        ]

        for key in keys {
            if let data = UserDefaults.standard.data(forKey: key),
               let decoded = try? JSONDecoder().decode([MoodRecord].self, from: data) {
                return decoded.sorted { $0.date > $1.date }
            }
        }

        return []
    }

    private func medicalStorageKey() -> String {
        scopedKey(
            base: "bagyt_medical_profile_items",
            token: appState.userToken ?? UserDefaults.standard.string(forKey: "userToken")
        )
    }

    private func scopedKey(base: String, token: String?) -> String {
        let raw = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        let user = raw?.isEmpty == false ? raw! : "guest"
        let safe = Data(user.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "\(base)_\(safe)"
    }

    // MARK: - Helpers

    private func items(for category: AnalysisMedicalCategory) -> [AnalysisMedicalItem] {
        medicalItems.filter { $0.category == category }
    }

    private func appendMedicalBlock(title: String, category: AnalysisMedicalCategory, to lines: inout [String]) {
        lines.append("\(title):")

        let entries = items(for: category)
        if entries.isEmpty {
            lines.append("- Не указано")
        } else {
            entries.forEach { item in
                let detail = item.detail.trimmingCharacters(in: .whitespacesAndNewlines)
                lines.append("- \(item.title) [\(item.importance.title)]\(detail.isEmpty ? "" : ": \(detail)")")
            }
        }

        lines.append("")
    }

    private func analysisCard(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(cardBg)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isDarkMode ? 0.24 : 0.055), radius: 14, x: 0, y: 8)
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundColor(accent)
            Text(title)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundColor(primaryText)
            Spacer()
        }
    }

    private func emptyPanel(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .black))
                .foregroundColor(accent)
                .frame(width: 36, height: 36)
                .background(accent.opacity(isDarkMode ? 0.16 : 0.10), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(primaryText)
                Text(text)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(secondaryText)
                    .lineSpacing(3)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isDarkMode ? Color.white.opacity(0.035) : Color.white.opacity(0.48))
        )
    }

    private func startDate(days: Int) -> Date {
        Calendar.current.date(
            byAdding: .day,
            value: -(days - 1),
            to: Calendar.current.startOfDay(for: Date())
        ) ?? Date()
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy, HH:mm"
        return formatter
    }()
}

// MARK: - Sheet

private struct AnalysisMedicalItemSheet: View {
    @Environment(\.dismiss) private var dismiss

    let mode: AnalysisMedicalSheetMode
    let isDarkMode: Bool
    let onSave: (AnalysisMedicalItem) -> Void

    @State private var title: String
    @State private var detail: String
    @State private var importance: AnalysisMedicalImportance

    private let accent = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)

    init(mode: AnalysisMedicalSheetMode, isDarkMode: Bool, onSave: @escaping (AnalysisMedicalItem) -> Void) {
        self.mode = mode
        self.isDarkMode = isDarkMode
        self.onSave = onSave
        _title = State(initialValue: mode.item?.title ?? "")
        _detail = State(initialValue: mode.item?.detail ?? "")
        _importance = State(initialValue: mode.item?.importance ?? .medium)
    }

    private var baseBg: Color {
        isDarkMode ? Color(red: 0.04, green: 0.06, blue: 0.10) : Color(red: 0.94, green: 0.97, blue: 1.0)
    }

    private var primaryText: Color {
        isDarkMode ? .white : Color(red: 0.06, green: 0.09, blue: 0.16)
    }

    private var secondaryText: Color {
        isDarkMode ? .white.opacity(0.64) : Color(red: 0.40, green: 0.55, blue: 0.65)
    }

    private var cardBg: Color {
        isDarkMode ? Color.white.opacity(0.07) : Color.white.opacity(0.82)
    }

    private var stroke: Color {
        isDarkMode ? Color.white.opacity(0.10) : Color.white.opacity(0.68)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                baseBg.ignoresSafeArea()

                AnimatedGradientBackground()
                    .opacity(isDarkMode ? 0.18 : 0.72)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        sheetHeader
                        titleInput
                        detailInput
                        importancePicker
                        saveButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                }
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .navigationTitle(mode.item == nil ? "Добавить" : "Изменить")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var sheetHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(mode.category.color.opacity(isDarkMode ? 0.18 : 0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: mode.category.icon)
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(mode.category.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(mode.category.title)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(primaryText)
                Text(mode.category.longHint)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(secondaryText)
                    .lineSpacing(3)
            }

            Spacer()
        }
        .padding(18)
        .background(sheetCard(cornerRadius: 24))
    }

    private var titleInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mode.category.inputTitle)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(secondaryText)

            TextField(mode.category.placeholder, text: $title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(primaryText)
                .textInputAutocapitalization(.sentences)
                .padding(15)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isDarkMode ? Color.black.opacity(0.18) : Color.white.opacity(0.64))
                )
        }
        .padding(16)
        .background(sheetCard(cornerRadius: 22))
    }

    private var detailInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Детали")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(secondaryText)

            TextEditor(text: $detail)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(primaryText)
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isDarkMode ? Color.black.opacity(0.18) : Color.white.opacity(0.64))
                )
                .overlay(alignment: .topLeading) {
                    if detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(mode.category.detailPlaceholder)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(secondaryText.opacity(0.65))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(16)
        .background(sheetCard(cornerRadius: 22))
    }

    private var importancePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Важность")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(secondaryText)

            HStack(spacing: 8) {
                ForEach(AnalysisMedicalImportance.allCases, id: \.self) { level in
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        importance = level
                    } label: {
                        Text(level.title)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(importance == level ? .white : level.color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                importance == level ? level.color : level.color.opacity(isDarkMode ? 0.14 : 0.09),
                                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(sheetCard(cornerRadius: 22))
    }

    private var saveButton: some View {
        Button {
            guard canSave else { return }

            let item = AnalysisMedicalItem(
                id: mode.item?.id ?? UUID(),
                category: mode.category,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
                importance: importance,
                updatedAt: Date()
            )

            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onSave(item)
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .black))
                Text(mode.item == nil ? "Сохранить запись" : "Сохранить изменения")
                    .font(.system(size: 16, weight: .black, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: canSave ? [accent, accent2] : [Color.gray.opacity(0.5), Color.gray.opacity(0.4)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
        }
        .disabled(!canSave)
        .buttonStyle(AnalysisPressStyle())
    }

    private func sheetCard(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(cardBg)
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isDarkMode ? 0.24 : 0.055), radius: 14, x: 0, y: 8)
    }
}

// MARK: - Models

private enum AnalysisSection: CaseIterable {
    case medical
    case anamnesis
    case risks
    case doctor

    var title: String {
        switch self {
        case .medical: return "Медкарта"
        case .anamnesis: return "Анамнез"
        case .risks: return "Риски"
        case .doctor: return "Врачу"
        }
    }

    var icon: String {
        switch self {
        case .medical: return "cross.case.fill"
        case .anamnesis: return "brain.head.profile"
        case .risks: return "waveform.path.ecg.rectangle.fill"
        case .doctor: return "stethoscope"
        }
    }
}

private enum AnalysisMedicalCategory: String, CaseIterable, Codable {
    case allergy
    case medication
    case condition
    case careNote

    var title: String {
        switch self {
        case .allergy: return "Аллергия"
        case .medication: return "Лекарство"
        case .condition: return "Диагноз"
        case .careNote: return "Важное"
        }
    }

    var icon: String {
        switch self {
        case .allergy: return "allergens.fill"
        case .medication: return "pills.fill"
        case .condition: return "cross.case.fill"
        case .careNote: return "staroflife.fill"
        }
    }

    var color: Color {
        switch self {
        case .allergy: return Color(red: 0.95, green: 0.25, blue: 0.32)
        case .medication: return Color(red: 0.55, green: 0.35, blue: 1.0)
        case .condition: return Color(red: 0.055, green: 0.647, blue: 0.914)
        case .careNote: return Color(red: 0.10, green: 0.78, blue: 0.48)
        }
    }

    var sortOrder: Int {
        switch self {
        case .allergy: return 0
        case .medication: return 1
        case .condition: return 2
        case .careNote: return 3
        }
    }

    var shortHint: String {
        switch self {
        case .allergy: return "реакции"
        case .medication: return "дозировки"
        case .condition: return "хроника"
        case .careNote: return "контекст"
        }
    }

    var longHint: String {
        switch self {
        case .allergy: return "Запишите вещество, продукт или препарат, на который была реакция."
        case .medication: return "Укажите препарат, дозировку, частоту приема и зачем он назначен."
        case .condition: return "Добавьте хроническое состояние, диагноз или важный медицинский фон."
        case .careNote: return "Группа крови, операции, противопоказания, контакт близкого или другая важная заметка."
        }
    }

    var inputTitle: String {
        switch self {
        case .allergy: return "На что аллергия"
        case .medication: return "Название лекарства"
        case .condition: return "Диагноз или состояние"
        case .careNote: return "Название заметки"
        }
    }

    var placeholder: String {
        switch self {
        case .allergy: return "Например: пенициллин"
        case .medication: return "Например: витамин D 2000 МЕ"
        case .condition: return "Например: астма"
        case .careNote: return "Например: группа крови O(I)+"
        }
    }

    var detailPlaceholder: String {
        switch self {
        case .allergy: return "Какая реакция, когда была, насколько сильная..."
        case .medication: return "Дозировка, время приема, кто назначил, побочные реакции..."
        case .condition: return "Когда поставили, что важно контролировать..."
        case .careNote: return "Любая информация, которую врачу важно увидеть сразу..."
        }
    }

    var emptyText: String {
        switch self {
        case .allergy: return "Добавить известную аллергию"
        case .medication: return "Добавить текущий препарат"
        case .condition: return "Добавить диагноз или состояние"
        case .careNote: return "Добавить важную заметку"
        }
    }
}

private struct AnalysisMedicalItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var category: AnalysisMedicalCategory
    var title: String
    var detail: String
    var importance: AnalysisMedicalImportance
    var updatedAt: Date = Date()
}

private enum AnalysisMedicalImportance: String, CaseIterable, Codable {
    case low
    case medium
    case high

    var title: String {
        switch self {
        case .low: return "Обычное"
        case .medium: return "Важно"
        case .high: return "Критично"
        }
    }

    var color: Color {
        switch self {
        case .low: return Color(red: 0.10, green: 0.78, blue: 0.48)
        case .medium: return Color(red: 1.0, green: 0.62, blue: 0.14)
        case .high: return Color(red: 0.95, green: 0.25, blue: 0.32)
        }
    }
}

private struct AnalysisMedicalSheetMode: Identifiable {
    let id = UUID()
    let category: AnalysisMedicalCategory
    var item: AnalysisMedicalItem? = nil
}

private enum AnalysisClinicalStatus {
    case urgent
    case watch
    case stable
    case incomplete

    var title: String {
        switch self {
        case .urgent: return "Есть красный флаг"
        case .watch: return "Есть факторы для внимания"
        case .stable: return "Критичных сигналов нет"
        case .incomplete: return "Заполните медкарту"
        }
    }

    var subtitle: String {
        switch self {
        case .urgent: return "Bagyt видит сигнал, который лучше не игнорировать. Это не диагноз, но повод оценить состояние внимательнее."
        case .watch: return "Есть повторяющиеся симптомы или факторы риска. Сводка поможет понять, что обсудить с врачом."
        case .stable: return "Медицинская карта и журнал выглядят спокойно. Продолжайте фиксировать важные изменения."
        case .incomplete: return "Добавьте аллергии, лекарства и диагнозы. Тогда анализ станет медицинским, а не просто набором метрик."
        }
    }

    var icon: String {
        switch self {
        case .urgent: return "exclamationmark.triangle.fill"
        case .watch: return "eye.fill"
        case .stable: return "checkmark.shield.fill"
        case .incomplete: return "square.and.pencil"
        }
    }

    var color: Color {
        switch self {
        case .urgent: return Color(red: 0.95, green: 0.25, blue: 0.32)
        case .watch: return Color(red: 1.0, green: 0.62, blue: 0.14)
        case .stable: return Color(red: 0.10, green: 0.78, blue: 0.48)
        case .incomplete: return Color(red: 0.055, green: 0.647, blue: 0.914)
        }
    }
}

private enum AnalysisAlertSeverity: Equatable {
    case critical
    case attention
    case info
    case stable

    var title: String {
        switch self {
        case .critical: return "важно"
        case .attention: return "наблюдать"
        case .info: return "заполнить"
        case .stable: return "спокойно"
        }
    }

    var color: Color {
        switch self {
        case .critical: return Color(red: 0.95, green: 0.25, blue: 0.32)
        case .attention: return Color(red: 1.0, green: 0.62, blue: 0.14)
        case .info: return Color(red: 0.055, green: 0.647, blue: 0.914)
        case .stable: return Color(red: 0.10, green: 0.78, blue: 0.48)
        }
    }
}

private struct AnalysisClinicalAlert: Identifiable {
    let id: String
    let severity: AnalysisAlertSeverity
    let icon: String
    let title: String
    let text: String

    init(
        id: String? = nil,
        severity: AnalysisAlertSeverity,
        icon: String,
        title: String,
        text: String
    ) {
        self.id = id ?? "\(severity.title)-\(icon)-\(title)"
        self.severity = severity
        self.icon = icon
        self.title = title
        self.text = text
    }
}

private struct AnalysisRiskFactor: Identifiable {
    let id: String
    let icon: String
    let title: String
    let text: String
    let color: Color

    init(
        id: String? = nil,
        icon: String,
        title: String,
        text: String,
        color: Color
    ) {
        self.id = id ?? "\(icon)-\(title)"
        self.icon = icon
        self.title = title
        self.text = text
        self.color = color
    }
}

private struct AnalysisVisitChecklistItem: Hashable {
    let title: String
    let text: String
    let isReady: Bool
}

private struct AnalysisPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.70), value: configuration.isPressed)
    }
}

#Preview {
    AnalysisView()
        .environmentObject(AppState())
        .environmentObject(LanguageManager())
}
