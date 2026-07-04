//
//  H264Encoder.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/7/26.
//
import Foundation
import CoreVideo
import CoreMedia
import VideoToolbox
import ImageIO


// `@unchecked Sendable` because VideoToolbox fires its compression
// callback on an internal queue. The encoder is driven from AVCCStream's
// serial queue, and `setBitrate(_:)` synchronises through `lock`.
final class H264Encoder: @unchecked Sendable {
    
    struct Encoded {
        let description: Data?
        let kind: Kind
        let avcc: Data
        
        enum Kind { case keyframe, delta }
    }
    
    private let lock = NSLock()
    
    var onEncoded: (@Sendable (Encoded) -> Void)?
    
    private var session: VTCompressionSession?
    private var width: Int32 = 0
    private var height: Int32 = 0
    private let fps: Int32
    private var bitrate: Int
    private var emittedDescription = false
    private var frameCount: Int64 = 0
    
    init(fps: Int, bitrate: Int = 2_000_000) {
        self.fps = Int32(fps)
        self.bitrate = bitrate
    }
    
    deinit {
        if let session {
            VTCompressionSessionInvalidate(session)
        }
    }
    
    func setBitrate(_ bps: Int) {
        lock.lock()
        defer { lock.unlock() }
        bitrate = bps
        guard let session else { return }
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate,
                             value: NSNumber(value: bps))
    }
    
    func encode(_ pixelBuffer: CVPixelBuffer, forceKeyframe: Bool = false, completion: (() -> Void)? = nil) {
        let w = Int32(CVPixelBufferGetWidth(pixelBuffer))
        let h = Int32(CVPixelBufferGetHeight(pixelBuffer))
        
        if session == nil || w != width || h != height {
            width = w
            height = h
            try? rebuildSession()
        }
        guard let session else { return }
        
        let frameProperties: NSDictionary? = forceKeyframe
        ? [kVTEncodeFrameOptionKey_ForceKeyFrame: kCFBooleanTrue!] as NSDictionary
        : nil
        
        frameCount += 1
        let presentationTimeStamp = CMTime(value: frameCount, timescale: fps)
        
        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: presentationTimeStamp,
            duration: .invalid,
            frameProperties: frameProperties,
            infoFlagsOut: nil
        ) { [weak self] status, _, sampleBuffer in
            guard let self, status == noErr, let sb = sampleBuffer else { return }
            if let encoded = self.extract(from: sb) {
                self.onEncoded?(encoded)
            }
        }
        
        if status != noErr {
            completion?()
        }
    }
    
    private func rebuildSession() throws {
        if let session {
            VTCompressionSessionInvalidate(session)
            self.session = nil
        }
        
        var sess: VTCompressionSession?
        let lowLatencySpec: NSDictionary = [
            kVTVideoEncoderSpecification_EnableLowLatencyRateControl: kCFBooleanTrue!,
        ]
        func create(spec: CFDictionary?) -> OSStatus {
            VTCompressionSessionCreate(
                allocator: kCFAllocatorDefault,
                width: width, height: height,
                codecType: kCMVideoCodecType_H264,
                encoderSpecification: spec,
                imageBufferAttributes: nil,
                compressedDataAllocator: kCFAllocatorDefault,
                outputCallback: nil,
                refcon: nil,
                compressionSessionOut: &sess
            )
        }
        let status = create(spec: lowLatencySpec)
        guard status == noErr, let sess else { return }
        
        let props: [(CFString, Any)] = [
            (kVTCompressionPropertyKey_RealTime, kCFBooleanTrue!),
            (kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_High_AutoLevel),
            (kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse!),
            (kVTCompressionPropertyKey_AverageBitRate, NSNumber(value: bitrate)),
            (kVTCompressionPropertyKey_ExpectedFrameRate, NSNumber(value: fps)),
            // 5-second keyframe interval — IDRs are ~5–10× larger than
            // P-frames, so a forced IDR mid-stream causes a visible
            // encode/transport stall. Spacing them out by 5s keeps the
            // typical pinch / scroll gesture inside one P-frame run, so
            // motion stays smooth. Late-joiner resync waits up to 5s,
            // which we sidestep by emitting a JPEG seed on first frame.
            (kVTCompressionPropertyKey_MaxKeyFrameInterval, NSNumber(value: fps * 5)),
        ]
        for (key, value) in props {
            VTSessionSetProperty(sess, key: key, value: value as CFTypeRef)
        }
        VTCompressionSessionPrepareToEncodeFrames(sess)
        
        session = sess
        emittedDescription = false
    }
    
    private func extract(from sample: CMSampleBuffer) -> Encoded? {
        let isKeyframe = !notSync(sample)
        guard let dataBuf = CMSampleBufferGetDataBuffer(sample) else { return nil }
        
        var totalLength = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(
            dataBuf, atOffset: 0, lengthAtOffsetOut: nil,
            totalLengthOut: &totalLength, dataPointerOut: &dataPointer
        ) == noErr, let dataPointer else {
            return nil
        }
        let avcc = Data(bytes: dataPointer, count: totalLength)
        
        var description: Data?
        if isKeyframe, !emittedDescription, let format = CMSampleBufferGetFormatDescription(sample) {
            description = avcCBlob(from: format)
            emittedDescription = description != nil
        }
        
        return Encoded(
            description: description,
            kind: isKeyframe ? .keyframe : .delta,
            avcc: avcc
        )
    }
    
    private func notSync(_ sample: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false),
              CFArrayGetCount(attachments) > 0,
              let dict = CFArrayGetValueAtIndex(attachments, 0)
        else { return false }
        let cfDict = unsafeBitCast(dict, to: CFDictionary.self)
        return CFDictionaryContainsKey(cfDict, Unmanaged.passUnretained(kCMSampleAttachmentKey_NotSync).toOpaque())
    }
    
    private func avcCBlob(from format: CMFormatDescription) -> Data? {
        var spsCount = 0
        var spsPtr: UnsafePointer<UInt8>?
        var spsSize = 0
        var nalSize: Int32 = 0
        guard CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            format, parameterSetIndex: 0,
            parameterSetPointerOut: &spsPtr, parameterSetSizeOut: &spsSize,
            parameterSetCountOut: &spsCount, nalUnitHeaderLengthOut: &nalSize
        ) == noErr, let spsPtr else { return nil }
        
        var ppsPtr: UnsafePointer<UInt8>?
        var ppsSize = 0
        guard CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            format, parameterSetIndex: 1,
            parameterSetPointerOut: &ppsPtr,
            parameterSetSizeOut: &ppsSize,
            parameterSetCountOut: nil,
            nalUnitHeaderLengthOut: nil
        ) == noErr, let ppsPtr else { return nil }
        
        let sps = UnsafeBufferPointer(start: spsPtr, count: spsSize)
        let pps = UnsafeBufferPointer(start: ppsPtr, count: ppsSize)
        var blob = Data()
        blob.append(0x01)
        blob.append(sps[1])
        blob.append(sps[2])
        blob.append(sps[3])
        blob.append(0xFF)
        blob.append(0xE1)
        blob.append(UInt8((spsSize >> 8) & 0xFF))
        blob.append(UInt8(spsSize & 0xFF))
        blob.append(contentsOf: sps)
        blob.append(0x01)
        blob.append(UInt8((ppsSize >> 8) & 0xFF))
        blob.append(UInt8(ppsSize & 0xFF))
        blob.append(contentsOf: pps)
        return blob
    }
}

