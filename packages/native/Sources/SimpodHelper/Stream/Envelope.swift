//
//  Envelope.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/11/26.
//
import Foundation

enum MJPEGEnvelope {
    static let header: Data = Data(
        "HTTP/1.1 200 OK\r\nContent-Type: multipart/x-mixed-replace; boundary=frame\r\n\r\n".utf8
    )
    
    static func send(frame jpeg: Data) -> Data {
        let header = "--frame\r\nContent-Type: image/jpeg\r\nContent-Length: \(jpeg.count)\r\n\r\n"
        var chunk = Data()
        chunk.append(Data(header.utf8))
        chunk.append(jpeg)
        chunk.append(Data("\r\n".utf8))
        return chunk
    }
}

enum AVCCEnvelope {
    static let descriptionTag: UInt8 = 0x01
    static let keyframeTag: UInt8 = 0x02
    static let deltaTag: UInt8 = 0x03
    static let seedTag: UInt8 = 0x04
    
    static func description(avcc: Data) -> Data { wrap(tag: descriptionTag, payload: avcc) }
    static func keyframe(avcc: Data) -> Data { wrap(tag: keyframeTag, payload: avcc) }
    static func delta(avcc: Data) -> Data { wrap(tag: deltaTag, payload: avcc) }
    static func seed(jpeg: Data) -> Data { wrap(tag: seedTag, payload: jpeg) }
    
    private static func wrap(tag: UInt8, payload: Data) -> Data {
        let length = UInt32(payload.count + 1)
        var out = Data(capacity: 5 + payload.count)
        out.append(UInt8((length >> 24) & 0xFF))
        out.append(UInt8((length >> 16) & 0xFF))
        out.append(UInt8((length >> 8) & 0xFF))
        out.append(UInt8(length & 0xFF))
        out.append(tag)
        out.append(payload)
        return out
    }
}
