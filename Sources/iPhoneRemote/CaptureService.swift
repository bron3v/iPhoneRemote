#if SWIFT_PACKAGE
import RemoteCore
#endif

import AVFoundation
import CoreMediaIO
import Combine

struct CaptureSource: Identifiable, Equatable {
    let id: String
    let name: String
    let isScreen: Bool
}

/// All session mutations and sample callbacks are confined to captureQueue.
final class CaptureService: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    private let captureQueue = DispatchQueue(label: "it.local.iphoneremote.capture", qos: .userInitiated)
    lazy var archive = CaptureArchive(queue: captureQueue)
    @Published private(set) var sources: [CaptureSource] = []
    @Published private(set) var status = "Collega l’iPhone via USB e aggiorna le sorgenti."
    @Published private(set) var frameSize = CGSize.zero
    @Published private(set) var fps = 0
    @Published private(set) var lastFrame: Date?
    @Published private(set) var selectedID: String?
    @Published private(set) var audioAvailable = false
    private var desiredID: String?
    private var output: AVCaptureVideoDataOutput?
    private var audioPreview: AVCaptureAudioPreviewOutput?
    private var audioGain: Float = 0
    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?
    private var frameCount = 0
    private var firstFrame = true
    private var lastDimensions = CGSize.zero
    private var sampleTime = Date()
    private var lastSampleAt = Date.distantPast
    private var lastRestartAt = Date.distantPast
    private var discovery: AVCaptureDevice.DiscoverySession?

    override init() {
        super.init()
        for name in [AVCaptureDevice.wasConnectedNotification, AVCaptureDevice.wasDisconnectedNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.refresh() })
        }
        observers.append(NotificationCenter.default.addObserver(forName: .AVCaptureSessionRuntimeError, object: session, queue: .main) { [weak self] note in
            let message = (note.userInfo?[AVCaptureSessionErrorKey] as? Error)?.localizedDescription ?? "Errore di acquisizione"
            self?.status = message
            self?.lastFrame = nil
            self?.audioAvailable = false
            self?.captureQueue.async { self?.archive.invalidateSource() }
        })
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.refresh() }
        refresh()
    }
    deinit {
        timer?.invalidate()
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    private func devices() -> [AVCaptureDevice] {
        // .external with nil mediaType also discovers muxed USB screen sources.
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.external], mediaType: nil, position: .unspecified)
        self.discovery = discovery
        return discovery.devices.filter { !$0.isContinuityCamera && ($0.hasMediaType(.video) || $0.hasMediaType(.muxed)) }
    }
    private func enableUSBScreenSources() throws {
        var address = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices), mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal), mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var enabled: UInt32 = 1
        let result = CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, UInt32(MemoryLayout.size(ofValue: enabled)), &enabled)
        guard result == noErr else { throw RemoteError.message("CoreMediaIO: impossibile abilitare le sorgenti schermo (\(result))") }
    }
    func refresh() {
        captureQueue.async { [weak self] in
            guard let self else { return }
            do { try self.enableUSBScreenSources() } catch {
                DispatchQueue.main.async { self.status = error.localizedDescription }
                return
            }
            let devices = self.devices()
            let list = devices.map { CaptureSource(id: $0.uniqueID, name: $0.localizedName + ($0.hasMediaType(.muxed) ? " · USB muxed" : " · video esterno"), isScreen: $0.hasMediaType(.muxed)) }
            DispatchQueue.main.async { self.sources = list }
            guard let desiredID = self.desiredID else { return }
            guard let device = devices.first(where: { $0.uniqueID == desiredID }) else {
                self.archive.invalidateSource()
                if self.session.isRunning { self.session.stopRunning() }
                DispatchQueue.main.async {
                    self.selectedID = nil; self.lastFrame = nil; self.fps = 0; self.audioAvailable = false
                    self.status = "Sorgente scollegata. In attesa dello stesso dispositivo…"
                }
                return
            }
            let stale = Date().timeIntervalSince(self.lastSampleAt) > 5
            if !self.session.isRunning || (stale && Date().timeIntervalSince(self.lastRestartAt) > 8) {
                self.lastRestartAt = Date()
                self.configure(device)
            }
        }
    }
    func start(id: String) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: select(id)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
                DispatchQueue.main.async {
                    if allowed { self?.select(id) }
                    else { self?.status = "Accesso fotocamera negato. Abilitalo nelle impostazioni Privacy del Mac." }
                }
            }
        default: status = "Abilita l’accesso Fotocamera per iPhone Remote nelle impostazioni Privacy del Mac."
        }
    }
    private func select(_ id: String) {
        lastFrame = nil; frameSize = .zero; fps = 0; audioAvailable = false
        captureQueue.async {
            self.desiredID = id
            if let device = self.devices().first(where: { $0.uniqueID == id }) { self.configure(device) }
        }
    }
    func setAudioPlayback(enabled: Bool, volume: Double) {
        let gain = enabled && volume.isFinite ? Float(min(max(volume, 0), 1)) : 0
        captureQueue.async {
            self.audioGain = gain
            self.audioPreview?.volume = gain
        }
    }
    func stop() {
        captureQueue.async {
            self.desiredID = nil
            self.archive.invalidateSource()
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async {
                self.selectedID = nil; self.lastFrame = nil; self.fps = 0; self.frameSize = .zero; self.audioAvailable = false
                self.status = "Acquisizione arrestata"
            }
        }
    }
    private func configure(_ device: AVCaptureDevice) {
        archive.invalidateSource()
        if session.isRunning { session.stopRunning() }
        session.beginConfiguration()
        session.inputs.forEach(session.removeInput)
        session.outputs.forEach(session.removeOutput)
        audioPreview = nil
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { throw RemoteError.message("Sorgente non utilizzabile") }
            session.addInput(input)
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.setSampleBufferDelegate(self, queue: captureQueue)
            guard session.canAddOutput(output) else { throw RemoteError.message("Output video non disponibile") }
            session.addOutput(output)
            self.output = output
            let hasAudio = configureAudioPreview(from: input)
            session.commitConfiguration()
            frameCount = 0; firstFrame = true; lastDimensions = .zero; sampleTime = Date()
            session.startRunning()
            DispatchQueue.main.async {
                self.selectedID = device.uniqueID
                self.audioAvailable = hasAudio && self.session.isRunning
                self.status = "Acquisizione avviata; attendo fotogrammi reali…"
            }
        } catch {
            session.commitConfiguration()
            DispatchQueue.main.async { self.status = error.localizedDescription; self.selectedID = nil; self.audioAvailable = false }
        }
    }
    private func configureAudioPreview(from input: AVCaptureDeviceInput) -> Bool {
        // Only monitor the selected USB screen stream, never a separate microphone.
        guard input.device.hasMediaType(.muxed),
              let port = input.ports.first(where: { $0.mediaType == .audio }) else { return false }
        let preview = AVCaptureAudioPreviewOutput()
        preview.volume = audioGain
        guard session.canAddOutput(preview) else { return false }
        session.addOutputWithNoConnections(preview)
        let connection = AVCaptureConnection(inputPorts: [port], output: preview)
        guard session.canAddConnection(connection) else {
            session.removeOutput(preview)
            return false
        }
        session.addConnection(connection)
        audioPreview = preview
        return true
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        lastSampleAt = Date()
        archive.consume(sampleBuffer)
        guard let format = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        let dimensions = CMVideoFormatDescriptionGetDimensions(format)
        frameCount += 1
        let now = Date(), interval = now.timeIntervalSince(sampleTime)
        let size = CGSize(width: Int(dimensions.width), height: Int(dimensions.height))
        guard interval >= 1 || firstFrame || size != lastDimensions else { return }
        lastDimensions = size
        firstFrame = false
        let rate = interval >= 1 ? Int(Double(frameCount) / interval) : 0
        frameCount = 0; sampleTime = now
        DispatchQueue.main.async {
            self.frameSize = CGSize(width: Int(dimensions.width), height: Int(dimensions.height))
            self.lastFrame = now
            self.fps = rate
            self.status = "Video attivo · \(dimensions.width) × \(dimensions.height) · \(rate) fps"
            if ProcessInfo.processInfo.arguments.contains("--capture-diagnostics") {
                print("CAPTURE frame=\(dimensions.width)x\(dimensions.height) fps=\(rate)")
                fflush(stdout)
            }
        }
    }
}
