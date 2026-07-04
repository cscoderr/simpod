//
//  FrameSink.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/11/26.
//
import Foundation
import Hummingbird
import HummingbirdWebSocket
import NIOCore

/// A parser pulls discrete frames/messages out of a stream of arbitrary-sized
/// byte chunks. MJPEG and AVCC have very different framing rules, so each
/// gets its own implementation; `FrameSink` owns the dispatch & write side.
protocol FrameParser: AnyObject {
    func parse(_ chunk: Data) -> [Data]
}

/// Drains framed messages from an upstream encoder onto a WebSocket.
///
/// Writes are serialised through a `Task` chain so we never call `outbound.write`
/// from two places at once — Hummingbird's writer is not safe to re-enter
/// concurrently, and dropping ordering would corrupt the AVCC stream.
final class FrameSink: @unchecked Sendable {
    private let outbound: WebSocketOutboundWriter
    private let parser: FrameParser
    private let lock = NSLock()
    private var lastWrite: Task<Void, Never>?

    init(outbound: WebSocketOutboundWriter, format: StreamFormat) {
        self.outbound = outbound
        self.parser = format.makeParser()
    }

    func write(_ data: Data) {
        for msg in parser.parse(data) {
            enqueue(msg)
        }
    }

    private func enqueue(_ data: Data) {
        let bytes = ByteBuffer(bytes: data)
        lock.lock()
        let prev = lastWrite
        let outbound = self.outbound
        // Each write awaits the previous one, forming a FIFO chain rooted in
        // the previous task. Once a frame is queued the prior task can fall
        // out of memory as soon as it finishes.
        lastWrite = Task {
            await prev?.value
            try? await outbound.write(.binary(bytes))
        }
        lock.unlock()
    }
}
