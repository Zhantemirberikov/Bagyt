//
//  HeartbeatHaptics.swift
//  Bagyt
//
//  Created by Жантемир Бериков on 20.04.2026.
//
//
//  HeartbeatHaptics.swift
//  Bagyt
//
//  Стук сердца через CoreHaptics — лёгкий, ненавязчивый
//

import CoreHaptics
import UIKit

final class HeartbeatHaptics {
    static let shared = HeartbeatHaptics()

    private var engine: CHHapticEngine?
    private var player: CHHapticPatternPlayer?
    private var timer: Timer?
    private var isRunning = false

    private init() { prepare() }

    // MARK: - Подготовка движка

    private func prepare() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            engine?.stoppedHandler = { [weak self] _ in
                self?.isRunning = false
            }
            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            try engine?.start()
        } catch {
            print("HeartbeatHaptics: engine init failed — \(error)")
        }
    }

    // MARK: - Старт

    func start() {
        guard !isRunning else { return }
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        isRunning = true

        // Если движок остановился — перезапускаем
        try? engine?.start()

        // Первый удар сразу, потом каждые 1.1 сек
        beat()
        timer = Timer.scheduledTimer(withTimeInterval: 1.1, repeats: true) { [weak self] _ in
            self?.beat()
        }
    }

    // MARK: - Стоп

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        player = nil
        engine?.stop()
    }

    // MARK: - Один удар сердца (lub-dub)

    private func beat() {
        guard let engine = engine else { return }

        do {
            // LUB — сильный первый удар
            let lub = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.85),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.30)
                ],
                relativeTime: 0
            )

            // DUB — слабый второй удар через 0.18 сек
            let dub = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.45),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.20)
                ],
                relativeTime: 0.18
            )

            let pattern = try CHHapticPattern(events: [lub, dub], parameters: [])
            let newPlayer = try engine.makePlayer(with: pattern)
            try newPlayer.start(atTime: CHHapticTimeImmediate)
            player = newPlayer

        } catch {
            print("HeartbeatHaptics: beat failed — \(error)")
        }
    }
}
