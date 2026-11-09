import CoreGraphics
import Foundation
let pid = Int(CommandLine.arguments[1])!
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
let own = windows.filter { ($0[kCGWindowOwnerPID as String] as? Int) == pid && ($0[kCGWindowLayer as String] as? Int) == 0 }
print("Visible normal application windows: \(own.count)")
for window in own { print("Window bounds: \(window[kCGWindowBounds as String] ?? [:])") }
if own.isEmpty { exit(1) }
