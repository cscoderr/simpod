//
//  SimulatorFrameCapture.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/11/26.
//
import Foundation
import CoreMedia

final class SimulatorFrameCapture: @unchecked Sendable {
    private let udid: String
    private let queue = DispatchQueue(label: "simpod.simulator.frame.capture", qos: .userInteractive)
    
    private var onFrame: (@Sendable (IOSurface) -> Void)?
    private var ioClient: NSObject?
    private var descriptors: [NSObject] = []
    private var callbackUUIDs: [ObjectIdentifier: NSUUID] = [:]
    
    init(udid: String) {
        self.udid = udid
    }
    
    func start(onFrame: @escaping @Sendable (IOSurface) -> Void) throws {
        self.onFrame = onFrame
        
        guard let device = SimulatorHelper.findSimDevice(with: udid) else {
            throw makeError(2, "Device \(udid) not found")
        }
        
        guard let io = device.perform(NSSelectorFromString("io"))?.takeUnretainedValue() as? NSObject else {
            throw makeError(3, "Failed to get device IO")
        }
        self.ioClient = io
        try wireFramebuffer()
    }
    
    func stop() {
        let unregSel = NSSelectorFromString("unregisterScreenCallbacksWithUUID:")
        for desc in descriptors {
            if let uuid = callbackUUIDs[ObjectIdentifier(desc)],
               desc.responds(to: unregSel) {
                desc.perform(unregSel, with: uuid)
            }
        }
        
        callbackUUIDs.removeAll()
        descriptors.removeAll()
        ioClient = nil
        onFrame = nil
    }
    
    private func wireFramebuffer() throws {
        guard let io = ioClient else { throw makeError(3, "No IO client") }
        
        io.perform(NSSelectorFromString("updateIOPorts"))
        
        guard let ports = io.value(forKey: "deviceIOPorts") as? [NSObject] else {
            throw makeError(4, "No device IO ports")
        }
        
        let pidSel = NSSelectorFromString("portIdentifier")
        let descSel = NSSelectorFromString("descriptor")
        let surfSel = NSSelectorFromString("framebufferSurface")
        
        var candidates: [NSObject] = []
        for port in ports where port.responds(to: pidSel) {
            guard let pid = port.perform(pidSel)?.takeUnretainedValue(),
                  "\(pid)" == "com.apple.framebuffer.display",
                  port.responds(to: descSel),
                  let desc = port.perform(descSel)?.takeUnretainedValue() as? NSObject,
                  desc.responds(to: surfSel)
            else { continue }
            candidates.append(desc)
        }
        if candidates.isEmpty { throw makeError(5, "No framebuffer display descriptor found") }
        descriptors = candidates
        
        for desc in candidates {
            try registerCallbacks(desc: desc)
        }
    }
    
    private func findBestDescriptor() -> IOSurface? {
        let surfSel = NSSelectorFromString("framebufferSurface")
        var best: IOSurface?
        var bestArea: Int = 0
        for desc in descriptors {
            guard let surfObj = desc.perform(surfSel)?.takeUnretainedValue() else { continue }
            let surf = unsafeDowncast(surfObj, to: IOSurface.self)
            let area = IOSurfaceGetWidth(surf) * IOSurfaceGetHeight(surf)
            if area > bestArea {
                best = surf
                bestArea = area
            }
        }
        return best
    }
    
    private func registerCallbacks(desc: NSObject) throws {
        let selector = NSSelectorFromString(
            "registerScreenCallbacksWithUUID:callbackQueue:frameCallback:" +
            "surfacesChangedCallback:propertiesChangedCallback:"
        )
        guard desc.responds(to: selector) else {
            throw makeError(8, "Descriptor doesn't support registerScreenCallbacks")
        }
        
        let uuid = NSUUID()
        callbackUUIDs[ObjectIdentifier(desc)] = uuid
        
        // Bind strong inside the block before re-dispatching, so the inner
        // `queue.async` closure captures a non-optional `self` instead of
        // re-piercing the weak optional under a `@Sendable` boundary.
        let frame: @convention(block) () -> Void = { [weak self] in
            guard let self else { return }
            self.queue.async { self.captureLastestFrame() }
        }
        let surfaces: @convention(block) () -> Void = { [weak self] in
            guard let self else { return }
            self.queue.async { self.captureLastestFrame() }
        }
        let props: @convention(block) () -> Void = {}
        
        guard let imp = class_getMethodImplementation(type(of: desc), selector) else {
            throw makeError(9, "objc_msgSend not found")
        }
        
        typealias MsgFunc = @convention(c) (
            AnyObject, Selector, AnyObject, AnyObject, AnyObject, AnyObject, AnyObject
        ) -> Void
        let msg = unsafeBitCast(imp, to: MsgFunc.self)
        
        msg(
            desc,
            selector,
            uuid,
            queue as AnyObject,
            frame as AnyObject,
            surfaces as AnyObject,
            props as AnyObject
        )
    }
    
    private func captureLastestFrame() {
        guard let desc = findBestDescriptor() else { return }
        onFrame?(desc)
    }
    
    private func makeError(_ code: Int, _ msg: String) -> NSError {
        NSError(domain: "SimulatorFrameCapture", code: code,
                userInfo: [NSLocalizedDescriptionKey: msg])
    }
}
