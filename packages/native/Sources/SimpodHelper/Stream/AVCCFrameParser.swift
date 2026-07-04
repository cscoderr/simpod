//
//  AVCCFrameParser.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/11/26.
//

import Foundation

/// AVCC framing is a stream of length-prefixed payloads: a 4-byte big-endian
/// length followed by `length` bytes of body. We accumulate bytes until each
/// length+body is fully present, then emit the body up to the caller.
final class AVCCFrameParser: FrameParser {
    private var buffer = Data()

    func parse(_ chunk: Data) -> [Data] {
        buffer.append(chunk)
        var msgs: [Data] = []
        while buffer.count >= 4 {
            let length =
                Int(buffer[buffer.startIndex]) << 24 |
                Int(buffer[buffer.startIndex + 1]) << 16 |
                Int(buffer[buffer.startIndex + 2]) << 8  |
                Int(buffer[buffer.startIndex + 3])
            // length == 0 is never legal here; treat negative-looking values
            // (high bit set) as a desync signal and stop draining.
            guard length > 0, buffer.count >= 4 + length else { break }
            let body = Data(buffer[
                buffer.startIndex + 4 ..< buffer.startIndex + 4 + length
            ])
            buffer = Data(buffer[(buffer.startIndex + 4 + length)...])
            msgs.append(body)
        }
        return msgs
    }
}
