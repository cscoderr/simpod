//
//  MJPEGFrameParser.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/11/26.
//

import Foundation

/// Pulls individual JPEGs out of the multipart/x-mixed-replace byte stream
/// emitted by `MJPEGStream`. Each frame is bounded by the SOI (0xFFD8) and
/// EOI (0xFFD9) markers from the JPEG standard.
final class MJPEGFrameParser: FrameParser {
    private var buffer = Data()
    /// `MJPEGStream` prepends an HTTP-style envelope header so that the same
    /// byte stream could in principle be served over plain HTTP. We strip
    /// it here before any JPEG scanning starts.
    private var headerSkipped = false

    func parse(_ chunk: Data) -> [Data] {
        if !headerSkipped {
            buffer.append(chunk)
            if let r = buffer.range(of: Data("\r\n\r\n".utf8)) {
                buffer = Data(buffer[r.upperBound...])
                headerSkipped = true
            } else {
                return []
            }
        } else {
            buffer.append(chunk)
        }

        // Protect against unbounded growth if a producer somehow stops emitting
        // EOI markers. 2 MiB is generous compared to a single iPhone frame.
        if buffer.count > 2 * 1024 * 1024 {
            buffer = Data(buffer.suffix(1024 * 1024))
        }

        var frames: [Data] = []
        while true {
            guard let soi = buffer.firstRange(of: Data([0xFF, 0xD8])) else { break }
            let after = buffer.index(soi.lowerBound, offsetBy: 2)
            guard after < buffer.endIndex,
                  let eoi = buffer[after...].firstRange(of: Data([0xFF, 0xD9]))
            else { break }
            frames.append(Data(buffer[soi.lowerBound ..< eoi.upperBound]))
            buffer = Data(buffer[eoi.upperBound...])
        }
        return frames
    }
}
