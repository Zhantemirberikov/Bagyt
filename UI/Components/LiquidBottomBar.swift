import SwiftUI

struct LiquidBottomBar: View {
    @Binding var selectedTab: Int
    var safeAreaBottom: CGFloat
    var keyboardHeight: CGFloat
    var panelHeight: CGFloat = 90
    @Binding var showAssistant: Bool

    @State private var dragX: CGFloat? = nil
    @State private var isDragging = false

    private let outerInset: CGFloat = 16
    private let innerInset: CGFloat = 16
    private let orbGapWidth: CGFloat = 92
    private let cornerRadius: CGFloat = 36

    var body: some View {
        GeometryReader { geo in
            let bottomInset = safeAreaBottom > 0 ? safeAreaBottom : 8
            let totalWidth = geo.size.width
            let contentWidth = totalWidth - (outerInset * 2) - (innerInset * 2)
            let slotWidth = max((contentWidth - orbGapWidth) / 4, 52)

            let centers = tabCenters(totalWidth: totalWidth, slotWidth: slotWidth)
            let activeX = centers[selectedTab] ?? centers[0] ?? totalWidth / 2
            let lensX = dragX ?? activeX

            ZStack(alignment: .bottomLeading) {
                
                // 1. НАСТОЯЩЕЕ IOS СТЕКЛО (Base Frosted Glass)
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.8), .white.opacity(0.1)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 10)

                // 2. ЖИДКАЯ ЛИНЗА (Хроматическая аберрация)
                Capsule(style: .continuous)
                    .fill(.thinMaterial)
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.9), .white.opacity(0.2)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    // Эффект "цветного преломления"
                    .background(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.red.opacity(0.5), Color.blue.opacity(0.4), Color.green.opacity(0.5), Color.purple.opacity(0.4)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 4
                            )
                            .blur(radius: 5)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
                    .frame(width: slotWidth + 12, height: 52)
                    .position(x: lensX, y: panelHeight / 2)
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: selectedTab)

                // 3. ИКОНКИ
                HStack(spacing: 0) {
                    barItem(icon: "house.fill", label: "Home", index: 0, slotWidth: slotWidth, centerX: centers[0] ?? 0, lensX: lensX)
                    barItem(icon: "book.fill", label: "Journal", index: 1, slotWidth: slotWidth, centerX: centers[1] ?? 0, lensX: lensX)

                    Color.clear
                        .frame(width: orbGapWidth, height: panelHeight)

                    barItem(icon: "waveform.path.ecg", label: "Metrics", index: 2, slotWidth: slotWidth, centerX: centers[2] ?? 0, lensX: lensX)
                    barItem(icon: "face.smiling.fill", label: "Mood", index: 3, slotWidth: slotWidth, centerX: centers[3] ?? 0, lensX: lensX)
                }
                .padding(.horizontal, innerInset)
                .frame(height: panelHeight)
            }
            .padding(.horizontal, outerInset)
            .padding(.bottom, bottomInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        isDragging = true
                        dragX = min(max(value.location.x, outerInset + 10), totalWidth - outerInset - 10)

                        if let next = nearestTab(to: dragX ?? value.location.x, centers: centers),
                           next != selectedTab {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                selectedTab = next
                            }
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.easeOut(duration: 0.22)) {
                            dragX = nil
                            isDragging = false
                        }
                    }
            )
        }
        .frame(height: panelHeight + (safeAreaBottom > 0 ? safeAreaBottom : 8))
    }

    private func tabCenters(totalWidth: CGFloat, slotWidth: CGFloat) -> [Int: CGFloat] {
        let start = outerInset + innerInset
        return [
            0: start + slotWidth * 0.5,
            1: start + slotWidth * 1.5,
            2: start + slotWidth * 2 + orbGapWidth + slotWidth * 0.5,
            3: start + slotWidth * 2 + orbGapWidth + slotWidth * 1.5
        ]
    }

    private func nearestTab(to x: CGFloat, centers: [Int: CGFloat]) -> Int? {
        centers.min(by: { abs($0.value - x) < abs($1.value - x) })?.key
    }

    private func barItem(
        icon: String,
        label: String,
        index: Int,
        slotWidth: CGFloat,
        centerX: CGFloat,
        lensX: CGFloat
    ) -> some View {
        let distance = abs(centerX - lensX)
        let liquidBoost = max(0, 1 - (distance / 90))
        let selectedBoost = selectedTab == index ? 1.0 : 0.0

        let iconScale = 1 + liquidBoost * 0.15 + selectedBoost * 0.05
        let yLift = liquidBoost * 8 + selectedBoost * 2
        
        let iconOpacity = selectedTab == index ? 1.0 : 0.45 + liquidBoost * 0.3
        let labelOpacity = selectedTab == index ? 0.9 : 0.35 + liquidBoost * 0.3

        return Button {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                selectedTab = index
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: selectedTab == index ? .bold : .medium))
                    .foregroundColor(Color.black.opacity(iconOpacity))
                    .scaleEffect(iconScale)
                    .offset(y: -yLift)

                Text(label)
                    .font(.system(size: 10, weight: selectedTab == index ? .bold : .medium))
                    .foregroundColor(Color.black.opacity(labelOpacity))
                    .scaleEffect(1 + liquidBoost * 0.05)
                    .offset(y: -yLift * 0.4)
            }
            .frame(width: slotWidth, height: panelHeight)
            .animation(.spring(response: 0.25, dampingFraction: 0.78), value: lensX)
            .animation(.spring(response: 0.25, dampingFraction: 0.78), value: selectedTab)
        }
        .buttonStyle(.plain)
    }
}
