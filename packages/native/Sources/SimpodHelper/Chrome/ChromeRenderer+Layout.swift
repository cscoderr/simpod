//
//  ChromeRenderer+Layout.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/17/26.
//
//  Layout maths, DeviceKit profile lookup, and screen/sensor compositing
//  helpers. Splitting these out of the main file keeps the public API
//  surface readable.
//

import AppKit
import CoreGraphics
import Foundation

extension ChromeRenderer {

    // MARK: - Chrome layout computation

    /// Produces a fully populated `ChromeLayout` (screen rect, content rect,
    /// corner radii, button frames…) for a device profile. This is the heart
    /// of the renderer — pretty much everything else feeds off the values
    /// returned here.
    func layout(for info: ChromeInfo, imagePrefix: String = "") throws -> ChromeLayout {
        let profile = info.profile
        let metadata = info.metadata
        let sizing = metadata.images?.sizing
        let stand = metadata.images?.stand

        let sizingTop = sizing?.topHeight ?? 0
        let sizingLeft = sizing?.leftWidth ?? 0
        let sizingBottom = sizing?.bottomHeight ?? 0
        let sizingRight = sizing?.rightWidth ?? 0
        let standHeight = stand?.height ?? 0

        let compositeSize = try self.compositeSize(for: info)
        if compositeSize == .zero {
            throw makeError(description: "Composite size is zero.", code: 11)
        }

        let border = metadata.paths?.simpleOutsideBorder
        let borderInsets = border?.insets
        let rawCornerRadius = border?.cornerRadiusX ?? 0

        let borderTop = borderInsets?.top ?? 0
        let borderLeft = borderInsets?.left ?? 0
        let borderBottom = borderInsets?.bottom ?? 0
        let borderRight = borderInsets?.right ?? 0

        // The bezel insets are the visible "frame" around the screen — the
        // sum of the artwork sizing and the path-derived border insets.
        let bezelTop = sizingTop + borderTop
        let bezelLeft = sizingLeft + borderLeft
        let bezelBottom = sizingBottom + borderBottom
        let bezelRight = sizingRight + borderRight

        let watchProfile = isWatchProfile(profile)
        let phoneProfile = isPhoneProfile(profile)
        let sensorName = profile.sensorBarImage ?? ""
        let hasModernPhoneSensor = shouldRenderPhoneChromeFromSlices(profile, sensorName: sensorName)
        let hasComposite = !hasModernPhoneSensor && !compositeAssetPath(for: info).isEmpty
        let screenScale = self.screenScale(for: info)
        let profileScreenSize = screenSize(for: info, chromeSize: compositeSize, screenScale: screenScale)
        let pointScreenWidth = profileScreenSize.width
        let pointScreenHeight = profileScreenSize.height

        var screenWidth: CGFloat = 0
        var screenHeight: CGFloat = 0
        var screenX: CGFloat = 0
        var screenY: CGFloat = 0
        var contentWidth: CGFloat = 0
        var contentHeight: CGFloat = 0
        var contentX: CGFloat = 0
        var contentY: CGFloat = 0

        if watchProfile {
            // Watch profiles publish a mask that defines the literal pixel
            // bounds of the round/octagonal screen — prefer that over the
            // rectangular bezel maths above.
            let maskSize = framebufferMaskSize(for: info)
            let displaySize = maskSize != .zero ? maskSize : profileScreenSize
            let blackScreenBounds = self.blackScreenBounds(for: info, matchingDisplaySize: displaySize)
            if blackScreenBounds != .zero {
                screenX = blackScreenBounds.minX
                screenY = blackScreenBounds.minY
                screenWidth = blackScreenBounds.width
                screenHeight = blackScreenBounds.height
            } else {
                let usableHeight = max(compositeSize.height - standHeight, 1.0)
                screenX = max(sizingLeft, 0.0)
                screenY = max(sizingTop, 0.0)
                screenWidth = max(compositeSize.width - sizingLeft - sizingRight, 1.0)
                screenHeight = max(usableHeight - sizingTop - sizingBottom, 1.0)
            }
            var contentBounds = CGRect(x: screenX, y: screenY, width: screenWidth, height: screenHeight)
            if blackScreenBounds != .zero {
                let screenPadding = self.screenPadding(for: info)
                var contentInset = max(max(screenPadding.width, screenPadding.height), 0.0)
                let horizontalBorderInset = min(max(borderLeft, 0.0), max(borderRight, 0.0))
                if horizontalBorderInset > 0.0 {
                    contentInset = max(contentInset, horizontalBorderInset + max(screenPadding.width, 0.0))
                }
                if contentInset > 0.0, contentBounds.width > (contentInset * 2.0), contentBounds.height > (contentInset * 2.0) {
                    contentBounds = contentBounds.insetBy(dx: contentInset, dy: contentInset)
                }
            }
            if displaySize != .zero {
                var fitScale = min(contentBounds.width / displaySize.width, contentBounds.height / displaySize.height)
                if !fitScale.isFinite || fitScale <= 0.0 { fitScale = 1.0 }
                fitScale = min(fitScale, 1.0)
                contentWidth = displaySize.width * fitScale
                contentHeight = displaySize.height * fitScale
            } else {
                contentWidth = contentBounds.width
                contentHeight = contentBounds.height
            }
            contentX = contentBounds.minX + max((contentBounds.width - contentWidth) / 2.0, 0.0)
            contentY = contentBounds.minY + max((contentBounds.height - contentHeight) / 2.0, 0.0)
        } else if hasComposite, pointScreenWidth > 0, pointScreenHeight > 0 {
            // Modern phone/pad path: center the published point-size screen
            // inside the composite, respecting the stand at the bottom.
            screenWidth = pointScreenWidth
            screenHeight = pointScreenHeight
            screenX = max((compositeSize.width - screenWidth) / 2.0, 0.0)
            let usableHeight = compositeSize.height - standHeight
            screenY = max((usableHeight - screenHeight) / 2.0, bezelTop)
            contentX = screenX
            contentY = screenY
            contentWidth = screenWidth
            contentHeight = screenHeight
        } else {
            // Fallback (old devices, sliced chrome): derive everything from
            // the bezel insets directly.
            screenX = bezelLeft
            screenY = bezelTop
            screenWidth = max(compositeSize.width - bezelLeft - bezelRight, 1.0)
            screenHeight = max(compositeSize.height - standHeight - bezelTop - bezelBottom, 1.0)
            contentX = screenX
            contentY = screenY
            contentWidth = screenWidth
            contentHeight = screenHeight
        }

        let innerRadius = max(rawCornerRadius - max(screenX, screenY), 0.0)
        let radiusScale = !watchProfile && pointScreenWidth > 0 ? screenWidth / pointScreenWidth : 1.0
        var chromeCornerRadius = innerRadius * radiusScale
        if watchProfile {
            // Watch corner radii come from the framebuffer mask, not the
            // chrome.json path data — the path data describes the bezel,
            // not the inner screen, which on watches are different.
            let maskCornerRadius = framebufferMaskCornerRadius(for: info, pointScreenWidth: contentWidth)
            if maskCornerRadius > 0 {
                chromeCornerRadius = maskCornerRadius
            }
        }
        let cornerRadius = chromeCornerRadius

        let fullFrame = self.fullFrame(for: info, chromeSize: compositeSize)
        let chromeX = -fullFrame.minX
        let chromeY = -fullFrame.minY
        let hasScreenMask = !phoneProfile && !screenMaskPath(for: info).isEmpty
        let buttons = buttonLayouts(
            for: info,
            chromeSize: compositeSize,
            chromeOffset: CGPoint(x: chromeX, y: chromeY),
            imagePrefix: imagePrefix
        )

        return ChromeLayout(
            totalWidth: fullFrame.width,
            totalHeight: fullFrame.height,
            chromeX: chromeX,
            chromeY: chromeY,
            chromeWidth: compositeSize.width,
            chromeHeight: compositeSize.height,
            screenX: screenX + chromeX,
            screenY: screenY + chromeY,
            screenWidth: screenWidth,
            screenHeight: screenHeight,
            contentX: contentX + chromeX,
            contentY: contentY + chromeY,
            contentWidth: contentWidth,
            contentHeight: contentHeight,
            cornerRadius: cornerRadius,
            chromeCornerRadius: chromeCornerRadius,
            hasScreenMask: hasScreenMask,
            buttons: buttons,
            bezelImage: ChromeBezelImage(
                bare: "\(imagePrefix)/bezel.png?buttons=false",
                rest: "\(imagePrefix)/bezel.png"
            )
        )
    }

    /// Loads the CoreSimulator profile.plist and the DeviceKit chrome.json
    /// for `deviceName`. Both files live in well-known paths under
    /// `/Library/Developer/...` and are required for every other operation.
    func chromeInfo(forDeviceName deviceName: String) throws -> ChromeInfo {
        let profilePath = "/Library/Developer/CoreSimulator/Profiles/DeviceTypes/\(deviceName).simdevicetype/Contents/Resources/profile.plist"
        guard let profileData = try? Data(contentsOf: URL(fileURLWithPath: profilePath)) else {
            throw makeError(description: "Unable to open profile.plist for \(deviceName).", code: 1)
        }

        guard let profile = try? DeviceProfile.decode(from: profileData) else {
            throw makeError(description: "Unable to decode the CoreSimulator device profile.", code: 2)
        }

        // chromeIdentifier looks like "com.apple.dt.devicekit.chrome.phone17",
        // which maps onto the on-disk bundle "phone17.devicechrome".
        let chromeIdentifier = profile.chromeIdentifier ?? ""
        let chromeName = chromeIdentifier.replacingOccurrences(of: "com.apple.dt.devicekit.chrome.", with: "")
        if chromeName.isEmpty {
            throw makeError(description: "The device profile for \(deviceName) did not specify a DeviceKit chrome identifier.", code: 3)
        }

        let chromePath = "/Library/Developer/DeviceKit/Chrome/\(chromeName).devicechrome/Contents/Resources"
        let jsonPath = (chromePath as NSString).appendingPathComponent("chrome.json")
        guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)) else {
            throw makeError(description: "Unable to locate DeviceKit chrome metadata for \(deviceName).", code: 4)
        }

        guard let metadata = try? ChromeMetadata.decode(from: jsonData) else {
            throw makeError(description: "Unable to decode DeviceKit chrome metadata.", code: 5)
        }
        
        let resourcesPath = (profilePath as NSString).deletingLastPathComponent

        // Modern device types store screen dimensions in capabilities.plist
        // (next to profile.plist) rather than in profile.plist. It is absent on
        // older profiles, so load it best-effort instead of failing the lookup.
        let capPath = (resourcesPath as NSString).appendingPathComponent("capabilities.plist")
        var capabilities: [String: Any]? = nil
        if let capData = try? Data(contentsOf: URL(fileURLWithPath: capPath)),
           let caps = try? PropertyListSerialization.propertyList(from: capData, options: [], format: nil) as? [String: Any] {
            capabilities = caps
        }

        return ChromeInfo(
            profile: profile,
            metadata: metadata,
            chromePath: chromePath,
            profileResourcesPath: resourcesPath,
            capabilities: capabilities
        )
    }

    /// Returns the size of the rasterised bezel composite. For devices with
    /// a composite PDF, this is the PDF's media box. For modern phones that
    /// ship without one, we synthesise it from sliced-chrome metadata.
    func compositeSize(for info: ChromeInfo) throws -> CGSize {
        let profile = info.profile
        let sensorName = profile.sensorBarImage ?? ""
        let hasModernPhoneSensor = shouldRenderPhoneChromeFromSlices(profile, sensorName: sensorName)
        let compositePath = hasModernPhoneSensor ? "" : compositeAssetPath(for: info)

        if compositePath.isEmpty {
            let images = info.metadata.images
            let sizing = images?.sizing
            let borderInsets = info.metadata.paths?.simpleOutsideBorder?.insets
            let size = screenSize(for: info, chromeSize: .zero, screenScale: screenScale(for: info))

            // Guard the screen dimensions *before* adding bezels. The bezel
            // insets alone sum to a positive value, so checking only the total
            // would silently produce a bezel-only result (e.g. ~36×36) when the
            // screen size is missing.
            guard size.width > 0, size.height > 0 else {
                throw makeError(description: "The DeviceKit chrome metadata did not include usable display dimensions.", code: 11)
            }

            let bezelLeft = (sizing?.leftWidth ?? 0) + (borderInsets?.left ?? 0)
            let bezelRight = (sizing?.rightWidth ?? 0) + (borderInsets?.right ?? 0)
            let bezelTop = (sizing?.topHeight ?? 0) + (borderInsets?.top ?? 0)
            let bezelBottom = (sizing?.bottomHeight ?? 0) + (borderInsets?.bottom ?? 0)

            let standHeight = images?.stand?.height ?? 0

            let totalWidth = size.width + bezelLeft + bezelRight
            let totalHeight = size.height + bezelTop + bezelBottom + standHeight
            if totalWidth > 0 && totalHeight > 0 {
                return CGSize(width: totalWidth, height: totalHeight)
            }
            throw makeError(description: "The DeviceKit chrome metadata did not specify enough sizing data.", code: 11)
        }

        let url = URL(fileURLWithPath: compositePath)
        guard let document = CGPDFDocument(url as CFURL),
              let page = document.page(at: 1)
        else {
            throw makeError(description: "Unable to open the DeviceKit chrome composite PDF.", code: 12)
        }
        let pageRect = page.getBoxRect(.mediaBox)
        return pageRect.size
    }

    /// Logical size of the device screen in CoreSimulator points. Watch
    /// profiles already publish point-sized values so they bypass the scale
    /// division.
    func screenSize(for info: ChromeInfo, chromeSize: CGSize, screenScale: CGFloat) -> CGSize {
        let profile = info.profile
        guard let rawSize = try? displayPixelSize(for: info) else { return .zero }
        let scale = max(screenScale, 1.0)
        if !isWatchProfile(profile) {
            return CGSize(width: rawSize.width / scale, height: rawSize.height / scale)
        }
        return rawSize
    }

    // MARK: - Screen / sensor drawing

    /// Punches a hole in the bezel where the screen sits, respecting the
    /// device's corner radius (or framebuffer mask, where present).
    func clearScreenArea(for info: ChromeInfo, layout: ChromeLayout, context: CGContext) throws {
        let x = layout.contentX
        let y = layout.contentY
        let width = layout.contentWidth
        let height = layout.contentHeight
        if width <= 0 || height <= 0 { return }

        let rect = CGRect(x: x, y: y, width: width, height: height)
        if layout.hasScreenMask {
            let maskPath = self.screenMaskPath(for: info)
            if !maskPath.isEmpty, let maskImage = try? pdfRasterizer.loadImage(atPath: maskPath) {
                context.saveGState()
                context.clip(to: rect, mask: maskImage)
                context.setBlendMode(.clear)
                context.fill(rect)
                context.restoreGState()
                return
            }
        }

        var radius = layout.cornerRadius
        if radius <= 0 {
            radius = layout.chromeCornerRadius
        }
        let clampedRadius = min(max(radius, 0.0), min(width, height) / 2.0)

        context.saveGState()
        context.setBlendMode(.clear)
        if clampedRadius <= 0 {
            context.fill(rect)
        } else {
            // CG's `addArc(tangent1End:tangent2End:radius:)` is the cleanest
            // way to build a rounded-rect path manually — the convenience
            // initialisers don't expose corner anchor control.
            let path = CGMutablePath()
            path.move(to: CGPoint(x: rect.minX + clampedRadius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - clampedRadius, y: rect.minY))
            path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY + clampedRadius), radius: clampedRadius)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - clampedRadius))
            path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - clampedRadius, y: rect.maxY), radius: clampedRadius)
            path.addLine(to: CGPoint(x: rect.minX + clampedRadius, y: rect.maxY))
            path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY - clampedRadius), radius: clampedRadius)
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + clampedRadius))
            path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + clampedRadius, y: rect.minY), radius: clampedRadius)
            path.closeSubpath()
            context.addPath(path)
            context.fillPath()
        }
        context.restoreGState()
    }

    /// Draws the iPhone "Dynamic Island"/sensor-bar overlay across the top of
    /// the screen rect. Most devices skip this.
    func drawSensorBar(for info: ChromeInfo, layout: ChromeLayout, context: CGContext) throws {
        let sensorPath = self.sensorBarPath(for: info)
        if sensorPath.isEmpty { return }

        let sensorSize = pdfRasterizer.pageSize(atPath: sensorPath)
        if sensorSize.width <= 0 || sensorSize.height <= 0 { return }

        if layout.screenWidth <= 0 { return }

        let rect = CGRect(
            x: layout.screenX + ((layout.screenWidth - sensorSize.width) / 2.0),
            y: layout.screenY,
            width: sensorSize.width,
            height: sensorSize.height
        )
        _ = try pdfRasterizer.draw(atPath: sensorPath, in: rect, into: context)
    }

    // MARK: - Resource paths

    func sensorBarPath(for info: ChromeInfo) -> String {
        let sensorName = info.profile.sensorBarImage ?? ""
        let resourcesPath = info.profileResourcesPath
        if resourcesPath.isEmpty || sensorName.isEmpty { return "" }
        let path = (resourcesPath as NSString).appendingPathComponent("\(sensorName).pdf")
        return FileManager.default.fileExists(atPath: path) ? path : ""
    }

    func screenMaskPath(for info: ChromeInfo) -> String {
        let maskName = info.profile.framebufferMask ?? ""
        let resourcesPath = info.profileResourcesPath
        if resourcesPath.isEmpty || maskName.isEmpty { return "" }
        let path = (resourcesPath as NSString).appendingPathComponent("\(maskName).pdf")
        return FileManager.default.fileExists(atPath: path) ? path : ""
    }

    func framebufferMaskSize(for info: ChromeInfo) -> CGSize {
        let maskPath = self.screenMaskPath(for: info)
        return pdfRasterizer.pageSize(atPath: maskPath)
    }

    // MARK: - Black-screen probe (watch)

    /// Walks the composite PDF pixel-by-pixel looking for the black "screen
    /// fill" region inserted by DeviceKit. Used only by watch profiles, where
    /// the screen is round/octagonal and not derivable from the bezel insets.
    /// Results are cached because the scan is O(width*height).
    func blackScreenBounds(for info: ChromeInfo, matchingDisplaySize displaySize: CGSize) -> CGRect {
        if !isWatchProfile(info.profile) || displaySize.width <= 0 || displaySize.height <= 0 {
            return .zero
        }

        let compositePath = compositeAssetPath(for: info)
        if compositePath.isEmpty { return .zero }

        let cacheKey = String(format: "%@:%.3fx%.3f", compositePath, displaySize.width, displaySize.height)
        boundsCacheLock.lock()
        if let cached = boundsCache[cacheKey] {
            boundsCacheLock.unlock()
            return cached
        }
        boundsCacheLock.unlock()

        var result: CGRect = .zero
        let url = URL(fileURLWithPath: compositePath)
        guard let document = CGPDFDocument(url as CFURL),
              let page = document.page(at: 1)
        else {
            return .zero
        }

        let mediaBox = page.getBoxRect(.mediaBox)
        let width = max(Int(ceil(mediaBox.size.width)), 1)
        let height = max(Int(ceil(mediaBox.size.height)), 1)

        // Guardrail: refuse to scan absurdly large pages. 4096² is well past
        // any realistic device chrome (largest watch chrome is ~500²).
        if width > 1 && height > 1 && width <= 4096 && height <= 4096 {
            let bytesPerRow = width * 4
            var pixels = Data(count: height * bytesPerRow)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            pixels.withUnsafeMutableBytes { (pixelBuf: UnsafeMutableRawBufferPointer) in
                guard let context = CGContext(
                    data: pixelBuf.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
                ) else {
                    return
                }
                context.clear(CGRect(x: 0, y: 0, width: width, height: height))
                context.saveGState()
                context.translateBy(x: 0, y: CGFloat(height))
                context.scaleBy(x: CGFloat(width) / max(mediaBox.size.width, 1.0), y: -CGFloat(height) / max(mediaBox.size.height, 1.0))
                context.translateBy(x: -mediaBox.origin.x, y: -mediaBox.origin.y)
                context.drawPDFPage(page)
                context.restoreGState()
            }

            pixels.withUnsafeBytes { (pixelBuf: UnsafeRawBufferPointer) in
                guard let bytes = pixelBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                var minX = width
                var minY = height
                var maxX = -1
                var maxY = -1
                // "Black" = R/G/B all < 8 with alpha > 127. Tighter than pure
                // zero so we tolerate any slight anti-aliasing fuzz.
                for y in 0..<height {
                    for x in 0..<width {
                        let idx = (y * bytesPerRow) + (x * 4)
                        let red = bytes[idx]
                        let green = bytes[idx + 1]
                        let blue = bytes[idx + 2]
                        let alpha = bytes[idx + 3]
                        if alpha > 127 && red < 8 && green < 8 && blue < 8 {
                            minX = min(minX, x)
                            minY = min(minY, y)
                            maxX = max(maxX, x)
                            maxY = max(maxY, y)
                        }
                    }
                }

                if maxX >= minX && maxY >= minY {
                    let pixelBounds = CGRect(x: CGFloat(minX), y: CGFloat(minY), width: CGFloat(maxX - minX + 1), height: CGFloat(maxY - minY + 1))
                    let widthDelta = abs(pixelBounds.width - displaySize.width)
                    let heightDelta = abs(pixelBounds.height - displaySize.height)
                    // Only accept the probe if the bounds are close to the
                    // expected display size — otherwise we likely picked up
                    // a stray black artwork detail (a button glyph, etc).
                    let tolerance = max(8.0, max(displaySize.width, displaySize.height) * 0.02)
                    if widthDelta <= tolerance && heightDelta <= tolerance {
                        result = pixelBounds
                    }
                }
            }
        }

        boundsCacheLock.lock()
        boundsCache[cacheKey] = result
        boundsCacheLock.unlock()
        return result
    }

    /// Derives the watch screen's corner radius by inspecting the framebuffer
    /// mask's alpha edge. Used only when DeviceKit ships a mask PDF.
    func framebufferMaskCornerRadius(for info: ChromeInfo, pointScreenWidth: CGFloat) -> CGFloat {
        let maskPath = self.screenMaskPath(for: info)
        if maskPath.isEmpty || pointScreenWidth <= 0 { return 0.0 }

        let url = URL(fileURLWithPath: maskPath)
        guard let document = CGPDFDocument(url as CFURL),
              let page = document.page(at: 1)
        else {
            return 0.0
        }

        let mediaBox = page.getBoxRect(.mediaBox)
        let width = max(Int(ceil(mediaBox.size.width)), 1)
        let height = max(Int(ceil(mediaBox.size.height)), 1)
        if width <= 1 || height <= 1 || width > 4096 || height > 4096 {
            return 0.0
        }

        let bytesPerRow = width * 4
        var pixels = Data(count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        pixels.withUnsafeMutableBytes { (pixelBuf: UnsafeMutableRawBufferPointer) in
            guard let context = CGContext(
                data: pixelBuf.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ) else {
                return
            }
            context.clear(CGRect(x: 0, y: 0, width: width, height: height))
            context.saveGState()
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: CGFloat(width) / max(mediaBox.size.width, 1.0), y: -CGFloat(height) / max(mediaBox.size.height, 1.0))
            context.translateBy(x: -mediaBox.origin.x, y: -mediaBox.origin.y)
            context.drawPDFPage(page)
            context.restoreGState()
        }

        // Walk down/right from the top-left corner until we hit a non-empty
        // pixel — that distance is the corner radius in mask coordinates.
        var topInset = -1
        var leftInset = -1
        pixels.withUnsafeBytes { (pixelBuf: UnsafeRawBufferPointer) in
            guard let bytes = pixelBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for x in 0..<width {
                if bytes[x * 4 + 3] > 127 {
                    topInset = x
                    break
                }
            }
            for y in 0..<height {
                if bytes[y * bytesPerRow + 3] > 127 {
                    leftInset = y
                    break
                }
            }
        }

        if topInset < 0 || leftInset < 0 { return 0.0 }
        let maskRadius = max(CGFloat(topInset), CGFloat(leftInset))
        let maskWidth = max(mediaBox.size.width, 1.0)
        return maskRadius * pointScreenWidth / maskWidth
    }
}
