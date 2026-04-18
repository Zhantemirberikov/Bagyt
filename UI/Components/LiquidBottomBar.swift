// LiquidBottomBar.swift
// Bagyt — Liquid glass bottom bar, LiquidGlass + container + soft pill + bar

import SwiftUI

/// LiquidBottomBar: uses LiquidGlassContainer and provides:
/// - icons row
/// - soft pill behind selected icon
/// - small lens follow effect while dragging
/// - orb is NOT drawn inside Canvas (should be rendered above from HomeView)
struct LiquidBottomBar: View {
    @Binding var selectedTab: Int
    var safeAreaBottom: CGFloat
    var keyboardHeight: CGFloat
    var panelHeight: CGFloat = 94
    @Binding var showAssistant: Bool

    // lens state (touch position in bar coordinate)
    @State private var lensPos: CGPoint? = nil

    var body: some View {
        ZStack {
            // Liquid glass background with icons stacked as content
            LiquidGlassContainer(cornerRadius: 28, panelHeight: panelHeight) {
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
                .contentShape(Rectangle())
                .gesture(dragGesture(in: panelHeight))
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

    // Drag gesture updates lensPos and approximate selectedTab
    private func dragGesture(in panelHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                self.lensPos = value.location
                // approximate selection based on x: map to index
                if let width = value.startLocation.x as CGFloat? {
                    // We need geometry width - but we can approximate by using value.location and a default layout:
                    // Better approach: compute using available width from screen
                    let screenW = UIScreen.main.bounds.width
                    let leftPadding: CGFloat = 40 + 12
                    let usable = screenW - leftPadding * 2
                    let slot = usable / 5.0
                    let x = value.location.x - leftPadding
                    if x > 0 {
                        // map to slots: 0,1, skip orb slot, 2-> index2, 3-> index3
                        let rawSlot = Int((x + slot * 0.5) / slot)
                        let mapped: Int
                        switch rawSlot {
                        case 0: mapped = 0
                        case 1: mapped = 1
                        case 2: mapped = 2 // could be orb slot — harmless
                        case 3: mapped = 2
                        case 4: mapped = 3
                        default: mapped = selectedTab
                        }
                        if mapped != selectedTab {
                            withAnimation(.spring()) { selectedTab = mapped }
                        }
                    }
                }
            }
            .onEnded { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    withAnimation(.easeOut) { self.lensPos = nil }
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

// LensView - radial highlight
struct LensView: View {
    var center: CGPoint
    var radius: CGFloat = 64

    var body: some View {
        GeometryReader { geo in
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
                .offset(x: offsetX, y: offsetY - 6)
                .blendMode(.screen)
        }
        .compositingGroup()
        .allowsHitTesting(false)
    }
}

// MARK: - LiquidGlass (Canvas metaballs) + container + soft pill
public struct LiquidGlass: View {
    public var cornerRadius: CGFloat = 28
    public var panelHeight: CGFloat = 94
    public var tint: Color = .white
    public var baseTintOpacity: Double = 0.03

    @State private var blobOffsets: [CGSize] = [
        CGSize(width: -30, height: -6),
        CGSize(width: 0, height: -4),
        CGSize(width: 30, height: -8)
    ]

    public init(cornerRadius: CGFloat = 28, panelHeight: CGFloat = 94) {
        self.cornerRadius = cornerRadius
        self.panelHeight = panelHeight
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                Canvas { context, size in
                    // apply threshold + blur to merge blobs (metaballs)
                    context.addFilter(.alphaThreshold(min: 0.45))
                    context.addFilter(.blur(radius: 22))

                    let centerX = size.width / 2
                    let centerY = size.height / 2
                    let radii: [CGFloat] = [56, 70, 52]

                    for i in 0..<radii.count {
                        let cx = centerX + blobOffsets[i].width
                        let cy = centerY + blobOffsets[i].height
                        let r = radii[i]
                        let rect = CGRect(x: cx - r, y: cy - r, width: r*2, height: r*2)
                        let p = Path(ellipseIn: rect)
                        context.fill(p, with: .color(.white.opacity(0.9)))
                    }
                }
                .mask(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .frame(height: panelHeight)
                )
                .frame(height: panelHeight)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint.opacity(baseTintOpacity))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.08), .white.opacity(0.01)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .blendMode(.screen)
                        .opacity(0.95)
                )
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: -4)
                .onAppear {
                    withAnimation(Animation.easeInOut(duration: 3.8).repeatForever(autoreverses: true)) {
                        blobOffsets = [
                            CGSize(width: -22, height: -6),
                            CGSize(width: 0, height: 0),
                            CGSize(width: 20, height: -10)
                        ]
                    }
                }
            }
        }
        .frame(height: panelHeight)
    }
}

public struct LiquidGlassContainer<Content: View>: View {
    private let cornerRadius: CGFloat
    private let panelHeight: CGFloat
    private let content: () -> Content

    public init(cornerRadius: CGFloat = 28, panelHeight: CGFloat = 94, @ViewBuilder content: @escaping () -> Content) {
        self.cornerRadius = cornerRadius
        self.panelHeight = panelHeight
        self.content = content
    }

    public var body: some View {
        ZStack {
            LiquidGlass(cornerRadius: cornerRadius, panelHeight: panelHeight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            // content on top
            content()
                .frame(height: panelHeight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .compositingGroup()
    }
}

public struct LiquidSoftPill: View {
    public var width: CGFloat = 90
    public var height: CGFloat = 46

    public init(width: CGFloat = 90, height: CGFloat = 46) {
        self.width = width
        self.height = height
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .frame(width: width, height: height)
            .blur(radius: 0.3)
            .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 2)
            .allowsHitTesting(false)
    }
}
