import AppKit
import Observation
import SwiftUI

struct Shot: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let thumb: NSImage
    let isVideo: Bool
    let added: Date

    var aspect: CGFloat {
        let s = thumb.size
        return s.height > 0 ? s.width / s.height : 1.6
    }

    static func == (a: Shot, b: Shot) -> Bool { a.id == b.id }
}

/// All geometry lives in window coordinates, top-left origin (SwiftUI and the flipped input view agree on it).
enum Metrics {
    static let windowSize = CGSize(width: 820, height: 270)
    static let cardWidth: CGFloat = 128
    static let rodY: CGFloat = 14              // rod centre line
    static let hookCentre: CGFloat = 8         // hook circle centre, inside a hanger view
    static let cardTopInHanger: CGFloat = 38   // where the card starts, inside a hanger view
    static let rightInset: CGFloat = 18
    static let maxRackWidth: CGFloat = 540
    static let gap: CGFloat = 14
    static let maxItems = 30

    static var cardTop: CGFloat { rodY - hookCentre + cardTopInHanger }
    static var rodRight: CGFloat { windowSize.width - 4 }

    static func cardHeight(_ aspect: CGFloat) -> CGFloat {
        min(max(cardWidth / max(aspect, 0.1), 56), 168)
    }
}

/// Stretches every animation and the physics. Only the demo renderer changes it, to record in slow motion.
var slowMo = 1.0

@Observable
final class Rack {
    private(set) var items: [Shot] = []
    private(set) var hovered: UUID?
    private(set) var rackHovered = false
    private(set) var closeHot = false
    private(set) var clearHot = false
    private(set) var dragging: UUID?
    private(set) var swing: [UUID: Double] = [:]   // degrees, positive = clockwise

    @ObservationIgnored var onChange: () -> Void = {}
    @ObservationIgnored var removeAfterDrop = true

    // MARK: Layout

    func frames() -> [CGRect] {
        let n = items.count
        guard n > 0 else { return [] }
        let w = Metrics.cardWidth
        let full = w + Metrics.gap
        let step = n == 1 ? full : min(full, (Metrics.maxRackWidth - w) / CGFloat(n - 1))
        let right = Metrics.windowSize.width - Metrics.rightInset
        // Flipping through clothes: everything left of (and including) the hovered card slides
        // left so it comes out from under its right-hand neighbour.
        let h = hovered.flatMap { id in items.firstIndex { $0.id == id } }
        let shift = step < full ? w - step + 8 : 0
        return items.indices.map { i in
            var x = right - w - CGFloat(n - 1 - i) * step
            if let h, i <= h { x -= shift }
            return CGRect(x: x, y: Metrics.cardTop, width: w, height: Metrics.cardHeight(items[i].aspect))
        }
    }

    func frame(of id: UUID) -> CGRect? {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return nil }
        return frames()[i]
    }

    var rodLeft: CGFloat {
        (frames().map(\.minX).min() ?? Metrics.rodRight) - 22
    }

    var clearRect: CGRect {
        CGRect(x: rodLeft - 70, y: Metrics.rodY - 11, width: 60, height: 22)
    }

    var showsClear: Bool { rackHovered && items.count > 1 }

    static func closeRect(for card: CGRect) -> CGRect {
        CGRect(x: card.minX - 9, y: card.minY - 9, width: 26, height: 26)
    }

    // MARK: Hit testing

    /// Topmost card under the point. The hovered card keeps a little slack so the shuffle can't flicker.
    func hitCard(_ p: CGPoint) -> UUID? {
        let fs = frames()
        if let h = hovered, let i = items.firstIndex(where: { $0.id == h }),
           fs[i].insetBy(dx: -10, dy: -10).contains(p) {
            return h
        }
        for i in items.indices.reversed() where fs[i].contains(p) {
            return items[i].id
        }
        return nil
    }

    func hitClose(_ p: CGPoint) -> Bool {
        guard let h = hovered, let f = frame(of: h) else { return false }
        return Self.closeRect(for: f).contains(p)
    }

    func hitClear(_ p: CGPoint) -> Bool {
        showsClear && clearRect.insetBy(dx: -3, dy: -3).contains(p)
    }

    /// Where clicks must land on us instead of falling through to the app underneath.
    func blocksClicks(at p: CGPoint) -> Bool {
        hitClear(p) || hitClose(p) || hitCard(p) != nil
    }

    private func inHoverZone(_ p: CGPoint) -> Bool {
        if blocksClicks(at: p) { return true }
        let band = CGRect(x: rodLeft - (rackHovered ? 80 : 4), y: 0,
                          width: Metrics.rodRight - rodLeft + 84, height: Metrics.cardTop)
        if band.contains(p) { return true }
        return frames().contains { $0.insetBy(dx: -6, dy: -6).contains(p) }
    }

    // MARK: Pointer

    @ObservationIgnored private var lastPointer: CGPoint?
    @ObservationIgnored private var lastDirection: CGFloat = 1

    func pointerMoved(to p: CGPoint?) {
        guard dragging == nil else { return }
        guard let p else {
            setHover(nil, zone: false, close: false, clear: false)
            lastPointer = nil
            return
        }
        if let last = lastPointer, abs(p.x - last.x) > 0.5 { lastDirection = p.x > last.x ? 1 : -1 }
        lastPointer = p

        let clear = hitClear(p)
        let close = hitClose(p)
        let card = close ? hovered : (clear ? nil : hitCard(p))
        setHover(card, zone: inHoverZone(p), close: close, clear: clear)
    }

    private func setHover(_ card: UUID?, zone: Bool, close: Bool, clear: Bool) {
        if card != hovered {
            if let card {
                // Brushing past a garment: push its hem the way the pointer travels.
                kick(card, -26 * Double(lastDirection))
                for n in neighbours(of: card) { kick(n, -9 * Double(lastDirection)) }
            }
            withAnimation(.spring(response: 0.42 * slowMo, dampingFraction: 0.78)) { hovered = card }
        }
        if zone != rackHovered { withAnimation(.easeOut(duration: 0.18 * slowMo)) { rackHovered = zone } }
        if close != closeHot { withAnimation(.easeOut(duration: 0.12 * slowMo)) { closeHot = close } }
        if clear != clearHot { withAnimation(.easeOut(duration: 0.12 * slowMo)) { clearHot = clear } }
    }

    private func neighbours(of id: UUID) -> [UUID] {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return [] }
        return [i - 1, i + 1].filter(items.indices.contains).map { items[$0].id }
    }

    // MARK: Items

    func shot(_ id: UUID) -> Shot? { items.first { $0.id == id } }

    func contains(_ url: URL) -> Bool { items.contains { $0.url == url } }

    func add(_ shot: Shot, quiet: Bool = false) {
        guard !contains(shot.url) else { return }
        withAnimation(.spring(response: 0.6 * slowMo, dampingFraction: 0.74)) {
            items.append(shot)
            if items.count > Metrics.maxItems { items.removeFirst(items.count - Metrics.maxItems) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (quiet ? 0.1 : 0.22) * slowMo) { [self] in
            kick(shot.id, quiet ? -30 : -75)
            for n in neighbours(of: shot.id) { kick(n, 18) }
        }
        onChange()
    }

    func remove(_ id: UUID) {
        withAnimation(.spring(response: 0.38 * slowMo, dampingFraction: 0.86)) {
            items.removeAll { $0.id == id }
            if hovered == id { hovered = nil; closeHot = false }
        }
        swing[id] = nil
        omega[id] = nil
        onChange()
    }

    func removeMissingFiles() {
        for s in items where !FileManager.default.fileExists(atPath: s.url.path) { remove(s.id) }
    }

    func clearAll() {
        // Unhook them one by one, newest first, for a little cascade.
        for (n, s) in items.reversed().enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(n) * 0.045 * slowMo) { [self] in remove(s.id) }
        }
    }

    func press(_ id: UUID) { kick(id, -14 * Double(lastDirection)) }

    func beginDrag(_ id: UUID) {
        withAnimation(.easeOut(duration: 0.12 * slowMo)) { dragging = id }
    }

    func endDrag(_ id: UUID, dropped: Bool) {
        withAnimation(.easeOut(duration: 0.15 * slowMo)) { dragging = nil }
        if dropped && removeAfterDrop {
            remove(id)
        } else {
            kick(id, 60)
        }
    }

    // MARK: Pendulum physics

    @ObservationIgnored private var omega: [UUID: Double] = [:]
    @ObservationIgnored private var timer: Timer?
    private let stiffness = 34.0   // ≈ 0.93 Hz
    private let damping = 1.7

    func kick(_ id: UUID, _ angularVelocity: Double) {
        guard items.contains(where: { $0.id == id }) else { return }
        omega[id, default: 0] += angularVelocity
        if timer == nil {
            let t = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in self?.step(1.0 / 120 / slowMo) }
            RunLoop.main.add(t, forMode: .common)
            timer = t
        }
    }

    private func step(_ dt: Double) {
        var next = swing
        var moving = false
        for id in Set(omega.keys).union(swing.keys) {
            var th = next[id] ?? 0
            var w = omega[id] ?? 0
            w += (-stiffness * th - damping * w) * dt
            th = max(-28, min(28, th + w * dt))
            if abs(th) < 0.02 && abs(w) < 0.05 {
                next[id] = nil
                omega[id] = nil
            } else {
                next[id] = th
                omega[id] = w
                moving = true
            }
        }
        swing = next
        if !moving {
            timer?.invalidate()
            timer = nil
        }
    }
}
