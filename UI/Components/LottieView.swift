//
//  LottieView.swift
//  Bagyt
//
//  Created by Жантемир Бериков on 21.11.2025.
//
import SwiftUI
import Lottie
import UIKit

/// Универсальный SwiftUI wrapper для Lottie (Lottie 4.x)
/// Пример использования:
/// LottieView(animationName: "aiaiai", loopMode: .loop, playAutomatically: true)
struct LottieView: UIViewRepresentable {
    let animationName: String
    var loopMode: LottieLoopMode = .loop
    var contentMode: UIView.ContentMode = .scaleAspectFit
    var playAutomatically: Bool = true
    var speed: CGFloat = 1.0
    var backgroundBehavior: LottieBackgroundBehavior = .pauseAndRestore

    // MARK: - makeUIView
    func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: .zero)
        container.backgroundColor = .clear

        // Попробуем создать LottieAnimationView через имя анимации (bundle)
        let animationView = LottieAnimationView(name: animationName)
        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.contentMode = contentMode
        animationView.loopMode = loopMode
        animationView.animationSpeed = speed
        animationView.backgroundBehavior = backgroundBehavior

        // optional: make it accessible
        animationView.isAccessibilityElement = true
        animationView.accessibilityLabel = animationName

        container.addSubview(animationView)

        // constraints — пусть растягивается по контейнеру
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: container.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        // сохранить в context для обновлений
        context.coordinator.animationView = animationView

        if playAutomatically {
            animationView.play()
        }

        return container
    }

    // MARK: - updateUIView
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let animationView = context.coordinator.animationView else { return }

        // обновляем параметры при изменении свойства View
        animationView.contentMode = contentMode
        animationView.loopMode = loopMode
        animationView.animationSpeed = speed
        animationView.backgroundBehavior = backgroundBehavior

        // если имя анимации поменялось — перезагрузим анимацию
        if context.coordinator.currentName != animationName {
            context.coordinator.currentName = animationName
            animationView.animation = LottieAnimation.named(animationName)
            if playAutomatically {
                animationView.play()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(currentName: animationName)
    }

    // MARK: - Coordinator
    class Coordinator {
        var animationView: LottieAnimationView?
        var currentName: String

        init(currentName: String) {
            self.currentName = currentName
        }
    }
}

// MARK: - Доп. утилиты (вьюмодификаторы)
extension LottieView {
    /// Быстрый способ получить view с фиксированным размером:
    /// LottieView(...).frame(width: 92, height: 92)
    func sized(_ size: CGSize) -> some View {
        self.frame(width: size.width, height: size.height)
    }
}
