//
//  HIDInput.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/8/26.
//
import Darwin
import Foundation
import ObjectiveC

final class HIDInput: @unchecked Sendable {
    enum TouchEdge: UInt32 {
        case none = 0
        case left = 1 // back gesture (iPadOS slide-over / iPhone X+ back swipe)
        case top = 2 // notification centre (top-right) / control centre (top-right)
        case bottom = 3 // home indicator — swipe-to-home or app switcher
        case right = 4 // (reserved; no standard gesture on iPhone as of iOS 17)
        
        /// Byte value written at offset 0x3B / 0xDB in the Indigo message
        /// produced by the IOHIDDigitizer path. Derived empirically by
        /// sweeping edge=0..4 through the 7-arg mouse signature and diffing
        /// the output bytes.
        var patchBit: UInt8 {
            switch self {
                case .none: return 0x00
                case .left: return 0x02
                case .top: return 0x08
                case .right: return 0x04
                case .bottom: return 0x01
            }
        }
    }
    
    enum HardwareButton: String {
        case home
        case lock // power / sleep-wake
        case volumeUp = "volume_up"
        case volumeDown = "volume_down"
        case siri // hold required; single press is ignored by iOS
        case sideButton = "side_button" // iPhone 15 Pro / iPad Pro action button
        case appSwitcher = "app_switcher" // synthesised as double-home
        
        /// idb eventSource constants (first arg to IndigoHIDMessageForButton).
        /// Reverse-engineered from Simulator.app + idb FBSimulatorPurpleHID.
        var eventSource: Int32 {
            switch self {
                case .home: return 0x0
                case .lock: return 0x1
                case .volumeUp: return 0x2
                case .volumeDown: return 0x3
                case .siri: return 0x400002
                case .sideButton: return 0xbb8
                case .appSwitcher: return 0x0
            }
        }
        
        /// Direction constants (second arg): 1 = down, 2 = up.
        /// 0 is NOT a valid direction — it crashes backboardd on iOS 17+.
        static let directionDown: Int32 = 1
        static let directionUp: Int32 = 2
        
        /// Third arg: routing target for hardware buttons (distinct from
        /// the touch digitizer target 0x32 used by mouse events).
        static let target: Int32 = 0x33
    }
    
    enum KeyType: String {
        case down
        case up
        
        var value: UInt32 {
            switch self {
                case .down: return 1
                case .up: return 2
            }
        }
    }
    
    enum TouchPhase: String {
        case begin, end, move, unknown
        
        var type: UInt32 {
            switch self {
                case .begin: return 1
                case .end: return 2
                case .move: return 1 // 3
                case .unknown: return 0
            }
        }
    }
    
    /// UIDeviceOrientation values. Sent via GSEvent mach message (PATH C).
    enum DeviceOrientation: UInt32 {
        case portrait = 1
        case portraitUpsideDown = 2
        case landscapeRight = 3 // home button on right (iOS convention)
        case landscapeLeft = 4 // home button on left
        case faceUp = 5
        case faceDown = 6
        case unknown = 0
    }
    
    enum HIDInputError: LocalizedError {
        case frameworkLoadFailed(String)
        case symbolMissing(String)
        case clientCreationFailed(String)
        case deviceNotFound(String)
        case orientationPortNotFound
        case unsupported(String)

        var errorDescription: String? {
            switch self {
                case .frameworkLoadFailed(let p): return "dlopen failed for \(p)"
                case .symbolMissing(let s): return "Symbol not found: \(s)"
                case .clientCreationFailed(let r): return "HID client init failed: \(r)"
                case .deviceNotFound(let u): return "SimDevice \(u) not found (is the sim booted?)"
                case .orientationPortNotFound: return "PurpleWorkspacePort not found — Simulator.app must be running"
                case .unsupported(let reason): return reason
            }
        }
    }
    
    // Passing NSSize(1.0,1.0) means the C code computes
    //   stored_ratio = point / nsSize = point / 1.0 = point
    // so no additional client-side scaling is needed.
    private typealias MouseFn = @convention(c) (
        UnsafePointer<CGPoint>, // point1
        UnsafePointer<CGPoint>?, // point2 (nil = single touch)
        UInt32, // target (0x32)
        UInt32, // nsEventType
        UInt32, // edge (IndigoHIDEdge)
        Double, // NSSize.width  (always 1.0)
        Double // NSSize.height (always 1.0)
    ) -> UnsafeMutableRawPointer? // heap-allocated IndigoMessage; caller owns
    
    // IndigoHIDMessageForButton(int32 eventSource, int32 direction, int32 target)
    // Note: some headers show this as (source, direction, UInt64 timestamp) but
    // disassembly confirms the third arg is the routing target (0x33), not a
    // timestamp. Passing a timestamp here corrupts the message.
    private typealias ButtonFn = @convention(c) (
        Int32, // eventSource (which button)
        Int32, // direction (1=down, 2=up)
        Int32 // target (0x33 = hardware-button subsystem)
    ) -> UnsafeMutableRawPointer?
    
    // IndigoHIDMessageForKeyboardArbitrary(uint32 keyCode, uint32 direction)
    // direction: 1 = key down, 2 = key up. Sends USB HID page 0x07 events.
    private typealias KeyboardFn = @convention(c) (
        UInt32, // HID usage code (USB keyboard page 0x07)
        UInt32 // direction: 1=down, 2=up
    ) -> UnsafeMutableRawPointer?
    
    // ObjC send IMP — matches SimDeviceLegacyHIDClient's
    // -sendWithMessage:freeWhenDone:completionQueue:completion:
    // freeWhenDone:YES hands ownership of the heap message to the client,
    // which calls free() after serialising it over the Mach channel.
    private typealias SendIMP = @convention(c) (
        AnyObject, Selector,
        UnsafeMutableRawPointer, // IndigoMessage*
        ObjCBool, // freeWhenDone
        AnyObject?, // completionQueue (nil = fire-and-forget)
        AnyObject? // completion block (nil)
    ) -> Void
    
    // Dispatch queue for button events that need precise timing (double-
    // home, Siri long-press). Separate from the calling thread so the
    // caller is not blocked during the hold interval.
    private let buttonQueue = DispatchQueue(label: "com.hidinjector.button", qos: .userInitiated)
    
    private let udid: String
    private let warmLock = NSLock()
    
    // Lazily created on first use (ensureWarm). Once set, lives for the
    // instance's lifetime. Declared as AnyObject to avoid importing SimulatorKit.
    private var hidClient: AnyObject?
    private var sendSel: Selector?
    
    // Cached send IMP — avoids repeated class_getMethodImplementation lookups
    // on the hot path (every touch event in a 60 fps gesture stream).
    private var cachedSendIMP: IMP?
    
    private var mouseFn: MouseFn?
    private var buttonFn: ButtonFn?
    private var keyboardFn: KeyboardFn?
    
    init(udid: String) {
        self.udid = udid
    }
    
    func touch(phase: TouchPhase, x: Double, y: Double, edge: TouchEdge = .none) throws {
        let client = try getHIDClient()
        
        let point = CGPoint(x: x, y: y)
        try sendTouch(point: point, p2: nil, nsEventType: phase.type, edge: edge, client: client)
    }
    
    func pinch(phase: TouchPhase, x1: Double, y1: Double, x2: Double, y2: Double) throws {
        let client = try getHIDClient()
        
        let point1 = CGPoint(x: x1, y: y1)
        let point2 = CGPoint(x: x2, y: y2)
        try sendPinch(
            p1: point1,
            p2: point2,
            nsEventType: phase.type,
            client: client
        )
    }
    
    func press(_ btn: HardwareButton) throws {
        // Warm the client up-front so any failure surfaces synchronously,
        // but re-acquire it inside the dispatch closures — `AnyObject`
        // isn't Sendable, and `getHIDClient()` is cached after first call.
        _ = try getHIDClient()
        guard let bfn = buttonFn else {
            throw HIDInputError.symbolMissing("IndigoHIDMessageForButton")
        }

        switch btn {
            case .appSwitcher:
                // Double-home: two independent press-release cycles 150 ms apart.
                // SpringBoard listens to the home eventSource regardless of
                // physical home-button presence (Face ID iPhones included).
                buttonQueue.async { [self] in
                    guard let client = try? self.getHIDClient() else { return }
                    self.pressButtonSync(source: btn.eventSource,
                                         holdUs: 120_000, fn: bfn, client: client)
                    usleep(150_000)
                    self.pressButtonSync(source: btn.eventSource,
                                         holdUs: 120_000, fn: bfn, client: client)
                }

            case .siri:
                // iOS only responds to Siri button if it's held ≥ ~280 ms.
                // We default to 320 ms for margin; the caller can override.
                let holdUs = UInt32(0.32 * 1_000_000)
                buttonQueue.async { [self] in
                    guard let client = try? self.getHIDClient() else { return }
                    self.pressButtonSync(source: btn.eventSource, holdUs: holdUs, fn: bfn, client: client)
                }
            case .home:
                launchSpringBoard()

            case .volumeUp, .volumeDown:
                // CoreSimulator does not route hardware volume events: the
                // Indigo button sources (0x2/0x3), keyboard usages
                // (0x80/0x81), and consumer-page usages are all ignored, and
                // neither Simulator.app, idb, nor Appium expose volume on
                // simulators. Fail loudly instead of silently dropping it.
                throw HIDInputError.unsupported(
                    "volume buttons can't be injected into the iOS Simulator"
                )

            default:
                let holdUs = UInt32(0.12 * 1_000_000)
                let client = try getHIDClient()
                self.pressButtonSync(source: btn.eventSource, holdUs: holdUs, fn: bfn, client: client)
        }
    }
    
    func key(usage: UInt32, type: KeyType? = nil, holdSeconds: Double = 0.05) throws {
        let client = try getHIDClient()
        guard let kfn = keyboardFn else {
            throw HIDInputError.symbolMissing("IndigoHIDMessageForKeyboardArbitrary")
        }
        
        let holdUs = UInt32(max(0.02, holdSeconds) * 1_000_000)
        
        if type != nil {
            if let msg = kfn(usage, type!.value) { sendRaw(msg, to: client) }
        } else {
            if let msg = kfn(usage, 1) { sendRaw(msg, to: client) }
            usleep(holdUs)
            if let msg = kfn(usage, 2) { sendRaw(msg, to: client) }
        }
      }
    
    func setOrientation(_ orientation: DeviceOrientation) throws -> Bool {
        guard let device = SimulatorHelper.findSimDevice(with: udid) else {
            throw HIDInputError.deviceNotFound(udid)
        }
        
        // SimDevice exposes a -lookup:error: method that returns a mach port
        // by name. PurpleWorkspacePort is published by the simulated
        // backboardd process and is the standard channel for GSEvents.
        let lookupSel = NSSelectorFromString("lookup:error:")
        typealias LookupFn = @convention(c) (
            AnyObject, Selector, NSString,
            AutoreleasingUnsafeMutablePointer<NSError?>
        ) -> mach_port_t
        guard let lookupIMP = class_getMethodImplementation(
            object_getClass(device)!, lookupSel
        )
        else { throw HIDInputError.orientationPortNotFound }
        
        var lookupErr: NSError?
        let port = unsafeBitCast(lookupIMP, to: LookupFn.self)(
            device, lookupSel, "PurpleWorkspacePort" as NSString, &lookupErr
        )
        guard port != 0 else { throw HIDInputError.orientationPortNotFound }
        
        // Wire format reverse-engineered from Simulator.app + idb:
        //   offset 0x00  mach_msg_header_t (24 bytes)
        //   offset 0x18  GSEvent type | host flag (UInt32)
        //   offset 0x48  record_info_size = 4 (UInt32)
        //   offset 0x4C  UIDeviceOrientation value (UInt32)
        //   total msgh_size = 108 bytes
        //
        // gsEventHostFlag (0x20000) tells backboardd the event originated
        // from the host, not from the simulated device. Without it the event
        // is dropped by GraphicsServices.
        var buf = [UInt8](repeating: 0, count: 112)
        return buf.withUnsafeMutableBufferPointer { ptr in
            let base = UnsafeMutableRawPointer(ptr.baseAddress!)
            let hdr = base.assumingMemoryBound(to: mach_msg_header_t.self)
            
            hdr.pointee.msgh_bits = mach_msg_bits_t(MACH_MSG_TYPE_COPY_SEND)
            hdr.pointee.msgh_size = 108
            hdr.pointee.msgh_remote_port = port
            hdr.pointee.msgh_local_port = mach_port_t(MACH_PORT_NULL)
            hdr.pointee.msgh_voucher_port = mach_port_t(MACH_PORT_NULL)
            hdr.pointee.msgh_id = 0x7b // kGSEventMachMessageID
            
            // gsEventTypeDeviceOrientationChanged = 50, host flag = 0x20000
            base.storeBytes(of: UInt32(50) | UInt32(0x20000), toByteOffset: 0x18, as: UInt32.self)
            base.storeBytes(of: UInt32(4), toByteOffset: 0x48, as: UInt32.self)
            base.storeBytes(of: orientation.rawValue, toByteOffset: 0x4c, as: UInt32.self)
            
            let kr = mach_msg_send(hdr)
            if kr != KERN_SUCCESS {
                fputs("[HIDInput] mach_msg_send failed kr=\(kr)\n", stderr)
                return false
            }
            return true
        }
    }
    
    private func launchSpringBoard() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "launch", udid, "com.apple.springboard"]
        try? process.run()
    }
}

private extension HIDInput {
    /// Ensure symbols are resolved and the ObjC HID client is created.
    /// Thread-safe; idempotent after the first successful call.
    func getHIDClient() throws -> AnyObject {
        warmLock.lock()
        defer { warmLock.unlock() }
        if let existing = hidClient { return existing }
        
        try resolveSymbols()
        let client = try createHIDClient()
        hidClient = client
        return client
    }
    
    /// dlopen SimulatorKit and resolve all Indigo C symbols.
    ///
    /// We use `UnsafeMutableRawPointer(bitPattern: -2)` (RTLD_DEFAULT) for
    /// IOKit symbols (IOHIDEvent*) because they live in the dyld shared cache
    /// and are globally available without an explicit dlopen. SimulatorKit
    /// symbols (Indigo*, trackpad wrapper) require an explicit dlopen at the
    /// known framework path because SimulatorKit is not in the shared cache.
    func resolveSymbols() throws {
        let devDir = SimulatorHelper.developerDir
        let candidates = [
            "\(devDir)/Library/PrivateFrameworks/SimulatorKit.framework/SimulatorKit",
            "\(devDir)/../SharedFrameworks/SimulatorKit.framework/SimulatorKit",    // Xcode 27+, SimulatorKit moved to SharedFrameworks
            "/Applications/Xcode.app/Contents/Developer/Library/PrivateFrameworks/SimulatorKit.framework/SimulatorKit"
        ]
        for path in candidates {
            if let handle = dlopen(path, RTLD_NOW | RTLD_LOCAL) {
                resolveFrom(handle: handle)
                return
            }
        }
        throw HIDInputError.frameworkLoadFailed(candidates.first!)
    }
    
    func resolveFrom(handle: UnsafeMutableRawPointer) {
        if let mousePtr = dlsym(handle, "IndigoHIDMessageForMouseNSEvent") {
            mouseFn = unsafeBitCast(mousePtr, to: MouseFn.self)
            print("[hid] IndigoHIDMessageForMouseNSEvent loaded")
        } else {
            print("[hid] Warning: IndigoHIDMessageForMouseNSEvent not found")
        }
        
        if let buttonPtr = dlsym(handle, "IndigoHIDMessageForButton") {
            buttonFn = unsafeBitCast(buttonPtr, to: ButtonFn.self)
            print("[hid] IndigoHIDMessageForButton loaded")
        } else {
            print("[hid] Warning: IndigoHIDMessageForButton not found")
        }
        if let keyboardPtr = dlsym(handle, "IndigoHIDMessageForKeyboardArbitrary") {
            keyboardFn = unsafeBitCast(keyboardPtr, to: KeyboardFn.self)
            print("[hid] IndigoHIDMessageForKeyboardArbitrary loaded")
        } else {
            print("[hid] Warning: IndigoHIDMessageForKeyboardArbitrary not found")
        }
    }
    
    /// Instantiate `_TtC12SimulatorKit24SimDeviceLegacyHIDClient` via ObjC
    /// runtime calls. The mangled name is stable across Xcode versions; the
    /// underlying Swift class hasn't changed its init signature since Xcode 11.
    func createHIDClient() throws -> AnyObject {
        guard let device = SimulatorHelper.findSimDevice(with: udid) else {
            throw HIDInputError.deviceNotFound(udid)
        }
        guard let cls = NSClassFromString("_TtC12SimulatorKit24SimDeviceLegacyHIDClient") else {
            throw HIDInputError.frameworkLoadFailed("SimDeviceLegacyHIDClient (class not found)")
        }
        
        // alloc
        let allocSel = NSSelectorFromString("alloc")
        guard let metaCls = object_getClass(cls),
              let allocIMP = class_getMethodImplementation(metaCls, allocSel)
        else {
            throw HIDInputError.clientCreationFailed("Cannot get +alloc IMP")
        }
        typealias AllocFn = @convention(c) (AnyClass, Selector) -> AnyObject?
        guard let allocated = unsafeBitCast(allocIMP, to: AllocFn.self)(cls, allocSel) else {
            throw HIDInputError.clientCreationFailed("+alloc returned nil")
        }
        
        // initWithDevice:error:
        let initSel = NSSelectorFromString("initWithDevice:error:")
        guard let initIMP = class_getMethodImplementation(cls, initSel) else {
            throw HIDInputError.clientCreationFailed("Cannot get -initWithDevice:error: IMP")
        }
        typealias InitFn = @convention(c) (
            AnyObject, Selector, AnyObject,
            AutoreleasingUnsafeMutablePointer<NSError?>
        ) -> AnyObject?
        var initErr: NSError?
        guard let client = unsafeBitCast(initIMP, to: InitFn.self)(
            allocated, initSel, device, &initErr
        )
        else {
            throw HIDInputError.clientCreationFailed(initErr?.localizedDescription ?? "unknown")
        }
        
        // Cache the send selector and its IMP for zero-overhead dispatch on
        // the hot path. Using the IMP directly avoids objc_msgSend overhead
        // and the selector lookup cache miss on first call.
        let sel = NSSelectorFromString("sendWithMessage:freeWhenDone:completionQueue:completion:")
        sendSel = sel
        cachedSendIMP = class_getMethodImplementation(object_getClass(client)!, sel)
        
        return client
    }
}

// MARK: - Button Helper

private extension HIDInput {
    /// Synchronous press-and-release for one hardware button.
    /// Called from `buttonQueue` for timing-sensitive sequences.
    private func pressButtonSync(source: Int32, holdUs: UInt32,
                                 fn: ButtonFn, client: AnyObject)
    {
        if let down = fn(source, HardwareButton.directionDown, HardwareButton.target) {
            sendRaw(down, to: client)
        }
        usleep(holdUs)
        if let up = fn(source, HardwareButton.directionUp, HardwareButton.target) {
            sendRaw(up, to: client)
        }
    }
}

private extension HIDInput {
    /// Send a single-finger mouse event via IndigoHIDMessageForMouseNSEvent.
    ///
    /// nsEventType: 1 = LeftMouseDown (use for both down AND move in the
    /// edge-gesture path), 2 = LeftMouseUp, 6 = LeftMouseDragged (valid
    /// only in the non-edge / two-finger path).
    func sendTouch(point: CGPoint, p2: CGPoint?,
                   nsEventType: UInt32, edge: TouchEdge,
                   client: AnyObject) throws
    {
        guard let mfn = mouseFn else {
            throw HIDInputError.symbolMissing("IndigoHIDMessageForMouseNSEvent")
        }
        var pt1 = point
        var msg: UnsafeMutableRawPointer?
        
        // Retry up to 3× with 5 ms delay. The builder returns nil for ~50 ms
        // after a two-finger touch-down while the C code initialises internal
        // state; retrying covers the window for two-finger gestures.
        var attempt = 0
        repeat {
            msg = withUnsafePointer(to: &pt1) { p1 in
                mfn(p1, nil, 0x32, nsEventType, edge.rawValue, 1.0, 1.0)
            }
            if msg != nil { break }
            usleep(5_000)
            attempt += 1
        } while attempt < 3
        
        if let msg {
            sendRaw(msg, to: client)
        }
    }
    
    /// Two-finger variant. Passing both CGPoints makes the C function build
    /// a 3-record Indigo message (header + 2 finger blocks), which iOS
    /// interprets as a multi-touch sequence.
    func sendPinch(p1: CGPoint, p2: CGPoint,
                   nsEventType: UInt32, client: AnyObject) throws
    {
        guard let mfn = mouseFn else {
            throw HIDInputError.symbolMissing("IndigoHIDMessageForMouseNSEvent")
        }
        var pt1 = p1, pt2 = p2
        var msg: UnsafeMutableRawPointer?
        
        // Up to 12 retries for two-finger: the settle window is ~50 ms after
        // a multi-touch down, so 12 × 5 ms = 60 ms covers it.
        for _ in 0 ..< 12 {
            msg = withUnsafePointer(to: &pt1) { r1 in
                withUnsafePointer(to: &pt2) { r2 in
                    mfn(r1, r2, 0x32, nsEventType, TouchEdge.none.rawValue, 1.0, 1.0)
                }
            }
            if msg != nil { break }
            usleep(5_000)
        }
        if let msg { sendRaw(msg, to: client) }
    }
}

// MARK: - Send 
private extension HIDInput {
    /// Dispatch a heap-allocated Indigo message to the HID client.
    ///
    func sendRaw(_ msg: UnsafeMutableRawPointer, to client: AnyObject) {
        guard let imp = cachedSendIMP, let sel = sendSel else { return }
        unsafeBitCast(imp, to: SendIMP.self)(client, sel, msg, ObjCBool(true), nil, nil)
    }
}
