import Foundation

private final class QueueStub: URLProtocol {
    static var recordText: ((String) -> Void)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var value: [String: Any] = [:]
        switch request.url!.path {
        case "/session": value = ["sessionId": "queue-test"]
        case "/session/queue-test/wda/activeAppInfo": value = ["bundleId": "com.apple.mobilenotes"]
        case "/session/queue-test/window/size": value = ["width": 393, "height": 852]
        case "/session/queue-test/wda/keys":
            if let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var data = Data(), buffer = [UInt8](repeating: 0, count: 1024)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    if count <= 0 { break }
                    data.append(buffer, count: count)
                }
                if let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let text = (body["value"] as? [String])?.first {
                    DispatchQueue.main.async { Self.recordText?(text) }
                }
            }
        default: break
        }
        let data = try! JSONSerialization.data(withJSONObject: ["value": value])
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main struct QueueCheck {
    @MainActor static func main() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [QueueStub.self]
        let model = RemoteModel(client: WDAClient(session: URLSession(configuration: configuration)))
        precondition(model.controlRequested && !model.controlEnabled)
        model.updateReadiness(videoReady: true, singleUSBPhone: true)
        precondition(!model.controlEnabled, "Disconnected client must not accept input")
        model.connect()
        for _ in 0..<100 where model.busy { try await Task.sleep(nanoseconds: 10_000_000) }
        precondition(model.connected && model.controlEnabled, "Ready connection enables control by default")
        model.controlRequested = false
        model.updateReadiness(videoReady: true, singleUSBPhone: true)
        precondition(!model.controlEnabled, "Manual disable must survive readiness updates")
        model.controlRequested = true
        precondition(model.controlEnabled)
        model.updateReadiness(videoReady: false, singleUSBPhone: true)
        precondition(!model.controlEnabled)
        model.updateReadiness(videoReady: true, singleUSBPhone: false)
        precondition(!model.controlEnabled)
        model.updateReadiness(videoReady: true, singleUSBPhone: true)
        precondition(model.controlEnabled)
        model.localInputSuspended = true
        model.updateReadiness(videoReady: true, singleUSBPhone: true)
        precondition(!model.controlEnabled && model.controlRequested)
        precondition(!model.type("must not leave the Mac"))
        model.perform { _ in preconditionFailure("Guide mode must not execute remote gestures") }
        model.pressReturn()
        try await Task.sleep(nanoseconds: 20_000_000)
        precondition(!model.busy && model.pendingCount == 0)
        model.localInputSuspended = false
        precondition(model.controlEnabled)
        var events: [String] = []
        QueueStub.recordText = { events.append("text:" + $0) }
        model.perform { _ in
            events.append("first")
            try await Task.sleep(nanoseconds: 80_000_000)
        }
        precondition(model.type("a"))
        precondition(model.type("b"))
        model.perform { _ in events.append("second") }
        model.perform { _ in events.append("overflow") }
        for _ in 0..<100 where model.busy { try await Task.sleep(nanoseconds: 10_000_000) }
        precondition(events == ["first", "text:ab", "second"], "Unexpected order: \(events)")
        events.removeAll()
        model.perform { _ in try await Task.sleep(nanoseconds: 30_000_000) }
        precondition(model.type("draft"))
        model.pressReturn()
        for _ in 0..<100 where model.busy { try await Task.sleep(nanoseconds: 10_000_000) }
        precondition(events == ["text:draft", "text:\n"], "Return must follow all queued text: \(events)")
        model.perform { _ in
            events.append("in-flight")
            try await Task.sleep(nanoseconds: 30_000_000)
        }
        model.perform { _ in events.append("cancelled") }
        model.disableControl()
        for _ in 0..<100 where model.busy { try await Task.sleep(nanoseconds: 10_000_000) }
        precondition(!events.contains("cancelled"))
        model.updateReadiness(videoReady: true, singleUSBPhone: true)
        precondition(model.controlEnabled)
        model.perform { _ in throw RemoteError.message("Injected failure") }
        model.perform { _ in events.append("after-error") }
        for _ in 0..<100 where model.busy { try await Task.sleep(nanoseconds: 10_000_000) }
        precondition(!model.connected && !model.controlEnabled && !events.contains("after-error"))
        model.updateReadiness(videoReady: true, singleUSBPhone: true)
        precondition(!model.controlEnabled, "An error still requires explicit WDA reconnection")
        model.connect()
        for _ in 0..<100 where model.busy { try await Task.sleep(nanoseconds: 10_000_000) }
        precondition(model.connected && model.controlEnabled)
        model.perform { _ in try await Task.sleep(nanoseconds: 50_000_000) }
        precondition(model.type("pending text"))
        model.connectionLost("Injected USB disconnect")
        try await Task.sleep(nanoseconds: 100_000_000)
        precondition(!model.connected && !model.busy && model.pendingCount == 0)
        precondition(model.unconfirmedText.contains("pending text") && model.inputNotice != nil)
        model.connect()
        for _ in 0..<100 where model.busy { try await Task.sleep(nanoseconds: 10_000_000) }
        precondition(model.connected)
        model.clearUnconfirmedText()
        model.perform { _ in try await Task.sleep(nanoseconds: 50_000_000) }
        precondition(model.type(String(repeating: "x", count: 32768)))
        precondition(!model.type("overflow text"))
        precondition(model.unconfirmedText == "overflow text" && model.inputNotice != nil)
        model.disableControl()
        for _ in 0..<100 where model.busy { try await Task.sleep(nanoseconds: 10_000_000) }
        model.disconnect()
        model.updateReadiness(videoReady: true, singleUSBPhone: true)
        model.maintainConnection(transportReady: true, singleUSBPhone: true)
        try await Task.sleep(nanoseconds: 50_000_000)
        precondition(!model.connected && !model.wantsConnection, "Manual disconnect must block auto reconnect")
        model.connect()
        model.disconnect()
        try await Task.sleep(nanoseconds: 50_000_000)
        precondition(!model.connected && !model.busy, "Stale connect completion must not restore a disconnected session")
        model.connect()
        for _ in 0..<100 where model.busy { try await Task.sleep(nanoseconds: 10_000_000) }
        let countBeforeReconnect = events.count
        model.connectionLost("Injected transport restart")
        model.automaticReconnect = false
        try await Task.sleep(nanoseconds: 2_100_000_000)
        model.maintainConnection(transportReady: true, singleUSBPhone: true)
        precondition(!model.connected && !model.busy)
        model.automaticReconnect = true
        model.maintainConnection(transportReady: true, singleUSBPhone: true)
        for _ in 0..<100 where model.busy { try await Task.sleep(nanoseconds: 10_000_000) }
        precondition(model.connected && events.count == countBeforeReconnect, "Automatic reconnect must restore only the session, without replay")
        print("PASS: default automatic control; readiness gates; manual disable respected; bounded FIFO queue; visible overflow and retained text; stale task cancellation; manual disconnect respected")
    }
}
