import CoreGraphics
import Foundation

public enum RemoteError: LocalizedError {
    case message(String)
    public var errorDescription: String? { if case let .message(text) = self { return text }; return nil }
}

/// Only HTTP on loopback; no private Apple APIs are linked by the Mac app.
/// The separate WDA runner does use private XCTest APIs.
public actor WDAClient {
    private let base = URL(string: "http://127.0.0.1:8100")!
    private let http: URLSession
    private var sessionID: String?
    private var cachedSize: CGSize?
    public init(session: URLSession? = nil) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12
        configuration.connectionProxyDictionary = [:]
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        http = session ?? URLSession(configuration: configuration)
    }
    private func request(_ method: String, _ path: String, _ body: [String: Any]? = nil) async throws -> [String: Any] {
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.httpMethod = method
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await http.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw RemoteError.message("Risposta WDA non HTTP") }
        guard let result = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw RemoteError.message("WDA ha restituito una risposta JSON non valida")
        }
        let value = result["value"] as? [String: Any]
        guard (200..<300).contains(response.statusCode), value?["error"] == nil else {
            if value?["error"] as? String == "invalid session id", let id = sessionID,
               path.hasPrefix("session/\(id)/") { sessionID = nil; cachedSize = nil }
            let message = value?["message"] as? String ?? "WDA HTTP \(response.statusCode)"
            if message.contains("BSErrorCodeDescription=Locked") || message.contains("device was not, or could not be, unlocked") {
                throw RemoteError.message("L’iPhone è bloccato. Sbloccalo sul telefono, poi ricollega WDA.")
            }
            throw RemoteError.message(message)
        }
        return result
    }
    public func connect() async throws -> CGSize {
        cachedSize = nil
        _ = try await request("GET", "status")
        let result = try await request("POST", "session", ["capabilities": ["alwaysMatch": ["shouldWaitForQuiescence": false, "waitForIdleTimeout": 0, "disableAutomaticScreenshots": true]]])
        let value = result["value"] as? [String: Any]
        guard let id = result["sessionId"] as? String ?? value?["sessionId"] as? String else {
            throw RemoteError.message("WDA non ha restituito una sessione")
        }
        sessionID = id
        // Interactive input should not wait for an app to finish every animation.
        _ = try await request("POST", try sessionPath("appium/settings"), ["settings": ["waitForIdleTimeout": 0, "animationCoolOffTimeout": 0]])
        return try await windowSize()
    }
    private func sessionPath(_ suffix: String) throws -> String {
        guard let sessionID else { throw RemoteError.message("Collega prima WebDriverAgent") }
        return "session/\(sessionID)/\(suffix)"
    }
    public func checkConnection() async throws {
        _ = try await request("GET", try sessionPath("appium/settings"))
    }
    public func windowSize() async throws -> CGSize {
        let result = try await request("GET", try sessionPath("window/size"))
        guard let value = result["value"] as? [String: Any], let width = value["width"] as? Double,
              let height = value["height"] as? Double, width > 0, height > 0 else {
            throw RemoteError.message("Dimensioni schermo WDA non valide")
        }
        let size = CGSize(width: width, height: height)
        cachedSize = size
        return size
    }
    public func gesture(from: CGPoint, to: CGPoint, hold: Double, move: Double, endHold: Double = 0, videoSize: CGSize? = nil) async throws {
        // A video orientation change invalidates the cached iOS-point geometry.
        // Stable portrait/landscape input avoids an expensive accessibility query per click.
        if let videoSize, videoSize.width > 0, videoSize.height > 0, let cachedSize,
           (videoSize.width > videoSize.height) != (cachedSize.width > cachedSize.height) {
            self.cachedSize = nil
        }
        let size: CGSize
        if let cachedSize { size = cachedSize }
        else { size = try await windowSize() }
        let a = ScreenGeometry.devicePoint(from, size: size), b = ScreenGeometry.devicePoint(to, size: size)
        var actions: [[String: Any]] = [
            ["type": "pointerMove", "duration": 0, "x": Int(a.x), "y": Int(a.y), "origin": "viewport"],
            ["type": "pointerDown", "button": 0]
        ]
        if hold > 0 { actions.append(["type": "pause", "duration": Int(min(hold, 3) * 1000)]) }
        if move > 0 { actions.append(["type": "pointerMove", "duration": Int(min(max(move, 0.1), 2) * 1000), "x": Int(b.x), "y": Int(b.y), "origin": "viewport"]) }
        if endHold > 0 { actions.append(["type": "pause", "duration": Int(min(endHold, 2) * 1000)]) }
        actions.append(["type": "pointerUp", "button": 0])
        _ = try await request("POST", try sessionPath("actions"), ["actions": [["type": "pointer", "id": "finger", "parameters": ["pointerType": "touch"], "actions": actions]]])
    }
    public func type(_ text: String) async throws {
        _ = try await request("POST", try sessionPath("wda/keys"), ["value": [text]])
    }
    public enum ReturnResult { case sent, newline, unavailable }

    /// Conservative chat support: never guess coordinates or click a generic form button.
    public func pressReturn() async throws -> ReturnResult {
        let info = try await request("GET", try sessionPath("wda/activeAppInfo"))
        guard let app = (info["value"] as? [String: Any])?["bundleId"] as? String else {
            return .unavailable
        }
        let chatApps: Set<String> = ["com.apple.MobileSMS", "net.whatsapp.WhatsApp",
                                     "ph.telegra.Telegraph", "org.whispersystems.signal"]
        guard chatApps.contains(app) else {
            try await type("\n")
            return .newline
        }
        let predicate = "type == 'XCUIElementTypeButton' AND visible == 1 AND enabled == 1 AND (label IN {'Send', 'Invia', 'Send message', 'Invia messaggio'} OR name IN {'Send', 'Invia', 'Send message', 'Invia messaggio'})"
        let result = try await request("POST", try sessionPath("elements"),
                                       ["using": "predicate string", "value": predicate])
        guard let elements = result["value"] as? [[String: Any]], elements.count == 1,
              let id = elements[0]["element-6066-11e4-a52e-4f735466cecf"] as? String ?? elements[0]["ELEMENT"] as? String,
              !id.isEmpty, !id.contains("/") else { return .unavailable }
        // Recheck the foreground app immediately before a potentially irreversible click.
        let current = try await request("GET", try sessionPath("wda/activeAppInfo"))
        guard (current["value"] as? [String: Any])?["bundleId"] as? String == app else { return .unavailable }
        _ = try await request("POST", try sessionPath("element/\(id)/click"), [:])
        return .sent
    }
    public func controlCenter(videoSize: CGSize? = nil) async throws {
        try await gesture(from: CGPoint(x: 0.95, y: 0.005), to: CGPoint(x: 0.95, y: 0.65), hold: 0, move: 0.25, videoSize: videoSize)
    }
    public func notifications(videoSize: CGSize? = nil) async throws {
        try await gesture(from: CGPoint(x: 0.3, y: 0.005), to: CGPoint(x: 0.3, y: 0.65), hold: 0, move: 0.25, videoSize: videoSize)
    }
    public func appSwitcher() async throws {
        // Native XCTest drag recognizes the system edge gesture on this physical iPhone;
        // the equivalent W3C touch sequence returned to Home during device verification.
        let size = try await windowSize()
        _ = try await request("POST", try sessionPath("wda/dragfromtoforduration"),
                              ["fromX": Int((size.width - 1) * 0.5), "fromY": Int(size.height - 1),
                               "toX": Int((size.width - 1) * 0.5), "toY": Int((size.height - 1) * 0.53),
                               "duration": 0.2])
    }
    public func home() async throws { _ = try await request("POST", try sessionPath("wda/pressButton"), ["name": "home"]) }
    public func disconnect() async {
        let oldID = sessionID
        sessionID = nil; cachedSize = nil
        if let oldID { _ = try? await request("DELETE", "session/\(oldID)") }
    }
}
