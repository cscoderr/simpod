//
//  StreamFormat.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/9/26.
//

import Foundation

enum StreamFormat: String {
    case mjpeg
    case avcc

    func makeStream(
        sink: FrameSink,
        quality: Double,
        fps: Int = 60,
        bitrate: Int = 8_000_000
    ) -> any Stream {
        switch self {
        case .mjpeg: return MJPEGStream(sink: sink, quality: quality)
        case .avcc:
            return AVCCStream(
                sink: sink, quality: quality, fps: fps, bitrate: bitrate
            )
        }
    }

    func makeParser() -> FrameParser {
        switch self {
        case .mjpeg: return MJPEGFrameParser()
        case .avcc:  return AVCCFrameParser()
        }
    }
}
