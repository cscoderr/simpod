//
//  ChromeRenderer+Inputs.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/17/26.
//
//  Geometry + drawing for the physical inputs that sit on the bezel —
//  side buttons, volume rocker, digital crown, etc. The bulk of this
//  file is translating DeviceKit's anchor/align/offset coordinate
//  system (see [[ChromeInput-Offsets]]) into absolute frames.
//

import CoreGraphics
import Foundation

extension ChromeRenderer {

    // MARK: - Drawing

    /// Draws every input asset that matches `onlyOnTop`. The chrome composite
    /// is rendered between the two passes: bottom-of-chrome inputs (recessed
    /// side buttons) draw first, then the bezel, then top-of-chrome inputs
    /// (digital crowns, action buttons that sit proud of the chrome).
    func drawInputImages(for info: ChromeInfo, inSize size: CGSize, context: CGContext, onlyOnTop: Bool) throws {
        let chromePath = info.chromePath
        for input in info.metadata.inputs ?? [] {
            let onTop = shouldDrawInputOnTop(input, info: info)
            if onTop != onlyOnTop { continue }

            let assetName = input.image ?? ""
            if assetName.isEmpty { continue }
            let assetPath = resolvedChromeAssetPath(forName: assetName, chromePath: chromePath)

            let inputScaleVal = inputAssetScale(forInput: input, info: info, chromeSize: size)
            let coordinateScaleVal = inputCoordinateScale(for: info, chromeSize: size)
            let assetSize = scaledInputAssetSize(pdfRasterizer.pageSize(atPath: assetPath), scale: inputScaleVal)
            if assetSize.width <= 0 || assetSize.height <= 0 { continue }

            var rect = inputFrame(forInput: input, assetSize: assetSize, inSize: size, scale: coordinateScaleVal)
            rect = rect.offsetBy(dx: inputHorizontalAdjustment(forInput: input, info: info, chromeSize: size), dy: 0)
            rect = rect.offsetBy(dx: 0, dy: inputVerticalAdjustment(forInput: input, info: info, chromeSize: size))

            _ = try pdfRasterizer.draw(atPath: assetPath, in: rect, into: context)
            if isDigitalCrownInput(input) {
                // DeviceKit ships the crown as a flat side-on PDF; we layer
                // the ribbed texture on top so it doesn't look like a sticker.
                drawDigitalCrownTexture(inRect: rect, context: context)
            }
        }
    }

    // MARK: - Geometry

    /// Bounding rect of every drawn pixel for the device — chrome + all
    /// input assets, in both their rest and rollover positions. The output
    /// rect drives the total PNG dimensions.
    func fullFrame(for info: ChromeInfo, chromeSize: CGSize) -> CGRect {
        let profile = info.profile
        if isWatchProfile(profile) {
            let padding = screenPadding(for: info)
            var bounds = CGRect(
                x: -max(padding.width, 0.0),
                y: -max(padding.height, 0.0),
                width: chromeSize.width + (max(padding.width, 0.0) * 2.0),
                height: chromeSize.height + (max(padding.height, 0.0) * 2.0)
            )
            let chromePath = info.chromePath
            for input in info.metadata.inputs ?? [] {
                let assetName = input.image ?? ""
                if assetName.isEmpty { continue }
                let assetPath = resolvedChromeAssetPath(forName: assetName, chromePath: chromePath)
                let inputScaleVal = inputAssetScale(forInput: input, info: info, chromeSize: chromeSize)
                let coordinateScaleVal = inputCoordinateScale(for: info, chromeSize: chromeSize)
                let verticalAdjustment = inputVerticalAdjustment(forInput: input, info: info, chromeSize: chromeSize)
                let assetSize = scaledInputAssetSize(pdfRasterizer.pageSize(atPath: assetPath), scale: inputScaleVal)
                if assetSize.width <= 0 || assetSize.height <= 0 { continue }

                let normalRect = inputFrame(forInput: input, assetSize: assetSize, inSize: chromeSize, scale: coordinateScaleVal, offsetName: "normal")
                let rolloverRect = inputFrame(forInput: input, assetSize: assetSize, inSize: chromeSize, scale: coordinateScaleVal, offsetName: "rollover")
                let horizontalAdjustment = inputHorizontalAdjustment(forInput: input, info: info, chromeSize: chromeSize)

                bounds = bounds.union(normalRect.offsetBy(dx: horizontalAdjustment, dy: verticalAdjustment))
                bounds = bounds.union(rolloverRect.offsetBy(dx: horizontalAdjustment, dy: verticalAdjustment))
            }
            return bounds.integral
        }

        let padding = devicePadding(for: info, chromeSize: chromeSize)
        if padding.top != 0 || padding.left != 0 || padding.bottom != 0 || padding.right != 0 {
            return CGRect(
                x: -padding.left,
                y: -padding.top,
                width: chromeSize.width + padding.left + padding.right,
                height: chromeSize.height + padding.top + padding.bottom
            )
        }

        var bounds = CGRect(origin: .zero, size: chromeSize)
        let chromePath = info.chromePath
        let hasComposite = !compositeAssetPath(for: info).isEmpty
        let watchProfile = isWatchProfile(profile)
        for input in info.metadata.inputs ?? [] {
            let onTop = shouldDrawInputOnTop(input, info: info)
            // For composite-rendered watches, the under-chrome inputs are
            // already baked into the composite — counting them again would
            // expand the frame past the visible artwork.
            if hasComposite && watchProfile && !onTop { continue }

            let assetName = input.image ?? ""
            if assetName.isEmpty { continue }
            let assetPath = resolvedChromeAssetPath(forName: assetName, chromePath: chromePath)
            let inputScaleVal = inputAssetScale(forInput: input, info: info, chromeSize: chromeSize)
            let coordinateScaleVal = inputCoordinateScale(for: info, chromeSize: chromeSize)
            let verticalAdjustment = inputVerticalAdjustment(forInput: input, info: info, chromeSize: chromeSize)
            let assetSize = scaledInputAssetSize(pdfRasterizer.pageSize(atPath: assetPath), scale: inputScaleVal)
            if assetSize.width <= 0 || assetSize.height <= 0 { continue }

            let normalRect = inputFrame(forInput: input, assetSize: assetSize, inSize: chromeSize, scale: coordinateScaleVal, offsetName: "normal")
            let rolloverRect = inputFrame(forInput: input, assetSize: assetSize, inSize: chromeSize, scale: coordinateScaleVal, offsetName: "rollover")
            let horizontalAdjustment = inputHorizontalAdjustment(forInput: input, info: info, chromeSize: chromeSize)

            bounds = bounds.union(normalRect.offsetBy(dx: horizontalAdjustment, dy: verticalAdjustment))
            bounds = bounds.union(rolloverRect.offsetBy(dx: horizontalAdjustment, dy: verticalAdjustment))
        }
        return bounds.integral
    }

    /// Computes the absolute frame of a single input asset on the bezel.
    ///
    /// DeviceKit uses an anchor + align + offset coordinate system that
    /// mirrors CSS positioning. `anchor` says which chrome edge the asset
    /// hangs off; `align` says how it's distributed along the perpendicular
    /// axis; `offset.x/y` is the final nudge in the chosen frame.
    func inputFrame(forInput input: ChromeInput, assetSize: CGSize, inSize size: CGSize, scale: CGFloat, offsetName: String = "normal") -> CGRect {
        let offsets = input.offsets
        let normalOffset = offsets?.normal
        let rolloverOffset = offsets?.rollover
        let requestedOffset = offsetName == "rollover" ? rolloverOffset : normalOffset
        // Fall back to whatever offset *exists* — older chromes only ship one.
        let primaryOffset = normalOffset ?? rolloverOffset ?? requestedOffset
        let secondaryOffset = rolloverOffset ?? normalOffset ?? requestedOffset

        let coordinateScale = max(scale, 1.0)
        let normalX = (primaryOffset?.x ?? 0) * coordinateScale
        let normalY = (primaryOffset?.y ?? 0) * coordinateScale
        let rolloverX = (secondaryOffset?.x ?? 0) * coordinateScale
        let rolloverY = (secondaryOffset?.y ?? 0) * coordinateScale

        var restX = normalX
        var restY = normalY
        if offsetName == "rollover" {
            restX = rolloverX; restY = rolloverY
        }

        let anchor = input.anchor ?? ""
        let align = input.align ?? ""

        var x = restX - (assetSize.width / 2.0)
        var y = restY

        if anchor == "left" {
            x = restX - assetSize.width
        } else if anchor == "right" {
            x = size.width + restX
            y = restY
        } else if anchor == "top" {
            if align == "trailing" {
                x = size.width + restX - assetSize.width
            } else {
                x = restX
            }
            y = restY - assetSize.height
        } else if anchor == "bottom" {
            if align == "trailing" {
                x = size.width + restX - assetSize.width
            } else {
                x = restX
            }
            y = size.height + restY
        }

        if anchor == "left" || anchor == "right" {
            if align == "center" {
                y = (size.height - assetSize.height) / 2.0 + restY
            } else if align == "trailing" {
                y = size.height - assetSize.height + restY
            }
        } else if anchor == "top" || anchor == "bottom" {
            if align == "center" {
                x = (size.width / 2.0) + restX - (assetSize.width / 2.0)
            }
        } else if align == "center" {
            x = (size.width - assetSize.width) / 2.0 + restX
        } else if align == "trailing" {
            x = size.width - assetSize.width + restX
        }

        return CGRect(x: x, y: y, width: assetSize.width, height: assetSize.height)
    }

    func devicePadding(for info: ChromeInfo, chromeSize: CGSize) -> NSEdgeInsets {
        let padding = info.metadata.images?.devicePadding
        let inputScaleVal = inputScale(for: info, chromeSize: chromeSize)
        return NSEdgeInsets(
            top: (padding?.top ?? 0) * inputScaleVal,
            left: (padding?.left ?? 0) * inputScaleVal,
            bottom: (padding?.bottom ?? 0) * inputScaleVal,
            right: (padding?.right ?? 0) * inputScaleVal
        )
    }

    func screenPadding(for info: ChromeInfo) -> CGSize {
        info.metadata.images?.padding?.cgSize ?? .zero
    }

    /// Returns the JSON-ready button layout for every named input. This is
    /// the data the UI uses to draw hit-targets on top of the bezel.
    func buttonLayouts(for info: ChromeInfo, chromeSize: CGSize, chromeOffset: CGPoint, imagePrefix: String = "") -> [ChromeButtonLayout] {
        let chromePath = info.chromePath
        var buttons: [ChromeButtonLayout] = []

        for input in info.metadata.inputs ?? [] {
            let name = input.name ?? ""
            let assetName = input.image ?? ""
            if name.isEmpty || assetName.isEmpty { continue }

            let assetPath = resolvedChromeAssetPath(forName: assetName, chromePath: chromePath)
            let inputScaleVal = inputAssetScale(forInput: input, info: info, chromeSize: chromeSize)
            let coordinateScaleVal = inputCoordinateScale(for: info, chromeSize: chromeSize)
            let assetSize = scaledInputAssetSize(pdfRasterizer.pageSize(atPath: assetPath), scale: inputScaleVal)
            if assetSize.width <= 0 || assetSize.height <= 0 { continue }

            var rect = inputFrame(forInput: input, assetSize: assetSize, inSize: chromeSize, scale: coordinateScaleVal)
            rect = rect.offsetBy(dx: inputHorizontalAdjustment(forInput: input, info: info, chromeSize: chromeSize), dy: 0)
            rect = rect.offsetBy(dx: 0, dy: inputVerticalAdjustment(forInput: input, info: info, chromeSize: chromeSize))
            rect = rect.offsetBy(dx: chromeOffset.x, dy: chromeOffset.y)
            if rect.width <= 0 || rect.height <= 0 { continue }

            let normalOffset = input.offsets?.normal
            let rolloverOffset = input.offsets?.rollover ?? normalOffset
            let label = input.accessibilityTitle ?? name
            let type = input.type ?? ""
            let anchor = input.anchor ?? ""
            let align = input.align ?? ""
            let imageDownName = input.imageDown
            let imageDownDrawMode = input.imageDownDrawMode
            let onTop = shouldDrawInputOnTop(input, info: info)

            buttons.append(ChromeButtonLayout(
                name: name,
                label: label,
                type: type,
                imageName: assetName,
                frame: rect,
                anchor: anchor,
                align: align,
                onTop: onTop,
                restImageURL: "\(imagePrefix)/chrome-button/\(name).png",
                pressedImageURL: "\(imagePrefix)/chrome-button/\(name).png?pressed=true",
                normalOffset: CGPoint(
                    x: (normalOffset?.x ?? 0) * coordinateScaleVal,
                    y: (normalOffset?.y ?? 0) * coordinateScaleVal
                ),
                rolloverOffset: CGPoint(
                    x: (rolloverOffset?.x ?? 0) * coordinateScaleVal,
                    y: (rolloverOffset?.y ?? 0) * coordinateScaleVal
                ),
                imageDownName: (imageDownName?.isEmpty == false) ? imageDownName : nil,
                imageDownDrawMode: (imageDownDrawMode?.isEmpty == false) ? imageDownDrawMode : nil,
                usagePage: input.usagePage.map { NSNumber(value: $0) },
                usage: input.usage.map { NSNumber(value: $0) }
            ))
        }
        return buttons
    }

    func inputNamed(_ name: String, info: ChromeInfo) throws -> ChromeInput {
        // Tolerate ".png" suffixes and case differences so clients don't
        // need to learn the exact identifier in chrome.json.
        let normalized = (name as NSString).deletingPathExtension.lowercased()
        for input in info.metadata.inputs ?? [] {
            let inputName = input.name ?? ""
            if inputName.lowercased() == normalized {
                return input
            }
        }
        throw makeError(description: "The device chrome did not expose a button named `\(name)`.", code: 15)
    }

    // MARK: - Scale & adjustment helpers

    /// Watch input coordinates are described in pixels-per-screen-point, not
    /// composite points, so we scale them up to chrome-pixel space.
    func inputScale(for info: ChromeInfo, chromeSize: CGSize) -> CGFloat {
        if !isWatchProfile(info.profile) {
            return 1.0
        }
        let coordinateScaleVal = inputCoordinateScale(for: info, chromeSize: chromeSize)
        return max(coordinateScaleVal, 1.0)
    }

    func inputAssetScale(forInput input: ChromeInput, info: ChromeInfo, chromeSize: CGSize) -> CGFloat {
        inputScale(for: info, chromeSize: chromeSize)
    }

    func inputCoordinateScale(for info: ChromeInfo, chromeSize: CGSize) -> CGFloat {
        let profile = info.profile
        if !isWatchProfile(profile) {
            return inputScale(for: info, chromeSize: chromeSize)
        }

        let screenScale = self.screenScale(for: info)
        let sizing = info.metadata.images?.sizing
        let stand = info.metadata.images?.stand
        let nominalWidth = chromeSize.width - (sizing?.leftWidth ?? 0) - (sizing?.rightWidth ?? 0)
        let nominalHeight = chromeSize.height - (stand?.height ?? 0) - (sizing?.topHeight ?? 0) - (sizing?.bottomHeight ?? 0)
        guard let pixelSize = try? displayPixelSize(for: info) else { return screenScale }
        let screenWidth = pixelSize.width
        let screenHeight = pixelSize.height

        if nominalWidth <= 0 || nominalHeight <= 0 || screenWidth <= 0 || screenHeight <= 0 {
            return screenScale
        }

        // If the screen-pixel size is bigger than the nominal bezel slot,
        // the screen would overflow — cap at 1.0 so inputs scale *down* with
        // the screen rather than ballooning past the bezel.
        let fitScale = min(screenWidth / nominalWidth, screenHeight / nominalHeight)
        if !fitScale.isFinite || fitScale <= 0.0 {
            return screenScale
        }
        return screenScale * min(fitScale, 1.0)
    }

    /// Some watch chromes leave extra vertical room around the screen and
    /// expect the inputs to be re-centred in that space.
    func inputVerticalAdjustment(forInput input: ChromeInput, info: ChromeInfo, chromeSize: CGSize) -> CGFloat {
        let profile = info.profile
        if !isWatchProfile(profile) {
            return 0.0
        }

        let sizing = info.metadata.images?.sizing
        let stand = info.metadata.images?.stand
        let slotHeight = chromeSize.height - (stand?.height ?? 0) - (sizing?.topHeight ?? 0) - (sizing?.bottomHeight ?? 0)
        let maskSize = framebufferMaskSize(for: info)
        let displaySize = maskSize != .zero ? maskSize : screenSize(for: info, chromeSize: chromeSize, screenScale: screenScale(for: info))

        if slotHeight <= 0 || displaySize.height <= 0 {
            return 0.0
        }
        return max((slotHeight - min(displaySize.height, slotHeight)) / 2.0, 0.0)
    }

    /// The watch side button sits flush with the case edge, but when we shrink
    /// the chrome to match the framebuffer mask there's a tiny gap. Nudge the
    /// side button inward by the screen padding to close it.
    func inputHorizontalAdjustment(forInput input: ChromeInput, info: ChromeInfo, chromeSize: CGSize) -> CGFloat {
        if !isWatchProfile(info.profile) {
            return 0.0
        }

        let maskSize = framebufferMaskSize(for: info)
        let blackScreenBounds = self.blackScreenBounds(for: info, matchingDisplaySize: maskSize)
        if blackScreenBounds == .zero {
            return 0.0
        }

        let screenPadding = self.screenPadding(for: info)
        let adjustment = max(screenPadding.width, 0.0)
        if adjustment <= 0 { return 0.0 }

        let anchor = input.anchor ?? ""
        let name = input.name ?? ""
        if anchor != "right" { return 0.0 }
        if isDigitalCrownInput(input) { return 0.0 }
        if name == "side-button" {
            return -adjustment
        }
        return 0.0
    }

    func scaledInputAssetSize(_ assetSize: CGSize, scale: CGFloat) -> CGSize {
        let inputScaleVal = max(scale, 1.0)
        return CGSize(width: assetSize.width * inputScaleVal, height: assetSize.height * inputScaleVal)
    }

    func isDigitalCrownInput(_ input: ChromeInput) -> Bool {
        let type = input.type ?? ""
        let name = input.name ?? ""
        return type == "crown" || name == "digital-crown"
    }

    /// Inputs default to drawing under the bezel composite. Watch crowns and
    /// any input explicitly tagged `onTop: true` draw on top so they're not
    /// hidden by the device case artwork.
    func shouldDrawInputOnTop(_ input: ChromeInput, info: ChromeInfo) -> Bool {
        if input.onTop == true {
            return true
        }
        return isWatchProfile(info.profile) && isDigitalCrownInput(input)
    }

    /// Paints the ribbed knurled texture across the Digital Crown image.
    /// The PDF asset is a flat circle, so we draw faint diagonal hairlines
    /// inside a clipped rounded-rect to give it the ridged look that the
    /// physical hardware has.
    func drawDigitalCrownTexture(inRect rect: CGRect, context: CGContext) {
        if rect.width <= 3 || rect.height <= 6 { return }

        let width = rect.width
        let height = rect.height
        let radius = min(width, height) / 2.0
        let stripWidth = max(width * 0.22, 2.5)
        let textureRect = CGRect(x: rect.maxX - stripWidth, y: rect.minY + 8.0, width: stripWidth, height: max(height - 16.0, 1.0))

        context.saveGState()
        let clip = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        context.addPath(clip)
        context.clip()
        context.clip(to: textureRect)

        let minY = textureRect.minY
        let maxY = textureRect.maxY
        let minX = textureRect.minX
        let maxX = textureRect.maxX
        // Tune line spacing to screen size so a small crown doesn't end up
        // looking like a solid white strip.
        let lineSpacing = max(1.35, height / 52.0)
        context.setLineCap(.butt)
        context.setLineWidth(0.22)

        var y = minY
        while y <= maxY {
            // Inset the caps via a sine bulge so the lines tuck into the
            // curved edge of the crown rather than ending at a hard rect.
            let normalized = (y - rect.minY) / max(height, 1.0)
            let capInset = sin(normalized * CGFloat.pi) * stripWidth * 0.16
            let strokeStart = minX + capInset + stripWidth * 0.18
            let strokeEnd = maxX - stripWidth * 0.08

            context.setStrokeColor(CGColor(red: 0.88, green: 0.88, blue: 0.88, alpha: 0.10))
            context.move(to: CGPoint(x: strokeStart, y: y))
            context.addLine(to: CGPoint(x: strokeEnd, y: y))
            context.strokePath()

            context.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.08))
            context.move(to: CGPoint(x: strokeStart, y: y + 0.34))
            context.addLine(to: CGPoint(x: strokeEnd, y: y + 0.34))
            context.strokePath()

            y += lineSpacing
        }

        let innerShadow = CGRect(x: textureRect.minX, y: textureRect.minY, width: max(stripWidth * 0.18, 1.0), height: textureRect.height)
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.10))
        context.fill(innerShadow)

        let edgeHighlight = CGRect(x: textureRect.maxX - max(stripWidth * 0.18, 1.0), y: textureRect.minY, width: max(stripWidth * 0.08, 1.0), height: textureRect.height)
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.035))
        context.fill(edgeHighlight)

        context.restoreGState()
    }
}
