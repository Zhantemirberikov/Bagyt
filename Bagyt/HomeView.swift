import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome back, Zhan! 🌞")
                .font(.title)
                .bold()
            
            Text("This is your personal dashboard.")
                .foregroundColor(.gray)
            
            Button("Logout") {
                // позже добавим логику выхода
            }
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}
