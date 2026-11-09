import AppKit
import SwiftUI

@main struct GuidePreview {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let content = KeypadGuide(imageSize: CGSize(width: 1180, height: 2556), centerX: 0.5,
                                  top: 0.48, columnGap: 0.26, rowGap: 0.11, diameter: 0.18, opacity: 0.8)
            .frame(width: 393, height: 852).background(.black)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let cg = renderer.cgImage,
              let data = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { fatalError("No rendered guide") }
        try data.write(to: URL(fileURLWithPath: "build/logs/keypad-guide-preview.png"))
        print("Rendered \(cg.width)×\(cg.height), without reading the iPhone or sending input")
    }
}
