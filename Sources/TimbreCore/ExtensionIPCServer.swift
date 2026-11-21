// SPDX-License-Identifier: MPL-2.0
import Foundation
import Network
import Security

public struct TabAudioUpdate: Codable, Sendable {
    public let browser: String
    public let tabID: String
    public let title: String
    public let origin: String
    public let volume: Double
    public let isMuted: Bool

    public init(browser: String, tabID: String, title: String, origin: String, volume: Double, isMuted: Bool) {
        self.browser = browser
        self.tabID = tabID
        self.title = title
        self.origin = origin
        self.volume = volume
        self.isMuted = isMuted
    }
}

public enum IPCRequestValidator {
    public static let allowedOriginPrefixes = [
        "chrome-extension://",
        "safari-web-extension://",
        "moz-extension://"
    ]

    public static func generateEphemeralToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    public static func isAuthorized(bearerToken: String?, origin: String?, expectedToken: String) -> Bool {
        guard let bearerToken, bearerToken == expectedToken else { return false }
        guard let origin else { return false }
        return allowedOriginPrefixes.contains { origin.hasPrefix($0) }
    }
}

public final class ExtensionIPCServer: @unchecked Sendable {
    public let sessionToken: String
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "dev.v1torres.timbr.ipc")
    private let onTabUpdate: @Sendable (TabAudioUpdate) -> Void

    public init(onTabUpdate: @escaping @Sendable (TabAudioUpdate) -> Void) {
        self.sessionToken = IPCRequestValidator.generateEphemeralToken()
        self.onTabUpdate = onTabUpdate
    }

    public func start(port: UInt16 = 48192) throws {
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = NWEndpoint.hostPort(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: port)!)
        let l = try NWListener(using: params)
        l.newConnectionHandler = { [weak self] conn in
            self?.handle(conn)
        }
        l.start(queue: queue)
        self.listener = l
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ conn: NWConnection) {
        conn.start(queue: queue)
        conn.receive(minimumIncompleteLength: 1, maximumLength: 16384) { [weak self] data, _, _, _ in
            guard let self, let data, let raw = String(data: data, encoding: .utf8) else {
                conn.cancel()
                return
            }
            let status = self.processHTTPRequest(raw)
            let resp = "HTTP/1.1 \(status)\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok"
            conn.send(content: resp.data(using: .utf8), completion: .contentProcessed { _ in
                conn.cancel()
            })
        }
    }

    public func processHTTPRequest(_ raw: String) -> String {
        let parts = raw.components(separatedBy: "\r\n\r\n")
        guard let headerBlock = parts.first else { return "400 Bad Request" }
        let headers = headerBlock.components(separatedBy: "\r\n")
        var authToken: String?
        var origin: String?
        for h in headers {
            if h.lowercased().hasPrefix("authorization: bearer ") {
                authToken = String(h.dropFirst("authorization: bearer ".count)).trimmingCharacters(in: .whitespaces)
            } else if h.lowercased().hasPrefix("origin:") {
                origin = String(h.dropFirst("origin:".count)).trimmingCharacters(in: .whitespaces)
            }
        }
        guard let authToken, authToken == sessionToken else {
            return "401 Unauthorized"
        }
        guard IPCRequestValidator.isAuthorized(bearerToken: authToken, origin: origin, expectedToken: sessionToken) else {
            return "403 Forbidden"
        }
        if parts.count > 1, let bodyData = parts[1].data(using: .utf8),
           let update = try? JSONDecoder().decode(TabAudioUpdate.self, from: bodyData) {
            onTabUpdate(update)
            return "200 OK"
        }
        return "400 Bad Request"
    }
}
