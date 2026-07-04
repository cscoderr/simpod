//
//  ChromeRenderer.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/17/26.
//

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Renders iOS/watchOS Simulator "device chrome" (the bezel artwork around a
/// simulator screen) from CoreSimulator/DeviceKit's private resources, and can
/// composite a raw simulator screenshot into that chrome.
///
/// The implementation is split across several files using extensions, grouped
/// by concern:
///   - `ChromeRenderer.swift`            – public API + tiny helpers
///   - `ChromeRenderer+Layout.swift`     – layout maths, profile/info lookup, screen/sensor drawing
///   - `ChromeRenderer+Bezel.swift`      – sliced/composite bezel artwork drawing
///   - `ChromeRenderer+Inputs.swift`     – input/button geometry and drawing
///   - `ChromeRenderer+Profile.swift`    – profile classification and asset-path helpers
///
/// All public methods are synchronous and throwing. The only mutable state is
/// `boundsCache`, which is always accessed under `boundsCacheLock`, so the
/// `@unchecked Sendable` conformance below is safe.
final class ChromeRenderer: @unchecked Sendable {

    let pdfRasterizer = PDFRasterizer()

    // Cache of `blackScreenBounds` results keyed by composite path + display
    // size. The pixel scan that fills this is expensive (full bitmap rasterise
    // + per-pixel inspection), so caching turns the second hit into a noop.
    var boundsCache = [String: CGRect]()
    let boundsCacheLock = NSLock()

    // MARK: - Public API

    /// Returns a dictionary describing the chrome layout (total/chrome/screen/content
    /// rects, corner radii, and per-button frames) for the given simulator device
    /// type name (e.g. `"iPhone 15 Pro"`). This is the payload of `/chrome`.
    func chromeLayoutJSON(forDeviceName deviceName: String, imagePrefix: String = "") throws -> [String: Any] {
        let info = try chromeInfo(forDeviceName: deviceName)
        return try layout(for: info, imagePrefix: imagePrefix).asJSON
    }
    
    /// Returns the native pixel size of the device's main screen framebuffer.
    func displayPixelSize(forDeviceName deviceName: String) throws -> CGSize {
        let info = try chromeInfo(forDeviceName: deviceName)
        return try displayPixelSize(for: info)
    }

    /// Renders the simulator chrome (bezel) artwork for `deviceName` as PNG data, at 3x scale.
    /// - Parameter includeButtons: Whether to render the physical buttons/crown on top of the chrome.
    func bezelPNG(forDeviceName deviceName: String, includeButtons: Bool = true) throws -> Data {
        let info = try chromeInfo(forDeviceName: deviceName)
        let compositePath = compositeAssetPath(for: info)
        let chromeSize = try compositeSize(for: info)
        guard chromeSize != .zero else {
            throw makeError(description: "The DeviceKit chrome composite for \(deviceName) had a zero size.", code: 6)
        }

        let layout = try layout(for: info)
        let renderSize = CGSize(width: layout.totalWidth, height: layout.totalHeight)
        let chromeX = layout.chromeX
        let chromeY = layout.chromeY

        // 3x covers @3x Retina screens at 1:1; downscaling on the client is
        // cheap, while *upscaling* a 1x bezel looks fuzzy.
        let scale: CGFloat = 3.0
        let pixelWidth = max(Int(ceil(renderSize.width * scale)), 1)
        let pixelHeight = max(Int(ceil(renderSize.height * scale)), 1)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            throw makeError(description: "Unable to create a CoreGraphics bitmap context for simulator chrome rendering.", code: 9)
        }

        context.clear(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        context.saveGState()
        // CG's origin is bottom-left; flip so subsequent drawing uses a
        // top-left origin to match the layout coordinates from DeviceKit.
        context.translateBy(x: 0, y: CGFloat(pixelHeight))
        context.scaleBy(x: scale, y: -scale)
        context.translateBy(x: chromeX, y: chromeY)

        if includeButtons {
            try drawInputImages(for: info, inSize: chromeSize, context: context, onlyOnTop: false)
        }

        let rendered: Bool
        if !compositePath.isEmpty {
            rendered = try pdfRasterizer.draw(atPath: compositePath, in: CGRect(x: 0, y: 0, width: chromeSize.width, height: chromeSize.height), into: context)
        } else {
            rendered = try drawSlicedChrome(info, inSize: chromeSize, context: context)
        }

        guard rendered else {
            context.restoreGState()
            throw makeError(description: "Unable to render the simulator chrome composite or sliced assets for \(deviceName).", code: 8)
        }

        context.translateBy(x: -chromeX, y: -chromeY)
        try clearScreenArea(for: info, layout: layout, context: context)
        try drawSensorBar(for: info, layout: layout, context: context)
        context.translateBy(x: chromeX, y: chromeY)

        if includeButtons {
            try drawInputImages(for: info, inSize: chromeSize, context: context, onlyOnTop: true)
        }

        context.restoreGState()

        guard let image = context.makeImage() else {
            throw makeError(description: "Unable to create a CGImage from the simulator chrome bitmap.", code: 10)
        }

        do {
            return try pdfRasterizer.encodePNG(image)
        } catch {
            throw makeError(description: "Unable to encode the simulator chrome PNG.", code: 11)
        }
    }

    /// Renders a single chrome button/crown asset (e.g. the volume rocker) as PNG data, at 3x scale.
    /// - Parameter pressed: If `true` and the button defines a pressed-state image, that image is used instead.
    func buttonPNG(forDeviceName deviceName: String, buttonName: String, pressed: Bool = false) throws -> Data {
        let info = try chromeInfo(forDeviceName: deviceName)
        let input = try inputNamed(buttonName, info: info)

        let assetName: String
        if pressed, let pressedImageName = input.imageDown, !pressedImageName.isEmpty {
            assetName = pressedImageName
        } else {
            assetName = input.image ?? ""
        }
        guard !assetName.isEmpty else {
            throw makeError(description: "The chrome button `\(buttonName)` did not specify a renderable image.", code: 14)
        }

        let assetPath = resolvedChromeAssetPath(forName: assetName, chromePath: info.chromePath)
        return try renderPNG(atPath: assetPath, scale: 3.0)
    }

    /// Renders the on-screen "framebuffer mask" (used to mask non-rectangular displays) as PNG data, at 1x scale.
    func screenMaskPNG(forDeviceName deviceName: String) throws -> Data {
        let info = try chromeInfo(forDeviceName: deviceName)
        let maskPath = screenMaskPath(for: info)
        guard !maskPath.isEmpty else {
            throw makeError(description: "The device profile for \(deviceName) did not specify a framebuffer mask.", code: 13)
        }
        return try renderPNG(atPath: maskPath, scale: 1.0)
    }

    /// Composites a raw simulator screenshot into the device's chrome (bezel), returning the
    /// result as PNG data at 3x scale.
    func composedScreenshotPNG(forDeviceName deviceName: String, screenshot: Data) throws -> Data {
        let chromePNGData = try bezelPNG(forDeviceName: deviceName, includeButtons: true)

        let info = try chromeInfo(forDeviceName: deviceName)
        let layout = try layout(for: info)

        guard let screenImage = NSImage(data: screenshot),
              let chromeImage = NSImage(data: chromePNGData)
        else {
            throw makeError(description: "Unable to decode simulator screenshot or chrome PNG data.", code: 15)
        }

        let scale: CGFloat = 3.0

        guard layout.totalWidth > 0, layout.totalHeight > 0, layout.screenWidth > 0, layout.screenHeight > 0 else {
            throw makeError(description: "Device chrome profile did not include usable screenshot geometry.", code: 16)
        }

        let pixelWidth = max(Int(ceil(layout.totalWidth * scale)), 1)
        let pixelHeight = max(Int(ceil(layout.totalHeight * scale)), 1)

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 32
        ) else {
            throw makeError(description: "Unable to create a bitmap for bezeled screenshot rendering.", code: 17)
        }

        let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        graphicsContext?.imageInterpolation = .high

        let outputRect = NSRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight)
        NSColor.clear.set()
        outputRect.fill()

        // NSImage uses bottom-left origin; the layout uses top-left. Flip the
        // screen rect's Y so the screenshot lands inside the chrome's hole.
        let screenRect = NSRect(
            x: layout.screenX * scale,
            y: CGFloat(pixelHeight) - ((layout.screenY + layout.screenHeight) * scale),
            width: layout.screenWidth * scale,
            height: layout.screenHeight * scale
        )

        let hints = [NSImageRep.HintKey.interpolation: NSImageInterpolation.high.rawValue]
        screenImage.draw(in: screenRect, from: .zero, operation: .sourceOver, fraction: 1.0, respectFlipped: false, hints: hints)
        chromeImage.draw(in: outputRect, from: .zero, operation: .sourceOver, fraction: 1.0, respectFlipped: false, hints: hints)

        NSGraphicsContext.restoreGraphicsState()

        guard let pngOutputData = bitmap.representation(using: .png, properties: [:]) else {
            throw makeError(description: "Unable to encode bezeled simulator screenshot PNG.", code: 18)
        }
        return pngOutputData
    }

    // MARK: - Errors / small value helpers

    func makeError(description: String, code: Int) -> NSError {
        NSError(
            domain: "Simpod.ChromeRenderer",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: description]
        )
    }

    /// Coerces an untyped plist/JSON value (`NSNumber` or `String`) to a
    /// `CGFloat`, returning 0 for anything else. Used when reading
    /// capabilities.plist, which is decoded loosely as `[String: Any]`.
    func numberValue(_ value: Any?) -> CGFloat {
        switch value {
        case let n as NSNumber: return CGFloat(n.doubleValue)
        case let s as String:   return CGFloat(Double(s) ?? 0)
        default:                return 0
        }
    }

    func renderPNG(atPath path: String, scale: CGFloat) throws -> Data {
        do {
            return try pdfRasterizer.pngData(atPath: path, scale: scale)
        } catch PDFRasterizerError.emptyPath {
            throw makeError(description: "Path is empty.", code: 14)
        } catch PDFRasterizerError.openFailed(let p) {
            throw makeError(description: "Unable to open PDF \(p).", code: 7)
        } catch PDFRasterizerError.contextCreationFailed {
            throw makeError(description: "Unable to create a CoreGraphics bitmap context for PDF rendering.", code: 9)
        } catch PDFRasterizerError.imageCreationFailed {
            throw makeError(description: "Unable to create a CGImage from the PDF bitmap.", code: 10)
        } catch PDFRasterizerError.pngEncoderUnavailable {
            throw makeError(description: "Unable to create a PNG encoder for PDF rendering.", code: 11)
        } catch PDFRasterizerError.pngEncodingFailed {
            throw makeError(description: "Unable to encode PDF render as PNG.", code: 12)
        }
    }
}
