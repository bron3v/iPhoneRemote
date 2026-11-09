import SwiftUI
import AppKit
#if SWIFT_PACKAGE
import RemoteCore
#endif

/// Waits for the system double-click interval; a second mouse-down cancels Home.
@MainActor final class PillClickCoordinator {
    private let interval: TimeInterval
    private var pending: Task<Void, Never>?
    init(interval: TimeInterval? = nil) { self.interval = interval ?? NSEvent.doubleClickInterval }
    func cancel() { pending?.cancel(); pending = nil }
    func mouseDown(clickCount: Int) { if clickCount >= 2 { cancel() } }
    func mouseUp(clickCount: Int, single: @escaping () -> Void, double: (() -> Void)?) {
        cancel()
        if clickCount == 2 { double?(); return }
        guard clickCount == 1 else { return }
        guard double != nil else { single(); return }
        pending = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(max(0, interval) * 1_000_000_000))
                guard !Task.isCancelled else { return }
                single()
            } catch { }
        }
    }
    deinit { pending?.cancel() }
}

struct NavigationPillFace: View {
    let icon: String
    var disclosure = false
    var highlighted = false
    var pressed = false
    var enabled = true
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: max(4, geometry.size.height * 0.28)) {
                Image(systemName: icon)
                    .font(.system(size: max(7, geometry.size.height * 0.53), weight: .semibold))
                if disclosure {
                    Image(systemName: "chevron.down")
                        .font(.system(size: max(5, geometry.size.height * 0.32), weight: .bold))
                }
            }
            .foregroundStyle(.white.opacity(0.95))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial, in: Capsule())
            .background(.black.opacity(0.35), in: Capsule())
            .overlay(Capsule().fill(.white.opacity(pressed ? 0.20 : (highlighted ? 0.10 : 0.025))))
            .overlay(Capsule().strokeBorder(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.08)], startPoint: .top, endPoint: .bottom), lineWidth: 0.7))
            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            .opacity(enabled ? 1 : 0.4)
        }
        .environment(\.colorScheme, .dark)
        .allowsHitTesting(false)
    }
}
struct NavigationPill: NSViewRepresentable {
    let title: String
    let icon: String
    var disclosure = false
    let enabled: Bool
    let single: () -> Void
    var double: (() -> Void)? = nil
    func makeNSView(context: Context) -> NavigationPillControl { NavigationPillControl() }
    func updateNSView(_ view: NavigationPillControl, context: Context) {
        view.icon = icon; view.disclosure = disclosure
        view.single = single; view.double = double
        view.toolTip = title; view.setAccessibilityLabel(title)
        view.updateEnabled(enabled)
        view.updateAccessibilityActions()
        view.refreshAppearance()
    }
    static func dismantleNSView(_ view: NavigationPillControl, coordinator: ()) { view.cancelPendingClick() }
}

final class NavigationPillControl: NSControl {
    var icon = "house.fill"
    var disclosure = false
    var single: (() -> Void)?
    var double: (() -> Void)?
    private var hovered = false
    private var pressed = false
    private let clicks = PillClickCoordinator()
    private let host = NSHostingView(rootView: NavigationPillFace(icon: "house.fill"))
    private var tracking: NSTrackingArea?
    private var resignObserver: NSObjectProtocol?
    override var acceptsFirstResponder: Bool { false }
    override init(frame: NSRect) {
        super.init(frame: frame)
        host.frame = bounds; host.autoresizingMask = [.width, .height]
        addSubview(host)
        setAccessibilityElement(true); setAccessibilityRole(.button)

    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func hitTest(_ point: NSPoint) -> NSView? {
        // The AppKit control owns its hit area, so no click reaches the phone view below.
        guard !isHidden, bounds.contains(convert(point, from: superview)) else { return nil }
        return self
    }
    func updateEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled { cancelPendingClick() }
    }
    func updateAccessibilityActions() {
        guard double != nil else { setAccessibilityCustomActions([]); return }
        setAccessibilityCustomActions([NSAccessibilityCustomAction(name: "Mostra app aperte", handler: { [weak self] in
            guard let self, self.isEnabled, let action = self.double else { return false }
            self.cancelPendingClick(); action(); return true
        })])
    }
    func refreshAppearance() {
        host.rootView = NavigationPillFace(icon: icon, disclosure: disclosure, highlighted: hovered, pressed: pressed, enabled: isEnabled)
    }
    func cancelPendingClick() { clicks.cancel(); pressed = false; refreshAppearance() }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
        addTrackingArea(area); tracking = area
    }
    override func mouseEntered(with event: NSEvent) { hovered = true; refreshAppearance() }
    override func mouseExited(with event: NSEvent) { hovered = false; refreshAppearance() }
    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        clicks.mouseDown(clickCount: event.clickCount)
        pressed = true; refreshAppearance()
    }
    override func mouseDragged(with event: NSEvent) {
        pressed = bounds.contains(convert(event.locationInWindow, from: nil)); refreshAppearance()
    }
    override func mouseUp(with event: NSEvent) {
        pressed = false; refreshAppearance()
        guard isEnabled, bounds.contains(convert(event.locationInWindow, from: nil)) else { clicks.cancel(); return }
        clicks.mouseUp(clickCount: event.clickCount, single: { [weak self] in
            guard let self, self.isEnabled, self.window?.isKeyWindow == true else { return }
            self.single?()
        }, double: double == nil ? nil : { [weak self] in
            guard let self, self.isEnabled, self.window?.isKeyWindow == true else { return }
            self.double?()
        })
    }
    override func accessibilityPerformPress() -> Bool {
        guard isEnabled else { return false }
        clicks.cancel(); single?(); return true
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        clicks.cancel()
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        resignObserver = nil
        if let window {
            resignObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in
                self?.cancelPendingClick()
            }
        }
    }
    deinit { if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) } }
}

struct PhoneNavigationOverlay: View {
    let imageSize: CGSize
    let enabled: Bool
    let scale: Double
    let opacity: Double
    let notifications: () -> Void
    let controlCenter: () -> Void
    let home: () -> Void
    let apps: () -> Void
    var body: some View {
        GeometryReader { geometry in
            let layout = NavigationOverlayGeometry.layout(image: imageSize, bounds: CGRect(origin: .zero, size: geometry.size), scale: scale)
            pill(title: "Notifiche", icon: "bell.fill", disclosure: true, frame: layout.notifications, action: notifications)
            pill(title: "Centro di Controllo", icon: "slider.horizontal.3", disclosure: true, frame: layout.controlCenter, action: controlCenter)
            NavigationPill(title: "Home · doppio clic: app aperte", icon: "house.fill", enabled: enabled, single: home, double: apps)
                .frame(width: layout.home.width, height: layout.home.height)
                .position(x: layout.home.midX, y: layout.home.midY)
        }.opacity(opacity)
    }
    private func pill(title: String, icon: String, disclosure: Bool, frame: CGRect, action: @escaping () -> Void) -> some View {
        NavigationPill(title: title, icon: icon, disclosure: disclosure, enabled: enabled, single: action)
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
    }
}
