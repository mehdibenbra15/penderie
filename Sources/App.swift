import AppKit
import ServiceManagement
import SwiftUI

final class RackPanel: NSPanel {
    init() {
        super.init(
            contentRect: CGRect(origin: .zero, size: Metrics.windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isMovable = false
        hidesOnDeactivate = false
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = true
        animationBehavior = .none
    }

    // Never steal focus from the app you're working in.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class PassiveHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@main
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    private let rack = Rack()
    private let panel = RackPanel()
    private var watcher: ScreenshotWatcher!
    private var statusItem: NSStatusItem!
    private var monitors: [Any] = []
    private var hideWork: DispatchWorkItem?
    private let defaults = UserDefaults.standard

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.register(defaults: ["removeAfterDrop": true, "sound": false])
        rack.removeAfterDrop = defaults.bool(forKey: "removeAfterDrop")

        let container = NSView(frame: CGRect(origin: .zero, size: Metrics.windowSize))
        let host = PassiveHostingView(rootView: RackView(rack: rack))
        host.sizingOptions = []
        host.frame = container.bounds
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)
        let input = RackInputView(rack: rack)
        input.frame = container.bounds
        input.autoresizingMask = [.width, .height]
        container.addSubview(input)
        panel.contentView = container

        rack.onChange = { [weak self] in self?.rackChanged() }

        let pointer: (NSEvent) -> Void = { [weak self] _ in self?.pointerMoved() }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: pointer) {
            monitors.append(m)
        }
        if let m = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved], handler: { pointer($0); return $0 }) {
            monitors.append(m)
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.placePanel() }

        setUpStatusItem()

        watcher = ScreenshotWatcher { [weak self] url in self?.hang(url, quiet: false) }
        restore()
        watcher.start()

        // Pick up captures deleted or moved elsewhere behind our back.
        let t = Timer(timeInterval: 3, repeats: true) { [weak self] _ in self?.rack.removeMissingFiles() }
        RunLoop.main.add(t, forMode: .common)
    }

    // MARK: Panel

    private func pointerMoved() {
        guard panel.isVisible else { return }
        let s = panel.convertPoint(fromScreen: NSEvent.mouseLocation)
        let p = CGPoint(x: s.x, y: Metrics.windowSize.height - s.y)
        let inside = CGRect(origin: .zero, size: Metrics.windowSize).insetBy(dx: -40, dy: -40).contains(p)
        rack.pointerMoved(to: inside ? p : nil)
        // Transparent parts of the rack let clicks fall through to whatever is underneath.
        let block = inside && rack.blocksClicks(at: p)
        if panel.ignoresMouseEvents == block { panel.ignoresMouseEvents = !block }
    }

    private func placePanel(onScreenWithPointer: Bool = false) {
        let mouse = NSEvent.mouseLocation
        let screen = (onScreenWithPointer ? NSScreen.screens.first { $0.frame.contains(mouse) } : panel.screen)
            ?? NSScreen.main ?? NSScreen.screens[0]
        let v = screen.visibleFrame
        panel.setFrameOrigin(CGPoint(x: v.maxX - Metrics.windowSize.width, y: v.maxY - Metrics.windowSize.height))
    }

    private func rackChanged() {
        defaults.set(rack.items.map(\.url.path), forKey: "rack")
        statusItem?.button?.image = statusImage
        hideWork?.cancel()
        if rack.items.isEmpty {
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.rack.items.isEmpty else { return }
                self.panel.orderOut(nil)
                self.panel.ignoresMouseEvents = true
            }
            hideWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
        } else if !panel.isVisible {
            placePanel(onScreenWithPointer: true)
            panel.orderFrontRegardless()
        }
    }

    // MARK: Items

    private func hang(_ url: URL, quiet: Bool, delay: Double = 0) {
        guard !rack.contains(url) else { return }
        Thumbnailer.make(url) { [weak self] image in
            guard let self, let image, FileManager.default.fileExists(atPath: url.path) else { return }
            let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
            let shot = Shot(
                url: url, thumb: image,
                isVideo: ScreenshotWatcher.videoExtensions.contains(url.pathExtension.lowercased()),
                added: created
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if !quiet {
                    if self.panel.isVisible { self.placePanel(onScreenWithPointer: true) }
                    if self.defaults.bool(forKey: "sound") { NSSound(named: "Tink")?.play() }
                }
                self.rack.add(shot, quiet: quiet)
            }
        }
    }

    private func restore() {
        let paths = defaults.stringArray(forKey: "rack") ?? []
        for (i, path) in paths.enumerated() where FileManager.default.fileExists(atPath: path) {
            let url = URL(fileURLWithPath: path)
            watcher.markSeen(url)
            hang(url, quiet: true, delay: 0.3 + Double(i) * 0.09)
        }
    }

    // MARK: Menu bar

    private var statusImage: NSImage? {
        let img = NSImage(systemSymbolName: "hanger", accessibilityDescription: "Penderie")
            ?? NSImage(systemSymbolName: "pin", accessibilityDescription: "Penderie")
        img?.isTemplate = true
        return img
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = statusImage
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let n = rack.items.count
        let header = NSMenuItem(title: n == 0 ? "Rack is empty" : "\(n) on the rack", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        if !watcher.probeAccess() {
            menu.addItem(ActionItem("⚠︎ Allow access to \(watcher.folder.lastPathComponent)…", symbol: "lock") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders")!)
            })
        }
        let clear = ActionItem("Clear Rack", symbol: "xmark") { [rack] in rack.clearAll() }
        clear.isEnabled = n > 0
        menu.addItem(clear)
        menu.addItem(ActionItem("Open Screenshots Folder", symbol: "folder") { [watcher] in
            NSWorkspace.shared.open(watcher!.folder)
        })
        menu.addItem(.separator())

        menu.addItem(toggle("Take Off After Drop", on: rack.removeAfterDrop) { [self] in
            rack.removeAfterDrop.toggle()
            defaults.set(rack.removeAfterDrop, forKey: "removeAfterDrop")
        })
        menu.addItem(toggle("Clink When Hung", on: defaults.bool(forKey: "sound")) { [self] in
            defaults.set(!defaults.bool(forKey: "sound"), forKey: "sound")
        })
        let instant = toggle("Instant Mode (skip macOS preview)", on: !Self.systemThumbnailEnabled) {
            Self.setSystemThumbnail(enabled: !Self.systemThumbnailEnabled)
        }
        instant.toolTip = "Turns off the floating thumbnail macOS shows after a capture, so screenshots hang immediately instead of ~5 s later."
        menu.addItem(instant)
        menu.addItem(toggle("Open at Login", on: SMAppService.mainApp.status == .enabled) {
            let s = SMAppService.mainApp
            try? (s.status == .enabled ? s.unregister() : s.register())
        })
        menu.addItem(.separator())
        menu.addItem(ActionItem("Quit Penderie", key: "q") { NSApp.terminate(nil) })
    }

    private func toggle(_ title: String, on: Bool, action: @escaping () -> Void) -> NSMenuItem {
        let item = ActionItem(title, action: action)
        item.state = on ? .on : .off
        return item
    }

    private static var systemThumbnailEnabled: Bool {
        screencapturePreference("show-thumbnail") as? Bool ?? true
    }

    private static func setSystemThumbnail(enabled: Bool) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        p.arguments = ["write", "com.apple.screencapture", "show-thumbnail", "-bool", enabled ? "true" : "false"]
        try? p.run()
    }
}
