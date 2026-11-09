import XCTest
import CoreGraphics
@testable import RemoteCore

private final class StubProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, [String: Any]))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, body) = try Self.handler!(request)
            let data = try JSONSerialization.data(withJSONObject: body)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

/// HTTP fixtures verify the client contract, not actual iPhone operation.
final class WDAClientTests: XCTestCase {
    private func makeClient() -> WDAClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        return WDAClient(session: URLSession(configuration: config))
    }
    private func body(_ request: URLRequest) throws -> [String: Any] {
        if let data = request.httpBody { return try JSONSerialization.jsonObject(with: data) as! [String: Any] }
        guard let stream = request.httpBodyStream else { return [:] }
        stream.open(); defer { stream.close() }
        var data = Data(), buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }
    private func normal(_ request: URLRequest) -> (Int, [String: Any]) {
        switch request.url!.path {
        case "/status": return (200, ["value": ["ready": true]])
        case "/session": return (200, ["value": ["sessionId": "test-session"]])
        case "/session/test-session/window/size": return (200, ["value": ["width": 393, "height": 852]])
        default: return (200, ["value": NSNull()])
        }
    }
    override func tearDown() { StubProtocol.handler = nil; super.tearDown() }
    func testGestureReusesGeometryAndSendsW3CTouchActions() async throws {
        var paths: [String] = []
        var actionsBody: [String: Any] = [:]
        StubProtocol.handler = { request in
            paths.append(request.url!.path)
            XCTAssertEqual(request.url?.host, "127.0.0.1")
            if request.url!.path.hasSuffix("/actions") { actionsBody = try self.body(request) }
            return self.normal(request)
        }
        let client = makeClient()
        _ = try await client.connect()
        try await client.gesture(from: CGPoint(x: 0.5, y: 0.5), to: CGPoint(x: 0.5, y: 0.2), hold: 0.8, move: 0.25)
        XCTAssertEqual(paths.filter { $0.hasSuffix("/window/size") }.count, 1)
        let pointers = try XCTUnwrap(actionsBody["actions"] as? [[String: Any]])
        XCTAssertEqual(pointers.first?["type"] as? String, "pointer")
        let actions = try XCTUnwrap(pointers.first?["actions"] as? [[String: Any]])
        XCTAssertEqual(actions.map { $0["type"] as! String }, ["pointerMove", "pointerDown", "pause", "pointerMove", "pointerUp"])
        XCTAssertEqual(actions[0]["x"] as? Int, 196)
        XCTAssertEqual(actions[0]["y"] as? Int, 425)
        XCTAssertEqual(actions[2]["duration"] as? Int, 800)
        XCTAssertEqual(actions[3]["duration"] as? Int, 250)
    }
    func testConnectionDisablesTestSynchronizationWaits() async throws {
        var settings: [String: Any] = [:]
        var capabilities: [String: Any] = [:]
        StubProtocol.handler = { request in
            if request.url!.path == "/session" {
                let data = try self.body(request)
                capabilities = (data["capabilities"] as? [String: Any])?["alwaysMatch"] as? [String: Any] ?? [:]
            }
            if request.url!.path.hasSuffix("/appium/settings") {
                settings = try self.body(request)["settings"] as? [String: Any] ?? [:]
            }
            return self.normal(request)
        }
        _ = try await makeClient().connect()
        XCTAssertEqual(capabilities["waitForIdleTimeout"] as? Int, 0)
        XCTAssertEqual(settings["waitForIdleTimeout"] as? Int, 0)
        XCTAssertEqual(settings["animationCoolOffTimeout"] as? Int, 0)
    }
    func testVideoRotationRefreshesCachedPointGeometry() async throws {
        var sizeReads = 0
        var point: [String: Any] = [:]
        StubProtocol.handler = { request in
            if request.url!.path.hasSuffix("/window/size") {
                sizeReads += 1
                let size = sizeReads == 1 ? ["width": 393, "height": 852] : ["width": 852, "height": 393]
                return (200, ["value": size])
            }
            if request.url!.path.hasSuffix("/actions") {
                let actions = try self.body(request)["actions"] as! [[String: Any]]
                point = (actions[0]["actions"] as! [[String: Any]])[0]
            }
            return self.normal(request)
        }
        let client = makeClient()
        _ = try await client.connect()
        try await client.gesture(from: CGPoint(x: 0.5, y: 0.25), to: .zero, hold: 0, move: 0, videoSize: CGSize(width: 2556, height: 1180))
        XCTAssertEqual(sizeReads, 2)
        XCTAssertEqual(point["x"] as? Int, 425)
        XCTAssertEqual(point["y"] as? Int, 98)
    }
    func testUnicodeTextIsSentAsJSONWithoutShellInterpolation() async throws {
        let text = "Caffè 👋\n$(literal)"
        var received = ""
        StubProtocol.handler = { request in
            if request.url!.path.hasSuffix("/wda/keys") {
                received = (try self.body(request)["value"] as? [String])?.first ?? ""
            }
            return self.normal(request)
        }
        let client = makeClient()
        _ = try await client.connect()
        try await client.type(text)
        XCTAssertEqual(received, text)
    }
    func testInvalidSessionIsRejectedWithoutReplayingGesture() async throws {
        var actionCount = 0
        StubProtocol.handler = { request in
            if request.url!.path.hasSuffix("/actions") {
                actionCount += 1
                return (404, ["value": ["error": "invalid session id", "message": "Sessione scaduta"]])
            }
            return self.normal(request)
        }
        let client = makeClient()
        _ = try await client.connect()
        do {
            try await client.gesture(from: .zero, to: .zero, hold: 0, move: 0)
            XCTFail("Expected invalid session")
        } catch { XCTAssertEqual(error.localizedDescription, "Sessione scaduta") }
        do { _ = try await client.windowSize(); XCTFail("Expected cleared session") }
        catch { XCTAssertEqual(error.localizedDescription, "Collega prima WebDriverAgent") }
        XCTAssertEqual(actionCount, 1)
    }
    func testLockedDeviceErrorExplainsRecovery() async throws {
        StubProtocol.handler = { request in
            if request.url!.path.hasSuffix("/wda/pressButton") {
                return (500, ["value": ["error": "unknown error", "message": "The request was denied: BSErrorCodeDescription=Locked"]])
            }
            return self.normal(request)
        }
        let client = makeClient()
        _ = try await client.connect()
        do { try await client.home(); XCTFail("Expected locked device error") }
        catch { XCTAssertEqual(error.localizedDescription, "L’iPhone è bloccato. Sbloccalo sul telefono, poi ricollega WDA.") }
    }
    func testReturnSendsOnlyUniqueChatButtonAndNeverRetries() async throws {
        for count in [0, 1, 2] {
            var clicks = 0
            var keys = 0
            var appReads = 0
            StubProtocol.handler = { request in
                let path = request.url!.path
                if path.hasSuffix("/wda/activeAppInfo") {
                    appReads += 1
                    return (200, ["value": ["bundleId": "net.whatsapp.WhatsApp"]])
                }
                if path.hasSuffix("/elements") {
                    let query = try self.body(request)
                    XCTAssertEqual(query["using"] as? String, "predicate string")
                    XCTAssertTrue((query["value"] as? String)?.contains("enabled == 1") == true)
                    return (200, ["value": (0..<count).map { ["element-6066-11e4-a52e-4f735466cecf": "send-\($0)"] }])
                }
                if path.hasSuffix("/click") { clicks += 1; XCTAssertTrue(path.hasSuffix("/element/send-0/click")) }
                if path.hasSuffix("/wda/keys") { keys += 1 }
                return self.normal(request)
            }
            let client = makeClient()
            _ = try await client.connect()
            let result = try await client.pressReturn()
            switch result {
            case .sent: XCTAssertEqual(count, 1)
            case .unavailable: XCTAssertNotEqual(count, 1)
            case .newline: XCTFail("No implicit newline in supported chat")
            }
            XCTAssertEqual(clicks, count == 1 ? 1 : 0)
            XCTAssertEqual(keys, 0)
            XCTAssertEqual(appReads, count == 1 ? 2 : 1)
        }
    }
    func testReturnOutsideSupportedChatTypesNewlineWithoutSearchingSend() async throws {
        var text = ""
        StubProtocol.handler = { request in
            let path = request.url!.path
            if path.hasSuffix("/wda/activeAppInfo") { return (200, ["value": ["bundleId": "com.apple.mobilemail"]]) }
            XCTAssertFalse(path.hasSuffix("/elements"))
            XCTAssertFalse(path.hasSuffix("/click"))
            if path.hasSuffix("/wda/keys") { text = (try self.body(request)["value"] as? [String])?.first ?? "" }
            return self.normal(request)
        }
        let client = makeClient()
        _ = try await client.connect()
        let result = try await client.pressReturn()
        guard case .newline = result else { return XCTFail("Expected newline") }
        XCTAssertEqual(text, "\n")
    }
    func testReturnDoesNotClickAfterForegroundAppChanges() async throws {
        var reads = 0
        StubProtocol.handler = { request in
            let path = request.url!.path
            if path.hasSuffix("/wda/activeAppInfo") {
                reads += 1
                return (200, ["value": ["bundleId": reads == 1 ? "com.apple.MobileSMS" : "com.apple.mobilemail"]])
            }
            if path.hasSuffix("/elements") { return (200, ["value": [["ELEMENT": "send"]]]) }
            XCTAssertFalse(path.hasSuffix("/click"))
            return self.normal(request)
        }
        let client = makeClient()
        _ = try await client.connect()
        let result = try await client.pressReturn()
        guard case .unavailable = result else { return XCTFail("Expected cancelled submit") }
    }
    func testSessionWithoutIdentifierFails() async throws {
        StubProtocol.handler = { _ in (200, ["value": [:]]) }
        do { _ = try await makeClient().connect(); XCTFail("Expected missing session error") }
        catch { XCTAssertEqual(error.localizedDescription, "WDA non ha restituito una sessione") }
    }
}
