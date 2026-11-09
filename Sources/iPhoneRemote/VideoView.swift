import SwiftUI
import AVFoundation
#if SWIFT_PACKAGE
import RemoteCore
#endif

struct VideoView: NSViewRepresentable {
    let capture: CaptureService
    let size: CGSize
    let interactive: Bool
    let onGesture: (CGPoint, CGPoint, Double, Double) -> Void
    let onText: (String) -> Void
    let onReturn: () -> Void
    func makeNSView(context: Context) -> PhoneVideoView {
        let view = PhoneVideoView()
        view.preview.session = capture.session
        return view
    }
    func updateNSView(_ view: PhoneVideoView, context: Context) {
        view.imageSize = size
        view.interactive = interactive
        view.onGesture = onGesture
        view.onText = onText
        view.onReturn = onReturn
    }
}

final class PhoneVideoView: NSView, NSTextInputClient {
    let preview = AVCaptureVideoPreviewLayer()
    var imageSize = CGSize.zero
    var interactive = false {
        didSet { if !interactive { clearComposition() } }
    }
    private var interpretingComposition = false
    private var marked = NSAttributedString(string: "")
    private var markedSelection = NSRange(location: 0, length: 0)
    private let compositionLabel = CATextLayer()
    var onGesture: ((CGPoint, CGPoint, Double, Double) -> Void)?
    var onText: ((String) -> Void)?
    var onReturn: (() -> Void)?
    private var start: CGPoint?
    private var startTime = 0.0
    private var lastScrollTime = 0.0
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        preview.videoGravity = .resizeAspect
        layer?.addSublayer(preview)
        compositionLabel.fontSize = 16
        compositionLabel.alignmentMode = .center
        compositionLabel.foregroundColor = NSColor.white.cgColor
        compositionLabel.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
        compositionLabel.cornerRadius = 6
        compositionLabel.isHidden = true
        layer?.addSublayer(compositionLabel)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        preview.frame = bounds
        compositionLabel.contentsScale = window?.backingScaleFactor ?? 2
        compositionLabel.frame = CGRect(x: 40, y: max(0, bounds.height - 90), width: max(0, bounds.width - 80), height: 28)
        if let connection = preview.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
        CATransaction.commit()
    }
    private func point(_ event: NSEvent) -> CGPoint? {
        ScreenGeometry.normalized(convert(event.locationInWindow, from: nil), in: ScreenGeometry.fittedRect(image: imageSize, bounds: bounds))
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        guard interactive else { start = nil; return }
        start = point(event); startTime = event.timestamp
    }
    override func mouseUp(with event: NSEvent) {
        defer { start = nil }
        guard interactive, let start, let end = point(event) else { return }
        let duration = event.timestamp - startTime
        let distance = hypot((end.x-start.x) * bounds.width, (end.y-start.y) * bounds.height)
        if distance < 5 {
            onGesture?(start, start, duration >= 0.45 ? duration : 0, 0)
        } else {
            onGesture?(start, end, 0, min(max(duration, 0.12), 0.25))
        }
    }
    override func rightMouseDown(with event: NSEvent) {
        guard interactive, let p = point(event) else { return }
        onGesture?(p, p, 0.8, 0)
    }
    override func scrollWheel(with event: NSEvent) {
        guard interactive, event.timestamp - lastScrollTime > 0.12,
              event.momentumPhase == [], let p = point(event),
              abs(event.scrollingDeltaY) + abs(event.scrollingDeltaX) > 1 else { return }
        lastScrollTime = event.timestamp
        // Each wheel burst becomes a bounded swipe; never enqueue trackpad momentum.
        let dx = event.scrollingDeltaX == 0 ? 0 : (event.scrollingDeltaX > 0 ? 0.18 : -0.18)
        let dy = event.scrollingDeltaY == 0 ? 0 : (event.scrollingDeltaY > 0 ? 0.22 : -0.22)
        let target = CGPoint(x: min(max(p.x + dx, 0.02), 0.98), y: min(max(p.y + dy, 0.02), 0.98))
        onGesture?(p, target, 0, 0.18)
    }
    override func keyDown(with event: NSEvent) {
        guard interactive else { super.keyDown(with: event); return }
        if event.modifierFlags.contains(.command) {
            if event.charactersIgnoringModifiers == "v", let text = NSPasteboard.general.string(forType: .string) { onText?(text) }
            else { super.keyDown(with: event) }
            return
        }
        if hasMarkedText() {
            interpretingComposition = true
            interpretKeyEvents([event])
            interpretingComposition = false
            return
        }
        switch event.keyCode {
        case 51: onText?("\u{8}")
        case 36, 76:
            guard !event.isARepeat else { return }
            if event.modifierFlags.contains(.shift) { onText?("\n") }
            else { onReturn?() }
        case 48: onText?("\t")
        default:
            if !event.modifierFlags.contains(.control) { interpretKeyEvents([event]) }
        }
    }
    private func clearComposition() {
        marked = NSAttributedString(string: ""); markedSelection = NSRange(location: 0, length: 0)
        compositionLabel.string = nil; compositionLabel.isHidden = true
    }
    func insertText(_ string: Any, replacementRange: NSRange) {
        let value = (string as? NSAttributedString)?.string ?? (string as? String ?? "")
        clearComposition()
        if interactive, !value.isEmpty { onText?(value) }
    }
    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        guard interactive else { return }
        marked = (string as? NSAttributedString) ?? NSAttributedString(string: string as? String ?? "")
        markedSelection = selectedRange
        compositionLabel.string = marked.string; compositionLabel.isHidden = marked.length == 0
        needsLayout = true
    }
    func unmarkText() {
        let value = marked.string
        clearComposition()
        if interactive, !value.isEmpty { onText?(value) }
    }
    func selectedRange() -> NSRange { markedSelection }
    func markedRange() -> NSRange { hasMarkedText() ? NSRange(location: 0, length: marked.length) : NSRange(location: NSNotFound, length: 0) }
    func hasMarkedText() -> Bool { marked.length > 0 }
    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        guard range.location != NSNotFound, range.location <= marked.length else { return nil }
        let valid = NSIntersectionRange(range, NSRange(location: 0, length: marked.length))
        actualRange?.pointee = valid
        return marked.attributedSubstring(from: valid)
    }
    func validAttributesForMarkedText() -> [NSAttributedString.Key] { [] }
    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        actualRange?.pointee = markedRange()
        let local = NSRect(x: bounds.midX, y: max(0, bounds.height - 95), width: 1, height: 28)
        return window?.convertToScreen(convert(local, to: nil)) ?? .zero
    }
    func characterIndex(for point: NSPoint) -> Int { 0 }
    override func doCommand(by selector: Selector) {
        switch NSStringFromSelector(selector) {
        case "deleteBackward:": onText?("\u{8}")
        case "insertNewline:", "insertNewlineIgnoringFieldEditor:":
            guard !interpretingComposition else { return }
            if NSEvent.modifierFlags.contains(.shift) { onText?("\n") } else { onReturn?() }
        case "insertTab:": onText?("\t")
        case "cancelOperation:": clearComposition()
        default: break
        }
    }

}
