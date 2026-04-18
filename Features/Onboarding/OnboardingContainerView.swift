//
//  OnboardingContainerView.swift
//  Bagyt
//
//  Created by Жантемир Бериков on 10.11.2025.
//

import SwiftUI

struct OnboardingContainerView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lang: LanguageManager

    @State private var currentPage = 0
    @State private var animateHeart = false
    @StateObject private var motion = MotionManager()

    @State private var showLanguagePicker = false

    private let pages = [
        OnboardingPage(
            imageName: "record",
            title: [
                .kk: "Сіздің денсаулық деректеріңіз — қауіпсіз жерде",
                .ru: "Ваши медицинские данные в безопасности",
                .en: "Your health data is safe"
            ],
            description: [
                .kk: "Біз сіздің медициналық жазбаларыңызды қауіпсіз және ыңғайлы сақтауға көмектесеміз.",
                .ru: "Мы помогаем хранить ваши медицинские записи безопасно и удобно.",
                .en: "We help you store your medical records safely and conveniently."
            ]
        ),
        OnboardingPage(
            imageName: "safe",
            title: [
                .kk: "AI сіздің әл-ауқатыңызды қолдайды",
                .ru: "AI поддерживает ваше благополучие",
                .en: "AI supports your wellbeing"
            ],
            description: [
                .kk: "Bagyt қолданбасы сіздің көңіл-күйіңіз бен денсаулығыңызды бақылауға көмектеседі.",
                .ru: "Bagyt помогает отслеживать настроение и состояние здоровья.",
                .en: "Bagyt helps you track your mood and health state."
            ]
        ),
        OnboardingPage(
            imageName: "docs",
            title: [
                .kk: "Барлығы бір жерде",
                .ru: "Всё в одном месте",
                .en: "Everything in one place"
            ],
            description: [
                .kk: "Сіздің деректеріңіз, жазбаларыңыз және ұсыныстарыңыз бір қосымшада сақталады.",
                .ru: "Ваши данные, записи и рекомендации хранятся в одном приложении.",
                .en: "Your data, notes, and recommendations are stored in one app."
            ]
        )
    ]

    var body: some View {
        ZStack {
            // фон
            AnimatedGradientBackground()

            if appState.isLoggedIn {
                HomeView()
                    .environmentObject(appState)
                    .environmentObject(lang)
                    .transition(.opacity.combined(with: .scale))
            } else {
                VStack {
                    // Верхняя панель: название + язык (кнопка, открывает confirmationDialog)
                    HStack {
                        Text("Bagyt")
                            .font(.largeTitle.bold())
                            .foregroundColor(.primary)
                            .shadow(color: .black.opacity(0.1), radius: 1)
                            .overlay(
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.red.opacity(0.8))
                                    .opacity(animateHeart ? 0.9 : 0.6)
                                    .scaleEffect(animateHeart ? 1.25 : 1.0)
                                    .offset(x: 55, y: -5)
                                    .animation(
                                        .easeInOut(duration: 0.9)
                                            .repeatForever(autoreverses: true),
                                        value: animateHeart
                                    )
                            )

                        Spacer()

                        // Надёжная кнопка выбора языка (confirmationDialog)
                        Button {
                            showLanguagePicker = true
                        } label: {
                            HStack(spacing: 6) {
                                Text(lang.currentLanguage.flag)
                                Text(lang.currentLanguage.title)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(12)
                        }
                        .confirmationDialog(
                            Text("Select language"),
                            isPresented: $showLanguagePicker,
                            titleVisibility: .visible
                        ) {
                            ForEach(AppLanguage.allCases, id: \.self) { code in
                                Button("\(code.flag)  \(code.title)") {
                                    withAnimation(.easeInOut) {
                                        lang.changeLanguage(to: code)
                                    }
                                }
                            }
                            Button("Cancel", role: .cancel) { }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .onAppear { animateHeart = true }

                    Spacer()

                    // контент: TabView с параллаксом
                    ZStack {
                        TabView(selection: $currentPage) {
                            ForEach(0..<pages.count, id: \.self) { index in
                                VStack(spacing: 24) {
                                    // Параллакс-изображение (реагирует на motion.pitch/roll)
                                    GeometryReader { geo in
                                        Image(pages[index].imageName)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 220)
                                            .rotation3DEffect(
                                                .degrees(motion.pitch * 20),
                                                axis: (x: 1, y: 0, z: 0)
                                            )
                                            .rotation3DEffect(
                                                .degrees(motion.roll * 20),
                                                axis: (x: 0, y: -1, z: 0)
                                            )
                                            .offset(
                                                x: motion.roll * 50,
                                                y: motion.pitch * 30
                                            )
                                            .shadow(color: .black.opacity(0.15),
                                                    radius: 10,
                                                    x: motion.roll * 20,
                                                    y: motion.pitch * 15)
                                            .animation(.easeOut(duration: 0.12), value: motion.pitch)
                                            .animation(.easeOut(duration: 0.12), value: motion.roll)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    }
                                    .frame(height: 220)

                                    Text(pages[index].title[lang.currentLanguage] ?? "")
                                        .font(.title2.bold())
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.primary)

                                    Text(pages[index].description[lang.currentLanguage] ?? "")
                                        .font(.subheadline)
                                        .foregroundColor(.primary.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 24)
                                }
                                .tag(index)
                            }

                            // Последняя страница — логин (фон отключён, заголовок отключён)
                            LoginView(showBackground: false, showHeader: false)
                                .environmentObject(appState)
                                .environmentObject(lang)
                                .tag(pages.count)
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: currentPage == pages.count ? .never : .always))
                        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                        // отключаем анимацию TabView при программном изменении selection
                        .transaction { transaction in
                            transaction.animation = nil
                        }
                        // небольшая анимация для визуальных изменений (но не для смены страницы)
                        .animation(.easeInOut(duration: 0.25), value: currentPage)

                        // Стрелка — быстрый переход (короткая анимация)
                        if currentPage < pages.count {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Button {
                                        // Быстро: чуть заметная анимация — 0.12 сек
                                        withAnimation(.linear(duration: 0.12)) {
                                            currentPage += 1
                                        }
                                    } label: {
                                        Image(systemName: "chevron.right.circle.fill")
                                            .font(.system(size: 36))
                                            .foregroundColor(.black.opacity(0.85))
                                            .shadow(radius: 2)
                                    }
                                    .padding(.trailing, 20)
                                    .padding(.bottom, 40)
                                }
                            }
                            .transition(.opacity)
                        }
                    }
                    Spacer(minLength: 30)
                }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: appState.isLoggedIn)
    }
}

#Preview {
    OnboardingContainerView()
        .environmentObject(AppState())
        .environmentObject(LanguageManager())
}
