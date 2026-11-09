import CoreGraphics
import Foundation

public enum ScreenGeometry {
    public static func fittedRect(image: CGSize, bounds: CGRect) -> CGRect {
        guard image.width > 0, image.height > 0, bounds.width > 0, bounds.height > 0 else { return .zero }
        let scale = min(bounds.width / image.width, bounds.height / image.height)
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
    }

    /// AppKit view must use flipped coordinates. Letterbox clicks are rejected.
    public static func normalized(_ point: CGPoint, in rect: CGRect) -> CGPoint? {
        guard rect.width > 0, rect.height > 0, rect.contains(point) else { return nil }
        return CGPoint(x: (point.x - rect.minX) / rect.width, y: (point.y - rect.minY) / rect.height)
    }

    public static func devicePoint(_ point: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(x: min(max(point.x, 0), 1) * max(size.width - 1, 0),
                y: min(max(point.y, 0), 1) * max(size.height - 1, 0))
    }
}
