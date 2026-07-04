//
//  ChromeRenderer+Bezel.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/17/26.
//
//  Draws the bezel artwork itself — either from a single composite PDF
//  (most modern devices) or from 9 sliced PDFs (corners + edges + middle)
//  for older device profiles.
//

import CoreGraphics
import Foundation

extension ChromeRenderer {

    /// Sliced-chrome rendering. The "9-slice" pattern is the same as a
    /// resizable image in UIKit: four corners stay fixed, the four edges
    /// stretch along one axis, and the centre stretches both ways.
    func drawSlicedChrome(_ info: ChromeInfo, inSize size: CGSize, context: CGContext) throws -> Bool {
        let images = info.metadata.images
        let sizing = images?.sizing
        let top = sizing?.topHeight ?? 0
        let left = sizing?.leftWidth ?? 0
        let bottom = sizing?.bottomHeight ?? 0
        let right = sizing?.rightWidth ?? 0

        let chromePath = info.chromePath
        let topLeftPath = resolvedChromeAssetPath(forName: images?.topLeft ?? "", chromePath: chromePath)
        let topPath = resolvedChromeAssetPath(forName: images?.top ?? "", chromePath: chromePath)
        let topRightPath = resolvedChromeAssetPath(forName: images?.topRight ?? "", chromePath: chromePath)
        let leftPath = resolvedChromeAssetPath(forName: images?.left ?? "", chromePath: chromePath)
        let rightPath = resolvedChromeAssetPath(forName: images?.right ?? "", chromePath: chromePath)
        let bottomLeftPath = resolvedChromeAssetPath(forName: images?.bottomLeft ?? "", chromePath: chromePath)
        let bottomPath = resolvedChromeAssetPath(forName: images?.bottom ?? "", chromePath: chromePath)
        let bottomRightPath = resolvedChromeAssetPath(forName: images?.bottomRight ?? "", chromePath: chromePath)

        let topLeftSize = pdfRasterizer.pageSize(atPath: topLeftPath)
        let topSize = pdfRasterizer.pageSize(atPath: topPath)
        let topRightSize = pdfRasterizer.pageSize(atPath: topRightPath)
        let leftSize = pdfRasterizer.pageSize(atPath: leftPath)
        let rightSize = pdfRasterizer.pageSize(atPath: rightPath)
        let bottomLeftSize = pdfRasterizer.pageSize(atPath: bottomLeftPath)
        let bottomSize = pdfRasterizer.pageSize(atPath: bottomPath)
        let bottomRightSize = pdfRasterizer.pageSize(atPath: bottomRightPath)

        // The published sizing metadata is occasionally wrong (older profiles
        // shipped before the chrome schema was tightened). Taking the
        // max of metadata + actual PDF size protects against under-sized
        // corner slices that would otherwise leave gaps.
        let topHeight = max(max(max(top, topSize.height), topLeftSize.height), topRightSize.height)
        let leftWidth = max(max(max(left, leftSize.width), topLeftSize.width), bottomLeftSize.width)
        let bottomHeight = max(max(max(bottom, bottomSize.height), bottomLeftSize.height), bottomRightSize.height)
        let rightWidth = max(max(max(right, rightSize.width), topRightSize.width), bottomRightSize.width)
        let middleWidth = max(size.width - leftWidth - rightWidth, 1.0)
        let standHeight = images?.stand?.height ?? 0
        let chromeHeight = max(size.height - standHeight, 1.0)
        let middleHeight = max(chromeHeight - topHeight - bottomHeight, 1.0)

        let pieces: [(path: String, rect: CGRect)] = [
            (topLeftPath, CGRect(x: 0, y: 0, width: leftWidth, height: topHeight)),
            (topPath, CGRect(x: leftWidth, y: 0, width: middleWidth, height: topHeight)),
            (topRightPath, CGRect(x: leftWidth + middleWidth, y: 0, width: rightWidth, height: topHeight)),
            (leftPath, CGRect(x: 0, y: topHeight, width: leftWidth, height: middleHeight)),
            (rightPath, CGRect(x: leftWidth + middleWidth, y: topHeight, width: rightWidth, height: middleHeight)),
            (bottomLeftPath, CGRect(x: 0, y: topHeight + middleHeight, width: leftWidth, height: bottomHeight)),
            (bottomPath, CGRect(x: leftWidth, y: topHeight + middleHeight, width: middleWidth, height: bottomHeight)),
            (bottomRightPath, CGRect(x: leftWidth + middleWidth, y: topHeight + middleHeight, width: rightWidth, height: bottomHeight))
        ]

        var drewAny = false
        for piece in pieces {
            if piece.path.isEmpty { continue }
            if piece.rect.width <= 0 || piece.rect.height <= 0 { continue }
            if try pdfRasterizer.drawRasterized(atPath: piece.path, in: piece.rect, into: context) {
                drewAny = true
            } else {
                return false
            }
        }

        if standHeight > 0 {
            _ = try drawStandImages(for: info, inSize: size, chromeYMax: chromeHeight, context: context)
        }

        if !drewAny {
            throw makeError(description: "The DeviceKit chrome did not expose renderable composite or sliced PDF assets.", code: 13)
        }
        return drewAny
    }

    /// iPad stand: another 3-slice (left cap, stretchable centre, right cap)
    /// that sits below the bezel. Only used by `.devicestand`-bearing
    /// profiles like the iPad Pro Magic Keyboard variant.
    func drawStandImages(for info: ChromeInfo, inSize size: CGSize, chromeYMax: CGFloat, context: CGContext) throws -> Bool {
        let stand = info.metadata.images?.stand
        let standWidth = stand?.width ?? 0
        let standHeight = stand?.height ?? 0
        if standWidth <= 0 || standHeight <= 0 { return true }

        let chromePath = info.chromePath
        let leftName = stand?.left ?? ""
        let centerName = stand?.center ?? ""
        let rightName = stand?.right ?? ""

        let leftPath = leftName.isEmpty ? "" : resolvedChromeAssetPath(forName: leftName, chromePath: chromePath)
        let centerPath = centerName.isEmpty ? "" : resolvedChromeAssetPath(forName: centerName, chromePath: chromePath)
        let rightPath = rightName.isEmpty ? "" : resolvedChromeAssetPath(forName: rightName, chromePath: chromePath)

        let leftSize = pdfRasterizer.pageSize(atPath: leftPath)
        let rightSize = pdfRasterizer.pageSize(atPath: rightPath)

        let leftWidth = max(leftSize.width, 0.0)
        let rightWidth = max(rightSize.width, 0.0)
        let centerWidth = max(standWidth - leftWidth - rightWidth, 1.0)
        let x = max((size.width - standWidth) / 2.0, 0.0)
        let y = chromeYMax

        if !leftPath.isEmpty && leftWidth > 0 {
            _ = try pdfRasterizer.drawRasterized(atPath: leftPath, in: CGRect(x: x, y: y, width: leftWidth, height: standHeight), into: context)
        }
        if !centerPath.isEmpty {
            _ = try pdfRasterizer.drawRasterized(atPath: centerPath, in: CGRect(x: x + leftWidth, y: y, width: centerWidth, height: standHeight), into: context)
        }
        if !rightPath.isEmpty && rightWidth > 0 {
            _ = try pdfRasterizer.drawRasterized(atPath: rightPath, in: CGRect(x: x + leftWidth + centerWidth, y: y, width: rightWidth, height: standHeight), into: context)
        }
        return true
    }
}
