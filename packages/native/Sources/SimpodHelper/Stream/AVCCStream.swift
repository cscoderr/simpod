//
//  AVCCStream.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/11/26.
//

import Foundation
import IOSurface

final class AVCCStream: Stream, @unchecked Sendable {
//    private(set) var config: StreamConfig
    private let sink: FrameSink
    private let jpeg: JPEGEncoder
    private let h264: H264Encoder
    private let scaler = IOSurfaceScaler()
    private let queue = DispatchQueue(label: "simpord.avcc.stream", qos: .userInteractive)
    
    let fps: Int
    let bitrate: Int
    let scale: Int = 1
    
    private var frameCapture: SimulatorFrameCapture?
    private var lastSurface: IOSurface?
    private var pump: DispatchSourceTimer?
    private var pendingForceKeyframe = true
    /// Pre-armed at start so the first surface emits a JPEG seed; later
    /// flips back on via `requestSnapshot()`.
    private var pendingSeedSnapshot = true
    
    init(
        sink: FrameSink,
        quality: Double = 0.7,
        fps: Int = 60,
        bitrate: Int = 8_000_000
    ) {
        self.sink = sink
        // Clamp to sane encoder bounds so a bad query param can't wedge
        // VideoToolbox.
        self.fps = max(1, min(fps, 120))
        self.bitrate = max(250_000, min(bitrate, 50_000_000))
        self.jpeg = JPEGEncoder(quality: quality)
        self.h264 = H264Encoder(fps: self.fps, bitrate: self.bitrate)
        self.h264.onEncoded = { [weak self] in self?.write($0) }
    }
    
    func start(frameCapture: SimulatorFrameCapture) throws {
        print("start: format=avcc fps=\(fps) bitrate=\(bitrate) scale=\(scale)")
        self.frameCapture = frameCapture
        try frameCapture.start { [weak self] surface in
            self?.handle(surface)
        }
    }
    
    func stop() {
        pump?.cancel()
        pump = nil
        frameCapture?.stop()
        frameCapture = nil
        lastSurface = nil
    }

    
    private func armPump() {
        pump?.cancel()
        let interval = 1.0 / Double(max(1, fps))
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in self?.pumpTick() }
        timer.resume()
        pump = timer
    }
    
    private func pumpTick() {
        guard let surface = lastSurface else { return }
        encode(surface)
    }
    
    func requestKeyframe() { pendingForceKeyframe = true }
    func requestSnapshot() { pendingSeedSnapshot = true }
    
    private func handle(_ surface: IOSurface) {
        queue.async { [weak self] in
            self?.lastSurface = surface
            self?.encode(surface)
            self?.armPump()
        }
    }
    
    private func encode(_ surface: IOSurface) {
        guard let pb = scaler.downscale(surface, scale: scale) else { return }
        if pendingSeedSnapshot {
            pendingSeedSnapshot = false
            if let bytes = jpeg.encode(pb) {
                sink.write(AVCCEnvelope.seed(jpeg: bytes))
            }
        }
        let force = pendingForceKeyframe
        pendingForceKeyframe = false
        h264.encode(pb, forceKeyframe: force)
    }
    
    private func write(_ encoded: H264Encoder.Encoded) {
        if let description = encoded.description {
            sink.write(AVCCEnvelope.description(avcc: description))
        }
        switch encoded.kind {
            case .keyframe: sink.write(AVCCEnvelope.keyframe(avcc: encoded.avcc))
            case .delta:    sink.write(AVCCEnvelope.delta(avcc: encoded.avcc))
        }
    }
}

