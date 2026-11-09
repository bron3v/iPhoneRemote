import AppKit
import Combine
import Foundation
import Security
#if SWIFT_PACKAGE
import RemoteCore
#endif

/// Owns only the processes it starts; no login item, daemon, or global Xcode changes.
@MainActor final class LocalAutomation: ObservableObject {
    struct Setup: Decodable {
        let udid: String
        let teamID: String
        let developerDirectory: String
    }
    @Published private(set) var ready = false
    @Published private(set) var starting = false
    @Published private(set) var profileExpiry: Date?
    @Published private(set) var renewing = false
    @Published private(set) var requiresUserAction = false
    private var forceRenewal = false
    private var retryAt = Date.distantPast
    private var retryCount = 0
    private var nextProbe = Date.distantPast
    private var probing = false
    private var healthFailures = 0
    private var lifecycle = 0
    private var activeProducts: URL?
    @Published private(set) var message = "In attesa dell’iPhone USB…"
    private let setup: Setup?
    private let resources: URL?
    private let support: URL
    var isConfigured: Bool { setup != nil }
    private var whenReady: (() -> Void)?
    private var attempted = false
    private var task: Task<Void, Never>?
    private var runner: Process?
    private var tunnel: Process?
    private var handles: [FileHandle] = []
    private let http: URLSession

    init() {
        resources = Bundle.main.resourceURL?.appendingPathComponent("DeviceAutomation")
        if let url = resources?.appendingPathComponent("Setup.plist"), let data = try? Data(contentsOf: url) {
            setup = try? PropertyListDecoder().decode(Setup.self, from: data)
        } else { setup = nil }
        support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("iPhone Remote")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 1
        configuration.timeoutIntervalForResource = 2
        configuration.connectionProxyDictionary = [:]
        http = URLSession(configuration: configuration)
        refreshProfileExpiry()
    }
    var profileWarning: String? {
        guard let profileExpiry else { return nil }
        let remaining = profileExpiry.timeIntervalSinceNow
        if remaining <= 0 { return "Firma scaduta: rinnova per riavviare il controllo." }
        if remaining <= 2 * 86400 { return "Firma in scadenza entro due giorni." }
        return nil
    }
    func renew(onReady: @escaping () -> Void) {
        guard !starting else { return }
        stop()
        forceRenewal = true
        start(onReady: onReady)
    }
    func refreshProfileExpiry() {
        let installed = support.appendingPathComponent("RunnerBuild/Build/Products")
        let bundled = resources?.appendingPathComponent("Products")
        if let activeProducts, let date = expiry(at: activeProducts) { profileExpiry = date; return }
        let installedDate = expiry(at: installed)
        let bundledDate = bundled.flatMap { expiry(at: $0) }
        if let installedDate, installedDate > Date().addingTimeInterval(3600) { profileExpiry = installedDate }
        else if let bundledDate, bundledDate > Date().addingTimeInterval(3600) { profileExpiry = bundledDate }
        else { profileExpiry = [installedDate, bundledDate].compactMap { $0 }.max() }
    }
    func matches(_ device: USBPhone) -> Bool {
        guard let setup else { return false }
        return device.id.replacingOccurrences(of: "-", with: "").lowercased() == setup.udid.replacingOccurrences(of: "-", with: "").lowercased()
    }
    func startIfNeeded(devices: [USBPhone], onReady: @escaping () -> Void) {
        guard devices.count == 1, devices.contains(where: matches) else {
            if attempted { stop(); attempted = false; requiresUserAction = false; retryCount = 0; message = "In attesa dell’iPhone USB…" }
            return
        }
        if ready {
            guard !probing, Date() >= nextProbe else { return }
            probing = true; nextProbe = Date().addingTimeInterval(5)
            let token = lifecycle
            Task {
                let responds = await isResponding()
                guard token == lifecycle else { return }
                probing = false
                guard ready else { return }
                healthFailures = responds ? 0 : healthFailures + 1
                if healthFailures >= 2 {
                    stop(); attempted = false; retryAt = Date().addingTimeInterval(3)
                    message = "Collegamento interrotto. Riconnessione in corso…"
                }
            }
            return
        }
        guard !starting, !requiresUserAction, Date() >= retryAt else { return }
        start(onReady: onReady)
    }
    func start(onReady: @escaping () -> Void) {
        guard !starting else { return }
        guard let setup, let resources else {
            message = "Avvio automatico disponibile nella copia installata in Applicazioni."
            return
        }
        lifecycle += 1
        whenReady = onReady
        requiresUserAction = false
        let mustRenew = forceRenewal
        forceRenewal = false
        attempted = true; starting = true; ready = false; renewing = mustRenew
        task = Task {
            do {
                try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
                if mustRenew {
                    for _ in 0..<30 where runner?.isRunning == true || tunnel?.isRunning == true {
                        try await Task.sleep(nanoseconds: 100_000_000)
                    }
                    try Task.checkCancellation()
                    guard runner?.isRunning != true, tunnel?.isRunning != true else {
                        throw RemoteError.message("Il controllo precedente si sta ancora chiudendo. Riprova tra pochi secondi.")
                    }
                }
                try Task.checkCancellation()
                // Reuse an already running USB helper instead of replacing its XCTest session.
                if !mustRenew, await isResponding() { finish(); return }
                try Task.checkCancellation()
                guard FileManager.default.fileExists(atPath: setup.developerDirectory + "/usr/bin/xcodebuild") else {
                    throw RemoteError.message("Xcode non è disponibile. Ripristina Xcode nella cartella Applicazioni.")
                }
                message = "Preparo il collegamento USB…"
                if tunnel?.isRunning != true {
                    let candidates = ["/opt/homebrew/bin/iproxy", "/usr/local/bin/iproxy"]
                    guard let proxy = candidates.first(where: FileManager.default.isExecutableFile(atPath:)) else {
                        throw RemoteError.message("Manca il componente USB iproxy. Consulta la procedura di installazione dell’app.")
                    }
                    tunnel = try launch(proxy, ["-l", "-s", "127.0.0.1", "-u", setup.udid, "8100:8100"], log: "usb.log")
                }
                // A pre-existing listener may already lead to a running runner.
                if !mustRenew, await isResponding() { finish(); return }
                let installed = support.appendingPathComponent("RunnerBuild/Build/Products")
                let bundled = resources.appendingPathComponent("Products")
                let products: URL
                if !mustRenew && validRunner(at: installed) { products = installed }
                else if !mustRenew && validRunner(at: bundled) {
                    // XCTest may prepare its test host. Work on a copy, never inside the signed Mac bundle.
                    let runtime = support.appendingPathComponent("BundledRunner")
                    let profilePath = "Debug-iphoneos/WebDriverAgentRunner-Runner.app/embedded.mobileprovision"
                    let original = try Data(contentsOf: bundled.appendingPathComponent(profilePath))
                    let cached = try? Data(contentsOf: runtime.appendingPathComponent(profilePath))
                    if !validRunner(at: runtime) || cached != original {
                        if FileManager.default.fileExists(atPath: runtime.path) { try FileManager.default.removeItem(at: runtime) }
                        try FileManager.default.copyItem(at: bundled, to: runtime)
                    }
                    products = runtime
                }
                else {
                    renewing = true
                    message = "Rinnovo la firma del runner con Xcode…"
                    let source = resources.appendingPathComponent("Source/WebDriverAgent.xcodeproj")
                    let build = try launch(setup.developerDirectory + "/usr/bin/xcodebuild", [
                        "build-for-testing", "-project", source.path, "-scheme", "WebDriverAgentRunner",
                        "-destination", "platform=iOS,id=" + setup.udid, "-destination-timeout", "30",
                        "-derivedDataPath", support.appendingPathComponent("RunnerBuild").path,
                        "-allowProvisioningUpdates", "-allowProvisioningDeviceRegistration",
                        "DEVELOPMENT_TEAM=" + setup.teamID, "CODE_SIGN_STYLE=Automatic"
                    ], log: "runner-build.log")
                    runner = build
                    while build.isRunning { try await Task.sleep(nanoseconds: 500_000_000) }
                    guard build.terminationStatus == 0 else { throw RemoteError.message("Xcode non ha potuto rinnovare la firma. Verifica il tuo Apple Account in Xcode → Settings → Accounts.") }
                    products = installed
                    refreshProfileExpiry()
                }
                try Task.checkCancellation()
                guard let manifest = manifest(in: products) else { throw RemoteError.message("Runner incompleto. Reinstalla la copia personale dell’app.") }
                activeProducts = products
                message = "Avvio il controllo. Sblocca l’iPhone e conferma l’eventuale richiesta XCTest."
                runner = try launch(setup.developerDirectory + "/usr/bin/xcodebuild", [
                    "test-without-building", "-xctestrun", manifest.path,
                    "-destination", "platform=iOS,id=" + setup.udid, "-destination-timeout", "30",
                    "-derivedDataPath", support.appendingPathComponent("RunnerRuntime").path
                ], log: "runner.log")
                // User authentication can take time. Never repeat authentication or gestures.
                while !Task.isCancelled {
                    if !mustRenew, await isResponding() { finish(); return }
                    if runner?.isRunning != true { throw RemoteError.message(runnerFailure()) }
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                }
            } catch is CancellationError { }
            catch {
                if !Task.isCancelled {
                    message = error.localizedDescription; starting = false; ready = false; renewing = false
                    let details = (try? String(contentsOf: support.appendingPathComponent("runner.log"))) ?? ""
                    requiresUserAction = details.contains("Authentication cancelled") || details.contains("automation mode") ||
                        details.contains("not trusted") || details.contains("BSErrorCodeDescription=Locked") ||
                        message.contains("Apple Account") || message.contains("Xcode non è disponibile") || message.contains("Manca il componente")
                    retryCount += 1
                    retryAt = Date().addingTimeInterval(min(pow(2, Double(retryCount + 1)), 60))
                    if retryCount >= 4 { requiresUserAction = true; message += " Premi Riprova per un nuovo tentativo." }
                }
            }
        }
    }
    private func finish() {
        guard !Task.isCancelled else { return }
        ready = true; starting = false; renewing = false; retryCount = 0; healthFailures = 0
        refreshProfileExpiry()
        message = "Collegamento USB pronto"; whenReady?()
    }
    private func isResponding() async -> Bool {
        guard let (data, response) = try? await http.data(from: URL(string: "http://127.0.0.1:8100/status")!),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = json["value"] as? [String: Any] else { return false }
        return value["ready"] as? Bool == true
    }
    private func manifest(in products: URL) -> URL? {
        (try? FileManager.default.contentsOfDirectory(at: products, includingPropertiesForKeys: nil))?.first { $0.pathExtension == "xctestrun" }
    }
    private func validRunner(at products: URL) -> Bool {
        guard manifest(in: products) != nil, let expiry = expiry(at: products) else { return false }
        return expiry > Date().addingTimeInterval(3600)
    }
    private func expiry(at products: URL) -> Date? {
        guard let data = try? Data(contentsOf: products.appendingPathComponent("Debug-iphoneos/WebDriverAgentRunner-Runner.app/embedded.mobileprovision")) else { return nil }
        var decoder: CMSDecoder?
        guard CMSDecoderCreate(&decoder) == errSecSuccess, let decoder else { return nil }
        let status = data.withUnsafeBytes { buffer -> OSStatus in
            guard let base = buffer.baseAddress else { return errSecDecode }
            return CMSDecoderUpdateMessage(decoder, base, buffer.count)
        }
        guard status == errSecSuccess, CMSDecoderFinalizeMessage(decoder) == errSecSuccess else { return nil }
        var content: CFData?
        guard CMSDecoderCopyContent(decoder, &content) == errSecSuccess, let content,
              let plist = try? PropertyListSerialization.propertyList(from: content as Data, format: nil) as? [String: Any] else { return nil }
        return plist["ExpirationDate"] as? Date
    }
    private func launch(_ executable: String, _ arguments: [String], log name: String) throws -> Process {
        let log = support.appendingPathComponent(name)
        FileManager.default.createFile(atPath: log.path, contents: nil)
        let handle = try FileHandle(forWritingTo: log)
        handles.append(handle)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = support
        var environment = ProcessInfo.processInfo.environment
        environment["DEVELOPER_DIR"] = setup?.developerDirectory
        environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin"
        process.environment = environment
        process.standardOutput = handle; process.standardError = handle
        try process.run()
        return process
    }
    private func runnerFailure() -> String {
        let log = (try? String(contentsOf: support.appendingPathComponent("runner.log"))) ?? ""
        if log.contains("not trusted") { return "Autorizza lo sviluppatore in Impostazioni → Generali → VPN e gestione dispositivo sull’iPhone, poi riprova." }
        if log.contains("automation mode") || log.contains("Authentication cancelled") {
            return "Conferma l’autenticazione XCTest sull’iPhone e verifica Impostazioni → Sviluppatore → Abilita automazione UI, poi riprova."
        }
        if log.contains("locked") { return "Sblocca l’iPhone e riprova l’avvio del controllo." }
        return "Il runner non si è avviato. Sblocca l’iPhone e riprova; i dettagli sono disponibili nei log dell’app."
    }
    func openLogs() { NSWorkspace.shared.open(support) }
    func stop() {
        lifecycle += 1; probing = false; healthFailures = 0
        task?.cancel()
        whenReady = nil
        if runner?.isRunning == true { runner?.terminate() }
        if tunnel?.isRunning == true { tunnel?.terminate() }
        handles.forEach { try? $0.close() }; handles.removeAll()
        ready = false; starting = false; renewing = false
    }
}
