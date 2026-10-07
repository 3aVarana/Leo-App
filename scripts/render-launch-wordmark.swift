#!/usr/bin/env swift
// Draws the "Leo" wordmark of the launch screen (docs/Leo-Launch-Screen-Plan.md, section 2.2).
// A launch screen can't use custom fonts, so the wordmark ships as two PDFs in
// Leo/Assets.xcassets/LaunchWordmark.imageset: one in the light Ink color, one in the dark one.
//
// Run from the repo root after changing the font, the size or the Ink color:
//     swift scripts/render-launch-wordmark.swift
//
// Each page is the line box SwiftUI gives a one-line `Text` in the same font (the advance width
// of "Leo" by ascent + descent + leading), with the baseline in the same place, so the image and
// the launch intro's first frame put the glyphs on the same pixels.

import CoreGraphics
import CoreText
import Foundation

let word = "Leo"
let pointSize: CGFloat = 48 // LeoTextStyle.launchWordmark
let fontURL = URL(fileURLWithPath: "Leo/Resources/Fonts/SourceSerif4-Semibold.otf")
let outputDirectory = URL(fileURLWithPath: "Leo/Assets.xcassets/LaunchWordmark.imageset")
/// The Ink color set, light and dark.
let variants: [(file: String, ink: [CGFloat])] = [
    ("LaunchWordmark.pdf", [0x20, 0x1E, 0x1D]),
    ("LaunchWordmark-dark.pdf", [0xEF, 0xED, 0xED]),
]

guard let descriptor = (CTFontManagerCreateFontDescriptorsFromURL(fontURL as CFURL) as? [CTFontDescriptor])?.first
else {
    fatalError("Can't load \(fontURL.path). Run this from the repo root.")
}

let font = CTFontCreateWithFontDescriptor(descriptor, pointSize, nil)

let ascent = CTFontGetAscent(font)
let descent = CTFontGetDescent(font)
let leading = CTFontGetLeading(font)
let lineHeight = ascent + descent + leading

/// Draw in the context's fill color, which changes per variant.
let line = CTLineCreateWithAttributedString(
    NSAttributedString(string: word, attributes: [
        kCTFontAttributeName as NSAttributedString.Key: font,
        kCTForegroundColorFromContextAttributeName as NSAttributedString.Key: true,
    ]),
)
let width = CTLineGetTypographicBounds(line, nil, nil, nil)

for variant in variants {
    var box = CGRect(x: 0, y: 0, width: width, height: lineHeight)
    let url = outputDirectory.appendingPathComponent(variant.file)
    guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else {
        fatalError("Can't create \(url.path)")
    }
    context.beginPDFPage(nil)
    context.setFillColor(CGColor(
        srgbRed: variant.ink[0] / 255, green: variant.ink[1] / 255, blue: variant.ink[2] / 255, alpha: 1,
    ))
    // PDF space has its origin at the bottom left: the baseline sits `descent + leading` above it.
    context.textPosition = CGPoint(x: 0, y: descent + leading)
    CTLineDraw(line, context)
    context.endPDFPage()
    context.closePDF()
    print("Wrote \(url.path): \(width) x \(lineHeight) pt")
}
