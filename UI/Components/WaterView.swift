//
//  WaterView.swift
//  Bagyt
//

import SwiftUI

struct WaterView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var consumed: Double  = 400
    @State private var goal: Double      = 2400
    @State private var selectedAmount    = 3
    @State private var wavePhase1        = 0.0
    @State private var wavePhase2        = 0.0
    @State private var appear            = false
    @State private var logBounce         = false
    @State private var minusBounce       = false
    @State private var ripple            = false   // пульс при добавлении

    private let amounts  = [50, 100, 150, 200, 250, 300, 350, 400, 450, 500, 600, 700, 800, 900, 1000]
    private let maxLimit = 5000.0

    private var progress: Double { min(max(consumed / goal, 0), 1.0) }
    private var percent:  Double { progress * 100 }

    private let accent  = Color(red: 0.055, green: 0.647, blue: 0.914)
    private let accent2 = Color(red: 0.024, green: 0.714, blue: 0.831)
    private let bg      = Color(red: 0.878, green: 0.949, blue: 0.992)

    var body: some View {
        ZStack {
            // ── Фон ──
            LinearGradient(
                colors: [bg, Color(red: 0.930, green: 0.972, blue: 0.998), bg],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                closeButton
                titleBlock
                mainZone
                bottomPanel
            }
        }
        .onAppear {
            appear = true
            withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) { wavePhase1 = 1.0 }
            withAnimation(.linear(duration: 3.1).repeatForever(autoreverses: false)) { wavePhase2 = 1.0 }
        }
    }

    // MARK: - Close

    private var closeButton: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                ZStack {
                    Circle().fill(Color.white.opacity(0.80)).frame(width: 40, height: 40)
                        .shadow(color: accent.opacity(0.10), radius: 6, x: 0, y: 2)
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(red: 0.35, green: 0.48, blue: 0.60))
                }
            }
            .padding(.trailing, 20).padding(.top, 16)
        }
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(spacing: 3) {
            Text("ВОДА")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(accent.opacity(0.65))
                .tracking(1.8)
            Text("Трекер потребления")
                .font(.system(size: 20, weight: .black))
                .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.16))
        }
        .padding(.top, 2).padding(.bottom, 6)
    }

    // MARK: - Main Zone (бутылка + статистика)

    private var mainZone: some View {
        ZStack {
            // Статистика — сзади
            statsBlock

           
            // Бутылка поверх
            BottleView(
                progress: progress,
                wavePhase1: wavePhase1,
                wavePhase2: wavePhase2,
                accent: accent,
                accent2: accent2
            )
            .frame(width: 290, height: 520)
            .scaleEffect(1.28)
            .shadow(color: accent.opacity(0.22), radius: 28, x: 10, y: 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, -20)
            .offset(y: -20)
            .opacity(appear ? 1 : 0)
            .scaleEffect(appear ? 1 : 0.88)
            .animation(.easeOut(duration: 0.7).delay(0.15), value: appear)
            .allowsHitTesting(false)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Stats

    private var statsBlock: some View {
        VStack(alignment: .trailing, spacing: 0) {
            // Процент + Цель
            HStack(alignment: .top, spacing: 20) {
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f%%", percent).replacingOccurrences(of: ".", with: ","))
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(LinearGradient(colors: [accent, accent2],
                                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4), value: consumed)
                    Text("Выполнено")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 0.45, green: 0.57, blue: 0.67))
                }
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1fл", goal / 1000).replacingOccurrences(of: ".", with: ","))
                        .font(.system(size: 30, weight: .black))
                        .foregroundColor(Color(red: 0.12, green: 0.18, blue: 0.28))
                    Text("Цель")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 0.45, green: 0.57, blue: 0.67))
                }
                .padding(.trailing, 20)
            }

            Spacer()

            // БОЛЬШОЕ ЧИСЛО — контрастное, тёмно-голубое
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(consumed))")
                    .font(.system(size: 128, weight: .black, design: .default))
                    .tracking(-4)
                    // Тёмно-синий градиент — контрастный, красивый
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.04, green: 0.38, blue: 0.72),
                                Color(red: 0.024, green: 0.60, blue: 0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.35)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4), value: consumed)
                    // blendMode даёт эффект "сквозь воду"
                    .blendMode(.plusDarker)
                    .shadow(color: accent.opacity(0.12), radius: 0, x: 0, y: 2)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Spacer()
                    Text("мл")
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(LinearGradient(colors: [accent, accent2],
                                                        startPoint: .leading, endPoint: .trailing))
                    Text("выпито сегодня")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 0.45, green: 0.57, blue: 0.67))
                        .padding(.bottom, 1)
                }
                .padding(.trailing, 20)
            }
            .padding(.bottom, 100)
        }
        .opacity(appear ? 1 : 0)
        .animation(.easeOut(duration: 0.7).delay(0.2), value: appear)
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(Color.white.opacity(0.68)))
                .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.72), .clear], startPoint: .top, endPoint: .center)))
                .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Color.white.opacity(0.85), lineWidth: 1))
                .shadow(color: accent.opacity(0.10), radius: 24, x: 0, y: -8)
                .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 14) {
                // − количество +
                HStack(alignment: .center) {
                    minusBtn
                    Spacer()
                    amountDisplay
                    Spacer()
                    plusBtn
                }
                .padding(.horizontal, 24).padding(.top, 20)

                amountSlider.padding(.horizontal, 24)

                addButton
                    .padding(.horizontal, 24).padding(.bottom, 36)
            }
        }
        .frame(maxHeight: 278)
    }

    private var minusBtn: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                consumed = max(consumed - Double(amounts[selectedAmount]), 0)
                minusBounce = true
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { minusBounce = false }
        } label: {
            ZStack {
                Circle()
                    .fill(Color(red:0.95,green:0.25,blue:0.25).opacity(0.08))
                    .frame(width: 46, height: 46)
                    .overlay(Circle().strokeBorder(Color(red:0.95,green:0.25,blue:0.25).opacity(0.22), lineWidth: 1.5))
                Image(systemName: "minus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(red:0.95,green:0.25,blue:0.25))
            }
        }
        .scaleEffect(minusBounce ? 0.88 : 1.0)
        .animation(.spring(response: 0.3), value: minusBounce)
    }

    private var plusBtn: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                consumed = min(consumed + Double(amounts[selectedAmount]), maxLimit)
                logBounce = true
            }
            triggerRipple()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { logBounce = false }
        } label: {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.10))
                    .frame(width: 46, height: 46)
                    .overlay(Circle().strokeBorder(accent.opacity(0.22), lineWidth: 1.5))
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(accent)
            }
        }
        .scaleEffect(logBounce ? 0.88 : 1.0)
        .animation(.spring(response: 0.3), value: logBounce)
    }

    private var amountDisplay: some View {
        HStack(alignment: .lastTextBaseline, spacing: 3) {
            Text("\(amounts[selectedAmount])")
                .font(.system(size: 46, weight: .black))
                .foregroundStyle(LinearGradient(colors: [accent, accent2],
                                                startPoint: .leading, endPoint: .trailing))
                .contentTransition(.numericText())
            Text("мл")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(accent.opacity(0.70))
                .padding(.bottom, 3)
        }
    }

    private var addButton: some View {
        Button {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                consumed = min(consumed + Double(amounts[selectedAmount]), maxLimit)
                logBounce = true
            }
            triggerRipple()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { logBounce = false }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "drop.fill").font(.system(size: 16, weight: .semibold))
                Text("Добавить").font(.system(size: 17, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(Capsule())
            .shadow(color: accent.opacity(0.42), radius: 16, x: 0, y: 7)
            .overlay(
                // Блик сверху
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.25), Color.white.opacity(0.0)],
                        startPoint: .top, endPoint: .center
                    ))
            )
        }
        .scaleEffect(logBounce ? 0.96 : 1.0)
        .animation(.spring(response: 0.3), value: logBounce)
    }

    // MARK: - Amount Slider

    private var amountSlider: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(0..<amounts.count, id: \.self) { i in
                    let val  = amounts[i]
                    let sel  = i == selectedAmount
                    let past = i < selectedAmount
                    let showLabel = [50, 250, 450, 600, 800, 1000].contains(val)

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { selectedAmount = i }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 6) {
                            Spacer(minLength: 0)
                            Capsule()
                                .fill(
                                    sel
                                    ? LinearGradient(colors: [accent, accent2], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(
                                        colors: [past ? accent.opacity(0.48) : accent.opacity(0.14),
                                                 past ? accent.opacity(0.48) : accent.opacity(0.14)],
                                        startPoint: .top, endPoint: .bottom)
                                )
                                .frame(width: sel ? 16 : 13, height: 16 + CGFloat(i) * 2.4)
                                .animation(.spring(response: 0.3), value: selectedAmount)
                                .shadow(color: sel ? accent.opacity(0.38) : .clear, radius: 5, x: 0, y: 2)

                            Text(showLabel ? "\(val)" : " ")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(showLabel
                                                 ? Color(red: 0.55, green: 0.67, blue: 0.75)
                                                 : .clear)
                                .fixedSize()
                        }
                    }
                }
            }
            .padding(.vertical, 8).padding(.horizontal, 4)
        }
        .frame(height: 78)
    }

    private func triggerRipple() {
        ripple = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation { ripple = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { ripple = false }
        }
    }
}

// MARK: - BottleView

struct BottleView: View {
    let progress: Double
    let wavePhase1: Double
    let wavePhase2: Double
    let accent: Color
    let accent2: Color

    var body: some View {
        ZStack {
            // Вода — чуть прозрачнее (opacity понижен)
            WaterLayer(
                progress: progress,
                wavePhase1: wavePhase1,
                wavePhase2: wavePhase2,
                accent: accent,
                accent2: accent2
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.top, 135)
            .padding(.bottom, 100)
            .padding(.leading, 70)
            .padding(.trailing, 65)
            .opacity(0.82)   // ← чуть прозрачнее — видна структура бутылки
            .animation(.spring(response: 1.0, dampingFraction: 0.75), value: progress)

            Image("bagyt_bottle")
                .resizable()
                .scaledToFit()
        }
        .frame(width: 290, height: 520)
    }
}

// MARK: - WaterLayer

struct WaterLayer: View {
    let progress: Double
    let wavePhase1: Double
    let wavePhase2: Double
    let accent: Color
    let accent2: Color

    var body: some View {
        GeometryReader { geo in
            let w    = geo.size.width
            let h    = geo.size.height
            let fillH = h * CGFloat(progress)
            let topY  = h - fillH

            ZStack(alignment: .top) {
                // Основная вода
                Rectangle()
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.40, green: 0.82, blue: 0.97).opacity(0.90),   // верх — светлее
                            Color(red: 0.05, green: 0.60, blue: 0.92).opacity(0.95)    // низ — насыщеннее
                        ],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: w, height: fillH)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                // Блик внутри воды
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.18))
                    .frame(width: w * 0.15, height: fillH * 0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 8)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, fillH * 0.05)

                // Волна 1
                WaveShape2(phase: wavePhase1, amplitude: 9, frequency: 1.0)
                    .fill(Color(red: 0.15, green: 0.70, blue: 0.95).opacity(0.55))
                    .frame(width: w, height: 28)
                    .offset(y: topY - 16)

                // Волна 2
                WaveShape2(phase: wavePhase2, amplitude: 6, frequency: 0.78)
                    .fill(Color.white.opacity(0.28))
                    .frame(width: w, height: 22)
                    .offset(y: topY - 8)
            }
            .frame(width: w, height: h)
        }
    }
}

// MARK: - WaveShape2

struct WaveShape2: Shape {
    var phase: Double
    var amplitude: Double = 6
    var frequency: Double = 1.0

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w   = Double(rect.width)
        let h   = rect.height
        let mid = h / 2
        p.move(to: CGPoint(x: 0, y: mid))
        stride(from: 0.0, through: w, by: 2.0).forEach { x in
            let angle = (x / w + phase) * Double.pi * 2.0 * frequency
            let y = mid + CGFloat(sin(angle) * amplitude)
            p.addLine(to: CGPoint(x: CGFloat(x), y: y))
        }
        p.addLine(to: CGPoint(x: rect.width, y: h))
        p.addLine(to: CGPoint(x: 0, y: h))
        p.closeSubpath()
        return p
    }
}

#Preview {
    WaterView()
}
