import CoreGraphics

public enum NavigationOverlayGeometry {
    public struct Layout {
        public let notifications: CGRect
        public let controlCenter: CGRect
        public let home: CGRect
    }
    /// Status-bar zones for the portrait iPhone reference; no UI detection is implied.
    public static func layout(image: CGSize, bounds: CGRect, scale: Double = 1) -> Layout {
        let rect = ScreenGeometry.fittedRect(image: image, bounds: bounds)
        guard rect.width > 0, rect.height > 0 else {
            return Layout(notifications: .zero, controlCenter: .zero, home: .zero)
        }
        let factor = CGFloat(scale.isFinite ? min(max(scale, 0.75), 1.6) : 1)
        let baseHeight = min(max(rect.width * 0.042 * factor, 10), 24)
        // Keep the pills above, rather than covering, the portrait time/network labels.
        let height = image.height >= image.width ? min(baseHeight, rect.height * 0.019) : baseHeight
        let width = min(max(rect.width * 0.19 * factor, 40), 96, rect.width * 0.28)
        let bottomWidth = min(max(rect.width * 0.27 * factor, 56), 136, rect.width * 0.40)
        let topY = max(rect.minY + height / 2 + 3, rect.minY + rect.height * 0.0125)
        let bottomY = min(rect.maxY - height / 2 - 3, rect.minY + rect.height * 0.978)
        func frame(x: CGFloat, y: CGFloat, width: CGFloat) -> CGRect {
            CGRect(x: x - width / 2, y: y - height / 2, width: width, height: height)
        }
        return Layout(notifications: frame(x: rect.minX + rect.width * 0.155, y: topY, width: width),
                      controlCenter: frame(x: rect.minX + rect.width * 0.845, y: topY, width: width),
                      home: frame(x: rect.midX, y: bottomY, width: bottomWidth))
    }
}
