import AppKit
import CoreServices
import QuickLookThumbnailing

/// Watches the folder macOS saves screenshots into and reports new captures.
final class ScreenshotWatcher {
    private let onNew: (URL) -> Void
    private let since = Date().addingTimeInterval(-3)
    private var seenPaths = Set<String>()
    private var seenDates = Set<Int>()   // Finder copies keep the creation date: don't re-hang duplicates.
    private var stream: FSEventStreamRef?
    private var folderTimer: Timer?
    private(set) var folder: URL

    init(onNew: @escaping (URL) -> Void) {
        self.onNew = onNew
        folder = Self.screenshotFolder()
    }

    static func screenshotFolder() -> URL {
        let raw = screencapturePreference("location") as? String
        if let raw, !raw.isEmpty {
            let url = URL(fileURLWithPath: (raw as NSString).expandingTildeInPath, isDirectory: true)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue { return url }
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)
    }

    /// Listing the folder is also what makes macOS show its "access your Desktop?" prompt.
    @discardableResult
    func probeAccess() -> Bool {
        (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) != nil
    }

    func start() {
        probeAccess()
        startStream()
        // The user can change the screenshot location in ⌘⇧5 › Options at any time.
        let t = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = Self.screenshotFolder()
            if now != self.folder {
                self.folder = now
                self.probeAccess()
                self.startStream()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        folderTimer = t
    }

    func markSeen(_ url: URL) {
        seenPaths.insert(url.path)
    }

    private func startStream() {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        var ctx = FSEventStreamContext(
            version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, _, paths, _, _ in
            guard let info, let paths = unsafeBitCast(paths, to: NSArray.self) as? [String] else { return }
            Unmanaged<ScreenshotWatcher>.fromOpaque(info).takeUnretainedValue().check(paths)
        }
        let flags = UInt32(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagUseCFTypes
        )
        stream = FSEventStreamCreate(
            nil, callback, &ctx, [folder.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.1, flags
        )
        if let stream {
            FSEventStreamSetDispatchQueue(stream, .main)
            FSEventStreamStart(stream)
        }
    }

    /// Only looks at the paths FSEvents reported, so a cluttered Desktop costs nothing.
    private func check(_ paths: [String]) {
        let keys: Set<URLResourceKey> = [.creationDateKey, .isRegularFileKey, .isHiddenKey]
        let dir = folder.resolvingSymlinksInPath().path
        for path in paths where !seenPaths.contains(path) {
            let url = URL(fileURLWithPath: path)
            guard url.deletingLastPathComponent().resolvingSymlinksInPath().path == dir,
                  let v = try? url.resourceValues(forKeys: keys),
                  v.isRegularFile == true, v.isHidden != true,
                  let created = v.creationDate, created >= since,
                  Self.isScreenshot(url)
            else { continue }
            seenPaths.insert(path)
            let stamp = Int(created.timeIntervalSinceReferenceDate * 1000)
            guard seenDates.insert(stamp).inserted else { continue }
            onNew(url)
        }
    }

    static let extensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tif", "tiff", "gif", "pdf", "bmp", "mov", "mp4"]
    static let videoExtensions: Set<String> = ["mov", "mp4"]

    static func isScreenshot(_ url: URL) -> Bool {
        guard extensions.contains(url.pathExtension.lowercased()) else { return false }
        if getxattr(url.path, "com.apple.metadata:kMDItemIsScreenCapture", nil, 0, 0, 0) > 0 { return true }
        let name = url.lastPathComponent.lowercased()
        let prefixes = [
            "screenshot", "screen shot", "screen recording",
            "capture d’écran", "capture d'écran", "enregistrement de l’écran", "enregistrement de l'écran",
            "bildschirmfoto", "bildschirmaufnahme", "captura de pantalla", "schermafbeelding", "istantanea",
        ]
        return prefixes.contains { name.hasPrefix($0) }
    }
}

/// Reads the system screenshot settings fresh each time (UserDefaults would cache a stale copy).
func screencapturePreference(_ key: String) -> Any? {
    let domain = "com.apple.screencapture" as CFString
    CFPreferencesAppSynchronize(domain)
    return CFPreferencesCopyAppValue(key as CFString, domain)
}

enum Thumbnailer {
    static func make(_ url: URL, attempt: Int = 0, completion: @escaping (NSImage?) -> Void) {
        let request = QLThumbnailGenerator.Request(
            fileAt: url, size: CGSize(width: 320, height: 640),
            scale: NSScreen.main?.backingScaleFactor ?? 2, representationTypes: .thumbnail
        )
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { rep, _ in
            DispatchQueue.main.async {
                if let image = rep?.nsImage {
                    completion(image)
                } else if attempt < 5 {
                    // Fresh captures can still be settling on disk.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        make(url, attempt: attempt + 1, completion: completion)
                    }
                } else {
                    completion(NSImage(contentsOf: url))
                }
            }
        }
    }
}
