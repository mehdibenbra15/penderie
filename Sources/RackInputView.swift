import AppKit

/// Transparent AppKit layer above the SwiftUI drawing: clicks, drags out, context menu.
final class RackInputView: NSView, NSDraggingSource {
    private let rack: Rack
    private var downPoint: CGPoint = .zero
    private var downItem: UUID?
    private var dragStarted = false
    private var draggingID: UUID?

    init(rack: Rack) {
        self.rack = rack
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
    }

    override func mouseMoved(with e: NSEvent) { rack.pointerMoved(to: point(e)) }
    override func mouseEntered(with e: NSEvent) { rack.pointerMoved(to: point(e)) }

    private func point(_ e: NSEvent) -> CGPoint { convert(e.locationInWindow, from: nil) }

    // MARK: Clicks

    override func mouseDown(with e: NSEvent) {
        let p = point(e)
        downItem = nil
        dragStarted = false
        if rack.hitClear(p) { rack.clearAll(); return }
        if let h = rack.hovered, rack.hitClose(p) { rack.remove(h); return }
        downItem = rack.hitCard(p)
        downPoint = p
        if let id = downItem { rack.press(id) }
    }

    override func mouseDragged(with e: NSEvent) {
        guard let id = downItem, !dragStarted, let shot = rack.shot(id), let frame = rack.frame(of: id) else { return }
        let p = point(e)
        guard hypot(p.x - downPoint.x, p.y - downPoint.y) > 3 else { return }
        dragStarted = true

        let item = NSDraggingItem(pasteboardWriter: shot.url as NSURL)
        item.setDraggingFrame(frame, contents: Self.rounded(shot.thumb, size: frame.size))
        let session = beginDraggingSession(with: [item], event: e, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        draggingID = id
        rack.beginDrag(id)
    }

    override func mouseUp(with e: NSEvent) {
        defer { downItem = nil }
        guard !dragStarted, let id = downItem, rack.hitCard(point(e)) == id, let shot = rack.shot(id) else { return }
        NSWorkspace.shared.open(shot.url)
    }

    // MARK: Drag source

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        // Copy only, so dropping on a Finder folder never moves the original away.
        context == .outsideApplication ? .copy : []
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        guard let id = draggingID else { return }
        draggingID = nil
        dragStarted = false
        rack.endDrag(id, dropped: operation != [])
    }

    // MARK: Context menu

    override func rightMouseDown(with e: NSEvent) {
        guard let id = rack.hitCard(point(e)), let shot = rack.shot(id) else { return }
        let menu = NSMenu()
        menu.addItem(ActionItem("Copy", symbol: "doc.on.doc") { Self.copy(shot.url) })
        menu.addItem(ActionItem("Open", symbol: "arrow.up.forward.app") { NSWorkspace.shared.open(shot.url) })
        menu.addItem(ActionItem("Show in Finder", symbol: "folder") {
            NSWorkspace.shared.activateFileViewerSelecting([shot.url])
        })
        menu.addItem(.separator())
        menu.addItem(ActionItem("Take Off Rack", symbol: "xmark") { [rack] in rack.remove(id) })
        menu.addItem(ActionItem("Move to Trash", symbol: "trash") { [rack] in
            NSWorkspace.shared.recycle([shot.url]) { _, _ in }
            rack.remove(id)
        })
        NSMenu.popUpContextMenu(menu, with: e, for: self)
    }

    static func copy(_ url: URL) {
        let item = NSPasteboardItem()
        item.setString(url.absoluteString, forType: .fileURL)
        if let image = NSImage(contentsOf: url), let tiff = image.tiffRepresentation {
            item.setData(tiff, forType: .tiff)
            if let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                item.setData(png, forType: .png)
            }
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([item])
    }

    private static func rounded(_ image: NSImage, size: CGSize) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            NSBezierPath(roundedRect: rect, xRadius: 9, yRadius: 9).addClip()
            let s = image.size
            let scale = max(rect.width / s.width, rect.height / s.height)
            let draw = CGSize(width: s.width * scale, height: s.height * scale)
            image.draw(in: CGRect(x: rect.midX - draw.width / 2, y: rect.midY - draw.height / 2,
                                  width: draw.width, height: draw.height))
            return true
        }
    }
}

final class ActionItem: NSMenuItem {
    private let action_: () -> Void

    init(_ title: String, symbol: String? = nil, key: String = "", action: @escaping () -> Void) {
        action_ = action
        super.init(title: title, action: #selector(fire), keyEquivalent: key)
        target = self
        if let symbol { image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func fire() { action_() }
}
