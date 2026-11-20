#!/usr/bin/env swift
//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

// Renders the sample's launcher icon rasters from the SVG sources next to this file, with CoreGraphics only:
// no image generator, no third-party tool. The icon is A3 "Pastille": the Octopus app symbol with its three
// dots on the navy gradient, the Flutter logo in the small bubble.
//
//     swift assets/icon/render_app_icons.swift      (run from example/)
//
// Writes:
// - ios/Runner/Assets.xcassets/AppIcon.appiconset/AppIcon.png — 1024, opaque (App Store Connect rejects alpha),
//   from ios-light.svg;
// - android/app/src/main/res/mipmap-*dpi/ic_launcher{,_round}.png — the legacy icons for API 24–25, the central
//   72 dp of the adaptive layers pre-masked to a rounded square and a circle;
// - android/app/src/main/ic_launcher-playstore.png — 512, opaque, the same 72 dp, for the Play listing.
//
// API 26+ draws the adaptive icon from the vector layers in res/drawable{,-v26}/ic_launcher_*.xml, which carry
// the same path data as android-background.svg / android-foreground.svg. The SVG reader handles just what those
// files use: `<rect>` and `<path>` with absolute M/L/C/Z commands, a solid or linear-gradient fill
// (objectBoundingBox or userSpaceOnUse, with stop-opacity) and an optional even-odd rule.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("render_app_icons: \(message)\n".utf8))
    exit(1)
}

func matches(_ pattern: String, in text: String) -> [[String]] {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
        fail("bad pattern \(pattern)")
    }
    let range = NSRange(text.startIndex..., in: text)
    return regex.matches(in: text, range: range).map { match in
        (0..<match.numberOfRanges).map { index in
            Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
        }
    }
}

func attribute(_ name: String, of element: String) -> String? {
    matches("\\s\(name)=\"([^\"]*)\"", in: element).first?[1]
}

func number(_ name: String, of element: String, default value: Double = 0) -> CGFloat {
    CGFloat(attribute(name, of: element).flatMap(Double.init) ?? value)
}

func color(_ hex: String, opacity: CGFloat = 1) -> CGColor {
    let value = UInt32(hex.dropFirst(), radix: 16) ?? 0
    return CGColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                   blue: CGFloat(value & 0xFF) / 255, alpha: opacity)
}

/// Absolute M, L, C and Z: everything the sources use, and nothing more.
func path(_ data: String) -> CGPath {
    let tokens = matches("[MLCZz]|-?[0-9]*\\.?[0-9]+(?:[eE][-+]?[0-9]+)?", in: data).map { $0[0] }
    let path = CGMutablePath()
    var index = 0
    var command = ""
    func number() -> CGFloat {
        guard index < tokens.count, let value = Double(tokens[index]) else { fail("bad path data near \(index)") }
        index += 1
        return CGFloat(value)
    }
    while index < tokens.count {
        if tokens[index].first?.isLetter == true {
            command = tokens[index]
            index += 1
        }
        switch command {
        case "M":
            path.move(to: CGPoint(x: number(), y: number()))
            command = "L"
        case "L": path.addLine(to: CGPoint(x: number(), y: number()))
        case "C":
            let control1 = CGPoint(x: number(), y: number())
            let control2 = CGPoint(x: number(), y: number())
            path.addCurve(to: CGPoint(x: number(), y: number()), control1: control1, control2: control2)
        case "Z", "z": path.closeSubpath()
        default: fail("unsupported path command \(command)")
        }
    }
    return path
}

struct Gradient {
    let shading: CGGradient
    let start: CGPoint
    let end: CGPoint
    let boundingBoxUnits: Bool
}

struct Shape {
    let path: CGPath
    let rule: CGPathFillRule
    let fill: String
}

struct Layer {
    let gradients: [String: Gradient]
    let shapes: [Shape]

    init(file: String) {
        guard let svg = try? String(contentsOfFile: file, encoding: .utf8) else { fail("cannot read \(file)") }
        var gradients: [String: Gradient] = [:]
        for match in matches("<linearGradient([^>]*)>(.*?)</linearGradient>", in: svg) {
            guard let id = attribute("id", of: match[1]) else { fail("unnamed gradient in \(file)") }
            let stops = matches("<stop[^>]*/>", in: match[2]).map { $0[0] }
            guard let shading = CGGradient(
                colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                colors: stops.map {
                    color(attribute("stop-color", of: $0) ?? "#000000",
                          opacity: number("stop-opacity", of: $0, default: 1))
                } as CFArray,
                locations: stops.map { number("offset", of: $0) }) else { fail("bad gradient \(id)") }
            gradients[id] = Gradient(
                shading: shading,
                start: CGPoint(x: number("x1", of: match[1]), y: number("y1", of: match[1])),
                end: CGPoint(x: number("x2", of: match[1]), y: number("y2", of: match[1])),
                boundingBoxUnits: attribute("gradientUnits", of: match[1]) != "userSpaceOnUse")
        }
        self.gradients = gradients
        shapes = matches("<(rect|path)\\s[^>]*/>", in: svg).compactMap { match in
            let element = match[0]
            guard let fill = attribute("fill", of: element) else { return nil }
            let shape: CGPath
            if match[1] == "rect" {
                shape = CGPath(rect: CGRect(x: number("x", of: element), y: number("y", of: element),
                                            width: number("width", of: element),
                                            height: number("height", of: element)), transform: nil)
            } else {
                guard let data = attribute("d", of: element) else { return nil }
                shape = path(data)
            }
            let rule: CGPathFillRule = attribute("fill-rule", of: element) == "evenodd" ? .evenOdd : .winding
            return Shape(path: shape, rule: rule, fill: fill)
        }
    }

    func draw(in context: CGContext) {
        for shape in shapes {
            context.saveGState()
            context.addPath(shape.path)
            if shape.fill.hasPrefix("url(#") {
                let id = String(shape.fill.dropFirst(5).dropLast())
                guard let gradient = gradients[id] else { fail("unknown gradient \(id)") }
                context.clip(using: shape.rule)
                var start = gradient.start
                var end = gradient.end
                if gradient.boundingBoxUnits {
                    let box = shape.path.boundingBoxOfPath
                    start = CGPoint(x: box.minX + start.x * box.width, y: box.minY + start.y * box.height)
                    end = CGPoint(x: box.minX + end.x * box.width, y: box.minY + end.y * box.height)
                }
                context.drawLinearGradient(gradient.shading, start: start, end: end,
                                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            } else {
                context.setFillColor(color(shape.fill))
                context.fillPath(using: shape.rule)
            }
            context.restoreGState()
        }
    }
}

enum Mask {
    case none
    case roundedSquare
    case circle
}

/// Draws `layers` cropped to `crop` (SVG user units) into a `size`-pixel square, writes it as PNG.
func render(_ layers: [Layer], crop: CGRect, size: Int, mask: Mask, opaque: Bool, to output: String) {
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space,
                                  bitmapInfo: opaque ? CGImageAlphaInfo.noneSkipLast.rawValue
                                                     : CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fail("cannot create the bitmap for \(output)")
    }
    // SVG user space, y down, onto the bitmap: flip, then fit the crop to the full square.
    context.translateBy(x: 0, y: CGFloat(size))
    context.scaleBy(x: CGFloat(size) / crop.width, y: -CGFloat(size) / crop.height)
    context.translateBy(x: -crop.minX, y: -crop.minY)
    switch mask {
    case .none: break
    case .roundedSquare:
        // Same corner as the Android sample's legacy rasters: 14 % of the side.
        let radius = crop.width * 0.14
        context.addPath(CGPath(roundedRect: crop, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.clip()
    case .circle:
        context.addEllipse(in: crop)
        context.clip()
    }
    layers.forEach { $0.draw(in: context) }
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: output) as CFURL,
                                                            UTType.png.identifier as CFString, 1, nil) else {
        fail("cannot write \(output)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fail("cannot write \(output)") }
    print("render_app_icons: wrote \(output) (\(size)x\(size)\(opaque ? ", opaque" : ""))")
}

let source = "assets/icon"
let ios = Layer(file: "\(source)/ios-light.svg")
let android = [Layer(file: "\(source)/android-background.svg"), Layer(file: "\(source)/android-foreground.svg")]
// The 72 dp an adaptive icon shows out of its 108 dp layers.
let visible = CGRect(x: 18, y: 18, width: 72, height: 72)
let res = "android/app/src/main/res"

render([ios], crop: CGRect(x: 0, y: 0, width: 1024, height: 1024), size: 1024, mask: .none, opaque: true,
       to: "ios/Runner/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
for (density, size) in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)] {
    render(android, crop: visible, size: size, mask: .roundedSquare, opaque: false,
           to: "\(res)/mipmap-\(density)/ic_launcher.png")
    render(android, crop: visible, size: size, mask: .circle, opaque: false,
           to: "\(res)/mipmap-\(density)/ic_launcher_round.png")
}
render(android, crop: visible, size: 512, mask: .none, opaque: true,
       to: "android/app/src/main/ic_launcher-playstore.png")
