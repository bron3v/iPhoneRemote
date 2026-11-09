import AppKit
import AVFoundation
import ImageIO

@main struct ExperienceCheck {
    static func sample(_ index: Int, width: Int = 320, height: Int = 480) -> CMSampleBuffer {
        var buffer: CVPixelBuffer?
        precondition(CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
                                        [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &buffer) == kCVReturnSuccess)
        let pixel = buffer!
        CVPixelBufferLockBaseAddress(pixel, [])
        memset(CVPixelBufferGetBaseAddress(pixel), Int32(index % 255), CVPixelBufferGetDataSize(pixel))
        CVPixelBufferUnlockBaseAddress(pixel, [])
        var format: CMVideoFormatDescription?
        precondition(CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixel, formatDescriptionOut: &format) == noErr)
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30), presentationTimeStamp: CMTime(value: Int64(index), timescale: 30), decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        precondition(CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixel, formatDescription: format!, sampleTiming: &timing, sampleBufferOut: &sample) == noErr)
        return sample!
    }
    @MainActor static func main() async throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 800, height: 650), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let phone = PhoneVideoView(frame: NSRect(x: 0, y: 0, width: 300, height: 600))
        window.contentView = phone
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        phone.interactive = true
        var committed: [String] = []
        var returns = 0
        phone.onText = { committed.append($0) }
        phone.onReturn = { returns += 1 }
        phone.setMarkedText("e", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        precondition(committed.isEmpty && phone.hasMarkedText(), "Composition must not reach WDA before commit")
        phone.insertText(NSAttributedString(string: "é 👩🏽‍💻"), replacementRange: NSRange(location: 0, length: 1))
        precondition(committed == ["é 👩🏽‍💻"] && !phone.hasMarkedText())
        phone.setMarkedText("中", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        phone.interactive = false
        precondition(!phone.hasMarkedText() && committed.count == 1, "Disabling input must discard unfinished composition")
        phone.interactive = true
        let returnEvent = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 1, windowNumber: window.windowNumber, context: nil, characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36)!
        phone.keyDown(with: returnEvent)
        precondition(returns == 1)
        let repeatReturn = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 2, windowNumber: window.windowNumber, context: nil, characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: true, keyCode: 36)!
        phone.keyDown(with: repeatReturn)
        precondition(returns == 1, "Held Return must not send repeatedly")
        print("PASS: marked composition, Unicode commit, cancellation and Return autorepeat")

        let suite = "it.local.iphoneremote.featurecheck.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let shortcuts = Shortcuts(defaults: defaults, isAppWindowActive: { true })
        var actions: [RemoteAction] = []
        shortcuts.onAction = { actions.append($0) }
        for _ in 0..<20 where !app.isActive { try await Task.sleep(nanoseconds: 20_000_000) }
        let shortcut = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.command, .option], timestamp: 3, windowNumber: window.windowNumber, context: nil, characters: "1", charactersIgnoringModifiers: "1", isARepeat: false, keyCode: 18)!
        precondition(shortcuts.handle(shortcut) == nil && actions == [.home], "Local shortcut must consume its event")
        shortcuts.editing = .apps
        precondition(shortcuts.handle(shortcut) == nil && shortcuts.editing == .apps, "Duplicate binding rejected")
        let custom = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.control, .option], timestamp: 4, windowNumber: window.windowNumber, context: nil, characters: "a", charactersIgnoringModifiers: "a", isARepeat: false, keyCode: 0)!
        _ = shortcuts.handle(custom)
        precondition(shortcuts.editing == nil)
        let restored = Shortcuts(defaults: defaults, isAppWindowActive: { true })
        precondition(restored.bindings[.apps] == shortcuts.bindings[.apps], "Custom shortcuts persist")
        print("PASS: shortcut dispatch, conflict rejection and persistence")

        let probe = WindowProbe(frame: .zero)
        phone.addSubview(probe)
        probe.compact = true; probe.onTop = true; probe.phoneSize = CGSize(width: 393, height: 852); probe.apply()
        precondition(window.level == .floating && abs(window.contentAspectRatio.width / window.contentAspectRatio.height - 393.0 / 852.0) < 0.001)
        probe.compact = false; probe.onTop = false; probe.apply()
        precondition(window.level == .normal && window.resizeIncrements == NSSize(width: 1, height: 1))
        print("PASS: compact aspect ratio, normal resize restoration and floating window")
        window.close()

        let clicks = PillClickCoordinator(interval: 0.03)
        var navigation: [String] = []
        clicks.mouseUp(clickCount: 1, single: { navigation.append("home") }, double: { navigation.append("apps") })
        precondition(navigation.isEmpty, "Single click must wait for possible double click")
        try await Task.sleep(nanoseconds: 60_000_000)
        precondition(navigation == ["home"])
        navigation.removeAll()
        clicks.mouseUp(clickCount: 1, single: { navigation.append("home") }, double: { navigation.append("apps") })
        clicks.mouseDown(clickCount: 2)
        try await Task.sleep(nanoseconds: 60_000_000)
        precondition(navigation.isEmpty, "Holding the second click must cancel the pending Home")
        clicks.mouseUp(clickCount: 2, single: { navigation.append("home") }, double: { navigation.append("apps") })
        precondition(navigation == ["apps"], "Double click must not run Home first")
        navigation.removeAll()
        clicks.mouseUp(clickCount: 1, single: { navigation.append("home") }, double: { navigation.append("apps") })
        clicks.cancel()
        try await Task.sleep(nanoseconds: 60_000_000)
        precondition(navigation.isEmpty, "Disabled or detached control must cancel pending navigation")
        clicks.mouseUp(clickCount: 1, single: { navigation.append("notifications") }, double: nil)
        precondition(navigation == ["notifications"], "Status controls should activate immediately")
        let pill = NavigationPillControl(frame: NSRect(x: 40, y: 40, width: 80, height: 16))
        phone.addSubview(pill)
        pill.single = { navigation.append("accessible-home") }
        precondition(pill.hitTest(NSPoint(x: 80, y: 48)) === pill, "Pill clicks must not reach the video underneath")
        pill.updateEnabled(false)
        precondition(!pill.accessibilityPerformPress())
        pill.updateEnabled(true)
        precondition(pill.accessibilityPerformPress() && navigation.last == "accessible-home")
        print("PASS: single vs double click, held second click, cancellation, immediate status controls and gated native hit testing")

        let queue = DispatchQueue(label: "featurecheck.capture")
        let archive = CaptureArchive(queue: queue)
        let folder = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("build/FeatureChecks/\(UUID().uuidString)")
        queue.sync { archive.consume(sample(0)) }
        archive.screenshot(in: folder)
        for _ in 0..<100 where archive.lastSavedURL == nil { try await Task.sleep(nanoseconds: 20_000_000) }
        let png = archive.lastSavedURL!
        let image = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(png as CFURL, nil)!, 0, nil)!
        precondition(image.width == 320 && image.height == 480)
        archive.start(in: folder)
        for index in 1...40 {
            queue.sync { archive.consume(sample(index)) }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        await withCheckedContinuation { continuation in archive.stop { continuation.resume() } }
        precondition(!archive.isRecording && !archive.isFinishing)
        let movie = archive.lastSavedURL!
        precondition(movie.pathExtension == "mov", archive.message)
        let asset = AVURLAsset(url: movie)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        precondition(CMTimeGetSeconds(duration) > 0.8 && tracks.count == 1)
        let size = try await tracks[0].load(.naturalSize)
        precondition(size == CGSize(width: 320, height: 480))
        print("PASS: real PNG decode and playable H.264 MOV (\(CMTimeGetSeconds(duration)) s); finish callback waits for file finalization")
        archive.start(in: folder)
        queue.async { archive.consume(sample(42, width: 480, height: 320)) }
        for _ in 0..<100 where archive.isRecording || archive.isFinishing { try await Task.sleep(nanoseconds: 20_000_000) }
        precondition(!archive.isRecording && !archive.isFinishing && archive.message.contains("orientamento"), archive.message)
        print("PASS: recording closes cleanly on orientation change")
        print("Artifacts: \(folder.path)")
    }
}
