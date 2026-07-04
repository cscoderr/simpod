//
//  IOSurfaceScaler.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/11/26.
//
import Foundation
import CoreImage
import IOSurface

final class IOSurfaceScaler {
    private let context = CIContext(options: [.priorityRequestLow: false])
    private var pool: CVPixelBufferPool?
    private var poolWidth: Int = 0
    private var poolHeight: Int = 0
    
    func downscale(_ surface: IOSurface, scale: Int) -> CVPixelBuffer? {
        let w = IOSurfaceGetWidth(surface)
        let h = IOSurfaceGetHeight(surface)
        let dstW = max(2, w / scale)
        let dstH = max(2, h / scale)
        
        if pool == nil || dstW != poolWidth || dstH != poolHeight {
            let attrs: [CFString: Any] = [
                kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey: dstW,
                kCVPixelBufferHeightKey: dstH,
                kCVPixelBufferIOSurfacePropertiesKey: [:] as [CFString: Any],
            ]
            var p: CVPixelBufferPool?
            CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &p)
            pool = p
            poolWidth = dstW
            poolHeight = dstH
        }
        guard let pool else { return nil }
        
        var pbOut: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pbOut)
        guard let dst = pbOut else { return nil }
        
        let src = CIImage(ioSurface: surface)
        let sx = CGFloat(dstW) / CGFloat(w)
        let sy = CGFloat(dstH) / CGFloat(h)
        context.render(src.transformed(by: CGAffineTransform(scaleX: sx, y: sy)), to: dst)
        return dst
    }
}
