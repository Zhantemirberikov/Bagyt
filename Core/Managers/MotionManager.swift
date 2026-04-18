import Foundation
import CoreMotion
import SwiftUI
import Combine

/// Управляет гироскопом для реалистичного параллакс-эффекта
final class MotionManager: ObservableObject {
    private let manager = CMMotionManager()

    @Published var pitch: Double = 0
    @Published var roll: Double = 0

    /// Максимальное значение угла (радианы ~25°)
    private let maxTilt: Double = 0.45
    /// Насколько сильно отклонения влияют на смещение (чем больше, тем плавнее)
    private let motionSensitivity: Double = 0.65
    /// Скорость обновления гироскопа
    private let updateInterval = 1.0 / 60.0

    init() {
        startUpdates()
    }

    private func startUpdates() {
        guard manager.isDeviceMotionAvailable else { return }

        manager.deviceMotionUpdateInterval = updateInterval
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self = self, let motion = motion else { return }

            // Ограничиваем диапазон наклона, чтобы не было экстремальных значений
            let clampedPitch = max(min(motion.attitude.pitch, self.maxTilt), -self.maxTilt)
            let clampedRoll  = max(min(motion.attitude.roll,  self.maxTilt), -self.maxTilt)

            // Гладкое движение с лёгкой пружиной (натуральная инерция)
            withAnimation(.interpolatingSpring(stiffness: 80, damping: 10)) {
                self.pitch = clampedPitch * self.motionSensitivity
                self.roll  = clampedRoll * self.motionSensitivity
            }
        }
    }

    deinit {
        manager.stopDeviceMotionUpdates()
    }
}
