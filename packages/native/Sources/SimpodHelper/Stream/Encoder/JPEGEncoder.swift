//
//  JPEGEncoder.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/7/26.
//
import Foundation
import CoreVideo
import CoreGraphics
import ImageIO

final class JPEGEncoder {
    let quality: Double
    
    init(quality: Double = 0.7) {
        self.quality = quality
    }
    
    func encode(_ pixelBuffer: CVPixelBuffer) -> Data? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width  = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytePerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: base,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytePerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue |
            CGBitmapInfo.byteOrder32Little.rawValue
        ), let cgImage = context.makeImage() else {
            return nil
        }
        
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            out, "public.jpeg" as CFString, 1, nil
        ) else { return nil }
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(dest, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}
