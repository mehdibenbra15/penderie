// Renders the README demo (docs/demo.gif, docs/demo.mp4, docs/hero.png) offscreen.
// Everything on screen is fake: a mock desktop, mock windows and mock screenshots,
// driving the real Rack model and RackView. Run via scripts/make-demo.sh.

import AppKit
import SwiftUI

let outDir = CommandLine.arguments[1]
let scene = CGSize(width: 1200, height: 600)
let rackOrigin = CGPoint(x: scene.width - Metrics.windowSize.width, y: 26)

RackStyle.flatGlass = true
// Offscreen frames take ~0.1 s to draw, so the whole scene plays 5× slower and the
// timestamps are squeezed back afterwards.
slowMo = 5
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

// MARK: - Fake screenshots

func snapshot<V: View>(_ view: V, _ size: CGSize) -> NSImage {
    MainActor.assumeIsolated {
        let r = ImageRenderer(content: view.frame(width: size.width, height: size.height).environment(\.colorScheme, .light))
        r.scale = 2
        return r.nsImage!
    }
}

struct PosterArt: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.98, green: 0.45, blue: 0.36), Color(red: 1, green: 0.78, blue: 0.42)],
                           startPoint: .top, endPoint: .bottom)
            Circle().fill(Color(red: 1, green: 0.95, blue: 0.75)).frame(width: 96).offset(y: 18)
            MountainShape().fill(Color(red: 0.42, green: 0.16, blue: 0.36)).offset(y: 70)
            MountainShape().fill(Color(red: 0.25, green: 0.09, blue: 0.26)).scaleEffect(x: -1.3, y: 0.8).offset(y: 110)
            VStack(spacing: 2) {
                Text("GOLDEN").font(.system(size: 30, weight: .black, design: .rounded))
                Text("HOUR").font(.system(size: 30, weight: .black, design: .rounded))
                Spacer()
                Text("FRI · 7PM · ROOFTOP").font(.system(size: 9, weight: .bold)).tracking(2)
            }
            .foregroundStyle(.white)
            .padding(.vertical, 18)
        }
        .clipped()
    }
}

struct MountainShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: r.maxY))
        p.addLine(to: CGPoint(x: 0, y: r.midY + 30))
        p.addLine(to: CGPoint(x: r.width * 0.28, y: r.midY - 20))
        p.addLine(to: CGPoint(x: r.width * 0.45, y: r.midY + 10))
        p.addLine(to: CGPoint(x: r.width * 0.7, y: r.midY - 35))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY + 20))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        return p
    }
}

func codeShot() -> NSImage {
    let colors: [Color] = [.pink, .cyan, .yellow, .green, .purple, .orange, .mint]
    return snapshot(
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) { ForEach([Color.red, .yellow, .green], id: \.self) { Circle().fill($0).frame(width: 8) } }
                .padding(.bottom, 4)
            ForEach(0..<9, id: \.self) { i in
                HStack(spacing: 5) {
                    Capsule().fill(Color.white.opacity(0.18)).frame(width: 10, height: 6)
                    Capsule().fill(colors[i % 7]).frame(width: CGFloat(30 + (i * 37) % 70), height: 6)
                        .padding(.leading, CGFloat((i % 3) * 14))
                    Capsule().fill(colors[(i + 3) % 7].opacity(0.8)).frame(width: CGFloat(20 + (i * 53) % 90), height: 6)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 0.11, green: 0.12, blue: 0.16)),
        CGSize(width: 320, height: 200)
    )
}

func paletteShot() -> NSImage {
    let swatches: [(Color, String)] = [
        (Color(red: 0.98, green: 0.45, blue: 0.36), "#FA735C"), (Color(red: 1, green: 0.78, blue: 0.42), "#FFC76B"),
        (Color(red: 0.42, green: 0.16, blue: 0.36), "#6B295C"), (Color(red: 0.25, green: 0.09, blue: 0.26), "#401742"),
        (Color(red: 0.55, green: 0.85, blue: 0.8), "#8CD9CC"),
    ]
    return snapshot(
        HStack(spacing: 0) {
            ForEach(swatches, id: \.1) { c, hex in
                c.overlay(alignment: .bottom) {
                    Text(hex).font(.system(size: 9, weight: .semibold).monospaced())
                        .foregroundStyle(.white.opacity(0.9)).rotationEffect(.degrees(-90)).padding(.bottom, 28)
                }
            }
        },
        CGSize(width: 300, height: 220)
    )
}

func chartShot() -> NSImage {
    let bars: [CGFloat] = [0.35, 0.5, 0.42, 0.66, 0.58, 0.8, 0.95]
    return snapshot(
        VStack(alignment: .leading, spacing: 6) {
            Text("Weekly signups").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            Text("+38%").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(.green)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(bars.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(i == bars.count - 1 ? Color.green : Color.green.opacity(0.35))
                        .frame(height: 90 * bars[i])
                }
            }
            .frame(height: 90, alignment: .bottom)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.white),
        CGSize(width: 320, height: 200)
    )
}

func phoneShot() -> NSImage {
    snapshot(
        VStack(spacing: 10) {
            LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(height: 120)
                .overlay(alignment: .bottomLeading) {
                    Text("Good\nmorning ☀️").font(.system(size: 22, weight: .bold)).foregroundStyle(.white).padding(14)
                }
            ForEach(0..<4, id: \.self) { i in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 8).fill([Color.orange, .blue, .mint, .pink][i].opacity(0.8)).frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 5) {
                        Capsule().fill(.black.opacity(0.7)).frame(width: 90, height: 6)
                        Capsule().fill(.black.opacity(0.2)).frame(width: 60, height: 5)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
            }
            Spacer()
        }
        .background(.white),
        CGSize(width: 180, height: 360)
    )
}

func terminalShot() -> NSImage {
    snapshot(
        VStack(alignment: .leading, spacing: 5) {
            Text("$ swift test").foregroundStyle(.white)
            Text("Building for debugging…").foregroundStyle(.white.opacity(0.5))
            Text("✓ 128 tests passed").foregroundStyle(.green)
            Text("✓ 0 failures").foregroundStyle(.green)
            Text("$ ▍").foregroundStyle(.white)
        }
        .font(.system(size: 13, weight: .medium).monospaced())
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 0.07, green: 0.07, blue: 0.09)),
        CGSize(width: 320, height: 180)
    )
}

func mapShot() -> NSImage {
    snapshot(
        ZStack {
            Color(red: 0.91, green: 0.94, blue: 0.9)
            ForEach(0..<6, id: \.self) { i in
                Rectangle().fill(.white).frame(width: 6).offset(x: CGFloat(i * 60 - 150)).rotationEffect(.degrees(12))
                Rectangle().fill(.white).frame(height: 6).offset(y: CGFloat(i * 45 - 110))
            }
            Path { p in
                p.move(to: CGPoint(x: 40, y: 190)); p.addCurve(to: CGPoint(x: 250, y: 50),
                    control1: CGPoint(x: 120, y: 180), control2: CGPoint(x: 160, y: 40))
            }
            .stroke(Color.blue, style: StrokeStyle(lineWidth: 5, lineCap: .round))
            Image(systemName: "mappin.circle.fill").font(.system(size: 30)).foregroundStyle(.white, .red).offset(x: 100, y: -62)
        },
        CGSize(width: 300, height: 230)
    )
}

func shot(_ name: String, _ image: NSImage) -> Shot {
    Shot(url: URL(fileURLWithPath: "/demo/\(name).png"), thumb: image, isVideo: false, added: Date().addingTimeInterval(-240))
}

let posterSize = CGSize(width: 220, height: 275)
let posterImage = snapshot(PosterArt(), posterSize)
let posterShot = Shot(url: URL(fileURLWithPath: "/demo/poster.png"), thumb: posterImage, isVideo: false, added: Date())
let paletteShotItem = shot("palette", paletteShot())
let initialShots = [shot("map", mapShot()), shot("code", codeShot()), paletteShotItem,
                    shot("chart", chartShot()), shot("terminal", terminalShot()), shot("phone", phoneShot())]

// MARK: - Scene state

enum CursorMode { case arrow, crosshair, dragCopy }

@Observable final class Stage {
    var cursor = CGPoint(x: 250, y: 560)
    var mode = CursorMode.arrow
    var selection: CGRect?
    var flash = 0.0
    var ghost: (image: NSImage, size: CGSize, offset: CGSize)?
    var dropHot = false
    var sent = false
}

let stage = Stage()
let rack = Rack()

let designWindow = CGRect(x: 40, y: 66, width: 470, height: 372)
let posterFrame = CGRect(x: designWindow.minX + 128, y: designWindow.minY + 70, width: posterSize.width, height: posterSize.height)
let chatWindow = CGRect(x: 430, y: 286, width: 520, height: 300)
let chatInput = CGRect(x: chatWindow.minX + 16, y: chatWindow.maxY - 50, width: chatWindow.width - 32, height: 36)

// MARK: - Scene views

struct Wallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.16, green: 0.2, blue: 0.48), Color(red: 0.46, green: 0.27, blue: 0.62),
                                    Color(red: 0.95, green: 0.55, blue: 0.5)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Color(red: 0.4, green: 0.75, blue: 1).opacity(0.6), .clear],
                           center: UnitPoint(x: 0.85, y: 0.85), startRadius: 0, endRadius: 420)
            RadialGradient(colors: [Color(red: 1, green: 0.6, blue: 0.4).opacity(0.5), .clear],
                           center: UnitPoint(x: 0.1, y: 1), startRadius: 0, endRadius: 380)
        }
    }
}

struct MenuBar: View {
    var body: some View {
        HStack(spacing: 18) {
            Text("Penderie").fontWeight(.bold)
            Text("File"); Text("Edit"); Text("View"); Text("Window")
            Spacer()
            Image(systemName: "hanger").font(.system(size: 14, weight: .semibold))
            Image(systemName: "wifi")
            Image(systemName: "battery.75percent")
            Text("Mon 12 Oct  12:41")
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(height: 26)
        .background(.black.opacity(0.12))
    }
}

struct WindowChrome<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach([Color(red: 1, green: 0.37, blue: 0.34), Color(red: 1, green: 0.74, blue: 0.18),
                         Color(red: 0.16, green: 0.79, blue: 0.25)], id: \.self) { Circle().fill($0).frame(width: 12) }
                Spacer()
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.black.opacity(0.75))
                Spacer()
                Color.clear.frame(width: 52)
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
            content
        }
        .background(Color(white: 0.985))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.black.opacity(0.12), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.32), radius: 30, y: 16)
    }
}

struct DesignApp: View {
    var body: some View {
        WindowChrome(title: "golden-hour.poster") {
            HStack(spacing: 0) {
                VStack(spacing: 10) {
                    ForEach(["cursorarrow", "square", "circle", "textformat", "pencil.tip"], id: \.self) {
                        Image(systemName: $0).font(.system(size: 13)).foregroundStyle(.black.opacity(0.55)).frame(width: 28, height: 28)
                    }
                    Spacer()
                }
                .padding(.top, 10)
                .frame(width: 44)
                ZStack {
                    Color(white: 0.93)
                    PosterArt().frame(width: posterSize.width, height: posterSize.height)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                }
                VStack(alignment: .leading, spacing: 9) {
                    Text("Layers").font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
                    ForEach(["Title", "Sun", "Mountains", "Sky"], id: \.self) {
                        Label($0, systemImage: "square.on.square").font(.system(size: 11)).foregroundStyle(.black.opacity(0.7))
                    }
                    Spacer()
                }
                .padding(12)
                .frame(width: 112, alignment: .leading)
            }
        }
    }
}

struct Bubble: View {
    let who: String
    let color: Color
    let text: String
    var image: NSImage? = nil
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(color).frame(width: 28).overlay(Text(String(who.prefix(1))).font(.system(size: 12, weight: .bold)).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 4) {
                Text(who).font(.system(size: 12, weight: .bold)).foregroundStyle(.black.opacity(0.85))
                Text(text).font(.system(size: 13)).foregroundStyle(.black.opacity(0.75))
                if let image {
                    Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).frame(height: 62)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            Spacer()
        }
    }
}

struct ChatApp: View {
    var stage: Stage
    var body: some View {
        WindowChrome(title: "# launch-crew") {
            VStack(alignment: .leading, spacing: 12) {
                Spacer(minLength: 0)
                if !stage.sent {  // the thread scrolls up when your message lands
                    Bubble(who: "Mia", color: .purple, text: "launch party poster goes out today 🎉")
                }
                Bubble(who: "Ana", color: .orange, text: "does anyone have the poster for friday?? 🙏")
                Bubble(who: "Theo", color: .blue, text: "it's somewhere in the design file…")
                if stage.sent {
                    Bubble(who: "You", color: .pink, text: "here ✨", image: posterImage)
                }
                HStack {
                    Text(stage.dropHot ? "Drop to share" : "Message #launch-crew")
                        .font(.system(size: 13, weight: stage.dropHot ? .semibold : .regular))
                        .foregroundStyle(stage.dropHot ? Color.accentColor : .black.opacity(0.35))
                    Spacer()
                    Image(systemName: "paperclip").foregroundStyle(.black.opacity(0.35))
                }
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(RoundedRectangle(cornerRadius: 10).fill(stage.dropHot ? Color.accentColor.opacity(0.08) : .white))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(stage.dropHot ? Color.accentColor : .black.opacity(0.12),
                                                                   lineWidth: stage.dropHot ? 2 : 0.5))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
            .clipped()
        }
    }
}

struct Cursor: View {
    let mode: CursorMode
    var body: some View {
        switch mode {
        case .crosshair:
            ZStack {
                Rectangle().fill(.white).frame(width: 25, height: 3)
                Rectangle().fill(.white).frame(width: 3, height: 25)
                Rectangle().fill(.black).frame(width: 23, height: 1)
                Rectangle().fill(.black).frame(width: 1, height: 23)
            }
        case .arrow, .dragCopy:
            ZStack(alignment: .topLeading) {
                ArrowShape().fill(.black).overlay(ArrowShape().stroke(.white, lineWidth: 1.5))
                    .frame(width: 17, height: 25)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                if mode == .dragCopy {
                    Circle().fill(.green).frame(width: 15).overlay(Image(systemName: "plus").font(.system(size: 9, weight: .black)).foregroundStyle(.white))
                        .overlay(Circle().stroke(.white, lineWidth: 1.2))
                        .offset(x: 12, y: 18)
                }
            }
            .frame(width: 30, height: 40, alignment: .topLeading)
        }
    }
}

struct ArrowShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let s = r.width / 17
        let pts: [(CGFloat, CGFloat)] = [(0, 0), (0, 22), (5.5, 17), (9, 25), (12.5, 23.5), (9, 16), (16, 16)]
        p.move(to: CGPoint(x: pts[0].0 * s, y: pts[0].1 * s))
        for pt in pts.dropFirst() { p.addLine(to: CGPoint(x: pt.0 * s, y: pt.1 * s)) }
        p.closeSubpath()
        return p
    }
}

struct DemoScene: View {
    var stage: Stage
    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(nsImage: backdrop).resizable().frame(width: scene.width, height: scene.height)
            ZStack {
                Image(nsImage: chatImages.base).resizable()
                Image(nsImage: chatImages.hot).resizable().opacity(stage.dropHot && !stage.sent ? 1 : 0)
                Image(nsImage: chatImages.sent).resizable().opacity(stage.sent ? 1 : 0)
                    .transaction { $0.animation = nil }
            }
            .frame(width: chatWindow.width + 2 * shadowPad, height: chatWindow.height + 2 * shadowPad)
            .offset(x: chatWindow.minX - shadowPad, y: chatWindow.minY - shadowPad)
            RackView(rack: rack).offset(x: rackOrigin.x, y: rackOrigin.y)

            if let sel = stage.selection {
                Path { p in
                    p.addRect(CGRect(origin: .zero, size: scene))
                    p.addRect(sel)
                }
                .fill(.black.opacity(0.28), style: FillStyle(eoFill: true))
                Rectangle().stroke(.white.opacity(0.9), lineWidth: 1)
                    .frame(width: sel.width, height: sel.height).offset(x: sel.minX, y: sel.minY)
                Text("\(Int(sel.width)) × \(Int(sel.height))")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Capsule().fill(.black.opacity(0.6)))
                    .offset(x: sel.maxX + 12, y: sel.maxY + 12)
            }
            if stage.flash > 0, let f = flashRect {
                Rectangle().fill(.white.opacity(stage.flash)).frame(width: f.width, height: f.height).offset(x: f.minX, y: f.minY)
            }
            if let g = stage.ghost {
                Image(nsImage: g.image).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: g.size.width, height: g.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .opacity(0.88)
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 8)
                    .offset(x: stage.cursor.x + g.offset.width, y: stage.cursor.y + g.offset.height)
            }
            Cursor(mode: stage.mode)
                .offset(x: stage.cursor.x - (stage.mode == .crosshair ? 12.5 : 1),
                        y: stage.cursor.y - (stage.mode == .crosshair ? 12.5 : 1))
        }
        .frame(width: scene.width, height: scene.height, alignment: .topLeading)
        .environment(\.colorScheme, .light)
    }
}

var flashRect: CGRect?

// Static layers are rendered once up front; shadows and gradients are too slow to redraw every frame.
let shadowPad: CGFloat = 70
let backdrop = snapshot(
    ZStack(alignment: .topLeading) {
        Wallpaper().frame(width: scene.width, height: scene.height)
        DesignApp().frame(width: designWindow.width, height: designWindow.height)
            .offset(x: designWindow.minX, y: designWindow.minY)
        MenuBar().frame(width: scene.width)
    }
    .frame(width: scene.width, height: scene.height, alignment: .topLeading),
    scene
)

func chatImage(hot: Bool, sent: Bool) -> NSImage {
    let s = Stage()
    s.dropHot = hot
    s.sent = sent
    return snapshot(
        ChatApp(stage: s).frame(width: chatWindow.width, height: chatWindow.height).padding(shadowPad),
        CGSize(width: chatWindow.width + 2 * shadowPad, height: chatWindow.height + 2 * shadowPad)
    )
}

let chatImages = (base: chatImage(hot: false, sent: false), hot: chatImage(hot: true, sent: false), sent: chatImage(hot: false, sent: true))

// MARK: - Script

struct Move {
    let t0: Double, t1: Double, bend: CGFloat
    let to: () -> CGPoint
}

func sceneFrame(_ id: UUID) -> CGRect {
    rack.frame(of: id)!.offsetBy(dx: rackOrigin.x, dy: rackOrigin.y)
}

let selStart = CGPoint(x: posterFrame.minX - 8, y: posterFrame.minY - 8)
let selEnd = CGPoint(x: posterFrame.maxX + 8, y: posterFrame.maxY + 8)
var grabbed: UUID?

let moves: [Move] = [
    Move(t0: 0.2, t1: 0.9, bend: 30) { selStart },
    Move(t0: 1.05, t1: 1.95, bend: 0) { selEnd },
    Move(t0: 2.5, t1: 3.2, bend: -40) {
        let f = sceneFrame(rack.items.first!.id)
        return CGPoint(x: f.minX + 18, y: f.minY + 60)
    },
    Move(t0: 3.2, t1: 4.7, bend: 10) {
        let f = sceneFrame(posterShot.id)
        return CGPoint(x: f.midX + 8, y: f.minY + 66)
    },
    Move(t0: 5.15, t1: 6.25, bend: -60) { CGPoint(x: chatInput.minX + 150, y: chatInput.midY) },
    Move(t0: 6.7, t1: 7.4, bend: 30) {
        let f = sceneFrame(paletteShotItem.id)
        return CGPoint(x: f.minX + 30, y: f.minY + 70)
    },
    Move(t0: 7.55, t1: 7.9, bend: 0) {
        let c = Rack.closeRect(for: sceneFrame(paletteShotItem.id))
        return CGPoint(x: c.midX, y: c.midY)
    },
    Move(t0: 8.4, t1: 9.2, bend: 20) { CGPoint(x: 760, y: 470) },
]

var events: [(Double, () -> Void)] = [
    (0.95, { stage.mode = .crosshair }),
    (1.05, { stage.selection = CGRect(origin: selStart, size: .zero) }),
    (1.95, {
        flashRect = stage.selection
        stage.selection = nil
        stage.flash = 0.9
        withAnimation(.easeOut(duration: 0.35 * slowMo)) { stage.flash = 0 }
    }),
    (2.05, { stage.mode = .arrow }),
    (2.15, { rack.add(posterShot) }),
    (4.95, { rack.press(posterShot.id) }),
    (5.1, {
        let f = sceneFrame(posterShot.id)
        stage.ghost = (posterImage, f.size, CGSize(width: f.minX - stage.cursor.x, height: f.minY - stage.cursor.y))
        stage.mode = .dragCopy
        grabbed = posterShot.id
        rack.beginDrag(posterShot.id)
    }),
    (6.45, {
        stage.ghost = nil
        stage.mode = .arrow
        withAnimation(.easeOut(duration: 0.15 * slowMo)) { stage.dropHot = false }
        rack.endDrag(posterShot.id, dropped: true)
        grabbed = nil
        stage.sent = true
    }),
    (8.05, { rack.remove(paletteShotItem.id) }),
]

func ease(_ u: Double) -> Double { u < 0.5 ? 4 * u * u * u : 1 - pow(-2 * u + 2, 3) / 2 }

var moveStarts: [Int: CGPoint] = [:]
var moveEnds: [Int: CGPoint] = [:]

func update(_ t: Double) {
    for (i, m) in moves.enumerated() where t >= m.t0 {
        if moveStarts[i] == nil { moveStarts[i] = stage.cursor; moveEnds[i] = m.to() }
        guard t <= m.t1 + 0.05 else { continue }
        let a = moveStarts[i]!, b = moveEnds[i]!
        let u = ease(min(1, (t - m.t0) / (m.t1 - m.t0)))
        let d = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let len = max(1, hypot(d.x, d.y))
        let bend = m.bend * CGFloat(sin(.pi * u))
        stage.cursor = CGPoint(x: a.x + d.x * u - d.y / len * bend, y: a.y + d.y * u + d.x / len * bend)
    }
    while let e = events.first, e.0 <= t {
        events.removeFirst()
        e.1()
    }
    if let sel = stage.selection {
        stage.selection = CGRect(x: sel.minX, y: sel.minY,
                                 width: max(0, stage.cursor.x - sel.minX), height: max(0, stage.cursor.y - sel.minY))
    }
    if grabbed != nil {
        let hot = chatWindow.contains(stage.cursor)
        if hot != stage.dropHot { withAnimation(.easeOut(duration: 0.15 * slowMo)) { stage.dropHot = hot } }
    } else {
        let p = CGPoint(x: stage.cursor.x - rackOrigin.x, y: stage.cursor.y - rackOrigin.y)
        rack.pointerMoved(to: p)
    }
}

// MARK: - Record

let host = NSHostingView(rootView: DemoScene(stage: stage))
host.sizingOptions = []
host.frame = CGRect(origin: .zero, size: scene)
let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
window.contentView = host

func render(scale: CGFloat) -> NSBitmapImageRep { MainActor.assumeIsolated {
    host.layoutSubtreeIfNeeded()
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(scene.width * scale), pixelsHigh: Int(scene.height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = scene
    host.cacheDisplay(in: host.bounds, to: rep)
    return rep
} }

for s in initialShots { rack.add(s, quiet: true) }
RunLoop.main.run(until: Date().addingTimeInterval(2.5 * slowMo))   // let everything settle

let writer = DispatchQueue(label: "writer", attributes: .concurrent)
let group = DispatchGroup()
var list = "ffconcat version 1.0\n"
var lastStamp = 0.0
var frame = 0
var heroDone = false
let start = Date()
let total = 9.8

while true {
    let t = Date().timeIntervalSince(start) / slowMo
    if t > total { break }
    update(t)
    RunLoop.main.run(until: Date().addingTimeInterval(0.004))
    if !heroDone && t > 4.15 {
        heroDone = true
        let hero = render(scale: 2)
        try! hero.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(outDir)/hero.png"))
    }
    let rep = render(scale: 1)
    let name = String(format: "f%05d.png", frame)
    if frame > 0 { list += "duration \(String(format: "%.4f", t - lastStamp))\n" }
    list += "file '\(name)'\n"
    lastStamp = t
    frame += 1
    group.enter()
    writer.async {
        try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(outDir)/frames/\(name)"))
        group.leave()
    }
}
list += "duration 0.04\n"
group.wait()
try! list.write(toFile: "\(outDir)/frames/list.txt", atomically: true, encoding: .utf8)
print("\(frame) frames in \(String(format: "%.1f", total)) s (\(String(format: "%.0f", Double(frame) / total)) fps)")
