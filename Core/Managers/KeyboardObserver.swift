import SwiftUI
import Combine
import UIKit

final class KeyboardObserver: ObservableObject {
    @Published var keyboardHeight: CGFloat = 0
    private var cancellables = Set<AnyCancellable>()

    init() {
        let willShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
        let willChange = NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)

        Publishers.Merge(willShow, willChange)
            .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }
            .map { frame -> CGFloat in
                // Высота видимой части клавиатуры относительно экрана
                return UIScreen.main.bounds.height - frame.origin.y
            }
            .merge(with: willHide.map { _ in CGFloat(0) })
            .receive(on: RunLoop.main)
            .sink { [weak self] raw in
                // Обрезаем отрицательные и мелкие значения
                self?.keyboardHeight = max(raw, 0)
            }
            .store(in: &cancellables)
    }

    deinit {
        cancellables.forEach { $0.cancel() }
    }
}
