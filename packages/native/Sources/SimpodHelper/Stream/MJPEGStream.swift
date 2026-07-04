//
//  MJPEGStream.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/11/26.
//
import Foundation
import CoreMedia
import CoreImage
import IOSurface
import CoreVideo

final class MJPEGStream: Stream, @unchecked Sendable {
    private let lock = NSLock()
    private let jpeg: JPEGEncoder
    private let sink: FrameSink
    private let scaler = IOSurfaceScaler()
    private var frameCapture: SimulatorFrameCapture?
    private var last: UInt32 = 0
    private let queue = DispatchQueue(label: "simpod.mjpeg.stream", qos: .userInteractive)
    
    init(sink: FrameSink, quality: Double) {
        self.sink = sink
        sink.write(MJPEGEnvelope.header)
        self.jpeg = JPEGEncoder(quality: quality)
    }
    
    func start(frameCapture: SimulatorFrameCapture) throws {
        self.frameCapture = frameCapture
        try frameCapture.start {[weak self] surface in
            self?.handle(surface)
        }
    }
    
    func stop() {
        frameCapture?.stop()
        frameCapture = nil
    }
    
    func requestKeyframe() { }
    func requestSnapshot() { }
    
    private func handle(_ surface: IOSurface) {
        guard shouldEmit(surface) else { return }
        queue.async { [weak self] in self?.encode(surface) }
    }
    
    private func shouldEmit(_ surface: IOSurface) -> Bool {
        var seed: UInt32 = 0
        surface.lock(options: .readOnly, seed: &seed)
        surface.unlock(options: .readOnly, seed: nil)
        guard seed != last else { return false }
        last = seed
        return true
    }
    
    private func encode(_ surface: IOSurface) {
        guard let pb = scaler.downscale(surface, scale: 1) else { return }
        guard let bytes = jpeg.encode(pb) else { return }
        sink.write(MJPEGEnvelope.send(frame: bytes))
    }
}
