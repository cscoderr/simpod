//
//  HTTPServer.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/9/26.
//
import Foundation
import Hummingbird
import HummingbirdWebSocket
import NIOCore

final class HTTPServer: Sendable {
    private let udid: String
    private let port: Int
    private let host: String
    private let hidInput: HIDInput
    private let frameCapture: SimulatorFrameCapture
    private let accessibility: SimulatorAccessibilityBridge
    private let chromeRenderer: ChromeRenderer

    private let corsHeaders: HTTPFields = [
        .accessControlAllowOrigin: "*",
        .accessControlAllowMethods: "GET, POST, OPTIONS",
        .accessControlAllowHeaders: "Content-Type",
    ]

    init(udid: String, port: Int = 5400, host: String = "0.0.0.0") {
        self.udid = udid
        self.host = host
        self.port = port
        self.hidInput = HIDInput(udid: udid)
        self.frameCapture = SimulatorFrameCapture(udid: udid)
        self.accessibility = SimulatorAccessibilityBridge(udid: udid)
        self.chromeRenderer = ChromeRenderer()
    }

    func start() async throws {
        let router = Router()
        router.get("/") { req, ctx in self.handleRoot(req, ctx) }
        router.get("/ping") { req, ctx in self.handlePing(req, ctx) }
        router.get("/bezel.png") { req, ctx in self.handleBezel(req, ctx) }
        router.get("/chrome-button/:name") { req, ctx in self.handleChromeButton(req, ctx) }
        router.get("/chrome.json") { req, ctx in self.handleChromeProfile(req, ctx) }
        router.get("/ax.json") { req, ctx in self.handleAXTree(req, ctx) }

        let wsRouter = Router(context: BasicWebSocketRequestContext.self)
        wsRouter.ws("/ws") { _, _ in .upgrade([:]) } onUpgrade: { inbound, outbound, context in
            let params = context.request.uri.queryParameters
            await self.handleWS(
                format: params.get("format")
                    .flatMap { StreamFormat(rawValue: $0) } ?? .mjpeg,
                quality: params.get("quality").flatMap(Double.init) ?? 0.7,
                fps: params.get("fps").flatMap(Int.init) ?? 60,
                bitrate: params.get("bitrate").flatMap(Int.init) ?? 8_000_000,
                inbound: inbound,
                outbound: outbound
            )
        }

        let app = Application(
            router: router,
            server: .http1WebSocketUpgrade(webSocketRouter: wsRouter),
            configuration: .init(address: .hostname(host, port: port))
        )

        try await app.runService()
    }
}

// MARK: - HTTP route handlers

private extension HTTPServer {
    @Sendable func handleRoot(_ request: Request, _ context: some RequestContext) -> Response {
        jsonResponse(#"{"message":"Welcome to Simpod Helper server"}"#)
    }

    @Sendable func handlePing(_ request: Request, _ context: some RequestContext) -> Response {
        jsonResponse(#"{"status": true}"#)
    }

    @Sendable func handleBezel(_ request: Request, _ context: some RequestContext) -> Response {
        let withButtons = request.uri.queryParameters.get("buttons")
            .map { $0.lowercased() != "false" } ?? true

        guard let deviceName = resolveDeviceName(),
              let data = try? chromeRenderer.bezelPNG(forDeviceName: deviceName, includeButtons: withButtons)
        else {
            return plainText("no bezel for \(udid)", status: .notFound)
        }
        return imageResponse(data, contentType: "image/png")
    }

    @Sendable func handleChromeButton(_ request: Request, _ context: some RequestContext) -> Response {
        // Path is `/chrome-button/<name>` or `/chrome-button/<name>.png`.
        // We tolerate the `.png` suffix because it lets clients pretend the
        // URL is a static asset and lean on the browser cache.
        let raw = String(request.uri.path.split(separator: "/").last ?? "")
        let decoded = raw.removingPercentEncoding ?? ""
        let buttonName = decoded.hasSuffix(".png") ? String(decoded.dropLast(4)) : decoded
        let pressed = request.uri.queryParameters.get("pressed")
            .map { $0.lowercased() != "false" } ?? false

        guard let deviceName = resolveDeviceName(),
              let data = try? chromeRenderer.buttonPNG(
                  forDeviceName: deviceName, buttonName: buttonName, pressed: pressed
              )
        else {
            return plainText("no button \(decoded) for \(udid)", status: .notFound)
        }
        return imageResponse(data, contentType: "image/png")
    }

    @Sendable func handleAXTree(_ request: Request, _ context: some RequestContext) -> Response {
        let x = request.uri.queryParameters.get("x").flatMap(Double.init)
        let y = request.uri.queryParameters.get("y").flatMap(Double.init)
        do {
            let data: Data
            if let x, let y {
                data = try accessibility.describeAt(x: x, y: y)
            } else {
                data = try accessibility.describeUI()
            }
            var headers: HTTPFields = [
                .contentType: "application/json",
                .cacheControl: "no-store",
            ]
            headers.append(contentsOf: corsHeaders)
            return Response(
                status: .ok,
                headers: headers,
                body: .init(byteBuffer: ByteBuffer(bytes: data))
            )
        } catch {
            let payload = (try? JSONSerialization.data(
                withJSONObject: ["error": error.localizedDescription]
            )) ?? Data(#"{"error":"ax unavailable"}"#.utf8)
            return jsonResponse(
                String(decoding: payload, as: UTF8.self),
                status: .internalServerError
            )
        }
    }

    @Sendable func handleChromeProfile(_ request: Request, _ context: some RequestContext) -> Response {
        // The chrome profile JSON embeds absolute image URLs so the UI can
        // load them lazily. Clients can override the prefix
        let scheme = request.uri.scheme.map(\.rawValue) ?? "http"
        let defaultPrefix = "\(scheme)://127.0.0.1:\(port)"
        let prefix = request.uri.queryParameters.get("prefix") ?? defaultPrefix

        guard let deviceName = resolveDeviceName(),
              let rawData = try? chromeRenderer.chromeLayoutJSON(forDeviceName: deviceName, imagePrefix: prefix)
        else {
            return plainText("no chrome for \(udid)", status: .notFound)
        }

        // sortedKeys keeps the response stable so HTTP caches don't churn on
        // dictionary reorderings between requests.
        let data = try! JSONSerialization.data(withJSONObject: rawData, options: [.sortedKeys])
        return Response(
            status: .ok,
            headers: [.contentType: "application/json", .cacheControl: "no-cache"],
            body: .init(byteBuffer: ByteBuffer(bytes: data))
        )
    }
}

// MARK: - Response builders

private extension HTTPServer {
    func jsonResponse(_ body: String, status: HTTPResponse.Status = .ok) -> Response {
        var headers: HTTPFields = [
            .contentType: "application/json",
            .cacheControl: "no-cache, no-store"
        ]
        headers.append(contentsOf: corsHeaders)
        return Response(
            status: status,
            headers: headers,
            body: .init(byteBuffer: ByteBuffer(string: body))
        )
    }

    func plainText(_ body: String, status: HTTPResponse.Status) -> Response {
        Response(
            status: status,
            headers: [.contentType: "text/plain"],
            body: .init(byteBuffer: ByteBuffer(string: body))
        )
    }

    func imageResponse(_ data: Data, contentType: String) -> Response {
        var headers: HTTPFields = [.contentType: contentType, .cacheControl: "public, max-age=86400"]
        headers.append(contentsOf: corsHeaders)
        return Response(
            status: .ok,
            headers: headers,
            body: .init(byteBuffer: ByteBuffer(bytes: data))
        )
    }
}

// MARK: - WebSocket

private extension HTTPServer {
    func handleWS(
        format: StreamFormat,
        quality: Double,
        fps: Int,
        bitrate: Int,
        inbound: WebSocketInboundStream,
        outbound: WebSocketOutboundWriter
    ) async {
        print("[ws] stream format=\(format.rawValue) quality=\(quality) fps=\(fps) bitrate=\(bitrate)")
        let sink = FrameSink(outbound: outbound, format: format)
        let stream = format.makeStream(
            sink: sink,
            quality: min(max(quality, 0.1), 1.0),
            fps: fps,
            bitrate: bitrate
        )
        do {
            try stream.start(frameCapture: frameCapture)
        } catch {
            try? await outbound.write(.text(
                #"{"status":false,"error":"\#(error.localizedDescription)"}"#
            ))
            return
        }
        defer {
            stream.stop()
            frameCapture.stop()
        }

        do {
            for try await wsMessage in inbound.messages(maxSize: 1 << 16) {
                // Binary frames are ignored — the protocol is text-only one way
                // (commands in) and binary one way (video out).
                guard case .text(let message) = wsMessage else { continue }
                if await handleHIDInputWs(line: message, outbound: outbound) { continue }
                if await handleAccessibilityWs(line: message, outbound: outbound) { continue }
            }
        } catch {}
    }

    func resolveDeviceName() -> String? {
        guard let device = SimulatorHelper.findSimDevice(with: udid) else { return nil }
        return (device.value(forKey: "deviceType") as? NSObject)
            .flatMap { $0.value(forKey: "name") as? String } ?? "Unknown"
    }

    func handleAccessibilityWs(line: String, outbound: WebSocketOutboundWriter) async -> Bool {
        guard let data = line.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (dict["wsType"] as? String) == "describe_ui"
        else {
            return false
        }

        let result: Data
        do {
            if let jsonData = dict["data"] as? [String: Any],
               let x = (jsonData["x"] as? Double) ?? (jsonData["x"] as? Int).map(Double.init),
               let y = (jsonData["y"] as? Double) ?? (jsonData["y"] as? Int).map(Double.init)
            {
                result = try accessibility.describeAt(x: x, y: y)
            } else {
                result = try accessibility.describeUI()
            }
        } catch {
            return true
        }
        try? await outbound.write(.text(String(decoding: result, as: UTF8.self)))
        return true
    }

    func handleHIDInputWs(line: String, outbound: WebSocketOutboundWriter) async -> Bool {
        guard let data = line.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (dict["wsType"] as? String) == "hid_input",
              let type = dict["type"] as? String,
              let jsonData = dict["data"] as? [String: Any],
              let payload = try? JSONSerialization.data(withJSONObject: jsonData)
        else {
            return parseDict(line)?["wsType"] as? String == "hid_input"
        }

        let messageType = WebSocketMessageType(rawValue: type)
        switch messageType {
        case .touch:
            await dispatch(type: type, payload: payload, outbound: outbound, log: "Touch") { (json: TouchEventPayload) in
                try self.hidInput.touch(
                    phase: HIDInput.TouchPhase(rawValue: json.phase) ?? .unknown,
                    x: json.x,
                    y: json.y,
                    edge: HIDInput.TouchEdge(rawValue: json.edge ?? 0) ?? .none
                )
            }
        case .button:
            await dispatch(type: type, payload: payload, outbound: outbound, log: "Button") { (json: ButtonEventPayload) in
                let hardwareButton = HIDInput.HardwareButton(rawValue: json.button) ?? .home
                try self.hidInput.press(hardwareButton)
            }
        case .pinch:
            await dispatch(type: type, payload: payload, outbound: outbound, log: "MultiTouch") { (json: MultiTouchEventPayload) in
                try self.hidInput.pinch(
                    phase: HIDInput.TouchPhase(rawValue: json.phase) ?? .unknown,
                    x1: json.x1, y1: json.y1, x2: json.x2, y2: json.y2
                )
            }
        case .key:
            // Key errors aren't logged historically — the keyboard event
            // stream is high-volume and noisy if we report each miss.
            await dispatch(type: type, payload: payload, outbound: outbound, log: nil) { (json: KeyEventPayload) in
                try self.hidInput.key(usage: json.usage, type: HIDInput.KeyType(rawValue: json.event))
            }
        case .orientation:
            await dispatch(type: type, payload: payload, outbound: outbound, log: "Orientation") { (json: OrientationEventPayload) in
                let deviceOrientation = HIDInput.DeviceOrientation(rawValue: json.orientation) ?? .unknown
                _ = try self.hidInput.setOrientation(deviceOrientation)
            }
        default:
            break
        }
        return true
    }

    /// Decode `payload` into `T`, run `body`, and emit a JSON error frame on
    /// failure. Reduces the per-event boilerplate to a single line per case.
    func dispatch<T: Decodable>(
        type: String,
        payload: Data,
        outbound: WebSocketOutboundWriter,
        log tag: String?,
        body: (T) throws -> Void
    ) async {
        guard let json = try? JSONDecoder().decode(T.self, from: payload) else { return }
        do {
            try body(json)
        } catch {
            try? await outbound.write(.text(
                #"{"type":"\#(type)","status":false,"error":"\#(error.localizedDescription)"}"#
            ))
            if let tag {
                print("[simpod] \(tag) error \(error.localizedDescription)")
            }
        }
    }

    /// Best-effort JSON parse without throwing — used only to decide whether
    /// to return `true` (claim the message) when required fields are missing.
    func parseDict(_ line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return dict
    }
}
