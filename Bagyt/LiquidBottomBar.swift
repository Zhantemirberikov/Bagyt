import SwiftUI

/// LiquidBottomBar: uses LiquidGlassContainer and provides:
/// - icons row
/// - soft pill behind selected icon
/// - "lens" follow effect when user drags across icons
/// - orb is NOT drawn inside Canvas to avoid artifacts
struct LiquidBottomBar: View {
    @Binding var selectedTab: Int
    var safeAreaBottom: CGFloat
    var keyboardHeight: CGFloat
    var panelHeight: CGFloat = 94

    // lens state (touch position in bar coordinate)
    @State private var lensPos: CGPoint? = nil
    @GestureState private var isDragging: Bool = false

    var body: some View {
        ZStack {
            // Liquid glass background with icons stacked as content
            LiquidGlassContainer(cornerRadius: 28, panelHeight: panelHeight) {
                // icons row (we keep icon + label)
                HStack {
                    tabItem(icon: "house.fill", label: "Home", index: 0)
                    Spacer()
                    tabItem(icon: "book.fill", label: "Journal", index: 1)
                    Spacer(minLength: 90) // orb space
                    tabItem(icon: "waveform.path.ecg", label: "Metrics", index: 2)
                    Spacer()
                    tabItem(icon: "gearshape.fill", label: "Profile", index: 3)
                }
                .padding(.horizontal, 40)
                .frame(height: panelHeight)
                .contentShape(Rectangle()) // gesture area
                .gesture(dragGesture) // detect drag over icons
            }
            .frame(height: panelHeight)
            .padding(.horizontal, 12)
            .padding(.bottom, safeAreaBottom > 0 ? safeAreaBottom : 8)

            // soft pill positioned dynamically behind selected icon
            GeometryReader { geo in
                let gW = geo.size.width
                let leftPadding: CGFloat = 40 + 12
                let usable = gW - leftPadding * 2
                let slot = usable / 5.0
                let centerX: CGFloat = {
                    switch selectedTab {
                    case 0: return leftPadding + slot * 0.5
                    case 1: return leftPadding + slot * 1.5
                    case 2: return leftPadding + slot * 3.5
                    case 3: return leftPadding + slot * 4.5
                    default: return leftPadding + slot * 0.5
                    }
                }()

                LiquidSoftPill()
                    .frame(width: 90, height: 46)
                    .offset(x: centerX - gW/2, y: -8)
                    .animation(.easeInOut(duration: 0.18), value: selectedTab)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 12)

            // LENS overlay: subtle radial highlight that follows finger
            if let p = lensPos {
                LensView(center: p, radius: 64)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .animation(.easeInOut, value: lensPos)
            }
        }
    }

    // Drag gesture: update lensPos while dragging; on end, clear after small delay
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                // convert global to local coordinate: value.location is local to the view that received gesture
                self.lensPos = value.location
                // optional: detect which index is under finger and change selection
                // We'll map x into index using same formula as pill
                // but we need view width - we don't have it here; simple heuristic:
                // change selection only on horizontal thresholds
                // -> we keep it simple: update selectedTab based on approximate slots
            }
            .onEnded { _ in
                // small delay then clear lens
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    withAnimation(.easeOut(duration: 0.18)) { self.lensPos = nil }
                }
            }
    }

    // button builder
    private func tabItem(icon: String, label: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.spring()) { selectedTab = index }
        }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(selectedTab == index ? .white : .white.opacity(0.65))
                Text(label)
                    .font(.caption2)
                    .foregroundColor(selectedTab == index ? .white : .white.opacity(0.65))
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
        }
    }
}

/// LensView - simple radial highlight and soft magnify impression
struct LensView: View {
    var center: CGPoint
    var radius: CGFloat = 64

    var body: some View {
        GeometryReader { geo in
            // place circle at `center`, using absolute coordinates inside GeometryReader
            let offsetX = center.x - geo.size.width / 2
            let offsetY = center.y - geo.size.height / 2

            Circle()
                .fill(
                    RadialGradient(stops: [
                        .init(color: Color.white.opacity(0.22), location: 0),
                        .init(color: Color.white.opacity(0.06), location: 0.35),
                        .init(color: Color.clear, location: 1)
                    ], center: .center, startRadius: 0, endRadius: radius)
                )
                .frame(width: radius*2, height: radius*2)
                .blur(radius: 6)
                .offset(x: offsetX, y: offsetY - 6) // slight upward shift for more natural light
                .blendMode(.screen)
        }
        .compositingGroup()
        .allowsHitTesting(false)
    }
}