import CoreGraphics
import XCTest
@testable import RemoteCore

final class ScreenGeometryTests: XCTestCase {
    func testLetterboxClicksAreRejectedAndCenterMapsCorrectly() {
        let rect = ScreenGeometry.fittedRect(image: CGSize(width: 1179, height: 2556), bounds: CGRect(x: 0, y: 0, width: 800, height: 600))
        XCTAssertEqual(rect.height, 600, accuracy: 0.001)
        XCTAssertNil(ScreenGeometry.normalized(CGPoint(x: 20, y: 300), in: rect))
        let point = ScreenGeometry.normalized(CGPoint(x: 400, y: 300), in: rect)!
        XCTAssertEqual(point.x, 0.5, accuracy: 0.0001)
        XCTAssertEqual(point.y, 0.5, accuracy: 0.0001)
    }
    func testLandscapeMappingUsesDevicePointsRatherThanVideoPixels() {
        let rect = ScreenGeometry.fittedRect(image: CGSize(width: 2556, height: 1179), bounds: CGRect(x: 10, y: 30, width: 600, height: 600))
        let normalized = ScreenGeometry.normalized(CGPoint(x: rect.minX + rect.width/4, y: rect.minY + rect.height/4), in: rect)!
        let point = ScreenGeometry.devicePoint(normalized, size: CGSize(width: 852, height: 393))
        XCTAssertEqual(point.x, 212.75, accuracy: 0.0001)
        XCTAssertEqual(point.y, 98, accuracy: 0.0001)
    }
    func testClampingAndInvalidBounds() {
        XCTAssertEqual(ScreenGeometry.fittedRect(image: .zero, bounds: CGRect(x: 0, y: 0, width: 200, height: 400)), .zero)
        XCTAssertNil(ScreenGeometry.normalized(.zero, in: .zero))
        XCTAssertEqual(ScreenGeometry.devicePoint(CGPoint(x: -1, y: 2), size: CGSize(width: 393, height: 852)), CGPoint(x: 0, y: 851))
    }
}
