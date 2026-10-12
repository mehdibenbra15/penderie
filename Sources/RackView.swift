import SwiftUI

struct RackView: View {
    var rack: Rack

    var body: some View {
        let frames = rack.frames()
        let rodLeft = rack.rodLeft

        ZStack(alignment: .topLeading) {
            if !rack.items.isEmpty {
                Rod(width: Metrics.rodRight - rodLeft)
                    .offset(x: rodLeft)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            ForEach(Array(rack.items.enumerated()), id: \.element.id) { i, shot in
                let f = frames[i]
                HangingShot(
                    shot: shot,
                    cardHeight: f.height,
                    hovered: rack.hovered == shot.id,
                    closeHot: rack.closeHot && rack.hovered == shot.id,
                    dragging: rack.dragging == shot.id
                )
                .rotationEffect(
                    .degrees(rack.swing[shot.id] ?? 0),
                    anchor: UnitPoint(x: 0.5, y: Metrics.hookCentre / (Metrics.cardTopInHanger + f.height))
                )
                .offset(x: f.minX, y: Metrics.rodY - Metrics.hookCentre)
                .zIndex(rack.hovered == shot.id ? 1000 : Double(i))
                .transition(.asymmetric(
                    insertion: .offset(y: -Metrics.windowSize.height),
                    removal: .scale(scale: 0.35, anchor: .top).combined(with: .opacity)
                ))
            }

            if rack.showsClear {
                ClearButton(hot: rack.clearHot)
                    .frame(width: rack.clearRect.width, height: rack.clearRect.height)
                    .offset(x: rack.clearRect.minX, y: rack.clearRect.minY)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .zIndex(2000)
            }
        }
        .frame(width: Metrics.windowSize.width, height: Metrics.windowSize.height, alignment: .topLeading)
    }
}

// MARK: - Rod

private let chrome = LinearGradient(
    stops: [
        .init(color: Color(white: 0.98), location: 0),
        .init(color: Color(white: 0.84), location: 0.35),
        .init(color: Color(white: 0.58), location: 0.75),
        .init(color: Color(white: 0.74), location: 1),
    ],
    startPoint: .top, endPoint: .bottom
)

private let graphite = LinearGradient(
    colors: [Color(white: 0.34), Color(white: 0.14)],
    startPoint: .leading, endPoint: .trailing
)

private struct Rod: View {
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            bracket.offset(x: 10)
            bracket.offset(x: width - 24)
            Capsule()
                .fill(chrome)
                .overlay(Capsule().strokeBorder(.black.opacity(0.18), lineWidth: 0.5))
                .frame(width: width, height: 7)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1.5)
                .offset(y: Metrics.rodY - 3.5)
        }
        .frame(width: width, height: Metrics.rodY + 8, alignment: .topLeading)
    }

    private var bracket: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1.5).fill(chrome).frame(width: 14, height: 3)
            Rectangle().fill(chrome).frame(width: 4, height: Metrics.rodY - 2)
                .overlay(Rectangle().stroke(.black.opacity(0.12), lineWidth: 0.5))
        }
        .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
    }
}

// MARK: - Hanger + card

private struct HangerShape: Shape {
    let barWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let c = CGPoint(x: cx, y: Metrics.hookCentre)
        let r: CGFloat = 5
        var p = Path()

        // Hook: from the neck, round over the rod, ending just past it.
        let steps = 28
        for s in 0...steps {
            let a = CGFloat(90 - Double(s) * 255 / Double(steps)) * .pi / 180
            let pt = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
            s == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }

        // Neck and shoulders, with a little sag in the curve.
        let neck = CGPoint(x: cx, y: c.y + r)
        let top = CGPoint(x: cx, y: c.y + r + 4)
        let barY: CGFloat = 30
        let l = CGPoint(x: cx - barWidth / 2, y: barY)
        let rt = CGPoint(x: cx + barWidth / 2, y: barY)
        p.move(to: neck)
        p.addLine(to: top)
        p.addQuadCurve(to: rt, control: CGPoint(x: cx + barWidth * 0.22, y: barY - 9))
        p.addLine(to: l)
        p.addQuadCurve(to: top, control: CGPoint(x: cx - barWidth * 0.22, y: barY - 9))
        return p
    }
}

private struct HangingShot: View {
    let shot: Shot
    let cardHeight: CGFloat
    let hovered: Bool
    let closeHot: Bool
    let dragging: Bool

    private let w = Metrics.cardWidth
    private var barWidth: CGFloat { w * 0.74 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            card
                .offset(y: Metrics.cardTopInHanger)

            HangerShape(barWidth: barWidth)
                .stroke(chrome, style: StrokeStyle(lineWidth: 2.3, lineCap: .round, lineJoin: .round))
                .shadow(color: .black.opacity(0.35), radius: 0.8, y: 0.8)
                .frame(width: w, height: 34)

            clip.offset(x: w / 2 - barWidth * 0.40 - 4, y: 29)
            clip.offset(x: w / 2 + barWidth * 0.40 - 4, y: 29)

            if hovered && !dragging {
                CloseButton(hot: closeHot)
                    .offset(x: -9, y: Metrics.cardTopInHanger - 9)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }
        .frame(width: w, height: Metrics.cardTopInHanger + cardHeight, alignment: .topLeading)
        .opacity(dragging ? 0.18 : 1)
    }

    private var clip: some View {
        VStack(spacing: 0) {
            Rectangle().fill(chrome).frame(width: 1.6, height: 4)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(graphite)
                .overlay(
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(.white.opacity(0.35)).frame(width: 1).offset(x: -1.6)
                )
                .frame(width: 8, height: 13)
        }
        .frame(width: 8)
        .shadow(color: .black.opacity(0.35), radius: 1.2, y: 1)
    }

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        return Image(nsImage: shot.thumb)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fill)
            .frame(width: w, height: cardHeight)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(shape)
            .overlay(shape.strokeBorder(.white.opacity(0.35), lineWidth: 0.6))
            .overlay(shape.stroke(.black.opacity(0.12), lineWidth: 0.5))
            .overlay(alignment: .center) {
                if shot.isVideo {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .rackGlass(in: Circle())
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if hovered && !dragging {
                    Text(age)
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .rackGlass(in: Capsule())
                        .padding(6)
                        .transition(.opacity)
                }
            }
            .shadow(color: .black.opacity(hovered ? 0.34 : 0.24), radius: hovered ? 14 : 7, y: hovered ? 9 : 4)
            .scaleEffect(hovered ? 1.04 : 1, anchor: .top)
    }

    private var age: String {
        let s = Int(Date().timeIntervalSince(shot.added))
        switch s {
        case ..<45: return "now"
        case ..<3600: return "\(max(1, s / 60)) min"
        case ..<86400: return "\(s / 3600) h"
        default: return "\(s / 86400) d"
        }
    }
}

// MARK: - Buttons

private struct CloseButton: View {
    let hot: Bool

    var body: some View {
        Image(systemName: "xmark")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.primary)
            .frame(width: 22, height: 22)
            .rackGlass(in: Circle())
            .scaleEffect(hot ? 1.15 : 1)
            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
    }
}

private struct ClearButton: View {
    let hot: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
            Text("Clear").font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .rackGlass(in: Capsule(), tint: hot ? .red.opacity(0.35) : nil)
        .scaleEffect(hot ? 1.06 : 1)
    }
}

// MARK: - Glass

enum RackStyle {
    /// Liquid Glass samples the live screen behind the window, so it can't show up in offscreen
    /// renders (like the README demo). This swaps in a flat look for those.
    static var flatGlass = false
}

extension View {
    @ViewBuilder
    func rackGlass<S: Shape>(in shape: S, tint: Color? = nil) -> some View {
        if RackStyle.flatGlass {
            background {
                shape.fill(Color(white: 0.97).opacity(0.92))
                    .overlay(shape.fill(tint ?? .clear))
                    .overlay(shape.stroke(.black.opacity(0.1), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
            }
            .environment(\.colorScheme, .light)
        } else {
            glassEffect(tint.map { Glass.regular.tint($0).interactive() } ?? .regular.interactive(), in: shape)
        }
    }
}
