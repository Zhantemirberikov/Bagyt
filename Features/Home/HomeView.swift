//
//  HomeView.swift
//  Bagyt
//

import SwiftUI
import Combine
import UIKit

struct HomeView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lang: LanguageManager

    @State private var selectedTab: Int   = 0
    @State private var pulse              = false
    @State private var showProfileSheet   = false
    @State private var showAssistantSheet = false
    @State private var showMoodSheet      = false   // ← новый
    @State private var appear             = false
    @State private var selectedMood: Int? = nil
    @State private var bgPhase            = false
    @State private var orbRing1           = false
    @State private var orbRing2           = false
    @State private var orbRing3           = false
    @State private var orbBob             = false
    @State private var orbOffset: CGSize  = .zero
    @State private var orbIsPressed       = false

    private let accent  = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)
    private let moodGold = Color(red: 1.0, green: 0.65, blue: 0.10)

    var body: some View {
        ZStack(alignment: .bottom) {

            // ── Фон ──
            ZStack {
                AnimatedGradientBackground()
                Circle()
                    .fill(RadialGradient(colors: [accent.opacity(0.30), .clear], center: .center, startRadius: 0, endRadius: 180))
                    .frame(width: 340, height: 340)
                    .offset(x: bgPhase ? -70 : 50, y: bgPhase ? -160 : -100)
                    .blur(radius: 45)
                    .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: bgPhase)
                Circle()
                    .fill(RadialGradient(colors: [accent2.opacity(0.25), .clear], center: .center, startRadius: 0, endRadius: 150))
                    .frame(width: 280, height: 280)
                    .offset(x: bgPhase ? 120 : 50, y: bgPhase ? 80 : 180)
                    .blur(radius: 40)
                    .animation(.easeInOut(duration: 9).repeatForever(autoreverses: true).delay(1.5), value: bgPhase)
                Circle()
                    .fill(RadialGradient(colors: [accent.opacity(0.20), .clear], center: .center, startRadius: 0, endRadius: 120))
                    .frame(width: 220, height: 220)
                    .offset(x: bgPhase ? -60 : 40, y: bgPhase ? 420 : 320)
                    .blur(radius: 35)
                    .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true).delay(0.8), value: bgPhase)
            }
            .ignoresSafeArea()

            // ── Контент ──
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                ZStack {
                    switch selectedTab {
                    case 0: homeContent
                    case 1: JournalView().environmentObject(appState).environmentObject(lang)
                    case 2: HealthMetricsView()
                    case 3: SettingsView().environmentObject(appState).environmentObject(lang)
                    default: homeContent
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Color.clear.frame(height: 104)
            }

            // ── Bottom Bar ──
            liquidBottomBar
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationBarHidden(true)
        .onAppear {
            pulse = true
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) { appear = true }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) { bgPhase = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { startOrbRings() }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true).delay(0.3)) { orbBob = true }
        }
        .sheet(isPresented: $showAssistantSheet) {
            ChatView().environmentObject(appState).environmentObject(lang)
        }
        .sheet(isPresented: $showMoodSheet) {   // ← новый sheet
            MoodView()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(greetingText())
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
                    .lineLimit(1).minimumScaleFactor(0.75)
                Text(localized("subtitle"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.55, blue: 0.65))
            }
            Spacer()
            Button { showProfileSheet.toggle() } label: {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                        .shadow(color: accent.opacity(0.35), radius: 8, x: 0, y: 3)
                    Text(initials(for: appState.userName))
                        .font(.system(size: 15, weight: .black)).foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showProfileSheet) {
                SettingsView().environmentObject(appState).environmentObject(lang)
            }
        }
    }

    // MARK: - Home Content

    private var homeContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                healthIndexCard
                metricsRow
                moodCard
                insightCard
                quickActions
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 16)
        }
    }

    // MARK: - Health Index Card

    private var healthIndexCard: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: accent.opacity(0.38), radius: 18, x: 0, y: 8)
            Circle().fill(Color.white.opacity(0.08)).frame(width: 150, height: 150).offset(x: 40, y: -50)
            Circle().fill(Color.white.opacity(0.05)).frame(width: 90, height: 90).offset(x: -20, y: 60)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ИНДЕКС ЗДОРОВЬЯ")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(.white.opacity(0.78)).tracking(0.9)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("87").font(.system(size: 60, weight: .black)).foregroundColor(.white)
                        Text("/100").font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white.opacity(0.65)).padding(.bottom, 6)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill").font(.system(size: 10))
                        Text("Отлично").font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white).padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Color.white.opacity(0.22)).clipShape(Capsule())
                }
                Spacer()
                ZStack {
                    Circle().stroke(Color.white.opacity(0.18), lineWidth: 7).frame(width: 70, height: 70)
                    Circle().trim(from: 0, to: appear ? 0.87 : 0)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .frame(width: 70, height: 70).rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 1.4).delay(0.3), value: appear)
                    Image(systemName: "heart.fill").font(.system(size: 20)).foregroundColor(.white)
                        .scaleEffect(pulse ? 1.12 : 0.9)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                }
            }.padding(22)
        }
        .opacity(appear ? 1 : 0).offset(y: appear ? 0 : 18)
        .animation(.easeOut(duration: 0.5).delay(0.05), value: appear)
    }

    // MARK: - Metrics Row

    private var metricsRow: some View {
        HStack(spacing: 10) {
            metricCard(icon: "figure.walk",    value: "8 420", unit: "шаг",    color: accent,                               progress: 0.84)
            metricCard(icon: "heart.fill",      value: "68",    unit: "уд/мин", color: Color(red:0.95,green:0.25,blue:0.25), progress: 0.68)
            metricCard(icon: "moon.stars.fill", value: "7.2",   unit: "ч сна",  color: Color(red:0.55,green:0.35,blue:1.0),  progress: 0.90)
        }
        .opacity(appear ? 1 : 0).offset(y: appear ? 0 : 18)
        .animation(.easeOut(duration: 0.5).delay(0.10), value: appear)
    }

    private func metricCard(icon: String, value: String, unit: String, color: Color, progress: Double) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().stroke(color.opacity(0.12), lineWidth: 4).frame(width: 44, height: 44)
                Circle().trim(from: 0, to: appear ? CGFloat(progress) : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 44, height: 44).rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.0).delay(0.5), value: appear)
                Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundColor(color)
            }
            VStack(spacing: 1) {
                Text(value).font(.system(size: 17, weight: .black)).foregroundColor(Color(red:0.06,green:0.09,blue:0.16))
                Text(unit).font(.system(size: 9, weight: .bold)).foregroundColor(Color(red:0.5,green:0.63,blue:0.72)).tracking(0.3)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14).background(whiteCard)
    }

    // MARK: - Mood Card

    private var moodCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Как вы себя чувствуете?")
                    .font(.system(size: 15, weight: .bold)).foregroundColor(Color(red:0.06,green:0.09,blue:0.16))
                Spacer()
                if let m = selectedMood {
                    Text(moodLabel(m)).font(.system(size: 12, weight: .semibold)).foregroundColor(accent).transition(.opacity)
                }
            }
            HStack(spacing: 0) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { selectedMood = i }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(selectedMood == i ? moodColor(i).opacity(0.12) : Color(red:0.93,green:0.97,blue:1.0))
                                    .frame(width: selectedMood == i ? 50 : 42, height: selectedMood == i ? 50 : 42)
                                    .overlay(Circle().strokeBorder(selectedMood == i ? moodColor(i) : Color.clear, lineWidth: 1.5))
                                Text(moodEmoji(i)).font(.system(size: selectedMood == i ? 26 : 20))
                            }
                            .animation(.spring(response: 0.3), value: selectedMood)
                            Circle().fill(selectedMood == i ? moodColor(i) : Color(red:0.85,green:0.92,blue:0.96)).frame(width: 5, height: 5)
                        }.frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(18).background(whiteCard)
        .opacity(appear ? 1 : 0).offset(y: appear ? 0 : 18)
        .animation(.easeOut(duration: 0.5).delay(0.15), value: appear)
    }

    // MARK: - Insight Card

    private var insightCard: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                Text("⭐").font(.system(size: 20))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("ИНСАЙТ ДНЯ").font(.system(size: 10, weight: .bold)).foregroundColor(accent).tracking(1.0)
                Text("Сегодня ваш пульс на 8% ниже среднего — хороший знак восстановления организма.")
                    .font(.system(size: 14, weight: .medium)).foregroundColor(Color(red:0.3,green:0.42,blue:0.52))
                    .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18).background(whiteCard)
        .opacity(appear ? 1 : 0).offset(y: appear ? 0 : 18)
        .animation(.easeOut(duration: 0.5).delay(0.20), value: appear)
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(spacing: 10) {
            // AI Ассистент
            Button {
                showAssistantSheet = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(LinearGradient(colors: [accent.opacity(0.15), accent2.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 46, height: 46)
                        Image(systemName: "brain.head.profile").font(.system(size: 20, weight: .semibold)).foregroundColor(accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localized("ai_recommendations")).font(.system(size: 15, weight: .bold)).foregroundColor(Color(red:0.06,green:0.09,blue:0.16))
                        Text(localized("ai_text")).font(.system(size: 12, weight: .medium)).foregroundColor(Color(red:0.4,green:0.55,blue:0.65))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundColor(Color(red:0.7,green:0.8,blue:0.85))
                }
                .padding(16).background(whiteCard)
            }
            .buttonStyle(ScaleButtonStyle())

            // Показатели + Журнал
            HStack(spacing: 10) {
                Button { withAnimation(.spring(response: 0.3)) { selectedTab = 2 } } label: {
                    actionMini(icon: "waveform.path.ecg", color: accent, title: localized("health_metrics"), sub: "Данные")
                }.buttonStyle(ScaleButtonStyle())
                Button { withAnimation(.spring(response: 0.3)) { selectedTab = 1 } } label: {
                    actionMini(icon: "book.fill", color: Color(red:0.55,green:0.35,blue:1.0), title: localized("journal"), sub: "Записи")
                }.buttonStyle(ScaleButtonStyle())
            }

            // Настроение — открывает MoodView
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showMoodSheet = true
            } label: {
                actionMini(
                    icon: "face.smiling.fill",
                    color: moodGold,
                    title: "Настроение",
                    sub: "Трекер самочувствия"
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .opacity(appear ? 1 : 0).offset(y: appear ? 0 : 18)
        .animation(.easeOut(duration: 0.5).delay(0.25), value: appear)
    }

    private func actionMini(icon: String, color: Color, title: String, sub: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(color.opacity(0.12)).frame(width: 38, height: 38)
                Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .bold)).foregroundColor(Color(red:0.06,green:0.09,blue:0.16)).lineLimit(1)
                Text(sub).font(.system(size: 11, weight: .medium)).foregroundColor(Color(red:0.5,green:0.63,blue:0.72))
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(Color(red:0.7,green:0.8,blue:0.85))
        }
        .padding(14).frame(maxWidth: .infinity).background(whiteCard)
    }

    private var whiteCard: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(0.88))
            .shadow(color: accent.opacity(0.10), radius: 12, x: 0, y: 4)
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.white.opacity(0.9), lineWidth: 1))
    }

    // MARK: - Liquid Glass Bottom Bar

    private var liquidBottomBar: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(Color.white.opacity(0.55)))
                .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.65), .clear], startPoint: .top, endPoint: .center)))
                .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Color.white.opacity(0.75), lineWidth: 1))
                .shadow(color: accent.opacity(0.12), radius: 20, x: 0, y: -6)
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: -2)

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    tabBtn(icon: "house.fill",        label: localized("home"),    index: 0).frame(maxWidth: .infinity)
                    tabBtn(icon: "book.fill",          label: localized("journal"), index: 1).frame(maxWidth: .infinity)
                    Color.clear.frame(width: 80)
                    tabBtn(icon: "waveform.path.ecg", label: localized("metrics"), index: 2).frame(maxWidth: .infinity)
                    // ← Профиль заменён на Настроение
                    moodTabBtn.frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 8)
                .padding(.top, 14)
                Color.clear.frame(height: 28)
            }

            liveOrb.offset(y: -38)
        }
        .frame(height: 104)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // ── Кнопка Настроение в баре ──
    private var moodTabBtn: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showMoodSheet = true
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "face.smiling.fill")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(Color(red:0.55,green:0.67,blue:0.75))
                Text("Настроение")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(red:0.55,green:0.67,blue:0.75))
            }
        }
    }

    // MARK: - Live Orb

    private var liveOrb: some View {
        ZStack {
            Circle().stroke(accent.opacity(0.15), lineWidth: 1.5).frame(width: 110, height: 110)
                .scaleEffect(orbRing3 ? 1.0 : 0.55).opacity(orbRing3 ? 0.0 : 0.7)
                .animation(.easeOut(duration: 1.9).repeatForever(autoreverses: false).delay(0.6), value: orbRing3)
            Circle().stroke(accent.opacity(0.22), lineWidth: 2).frame(width: 90, height: 90)
                .scaleEffect(orbRing2 ? 1.0 : 0.55).opacity(orbRing2 ? 0.0 : 0.85)
                .animation(.easeOut(duration: 1.9).repeatForever(autoreverses: false).delay(0.3), value: orbRing2)
            Circle().stroke(accent.opacity(0.32), lineWidth: 2.5).frame(width: 74, height: 74)
                .scaleEffect(orbRing1 ? 1.0 : 0.55).opacity(orbRing1 ? 0.0 : 1.0)
                .animation(.easeOut(duration: 1.9).repeatForever(autoreverses: false), value: orbRing1)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring()) { showAssistantSheet = true }
            } label: {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(red:0.03,green:0.50,blue:0.78), Color(red:0.01,green:0.42,blue:0.68)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 92, height: 92)
                        .shadow(color: accent.opacity(0.55), radius: 20, x: 0, y: 8)
                        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 3)
                    LottieView(animationName: "aiaia").frame(width: 92, height: 92).clipShape(Circle())
                    Circle().strokeBorder(
                        LinearGradient(colors: [Color.white.opacity(0.55), accent.opacity(0.25)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 2).frame(width: 92, height: 92)
                }
                .scaleEffect(orbIsPressed ? 0.93 : (pulse ? 1.04 : 0.98))
                .offset(y: orbBob ? -4 : 3)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: orbBob)
            }
            .buttonStyle(PlainButtonStyle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in orbOffset = CGSize(width: v.translation.width * 0.22, height: v.translation.height * 0.22); orbIsPressed = true }
                    .onEnded { _ in
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.interpolatingSpring(stiffness: 180, damping: 18)) { orbOffset = .zero; orbIsPressed = false }
                    }
            )
        }
        .offset(x: orbOffset.width, y: orbOffset.height)
    }

    private func startOrbRings() {
        orbRing1 = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { orbRing2 = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { orbRing3 = true }
    }

    // MARK: - Tab Button

    private func tabBtn(icon: String, label: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { selectedTab = index }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if selectedTab == index {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(accent.opacity(0.12)).frame(width: 38, height: 28)
                    }
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: selectedTab == index ? .bold : .regular))
                        .foregroundColor(selectedTab == index ? accent : Color(red:0.55,green:0.67,blue:0.75))
                        .scaleEffect(selectedTab == index ? 1.08 : 1.0)
                        .animation(.spring(response: 0.3), value: selectedTab)
                }
                Text(label)
                    .font(.system(size: 10, weight: selectedTab == index ? .bold : .medium))
                    .foregroundColor(selectedTab == index ? accent : Color(red:0.55,green:0.67,blue:0.75))
            }
        }
    }

    // MARK: - Helpers

    private func greetingText() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let g: String
        switch hour {
        case 5..<12:  g = localized("good_morning")
        case 12..<17: g = localized("good_afternoon")
        case 17..<22: g = localized("good_evening")
        default:      g = localized("good_night")
        }
        if let name = appState.userName, !name.isEmpty { return "\(g), \(name) 👋" }
        return "\(g)! 👋"
    }

    private func initials(for name: String?) -> String {
        let s = (name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? name! : "U"
        return s.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    private func moodEmoji(_ v: Int) -> String { ["😩","😕","😐","😊","🤩"][v-1] }
    private func moodLabel(_ v: Int) -> String  { ["Плохо","Так себе","Нормально","Хорошо","Отлично"][v-1] }
    private func moodColor(_ v: Int) -> Color {
        [Color(red:0.95,green:0.25,blue:0.25), Color(red:1.0,green:0.55,blue:0.1),
         accent, Color(red:0.1,green:0.78,blue:0.48), Color(red:0.55,green:0.35,blue:1.0)][v-1]
    }

    private func localized(_ key: String) -> String {
        let l = lang.currentLanguage
        switch key {
        case "good_morning":   return ["kk":"Қайырлы таң","ru":"Доброе утро","en":"Good morning"][l.rawValue]!
        case "good_afternoon": return ["kk":"Қайырлы күн","ru":"Добрый день","en":"Good afternoon"][l.rawValue]!
        case "good_evening":   return ["kk":"Қайырлы кеш","ru":"Добрый вечер","en":"Good evening"][l.rawValue]!
        case "good_night":     return ["kk":"Қайырлы түн","ru":"Доброй ночи","en":"Good night"][l.rawValue]!
        case "subtitle":
            switch l { case .kk: return "AI серіктесіңіз дайын 🩺"; case .ru: return "Ваш AI-помощник готов 🩺"; default: return "Your AI assistant is ready 🩺" }
        case "home":    return ["kk":"Басты","ru":"Главная","en":"Home"][l.rawValue]!
        case "journal": return ["kk":"Журнал","ru":"Журнал","en":"Journal"][l.rawValue]!
        case "metrics": return ["kk":"Метрики","ru":"Метрики","en":"Metrics"][l.rawValue]!
        case "profile": return ["kk":"Профиль","ru":"Профиль","en":"Profile"][l.rawValue]!
        case "ai_recommendations":
            switch l { case .kk: return "AI кеңестері"; case .ru: return "AI ассистент"; default: return "AI Assistant" }
        case "ai_text":
            switch l { case .kk: return "Сұрақтарыңызды қойыңыз"; case .ru: return "Задайте любой вопрос"; default: return "Ask anything" }
        case "health_metrics": return ["kk":"Метрики","ru":"Показатели","en":"Metrics"][l.rawValue]!
        default: return key
        }
    }
}

// MARK: - ScaleButtonStyle

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
        .environmentObject(LanguageManager())
}
