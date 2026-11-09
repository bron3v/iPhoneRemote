import AppKit
import SwiftUI

struct PillPreview: View {
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let layout = NavigationOverlayGeometry.layout(image: CGSize(width: 393, height: 852), bounds: CGRect(origin: .zero, size: size))
            ZStack {
                LinearGradient(colors: [Color(red: 0.16, green: 0.22, blue: 0.31), Color(red: 0.08, green: 0.10, blue: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Capsule().fill(.black).frame(width: size.width * 0.30, height: size.height * 0.035).position(x: size.width / 2, y: size.height * 0.035)
                Text("9:41").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    .position(x: size.width * 0.155, y: size.height * 0.035)
                HStack(spacing: 4) {
                    Image(systemName: "cellularbars")
                    Image(systemName: "wifi")
                    Image(systemName: "battery.100percent")
                }.font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                    .position(x: size.width * 0.845, y: size.height * 0.035)
                Text("Anteprima dei comandi\nNessun contenuto dell’iPhone")
                    .font(.system(size: 16)).foregroundStyle(.white.opacity(0.5)).multilineTextAlignment(.center)
                face("bell.fill", disclosure: true, frame: layout.notifications)
                face("slider.horizontal.3", disclosure: true, frame: layout.controlCenter)
                face("house.fill", disclosure: false, frame: layout.home)
            }
        }.frame(width: 393, height: 852)
    }
    private func face(_ icon: String, disclosure: Bool, frame: CGRect) -> some View {
        NavigationPillFace(icon: icon, disclosure: disclosure)
            .frame(width: frame.width, height: frame.height).position(x: frame.midX, y: frame.midY)
    }
}
@main struct Preview {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let renderer = ImageRenderer(content: PillPreview())
        renderer.scale = 2
        guard let image = renderer.cgImage, let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { fatalError("No preview") }
        try data.write(to: URL(fileURLWithPath: "build/logs/navigation-pills-preview.png"))
        print("Rendered navigation design without accessing the iPhone")
    }
}
