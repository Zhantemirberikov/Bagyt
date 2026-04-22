import Foundation
import Combine

final class HealthViewModel: ObservableObject {

    @Published var steps: Double = 0
    @Published var heartRate: Double = 0
    @Published var calories: Double = 0
    @Published var distance: Double = 0

    @Published var sleep: Double = 0
    @Published var hrv: Double = 0
    @Published var stressLevel: String = "Normal"

    @Published var score: Int = 0
    @Published var insight: String = "Analyzing your health..."

    @Published var isLoading = false

    // MARK: - LOAD
    func loadData() {
        isLoading = true

        HealthManager.shared.requestAccess { success in
            DispatchQueue.main.async {
                if success {
                    self.fetchAll()
                } else {
                    self.isLoading = false
                }
            }
        }
    }

    private func fetchAll() {
        let group = DispatchGroup()

        group.enter()
        HealthManager.shared.fetchSteps {
            self.steps = $0
            group.leave()
        }

        group.enter()
        HealthManager.shared.fetchHeartRate {
            self.heartRate = $0
            group.leave()
        }

        group.enter()
        HealthManager.shared.fetchCalories {
            self.calories = $0
            group.leave()
        }

        group.enter()
        HealthManager.shared.fetchDistance {
            self.distance = $0
            group.leave()
        }

        group.enter()
        HealthManager.shared.fetchSleep {
            self.sleep = $0
            group.leave()
        }

        group.enter()
        HealthManager.shared.fetchHRV {
            self.hrv = $0
            group.leave()
        }

        group.notify(queue: .main) {
            self.calculateScore()
            self.calculateStress()
            self.generateInsight()
            self.isLoading = false
        }
    }

    // MARK: - SCORE
    private func calculateScore() {
        let stepScore = min(steps / 10000, 1) * 30
        let calorieScore = min(calories / 800, 1) * 25
        let distanceScore = min(distance / 10, 1) * 20
        let sleepScore = min(sleep / 8, 1) * 25

        score = Int(stepScore + calorieScore + distanceScore + sleepScore)
    }

    // MARK: - STRESS (🔥 важная логика)
    private func calculateStress() {
        if hrv < 30 || heartRate > 95 {
            stressLevel = "🔴 High"
        } else if hrv < 50 {
            stressLevel = "🟠 Medium"
        } else {
            stressLevel = "🟢 Low"
        }
    }

    // MARK: - AI INSIGHT
    private func generateInsight() {

        if sleep < 5 {
            insight = "😴 You slept too little. Recovery is needed."
        }
        else if stressLevel.contains("High") {
            insight = "⚠️ High stress detected. Try breathing exercises."
        }
        else if steps < 2000 {
            insight = "🚶 Low activity. A short walk will help."
        }
        else {
            insight = "💪 You're in great shape today."
        }
    }
}
