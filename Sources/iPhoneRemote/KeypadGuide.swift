import SwiftUI
#if SWIFT_PACKAGE
import RemoteCore
#endif

struct KeypadGuide: View {
    let imageSize: CGSize
    let centerX: Double
    let top: Double
    let columnGap: Double
    let rowGap: Double
    let diameter: Double
    let opacity: Double
    var body: some View {
        GeometryReader { geometry in
            let rect = ScreenGeometry.fittedRect(image: imageSize, bounds: CGRect(origin: .zero, size: geometry.size))
            if rect.width > 0, rect.height > 0, imageSize.height >= imageSize.width {
                ForEach(KeypadGuideGeometry.keys(centerX: centerX, top: top, columnGap: columnGap, rowGap: rowGap)) { key in
                    Text(key.digit)
                        .font(.system(size: max(14, rect.width * diameter * 0.45), weight: .regular, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: rect.width * diameter, height: rect.width * diameter)
                        .background(.black.opacity(0.4), in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
                        .position(x: rect.minX + rect.width * key.center.x,
                                  y: rect.minY + rect.height * key.center.y)
                }
                Text("GUIDA INDICATIVA · TOCCA SULL’IPHONE")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.yellow)
                    .padding(7).background(.black.opacity(0.8), in: Capsule())
                    .position(x: rect.midX, y: rect.minY + max(60, rect.height * 0.10))
            } else if rect.width > 0 {
                Text("Guida tastierino: porta l’iPhone in verticale")
                    .font(.caption).foregroundStyle(.yellow).padding(8)
                    .background(.black.opacity(0.8), in: Capsule())
                    .position(x: rect.midX, y: rect.midY)
            }
        }
        .opacity(opacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
struct KeypadGuideSettings: View {
    @Binding var centerX: Double
    @Binding var top: Double
    @Binding var columnGap: Double
    @Binding var rowGap: Double
    @Binding var diameter: Double
    @Binding var opacity: Double
    let close: () -> Void
    let hide: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Guida tastierino", systemImage: "circle.grid.3x3").font(.headline)
            Text("Schema numerico standard da allineare manualmente. Posizioni indicative, non rilevate dall’iPhone.")
                .font(.caption).foregroundStyle(.secondary)
            adjustment("Posizione orizzontale", value: $centerX, range: 0.4...0.6)
            adjustment("Posizione verticale", value: $top, range: 0.32...0.58)
            adjustment("Distanza colonne", value: $columnGap, range: 0.18...0.30)
            adjustment("Distanza righe", value: $rowGap, range: 0.075...0.13)
            adjustment("Dimensione cerchi", value: $diameter, range: 0.12...0.22)
            adjustment("Opacità", value: $opacity, range: 0.35...1)
            Text("Clic e digitazione remoti sono sospesi. Inserisci il codice con il touch fisico; la guida non verifica l’allineamento e non inserisce cifre.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Ripristina griglia") {
                    centerX = 0.5; top = 0.48; columnGap = 0.26; rowGap = 0.11
                    diameter = 0.18; opacity = 0.8
                }
                Button("Chiudi pannello", action: close)
            }
            Button("Nascondi guida e riprendi controllo", action: hide)
        }.padding(18).frame(width: 300)
    }
    private func adjustment(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption)
            Slider(value: value, in: range)
        }
    }
}
