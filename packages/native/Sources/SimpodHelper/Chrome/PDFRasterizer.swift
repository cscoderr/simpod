//
//  PDFRasterizer.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/17/26.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum PDFRasterizerError: Error, Equatable {
    case emptyPath
    case openFailed(path: String)
    case contextCreationFailed
    case imageCreationFailed
    case pngEncoderUnavailable
    case pngEncodingFailed
}

/// File-system oriented PDF rasterization helpers used by `ChromeRenderer`.
/// Stateless and value-type, so safe to share across threads.
struct PDFRasterizer: Sendable {

    func pageSize(atPath path: String) -> CGSize {
        guard let page = page(atPath: path) else { return .zero }
        return page.getBoxRect(.mediaBox).size
    }

    func loadImage(atPath path: String) throws -> CGImage {
        guard !path.isEmpty else { throw PDFRasterizerError.emptyPath }
        guard let page = page(atPath: path) else {
            throw PDFRasterizerError.openFailed(path: path)
        }

        var box = page.getBoxRect(.cropBox)
        if box == .zero { box = page.getBoxRect(.mediaBox) }
        let width = max(Int(ceil(box.size.width)), 1)
        let height = max(Int(ceil(box.size.height)), 1)

        let context = try makeBitmapContext(width: width, height: height)
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.translateBy(x: -box.origin.x, y: -box.origin.y)
        context.drawPDFPage(page)
        guard let image = context.makeImage() else {
            throw PDFRasterizerError.imageCreationFailed
        }
        return image
    }

    @discardableResult
    func draw(atPath path: String, in rect: CGRect, into context: CGContext) throws -> Bool {
        guard let page = page(atPath: path) else {
            throw PDFRasterizerError.openFailed(path: path)
        }
        let mediaBox = page.getBoxRect(.mediaBox)
        context.saveGState()
        context.clip(to: rect)
        context.translateBy(x: rect.origin.x, y: rect.origin.y + rect.size.height)
        context.scaleBy(
            x: rect.size.width / max(mediaBox.size.width, 1.0),
            y: -rect.size.height / max(mediaBox.size.height, 1.0)
        )
        context.translateBy(x: -mediaBox.origin.x, y: -mediaBox.origin.y)
        context.drawPDFPage(page)
        context.restoreGState()
        return true
    }

    @discardableResult
    func drawRasterized(atPath path: String, in rect: CGRect, into context: CGContext) throws -> Bool {
        let image = try loadImage(atPath: path)
        let imageWidth = max(CGFloat(image.width), 1.0)
        let imageHeight = max(CGFloat(image.height), 1.0)
        context.saveGState()
        context.clip(to: rect)
        context.translateBy(x: rect.origin.x, y: rect.origin.y + rect.size.height)
        context.scaleBy(x: rect.size.width / imageWidth, y: -rect.size.height / imageHeight)
        context.draw(image, in: CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
        context.restoreGState()
        return true
    }

    func pngData(atPath path: String, scale: CGFloat) throws -> Data {
        guard !path.isEmpty else { throw PDFRasterizerError.emptyPath }
        guard let page = page(atPath: path) else {
            throw PDFRasterizerError.openFailed(path: path)
        }

        let mediaBox = page.getBoxRect(.mediaBox)
        let renderScale = max(scale, 1.0)
        let pixelWidth = max(Int(ceil(mediaBox.size.width * renderScale)), 1)
        let pixelHeight = max(Int(ceil(mediaBox.size.height * renderScale)), 1)

        let context = try makeBitmapContext(width: pixelWidth, height: pixelHeight)
        context.clear(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        context.saveGState()
        context.translateBy(x: 0, y: CGFloat(pixelHeight))
        context.scaleBy(
            x: CGFloat(pixelWidth) / max(mediaBox.size.width, 1.0),
            y: -CGFloat(pixelHeight) / max(mediaBox.size.height, 1.0)
        )
        context.translateBy(x: -mediaBox.origin.x, y: -mediaBox.origin.y)
        context.drawPDFPage(page)
        context.restoreGState()

        guard let image = context.makeImage() else {
            throw PDFRasterizerError.imageCreationFailed
        }
        return try encodePNG(image)
    }

    func encodePNG(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        let pngType = UTType.png.identifier as CFString
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, pngType, 1, nil) else {
            throw PDFRasterizerError.pngEncoderUnavailable
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw PDFRasterizerError.pngEncodingFailed
        }
        return data as Data
    }

    // MARK: - Private

    private func page(atPath path: String) -> CGPDFPage? {
        guard !path.isEmpty else { return nil }
        let url = URL(fileURLWithPath: path)
        guard let document = CGPDFDocument(url as CFURL),
              let page = document.page(at: 1)
        else { return nil }
        return page
    }

    private func makeBitmapContext(width: Int, height: Int) throws -> CGContext {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            throw PDFRasterizerError.contextCreationFailed
        }
        return context
    }
}
