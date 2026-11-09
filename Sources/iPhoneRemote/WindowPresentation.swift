import SwiftUI
import AppKit

/// AppKit owns window geometry; the video and input keep the same aspect-fit mapping.
struct WindowPresentation: NSViewRepresentable {
    let compact: Bool
    let onTop: Bool
    let phoneSize: CGSize
    var sidebarVisible = true
    func makeNSView(context: Context) -> WindowProbe { WindowProbe() }
    func updateNSView(_ view: WindowProbe, context: Context) {
        view.compact = compact; view.onTop = onTop; view.phoneSize = phoneSize; view.sidebarVisible = sidebarVisible
        DispatchQueue.main.async { view.apply() }
    }
}
final class WindowProbe: NSView {
    var sidebarVisible = true
    var compact = false
    var onTop = false
    var phoneSize = CGSize.zero
    private var appliedCompact: Bool?
    private var appliedRatio: CGFloat = 0
    private weak var configuredWindow: NSWindow?
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); apply() }
    func apply() {
        guard let window else { return }
        if configuredWindow !== window {
            configuredWindow = window
            _ = window.setFrameUsingName("iPhoneRemoteMainWindow")
            window.setFrameAutosaveName("iPhoneRemoteMainWindow")
        }
        window.level = onTop ? .floating : .normal
        guard !window.styleMask.contains(.fullScreen) else { return }
        if !compact { window.contentMinSize = NSSize(width: sidebarVisible ? 800 : 280, height: 480) }
        let ratio = phoneSize.width > 0 && phoneSize.height > 0 ? phoneSize.width / phoneSize.height : 393.0 / 852.0
        guard appliedCompact != compact || (compact && abs(appliedRatio - ratio) > 0.01) else { return }
        let wasCompact = appliedCompact
        appliedCompact = compact; appliedRatio = ratio
        if compact {
            if wasCompact == false { UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: "expandedWindowFrame") }
            let visible = window.screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let height = min(max(window.contentLayoutRect.height, 480), visible.height - 70)
            let width = max(240, height * ratio)
            window.contentMinSize = NSSize(width: 240, height: 240 / ratio)
            window.contentAspectRatio = NSSize(width: ratio, height: 1)
            window.setContentSize(NSSize(width: width, height: height))
            if !visible.contains(window.frame) {
                var frame = window.frame
                frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
                frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - frame.height)
                window.setFrame(frame, display: true)
            }
        } else {
            window.resizeIncrements = NSSize(width: 1, height: 1)
            window.contentMinSize = NSSize(width: sidebarVisible ? 800 : 280, height: 480)
            if wasCompact == true, let saved = UserDefaults.standard.string(forKey: "expandedWindowFrame") {
                window.setFrame(NSRectFromString(saved), display: true)
            }
        }
    }
}
