import CoreGraphics

/// A user-aligned reference grid, never a reconstruction of a protected iOS view.
public enum KeypadGuideGeometry {
    public struct Key: Identifiable {
        public let digit: String
        public let center: CGPoint
        public var id: String { digit }
    }
    public static func keys(centerX: Double = 0.5, top: Double = 0.48,
                            columnGap: Double = 0.26, rowGap: Double = 0.11) -> [Key] {
        let x = bounded(centerX, 0.4...0.6, fallback: 0.5)
        let y = bounded(top, 0.32...0.58, fallback: 0.48)
        let dx = bounded(columnGap, 0.18...0.30, fallback: 0.26)
        let dy = bounded(rowGap, 0.075...0.13, fallback: 0.11)
        var result: [Key] = []
        for value in 1...9 {
            let column: Int = (value - 1) % 3 - 1
            let row: Int = (value - 1) / 3
            let point = CGPoint(x: CGFloat(x + Double(column) * dx), y: CGFloat(y + Double(row) * dy))
            result.append(Key(digit: String(value), center: point))
        }
        result.append(Key(digit: "0", center: CGPoint(x: CGFloat(x), y: CGFloat(y + 3 * dy))))
        return result
    }
    private static func bounded(_ value: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
        value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : fallback
    }
}
