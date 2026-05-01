import SwiftUI

struct OnboardingPage: Identifiable {
    let id = UUID()
    let imageName: String
    let title: [AppLanguage: String]
    let description: [AppLanguage: String]
}

struct OnboardingView: View {
    @EnvironmentObject var lang: LanguageManager
    @State private var currentPage = 0

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
        NavigationStack {
            VStack {
                HStack {
                    Text("Bagyt")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color("AccentColor"))

                    Spacer()

                    Menu {
                        ForEach(AppLanguage.allCases, id: \.self) { langCode in
                            Button(action: {
                                lang.changeLanguage(to: langCode)
                            }) {
                                Text("\(langCode.flag) \(langCode.title)")
                            }
                        }
                    } label: {
                        Text("\(lang.currentLanguage.flag) \(lang.currentLanguage.title)")
                            .padding(8)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)

                Spacer()

                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        VStack(spacing: 24) {
                            Image(pages[index].imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)

                            Text(pages[index].title[lang.currentLanguage] ?? "")
                                .font(.title2)
                                .bold()
                                .multilineTextAlignment(.center)

                            Text(pages[index].description[lang.currentLanguage] ?? "")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle())

                NavigationLink(destination: LoginView()) {
                    Text(lang.localized(currentPage == pages.count - 1 ? "Start" : "Next"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    }
                })

                Spacer().frame(height: 20)
            }
        }
    }
}
