import AppKit
import Combine

enum RemoteAction: String, CaseIterable, Codable, Identifiable {
    case home, apps, notifications, controlCenter, pause, screenshot, recording
    var id: String { rawValue }
    var title: String {
        switch self {
        case .home: return "Home"
        case .apps: return "App aperte"
        case .notifications: return "Notifiche"
        case .controlCenter: return "Centro di Controllo"
        case .pause: return "Sospendi / riprendi controllo"
        case .screenshot: return "Salva screenshot"
        case .recording: return "Avvia / ferma registrazione"
        }
    }
}
struct RemoteShortcut: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt
    var key: String
    var label: String {
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        return (flags.contains(.control) ? "⌃" : "") + (flags.contains(.option) ? "⌥" : "") +
            (flags.contains(.shift) ? "⇧" : "") + (flags.contains(.command) ? "⌘" : "") + key.uppercased()
    }
}

/// Local shortcuts only: no global keyboard monitor or Accessibility permission.
@MainActor final class Shortcuts: ObservableObject {
    @Published private(set) var bindings: [RemoteAction: RemoteShortcut]
    @Published var editing: RemoteAction?
    @Published private(set) var message = "Scorciatoie attive soltanto in iPhone Remote."
    var onAction: ((RemoteAction) -> Void)?
    private var monitor: Any?
    private let defaults: UserDefaults
    private let isAppWindowActive: @MainActor () -> Bool
    static let flags: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
    static var standard: [RemoteAction: RemoteShortcut] {
        let codes: [UInt16] = [18, 19, 20, 21, 29, 23, 22]
        let keys = ["1", "2", "3", "4", "0", "5", "6"]
        return Dictionary(uniqueKeysWithValues: zip(RemoteAction.allCases, zip(codes, keys)).map {
            ($0.0, RemoteShortcut(keyCode: $0.1.0, modifiers: NSEvent.ModifierFlags([.command, .option]).rawValue, key: $0.1.1))
        })
    }
    init(defaults: UserDefaults = .standard,
         isAppWindowActive: (@MainActor () -> Bool)? = nil) {
        self.defaults = defaults
        self.isAppWindowActive = isAppWindowActive ?? { NSApp.isActive && NSApp.keyWindow != nil && NSApp.modalWindow == nil }
        if let data = defaults.data(forKey: "remoteShortcuts"),
           let saved = try? JSONDecoder().decode([RemoteAction: RemoteShortcut].self, from: data) {
            bindings = saved
        } else { bindings = Self.standard }
    }
    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            var result: NSEvent? = event
            MainActor.assumeIsolated { if let self { result = self.handle(event) } }
            return result
        }
    }
    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil; editing = nil; onAction = nil
    }
    func reset() {
        bindings = Self.standard; editing = nil; save()
        message = "Scorciatoie predefinite ripristinate."
    }
    func handle(_ event: NSEvent) -> NSEvent? {
        guard isAppWindowActive() else { return event }
        let modifiers = event.modifierFlags.intersection(Self.flags)
        if let editing {
            if event.keyCode == 53 { self.editing = nil; return nil }
            guard !event.isARepeat else { return nil }
            guard !modifiers.intersection([.command, .option, .control]).isEmpty,
                  let characters = event.charactersIgnoringModifiers, !characters.isEmpty else {
                message = "Usa almeno ⌘, ⌥ o ⌃. Esc annulla."; return nil
            }
            let binding = RemoteShortcut(keyCode: event.keyCode, modifiers: modifiers.rawValue,
                                         key: characters == " " ? "Spazio" : characters)
            guard !bindings.contains(where: { $0.key != editing && $0.value.keyCode == binding.keyCode && $0.value.modifiers == binding.modifiers }) else {
                message = "Questa combinazione è già assegnata."; return nil
            }
            // Keep the system's app/window shortcuts and sidebar toggle available.
            guard !(modifiers == .command && [12, 13, 4, 46].contains(event.keyCode)),
                  !(modifiers == [.control, .command] && event.keyCode == 1) else {
                message = "Combinazione riservata al Mac o alla sidebar."; return nil
            }
            bindings[editing] = binding; self.editing = nil; save()
            message = "Scorciatoia salvata."; return nil
        }
        guard NSApp.keyWindow?.sheetParent == nil, NSApp.keyWindow?.attachedSheet == nil else { return event }
        if let action = RemoteAction.allCases.first(where: {
            bindings[$0]?.keyCode == event.keyCode && bindings[$0]?.modifiers == modifiers.rawValue
        }) {
            if !event.isARepeat { onAction?(action) }
            return nil
        }
        return event
    }
    private func save() { defaults.set(try? JSONEncoder().encode(bindings), forKey: "remoteShortcuts") }
}
