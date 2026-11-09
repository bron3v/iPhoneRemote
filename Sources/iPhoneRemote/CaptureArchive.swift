import AppKit
import AVFoundation
import CoreImage
import Combine
import UniformTypeIdentifiers

/// Receives USB frames on captureQueue. No screen-recording or microphone permission.
final class CaptureArchive: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isFinishing = false
    @Published private(set) var recordingStartedAt: Date?
    @Published private(set) var message = "Screenshot PNG e video MOV salvati sul Mac."
    @Published private(set) var lastSavedURL: URL?
    private let queue: DispatchQueue
    private let imageQueue = DispatchQueue(label: "it.local.iphoneremote.png", qos: .utility)
    private var latest: CMSampleBuffer?
    private var latestDate = Date.distantPast
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var outputURL: URL?
    private var dimensions = CMVideoDimensions(width: 0, height: 0)
    private var lastTime = CMTime.invalid
    private var finishing = false
    private var completions: [() -> Void] = []
    init(queue: DispatchQueue) { self.queue = queue }
    static var defaultFolder: URL {
        FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0].appendingPathComponent("iPhone Remote")
    }
    private func newURL(in folder: URL, extension suffix: String) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let date = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        return folder.appendingPathComponent("iPhone-\(date)-\(UUID().uuidString.prefix(6)).\(suffix)")
    }
    /// Called exclusively by the capture delegate, before its UI frame-rate throttling.
    func consume(_ sample: CMSampleBuffer) {
        latest = sample; latestDate = Date()
        guard let writer, let input, !finishing, let format = CMSampleBufferGetFormatDescription(sample) else { return }
        let size = CMVideoFormatDescriptionGetDimensions(format)
        guard size.width == dimensions.width && size.height == dimensions.height else {
            finishOnQueue(reason: "Registrazione fermata: lo schermo ha cambiato orientamento.")
            return
        }
        let time = CMSampleBufferGetPresentationTimeStamp(sample)
        guard time.isValid else { return }
        if lastTime.isValid && CMTimeGetSeconds(CMTimeSubtract(time, lastTime)) < 1.0 / 30.0 { return }
        guard writer.status == .writing else {
            finishOnQueue(reason: writer.error?.localizedDescription ?? "Errore di registrazione")
            return
        }
        guard input.isReadyForMoreMediaData else { return }
        if input.append(sample) { lastTime = time }
        else { finishOnQueue(reason: writer.error?.localizedDescription ?? "Impossibile scrivere il fotogramma") }
    }
    func screenshot(in folder: URL) {
        queue.async {
            guard let sample = self.latest, Date().timeIntervalSince(self.latestDate) < 3,
                  let pixel = CMSampleBufferGetImageBuffer(sample) else {
                self.report("Nessun fotogramma recente da salvare."); return
            }
            self.imageQueue.async {
                do {
                    let url = try self.newURL(in: folder, extension: "png")
                    let image = CIImage(cvPixelBuffer: pixel)
                    try CIContext().writePNGRepresentation(of: image, to: url, format: .RGBA8,
                                                          colorSpace: CGColorSpaceCreateDeviceRGB())
                    self.report("Screenshot salvato: \(url.lastPathComponent)", saved: url)
                } catch { self.report("Screenshot non salvato: \(error.localizedDescription)") }
            }
        }
    }
    func start(in folder: URL) {
        guard !isRecording, !isFinishing else { return }
        isRecording = true; recordingStartedAt = Date(); message = "Avvio registrazione…"
        queue.async {
            do {
                guard self.writer == nil, !self.finishing, let sample = self.latest,
                      Date().timeIntervalSince(self.latestDate) < 3,
                      let format = CMSampleBufferGetFormatDescription(sample) else {
                    throw NSError(domain: "iPhoneRemote", code: 1, userInfo: [NSLocalizedDescriptionKey: "Nessun video recente disponibile."])
                }
                let url = try self.newURL(in: folder, extension: "mov")
                let size = CMVideoFormatDescriptionGetDimensions(format)
                let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
                let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: Int(size.width), AVVideoHeightKey: Int(size.height),
                    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 8_000_000,
                                                      AVVideoExpectedSourceFrameRateKey: 30]
                ])
                input.expectsMediaDataInRealTime = true
                guard writer.canAdd(input) else { throw NSError(domain: "iPhoneRemote", code: 2, userInfo: [NSLocalizedDescriptionKey: "Formato video non registrabile."]) }
                writer.add(input)
                guard writer.startWriting() else { throw writer.error ?? NSError(domain: "iPhoneRemote", code: 3) }
                writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sample))
                self.writer = writer; self.input = input; self.outputURL = url
                self.dimensions = size; self.lastTime = .invalid
                self.consume(sample)
                self.report("Registrazione in corso · video senza audio")
            } catch {
                DispatchQueue.main.async { self.isRecording = false; self.recordingStartedAt = nil }
                self.report("Registrazione non avviata: \(error.localizedDescription)")
            }
        }
    }
    func stop(completion: (() -> Void)? = nil) {
        queue.async { self.finishOnQueue(completion: completion) }
    }
    /// Called on captureQueue when a source is stopped, disconnected, or reconfigured.
    func invalidateSource() {
        latest = nil; latestDate = .distantPast
        finishOnQueue(reason: "Registrazione fermata: sorgente video interrotta.")
    }
    private func finishOnQueue(reason: String? = nil, completion: (() -> Void)? = nil) {
        if let completion { completions.append(completion) }
        guard !finishing else { return }
        guard let writer else { completeCallbacks(); return }
        finishing = true
        DispatchQueue.main.async { self.isRecording = false; self.isFinishing = true; self.recordingStartedAt = nil }
        if writer.status == .writing {
            input?.markAsFinished()
            if lastTime.isValid { writer.endSession(atSourceTime: CMTimeAdd(lastTime, CMTime(value: 1, timescale: 30))) }
        }
        let url = outputURL
        let complete = {
            self.queue.async {
                let success = writer.status == .completed
                let error = writer.error?.localizedDescription
                self.writer = nil; self.input = nil; self.outputURL = nil; self.finishing = false
                DispatchQueue.main.async {
                    self.isRecording = false; self.isFinishing = false; self.recordingStartedAt = nil
                    if success, let url {
                        self.lastSavedURL = url
                        self.message = reason.map { $0 + " Video salvato." } ?? "Video salvato: \(url.lastPathComponent)"
                    } else { self.message = "Registrazione non completata: \(error ?? reason ?? "nessun fotogramma")" }
                }
                self.completeCallbacks()
            }
        }
        if writer.status == .writing { writer.finishWriting(completionHandler: complete) }
        else { complete() }
    }
    private func completeCallbacks() {
        let callbacks = completions; completions.removeAll()
        DispatchQueue.main.async { callbacks.forEach { $0() } }
    }
    private func report(_ text: String, saved: URL? = nil) {
        DispatchQueue.main.async { self.message = text; if let saved { self.lastSavedURL = saved } }
    }
}
