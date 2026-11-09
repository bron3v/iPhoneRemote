import Foundation
import Combine
#if SWIFT_PACKAGE
import RemoteCore
#endif

@MainActor final class RemoteModel: ObservableObject {
    @Published private(set) var connected = false
    @Published private(set) var busy = false
    @Published private(set) var inputNotice: String?
    @Published private(set) var unconfirmedText = ""
    @Published private(set) var pendingCount = 0
    @Published private(set) var lastLatencyMS: Int?
    @Published private(set) var wantsConnection = true
    @Published var automaticReconnect = true
    private var generation = 0
    private var nextReconnect = Date.distantPast
    private var reconnectFailures = 0
    private var healthChecking = false
    private var lastHealthCheck = Date.distantPast
    @Published private(set) var message = "WDA non collegato · prima configura e avvia il runner firmato."
    @Published private(set) var controlEnabled = false
    @Published var controlRequested = true {
        didSet { reconcileControl() }
    }
    @Published var localInputSuspended = false { didSet { reconcileControl() } }
    private var inputReady = false
    let client: WDAClient
    init(client: WDAClient = WDAClient()) { self.client = client }
    private var videoSize = CGSize.zero
    private enum Command {
        case action((WDAClient) async throws -> Void)
        case text(String)
        case submit
    }
    private var pending: [Command] = []
    private var activeText: String?
    private let maximumPending = 2
    func updateVideoSize(_ size: CGSize) { videoSize = size }
    func updateReadiness(videoReady: Bool, singleUSBPhone: Bool) {
        inputReady = videoReady && singleUSBPhone
        reconcileControl()
    }
    private func reconcileControl() {
        controlEnabled = controlRequested && connected && inputReady && !localInputSuspended
        if !controlEnabled { discardPendingText() }
    }
    func connect() {
        wantsConnection = true
        guard !busy, !connected else { return }
        let token = generation
        busy = true
        Task {
            guard token == generation, wantsConnection else { return }
            do {
                let size = try await client.connect()
                guard token == generation else { return }
                connected = true
                reconnectFailures = 0
                reconcileControl()
                message = "WDA collegato · \(Int(size.width)) × \(Int(size.height)) punti"
            } catch {
                guard token == generation else { return }
                connected = false; controlEnabled = false; message = error.localizedDescription
                reconnectFailures += 1
                nextReconnect = Date().addingTimeInterval(min(pow(2, Double(reconnectFailures)), 30))
            }
            guard token == generation else { return }
            busy = false
        }
    }
    func disconnect() {
        wantsConnection = false
        retainActiveText()
        generation += 1; busy = false
        connected = false; controlEnabled = false; discardPendingText()
        Task { await client.disconnect() }
        message = "WDA scollegato"
    }
    func disableControl() { inputReady = false; reconcileControl() }
    func discardPendingText() {
        let text = pending.compactMap { command -> String? in if case let .text(value) = command { return value }; return nil }.joined()
        if !text.isEmpty {
            unconfirmedText += text
            inputNotice = "Digitazione interrotta: testo conservato, senza reinviarlo automaticamente."
        }
        pending.removeAll(); pendingCount = 0
    }
    private func retainActiveText() {
        if let activeText {
            unconfirmedText += activeText
            inputNotice = "Esito della digitazione incerto: testo conservato. Controlla l’iPhone prima di reinserirlo."
            self.activeText = nil
        }
    }
    func dismissNotice() { inputNotice = nil }
    func clearUnconfirmedText() { unconfirmedText = "" }
    func connectionLost(_ reason: String) {
        guard connected || busy else { return }
        retainActiveText()
        generation += 1; busy = false; healthChecking = false
        connected = false; controlEnabled = false; discardPendingText()
        message = reason
        nextReconnect = Date().addingTimeInterval(2)
    }
    /// Called by the UI heartbeat; reconnects sessions, never replays input.
    func maintainConnection(transportReady: Bool, singleUSBPhone: Bool) {
        if !singleUSBPhone { connectionLost("iPhone USB scollegato. In attesa della riconnessione…"); return }
        guard wantsConnection, automaticReconnect, transportReady else { return }
        if !connected, !busy, Date() >= nextReconnect { connect(); return }
        guard connected, !busy, !healthChecking, Date().timeIntervalSince(lastHealthCheck) >= 5 else { return }
        healthChecking = true; lastHealthCheck = Date()
        let token = generation
        Task {
            do { try await client.checkConnection() }
            catch { if token == generation { connectionLost("Controllo interrotto. Tento la riconnessione…") } }
            if token == generation { healthChecking = false }
        }
    }
    @discardableResult func type(_ text: String) -> Bool {
        guard connected, controlEnabled, !text.isEmpty else { return false }
        let queuedCharacters = pending.reduce(0) { total, command in
            if case let .text(value) = command { return total + value.utf16.count }; return total
        }
        guard queuedCharacters + text.utf16.count <= 32768, pending.count < 64 else {
            unconfirmedText += text
            inputNotice = "Digitazione troppo rapida: testo conservato. Attendi che la coda si svuoti."
            return false
        }
        if let last = pending.last, case let .text(previous) = last {
            pending[pending.count - 1] = .text(previous + text)
        } else {
            pending.append(.text(text))
        }
        pendingCount = pending.count
        executeNext()
        return true
    }
    func pressReturn() {
        guard connected, controlEnabled else { return }
        guard pending.count < maximumPending else {
            inputNotice = "Attendi la fine della digitazione, poi premi Invio."
            return
        }
        pending.append(.submit); pendingCount = pending.count
        executeNext()
    }
    func perform(_ action: @escaping (WDAClient) async throws -> Void) {
        guard connected, controlEnabled else { return }
        guard pending.count < maximumPending else {
            inputNotice = "Gesto non accodato: attendi il comando in corso."; return
        }
        pending.append(.action(action)); pendingCount = pending.count
        executeNext()
    }
    private func executeNext() {
        guard !busy, connected, controlEnabled, !pending.isEmpty else { return }
        let command = pending.removeFirst()
        if case let .text(value) = command { activeText = value }
        pendingCount = pending.count
        let token = generation
        let started = Date()
        busy = true
        Task {
            guard token == generation else { return }
            guard connected, controlEnabled else { retainActiveText(); busy = false; executeNext(); return }
            do {
                var completion = "Comando completato"
                switch command {
                case let .action(action): try await action(client)
                case let .text(text): try await client.type(text)
                case .submit:
                    switch try await client.pressReturn() {
                    case .sent: completion = "Pulsante Invia attivato"
                    case .newline: completion = "A capo inserito"
                    case .unavailable: completion = "Invia non riconosciuto: usa il pulsante della chat. ⇧Invio per andare a capo."
                    }
                }
                guard token == generation else { return }
                lastLatencyMS = Int(Date().timeIntervalSince(started) * 1000)
                activeText = nil
                message = completion
                if completion.hasPrefix("Invia non riconosciuto") { inputNotice = completion }
            } catch {
                // No gesture retry; discard pending input after any ambiguous failure.
                guard token == generation else { return }
                retainActiveText()
                connected = false; controlEnabled = false; discardPendingText()
                nextReconnect = Date().addingTimeInterval(2)
                message = error.localizedDescription
            }
            guard token == generation else { return }
            busy = false
            executeNext()
        }
    }
    func gesture(from: CGPoint, to: CGPoint, hold: Double, move: Double, endHold: Double = 0) {
        let size = videoSize
        perform { try await $0.gesture(from: from, to: to, hold: hold, move: move, endHold: endHold, videoSize: size) }
    }
}
