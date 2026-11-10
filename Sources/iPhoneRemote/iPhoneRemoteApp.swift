import SwiftUI
import AppKit
#if SWIFT_PACKAGE
import RemoteCore
#endif

@main struct iPhoneRemoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        Window("iPhone Remote", id: "main") { ContentView().environmentObject(delegate) }
            .defaultSize(width: 1040, height: 820)
    }
}
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var prepareToQuit: (() -> Void)?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let prepareToQuit else { return .terminateNow }
        prepareToQuit()
        return .terminateLater
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct ContentView: View {
    @EnvironmentObject private var appDelegate: AppDelegate
    @StateObject private var capture: CaptureService
    @StateObject private var archive: CaptureArchive
    init() {
        let service = CaptureService()
        _capture = StateObject(wrappedValue: service)
        _archive = StateObject(wrappedValue: service.archive)
    }
    @StateObject private var shortcuts = Shortcuts()
    @StateObject private var devices = DeviceMonitor()
    @StateObject private var remote = RemoteModel()
    @StateObject private var automation = LocalAutomation()
    @AppStorage("showSettingsSidebar") private var showSidebar = true
    @AppStorage("preferredCaptureSource") private var sourceID = ""
    @AppStorage("usbAudioEnabled") private var usbAudioEnabled = false
    @AppStorage("usbAudioVolume") private var usbAudioVolume = 0.6
    @AppStorage("compactWindow") private var compact = false
    @AppStorage("sidebarBeforeCompact") private var sidebarBeforeCompact = true
    @AppStorage("alwaysOnTop") private var onTop = false
    @AppStorage("overlayButtonSize") private var buttonSize = 28.0
    @AppStorage("overlayButtonOpacity") private var buttonOpacity = 0.8
    @AppStorage("archiveFolder") private var folderPath = ""
    @AppStorage("automaticReconnect") private var autoReconnect = true
    @AppStorage("keypadGuideCenterX") private var guideCenterX = 0.5
    @AppStorage("keypadGuideTop") private var guideTop = 0.48
    @AppStorage("keypadGuideColumnGap") private var guideColumnGap = 0.26
    @AppStorage("keypadGuideRowGap") private var guideRowGap = 0.11
    @AppStorage("keypadGuideDiameter") private var guideDiameter = 0.18
    @AppStorage("keypadGuideOpacity") private var guideOpacity = 0.8
    @State private var guideVisible = false
    @State private var audioSettingsVisible = false
    @State private var guideSettingsVisible = false
    @State private var didStartVideo = false
    @State private var launchedAutomation = false
    @State private var text = ""
    @State private var mediaNotice: String?
    @State private var mediaNoticeTask: Task<Void, Never>?
    private var freshVideo: Bool {
        guard let last = capture.lastFrame else { return false }
        return Date().timeIntervalSince(last) < 3 && capture.selectedID != nil
    }
    var body: some View {
        HStack(spacing: 0) {
            if showSidebar {
            ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label("iPhone Remote", systemImage: "iphone.gen3.radiowaves.left.and.right").font(.title2.bold())
                Text("USB · Tutto sul tuo Mac").foregroundStyle(.secondary)
                Divider()
                Label("Collegamento fisico", systemImage: "cable.connector").font(.headline)
                if devices.devices.isEmpty {
                    Text("Nessun iPhone rilevato via USB").foregroundStyle(.orange)
                }
                ForEach(devices.devices) { device in
                    VStack(alignment: .leading) {
                        Text(device.name)
                        Text(device.id).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
                Label("Video", systemImage: "video").font(.headline)
                Picker("Sorgente", selection: $sourceID) {
                    Text("Seleziona una sorgente").tag("")
                    ForEach(capture.sources) { source in Text(source.name).tag(source.id) }
                }.labelsHidden()
                HStack {
                    Button("Avvia video") { didStartVideo = true; remote.disableControl(); capture.start(id: sourceID) }.disabled(sourceID.isEmpty)
                    Button("Ferma") { didStartVideo = true; remote.disableControl(); capture.stop() }
                    Button(action: { capture.refresh(); devices.refresh() }) { Image(systemName: "arrow.clockwise") }.help("Aggiorna sorgenti")
                }
                Text(capture.status).font(.caption).foregroundStyle(.secondary)
                Divider()
                Label("Controllo con WebDriverAgent", systemImage: "hand.tap").font(.headline)
                Text("Richiede il runner firmato e il tunnel USB sulla porta locale 8100. WDA usa API private XCTest; destinato allo sviluppo locale.").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Collega WDA") {
                        if automation.isConfigured { automation.start { remote.connect() } }
                        else { remote.connect() }
                    }.disabled(remote.busy || remote.connected || automation.starting)
                    Button("Scollega") { remote.disconnect() }.disabled(!remote.connected || remote.busy)
                }
                if automation.isConfigured {
                    Text(automation.message).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        if !automation.ready { Button("Apri log") { automation.openLogs() }.font(.caption) }
                        if automation.requiresUserAction { Button("Riprova") { automation.start { if remote.wantsConnection { remote.connect() } } }.font(.caption) }
                    }
                }
                Text(remote.message).font(.caption).textSelection(.enabled)
                Toggle("Abilita controllo", isOn: $remote.controlRequested)
                    .disabled(!remote.connected || !freshVideo || devices.devices.count != 1)
                Text("Il controllo si attiva quando video e WDA sono pronti, con un solo iPhone USB. Puoi disattivarlo con questo interruttore.").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Home") { remote.perform { try await $0.home() } }
                    Button("App recenti") { remote.perform { try await $0.appSwitcher() } }
                }.disabled(!remote.controlEnabled || remote.busy || !freshVideo)
                HStack {
                    TextField("Testo da inviare", text: $text).onSubmit { sendText() }
                    Button("Invia") { sendText() }.disabled(text.isEmpty)
                }.disabled(!remote.controlEnabled || remote.busy || !freshVideo)
                Text("Clic: tocco · trascina: swipe\nTieni premuto o clic destro: pressione lunga\nRotella: swipe · clic sul video per digitare\nInvio: invia nelle chat supportate · ⇧Invio: a capo\nPer testo composto o lungo usa il campo Invia.")
                    .font(.caption).foregroundStyle(.secondary)
                ExperienceSettingsView(remote: remote, automation: automation, archive: archive,
                                       shortcuts: shortcuts, compact: $compact, onTop: $onTop,
                                       buttonSize: $buttonSize, buttonOpacity: $buttonOpacity,
                                       folderPath: $folderPath, autoReconnect: $autoReconnect, videoReady: freshVideo) {
                    remote.connectionLost("Rinnovo firma in corso…")
                    automation.renew { if remote.wantsConnection { remote.connect() } }
                }
                Spacer(minLength: 0)
            }.padding(22)
            }.frame(width: 355)
            Divider()
            }
            ZStack {
                Color.black
                VideoView(capture: capture, size: capture.frameSize,
                          interactive: remote.controlEnabled && freshVideo && devices.devices.count == 1 && !guideVisible,
                          onGesture: { a, b, hold, move in remote.gesture(from: a, to: b, hold: hold, move: move) },
                          onText: { value in remote.type(value) },
                          onReturn: { remote.pressReturn() })
                if freshVideo {
                    PhoneNavigationOverlay(imageSize: capture.frameSize,
                                           enabled: remote.controlEnabled && !guideVisible,
                                           scale: buttonSize / 28, opacity: buttonOpacity,
                                           notifications: { run(.notifications) },
                                           controlCenter: { run(.controlCenter) },
                                           home: { run(.home) }, apps: { run(.apps) })
                }
                if guideVisible, freshVideo {
                    KeypadGuide(imageSize: capture.frameSize, centerX: guideCenterX, top: guideTop,
                                columnGap: guideColumnGap, rowGap: guideRowGap,
                                diameter: guideDiameter, opacity: guideOpacity)
                }
                if let notice = remote.inputNotice {
                    VStack {
                        Spacer()
                        HStack(alignment: .top) {
                            Text(notice).font(.caption)
                            Button { remote.dismissNotice() } label: { Image(systemName: "xmark") }.buttonStyle(.plain).help("Chiudi avviso")
                        }
                        .foregroundStyle(.white).padding(10)
                        .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, 42).padding(.bottom, 52)
                    }
                }
                if capture.lastFrame == nil {
                    VStack(spacing: 12) {
                        Image(systemName: "iphone.gen3").font(.system(size: 60))
                        Text("Lo schermo dell’iPhone apparirà qui").font(.headline)
                        Text("Collega il cavo, sblocca l’iPhone e seleziona la sorgente USB.")
                            .font(.caption).multilineTextAlignment(.center)
                    }.foregroundStyle(.white.opacity(0.65)).padding().allowsHitTesting(false)
                }
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                if let mediaNotice {
                    HStack {
                        Text(mediaNotice).font(.caption).lineLimit(3)
                        Button { self.mediaNotice = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                    }.padding(10).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
                if automation.isConfigured && !automation.ready {
                    HStack(spacing: 10) {
                        if automation.starting { ProgressView().controlSize(.small) }
                        Text(automation.message).font(.caption)
                        Button("Impostazioni") { showSidebar = true }
                    }.padding(10).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
            }.padding(12)
        }
        .frame(minWidth: compact ? 240 : (showSidebar ? 800 : 280), minHeight: compact ? 320 : 480)
        .background(WindowPresentation(compact: compact, onTop: onTop, phoneSize: capture.frameSize, sidebarVisible: showSidebar))
        .overlay(alignment: .top) {
            StatusBadge(remote: remote, archive: archive, videoReady: freshVideo)
                .padding(.top, 8).allowsHitTesting(false)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { audioSettingsVisible.toggle() } label: {
                    Image(systemName: capture.audioAvailable && usbAudioEnabled && usbAudioVolume > 0 ? "speaker.wave.2" : "speaker.slash")
                }
                .help("Audio USB dell’iPhone")
                .accessibilityLabel("Audio USB dell’iPhone")
                .popover(isPresented: $audioSettingsVisible) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Riproduci audio USB sul Mac", isOn: $usbAudioEnabled)
                        Slider(value: $usbAudioVolume, in: 0...1) { Text("Volume") }
                            .disabled(!usbAudioEnabled)
                        Text(capture.audioAvailable
                             ? "Riproduzione dal vivo. Le registrazioni restano senza audio."
                             : "Nessuna traccia audio disponibile dalla sorgente video attuale.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(14).frame(width: 265)
                }
                Button {
                    guideVisible.toggle()
                    guideSettingsVisible = guideVisible
                } label: { Image(systemName: guideVisible ? "circle.grid.3x3.fill" : "circle.grid.3x3") }
                .help(guideVisible ? "Nascondi guida tastierino" : "Mostra guida tastierino (posizioni indicative)")
                .accessibilityLabel("Guida tastierino")
                .contextMenu {
                    Button("Regola guida…") { guideVisible = true; guideSettingsVisible = true }
                }
                .popover(isPresented: $guideSettingsVisible) {
                    KeypadGuideSettings(centerX: $guideCenterX, top: $guideTop,
                                        columnGap: $guideColumnGap, rowGap: $guideRowGap,
                                        diameter: $guideDiameter, opacity: $guideOpacity,
                                        close: { guideSettingsVisible = false },
                                        hide: { guideSettingsVisible = false; guideVisible = false })
                }
                Button { compact.toggle() } label: { Image(systemName: compact ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left") }
                    .help(compact ? "Esci dalla modalità compatta" : "Finestra compatta")
                Button { onTop.toggle() } label: { Image(systemName: onTop ? "pin.fill" : "pin") }
                    .help(onTop ? "Disattiva primo piano" : "Sempre in primo piano")
                Button { run(.screenshot) } label: { Image(systemName: "camera") }.help("Salva screenshot").disabled(!freshVideo)
                Button { run(.recording) } label: { Image(systemName: archive.isRecording ? "stop.circle.fill" : "record.circle") }
                    .help(archive.isRecording ? "Ferma registrazione" : "Registra video")
                    .disabled(archive.isFinishing || (!freshVideo && !archive.isRecording))
            }
            ToolbarItem(placement: .navigation) {
                Button {
                    showSidebar.toggle()
                } label: {
                    Label(showSidebar ? "Nascondi impostazioni" : "Mostra impostazioni", systemImage: "sidebar.left")
                }
                .help(showSidebar ? "Nascondi impostazioni (⌃⌘S)" : "Mostra impostazioni (⌃⌘S)")
                .keyboardShortcut("s", modifiers: [.control, .command])
            }
        }
        .onAppear {
            updateAudioPlayback()
            // Explicit launch option for device validation; normal launches stay manual.
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "--capture-source"), arguments.indices.contains(index + 1) {
                didStartVideo = true
                sourceID = arguments[index + 1]
                capture.start(id: sourceID)
            }
            if arguments.contains("--connect-wda") { remote.connect() }
            remote.automaticReconnect = autoReconnect
            shortcuts.onAction = { run($0) }
            shortcuts.start()
            appDelegate.prepareToQuit = {
                archive.stop {
                    automation.stop()
                    NSApp.reply(toApplicationShouldTerminate: true)
                }
            }
            preparePersonalLaunch()
            if let index = arguments.firstIndex(of: "--verify-experience"), arguments.indices.contains(index + 1) {
                let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
                let previousCompact = compact, previousOnTop = onTop, previousSidebar = showSidebar
                Task {
                    await LiveVerification.run(directory: directory, capture: capture, archive: archive,
                                               remote: remote, automation: automation,
                                               setPresentation: { compact = true; onTop = true },
                                               restorePresentation: {
                        compact = previousCompact; onTop = previousOnTop; showSidebar = previousSidebar
                    })
                }
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            preparePersonalLaunch()
            remote.updateReadiness(videoReady: freshVideo, singleUSBPhone: devices.devices.count == 1)
            remote.maintainConnection(transportReady: automation.ready || !automation.isConfigured,
                                      singleUSBPhone: devices.devices.count == 1)
        }
        .onChange(of: archive.message) { _, value in
            mediaNoticeTask?.cancel()
            mediaNotice = value
            mediaNoticeTask = Task {
                do { try await Task.sleep(nanoseconds: 5_000_000_000); mediaNotice = nil } catch { }
            }
        }
        .onChange(of: guideVisible) { _, visible in
            remote.localInputSuspended = visible
            if !visible { guideSettingsVisible = false }
        }
        .onChange(of: autoReconnect) { _, value in remote.automaticReconnect = value }
        .onChange(of: usbAudioEnabled) { _, _ in updateAudioPlayback() }
        .onChange(of: usbAudioVolume) { _, _ in updateAudioPlayback() }
        .onChange(of: compact) { _, value in
            if value { sidebarBeforeCompact = showSidebar; showSidebar = false }
            else { showSidebar = sidebarBeforeCompact }
        }
        .onChange(of: showSidebar) { _, value in
            if value && compact { sidebarBeforeCompact = true; compact = false }
        }
        .onChange(of: capture.frameSize) { _, size in remote.updateVideoSize(size) }
        .onChange(of: remote.controlEnabled) { _, enabled in if !enabled { remote.discardPendingText() } }
        .onChange(of: capture.selectedID) { _, _ in remote.disableControl() }
        .onChange(of: sourceID) { _, _ in remote.disableControl() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in automation.stop() }
        .onDisappear { shortcuts.stop(); capture.stop(); remote.disconnect(); automation.stop() }
    }
    private func updateAudioPlayback() {
        capture.setAudioPlayback(enabled: usbAudioEnabled, volume: usbAudioVolume)
    }
    private func preparePersonalLaunch() {
        guard automation.isConfigured else { return }
        let eligible = devices.devices.count == 1 && devices.devices.contains(where: automation.matches)
        guard eligible else {
            automation.startIfNeeded(devices: devices.devices) { }
            return
        }
        if remote.wantsConnection && (autoReconnect || !launchedAutomation) {
            launchedAutomation = true
            automation.startIfNeeded(devices: devices.devices) { if remote.wantsConnection { remote.connect() } }
        }
        guard !didStartVideo, devices.devices.count == 1, devices.devices.contains(where: automation.matches) else { return }
        let screenSources = capture.sources.filter(\.isScreen)
        let preferred = screenSources.first(where: { $0.id == sourceID })
        guard let source = preferred ?? (screenSources.count == 1 ? screenSources.first : nil) else { return }
        didStartVideo = true; sourceID = source.id; capture.start(id: source.id)
    }
    private func run(_ action: RemoteAction) {
        let folder = folderPath.isEmpty ? CaptureArchive.defaultFolder : URL(fileURLWithPath: folderPath)
        switch action {
        case .home: remote.perform { try await $0.home() }
        case .apps: remote.perform { try await $0.appSwitcher() }
        case .notifications: remote.perform { try await $0.notifications(videoSize: capture.frameSize) }
        case .controlCenter: remote.perform { try await $0.controlCenter(videoSize: capture.frameSize) }
        case .pause: remote.controlRequested.toggle()
        case .screenshot: archive.screenshot(in: folder)
        case .recording:
            if archive.isRecording { archive.stop() }
            else { archive.start(in: folder) }
        }
    }
    private func sendText() {
        guard !text.isEmpty else { return }
        let value = text
        if remote.type(value) { text = "" }
    }
}
