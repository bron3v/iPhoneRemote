import XCTest
@testable import RemoteCore

final class NavigationOverlayGeometryTests: XCTestCase {
    func testPortraitPillsStayOverStatusZonesAndLeaveTheCenterClear() {
        let bounds = CGRect(x: 0, y: 0, width: 393, height: 852)
        let layout = NavigationOverlayGeometry.layout(image: bounds.size, bounds: bounds)
        XCTAssertLessThan(layout.notifications.midX, bounds.width * 0.3)
        XCTAssertGreaterThan(layout.controlCenter.midX, bounds.width * 0.7)
        XCTAssertLessThan(layout.notifications.maxY, bounds.height * 0.025)
        XCTAssertGreaterThan(layout.notifications.width / layout.notifications.height, 3)
        XCTAssertEqual(layout.home.midX, bounds.midX, accuracy: 0.001)
        XCTAssertGreaterThan(layout.home.midY, bounds.height * 0.95)
        let center = CGRect(x: bounds.width * 0.33, y: 0, width: bounds.width * 0.34, height: 60)
        XCTAssertFalse(layout.notifications.intersects(center))
        XCTAssertFalse(layout.controlCenter.intersects(center))
    }
    func testControlsFollowTheVideoAndStayThinAtDifferentWindowSizes() {
        for bounds in [CGRect(x: 0, y: 0, width: 1000, height: 700), CGRect(x: 0, y: 0, width: 240, height: 520)] {
            let image = CGSize(width: 1180, height: 2556)
            let rect = ScreenGeometry.fittedRect(image: image, bounds: bounds)
            for scale in [0.75, 1.0, 1.6, Double.nan] {
                let layout = NavigationOverlayGeometry.layout(image: image, bounds: bounds, scale: scale)
                for pill in [layout.notifications, layout.controlCenter, layout.home] {
                    XCTAssertTrue(rect.contains(pill))
                    XCTAssertLessThanOrEqual(pill.height, 24)
                    XCTAssertGreaterThan(pill.width, pill.height * 2)
                }
                XCTAssertEqual(layout.home.midX, rect.midX, accuracy: 0.001)
            }
        }
    }
    func testMissingVideoDoesNotProduceFloatingControls() {
        let layout = NavigationOverlayGeometry.layout(image: .zero, bounds: CGRect(x: 0, y: 0, width: 400, height: 800))
        XCTAssertEqual(layout.notifications, .zero)
        XCTAssertEqual(layout.home, .zero)
    }
}
