import AppKit
import Foundation

// Original vector artwork: deep green tile, cream S and a golden key.
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let tile = NSBezierPath(roundedRect: NSRect(x: 55, y: 55, width: 914, height: 914), xRadius: 205, yRadius: 205)
NSGradient(starting: NSColor(red: 0.15, green: 0.37, blue: 0.29, alpha: 1), ending: NSColor(red: 0.06, green: 0.19, blue: 0.16, alpha: 1))!.draw(in: tile, angle: -60)
let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 600, weight: .semibold), .foregroundColor: NSColor(red: 0.97, green: 0.94, blue: 0.83, alpha: 1)]
("S" as NSString).draw(at: NSPoint(x: 300, y: 210), withAttributes: attributes)
NSColor(red: 0.87, green: 0.67, blue: 0.33, alpha: 1).setStroke()
let ring = NSBezierPath(ovalIn: NSRect(x: 210, y: 225, width: 105, height: 105)); ring.lineWidth = 27; ring.stroke()
let key = NSBezierPath(); key.move(to: NSPoint(x: 310, y: 277)); key.line(to: NSPoint(x: 735, y: 277)); key.line(to: NSPoint(x: 735, y: 225)); key.move(to: NSPoint(x: 660, y: 277)); key.line(to: NSPoint(x: 660, y: 235)); key.lineWidth = 27; key.lineCapStyle = .round; key.stroke()
image.unlockFocus()
guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Icon could not be drawn") }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
