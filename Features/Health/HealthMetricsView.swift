import SwiftUI

struct HealthMetricsView: View {

    @State private var steps: Double = 0
    @State private var heartRate: Double = 0
    @State private var calories: Double = 0
    @State private var distance: Double = 0

    @State private var score: Int = 0
    @State private var insight: String = "Analyzing your health..."

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                header

                scoreCard

                ringsSection

                heartCard

                insightsCard

                statsGrid

                Spacer()
            }
            .padding()
        }
        .onAppear {
            loadData()
        }
    }

    // MARK: - HEADER
    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Your Health")
                    .font(.largeTitle)
                    .bold()

                Text("Today")
                    .foregroundColor(.gray)
            }

            Spacer()
        }
    }

    // MARK: - SCORE CARD (🔥 WOW блок)
    private var scoreCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 10) {
                Text("Health Score")
                    .foregroundColor(.white.opacity(0.8))

                Text("\(score)")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.white)

                Text(scoreText)
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding()
        }
        .frame(height: 160)
    }

    private var scoreText: String {
        switch score {
        case 80...100: return "🔥 Excellent"
        case 60...79: return "💪 Good"
        case 40...59: return "🙂 Average"
        default: return "⚠️ Needs attention"
        }
    }

    // MARK: - RINGS
    private var ringsSection: some View {
        HStack(spacing: 20) {
            ring(title: "Steps", value: steps, max: 10000, color: .blue)
            ring(title: "Calories", value: calories, max: 800, color: .orange)
            ring(title: "Distance", value: distance, max: 10, color: .green)
        }
    }

    private func ring(title: String, value: Double, max: Double, color: Color) -> some View {
        let progress = min(value / max, 1)

        return VStack {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.2), value: progress)

                Text("\(Int(value))")
                    .font(.caption)
                    .bold()
            }
            .frame(width: 80, height: 80)

            Text(title)
                .font(.caption)
        }
    }

    // MARK: - HEART CARD
    private var heartCard: some View {
        HStack {
            Image(systemName: "heart.fill")
                .foregroundColor(.red)
                .font(.largeTitle)
                .scaleEffect(1.1)
                .animation(.easeInOut(duration: 0.8).repeatForever(), value: heartRate)

            VStack(alignment: .leading) {
                Text("Heart Rate")
                Text("\(Int(heartRate)) bpm")
                    .font(.title)
                    .bold()
            }

            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }

    // MARK: - AI INSIGHT (🔥 killer feature)
    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 10) {

            Text("AI Insight")
                .font(.headline)

            Text(insight)
                .foregroundColor(.white)

        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [.black, .gray],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
    }

    // MARK: - GRID
    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(), GridItem()]) {
            stat("Steps", "\(Int(steps))")
            stat("Calories", "\(Int(calories)) kcal")
            stat("Distance", String(format: "%.2f km", distance))
            stat("Heart", "\(Int(heartRate)) bpm")
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack {
            Text(title).font(.caption).foregroundColor(.gray)
            Text(value).bold()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    // MARK: - LOAD
    private func loadData() {
        HealthManager.shared.requestAccess { success in
            if success {
                HealthManager.shared.fetchSteps { steps = $0; updateScore() }
                HealthManager.shared.fetchHeartRate { heartRate = $0; updateInsight() }
                HealthManager.shared.fetchCalories { calories = $0; updateScore() }
                HealthManager.shared.fetchDistance { distance = $0; updateScore() }
            }
        }
    }

    // MARK: - SCORE LOGIC
    private func updateScore() {
        let stepScore = min(steps / 10000, 1) * 40
        let calorieScore = min(calories / 800, 1) * 30
        let distanceScore = min(distance / 10, 1) * 30

        score = Int(stepScore + calorieScore + distanceScore)
    }

    // MARK: - AI INSIGHT
    private func updateInsight() {
        if heartRate > 100 {
            insight = "⚠️ Your heart rate is elevated. Consider resting."
        } else if steps < 2000 {
            insight = "🚶 You are not very active today. Try walking more."
        } else {
            insight = "💪 You're doing great today. Keep it up!"
        }
    }
}
