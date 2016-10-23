//
//  WebP.swift
//  WebP
//
//  Created by ainame on Oct 16, 2016.
//  Copyright © 2016 satoshi.namai. All rights reserved.
//

import Foundation
import CWebP
import CoreGraphics

public class WebPSimple {
    public static func encode(_ rgbaDataPtr: UnsafeMutablePointer<UInt8>, width: Int, height: Int, stride: Int, quality: Float) throws -> Data {
        var outputPtr: UnsafeMutablePointer<UInt8>? = nil

        let size = WebPEncodeRGB(rgbaDataPtr, Int32(width), Int32(height), Int32(stride), quality, &outputPtr)
        if size == 0 {
            throw WebPError.encodeError
        }

        return Data(bytes: UnsafeMutableRawPointer(outputPtr!), count: size)
    }

    public static func decode(_ webPData: Data) throws -> CGImage {
        var config: WebPDecoderConfig = try webPData.withUnsafeBytes { (body: UnsafePointer<UInt8>) in
            var config = WebPDecoderConfig()
            if WebPInitDecoderConfig(&config) == 0 {
                fatalError("can't init decoder config")
            }

            var features = WebPBitstreamFeatures()
            if WebPGetFeatures(body, webPData.count, &features) != VP8_STATUS_OK {
                throw WebPError.brokenHeaderError
            }

            config.output.colorspace = MODE_RGBA

            if WebPDecode(body, webPData.count, &config) != VP8_STATUS_OK {
                throw WebPError.decodeError
            }
            return config
        }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: config.output.u.RGBA.rgba,
            width: Int(config.input.width),
            height: Int(config.input.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(config.output.u.RGBA.stride),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        WebPFreeDecBuffer(&config.output)
        return context.makeImage()!
    }
}

#if os(macOS)
import AppKit

extension WebPSimple {
    public static func encode(_ image: NSImage, quality: Float) throws -> Data {
        let data = image.tiffRepresentation!
        let stride = Int(image.size.width) * MemoryLayout<UInt8>.size * 3 // RGB = 3byte
        let bitmap = NSBitmapImageRep(data: data)!
        let webPData = try encode(bitmap.bitmapData!, width: Int(image.size.width), height: Int(image.size.height),
            stride: stride, quality: quality)
        return webPData
    }
}
#endif