import XCTest
@testable import RemoteCore

final class KeypadGuideGeometryTests: XCTestCase {
    func testReferenceContainsTenDistinctDigitsWithZeroBelowMiddleColumn() {
        let keys = KeypadGuideGeometry.keys()
        XCTAssertEqual(Set(keys.map(\.digit)), Set((0...9).map(String.init)))
        let zero = keys.first { $0.digit == "0" }!
        let eight = keys.first { $0.digit == "8" }!
        XCTAssertEqual(zero.center.x, eight.center.x)
        XCTAssertGreaterThan(zero.center.y, eight.center.y)
        XCTAssertEqual(Set(keys.map { "\($0.center.x),\($0.center.y)" }).count, 10)
    }
    func testStoredInvalidOrExtremeCalibrationStaysFiniteAndInsideImage() {
        for value in [Double.nan, .infinity, -.infinity, -1000, 1000] {
            let keys = KeypadGuideGeometry.keys(centerX: value, top: value, columnGap: value, rowGap: value)
            for key in keys {
                XCTAssertTrue(key.center.x.isFinite && key.center.y.isFinite)
                XCTAssertTrue((0...1).contains(key.center.x) && (0...1).contains(key.center.y))
            }
        }
    }
    func testGuideFollowsVideoAspectFitRatherThanWindowCorners() {
        let rect = ScreenGeometry.fittedRect(image: CGSize(width: 1180, height: 2556),
                                            bounds: CGRect(x: 0, y: 0, width: 900, height: 700))
        let key = KeypadGuideGeometry.keys().first { $0.digit == "5" }!
        let point = CGPoint(x: rect.minX + key.center.x * rect.width,
                            y: rect.minY + key.center.y * rect.height)
        let normalized = ScreenGeometry.normalized(point, in: rect)!
        XCTAssertEqual(normalized.x, key.center.x, accuracy: 0.0001)
        XCTAssertEqual(normalized.y, key.center.y, accuracy: 0.0001)
        XCTAssertGreaterThan(rect.minX, 0)
    }
}
