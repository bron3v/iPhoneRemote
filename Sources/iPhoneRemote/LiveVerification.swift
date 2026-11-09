import AppKit
import AVFoundation
import ImageIO

/// Explicit diagnostic launch only. Saves USB video; never types or taps on the iPhone.
@MainActor enum LiveVerification {
    static func run(directory: URL, capture: CaptureService, archive: CaptureArchive,
                    remote: RemoteModel, automation: LocalAutomation,
                    setPresentation: () -> Void, restorePresentation: () -> Void) async {
        var report: [String: Any] = [:]
        defer { restorePresentation() }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for _ in 0..<60 {
                if remote.connected, let date = capture.lastFrame, Date().timeIntervalSince(date) < 3 { break }
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
            guard let last = capture.lastFrame, Date().timeIntervalSince(last) < 3 else {
                throw NSError(domain: "LiveCheck", code: 1, userInfo: [NSLocalizedDescriptionKey: "No recent USB video"])
            }
            report["wdaConnected"] = remote.connected
            report["fps"] = capture.fps
            report["frameWidth"] = capture.frameSize.width
            report["frameHeight"] = capture.frameSize.height
            report["profileExpiry"] = automation.profileExpiry.map { ISO8601DateFormatter().string(from: $0) } ?? "unknown"
            setPresentation()
            try await Task.sleep(nanoseconds: 1_000_000_000)
            if let window = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain }) {
                report["floatingWindow"] = window.level == .floating
                report["compactAspectRatio"] = window.contentAspectRatio.width / window.contentAspectRatio.height
                report["windowWidth"] = window.frame.width
                report["windowHeight"] = window.frame.height
            }
            archive.screenshot(in: directory)
            archive.start(in: directory)
            try await Task.sleep(nanoseconds: 3_000_000_000)
            await withCheckedContinuation { continuation in archive.stop { continuation.resume() } }
            guard let movie = archive.lastSavedURL, movie.pathExtension == "mov" else {
                throw NSError(domain: "LiveCheck", code: 2, userInfo: [NSLocalizedDescriptionKey: archive.message])
            }
            let asset = AVURLAsset(url: movie)
            let duration = try await asset.load(.duration)
            report["movieDurationSeconds"] = CMTimeGetSeconds(duration)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            if let track = tracks.first {
                let size = try await track.load(.naturalSize)
                report["movieWidth"] = size.width; report["movieHeight"] = size.height
            }
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            guard let png = files.first(where: { $0.pathExtension == "png" }),
                  let source = CGImageSourceCreateWithURL(png as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw NSError(domain: "LiveCheck", code: 3, userInfo: [NSLocalizedDescriptionKey: "No readable PNG"])
            }
            report["pngWidth"] = image.width; report["pngHeight"] = image.height
            report["finishedWriting"] = !archive.isFinishing && !archive.isRecording
            report["passed"] = CMTimeGetSeconds(duration) >= 2 && remote.connected &&
                (report["floatingWindow"] as? Bool == true)
        } catch { report["passed"] = false; report["error"] = error.localizedDescription }
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: directory.appendingPathComponent("report.json"), options: .atomic)
        }
    }
}
