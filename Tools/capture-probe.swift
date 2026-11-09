import AVFoundation
import CoreMediaIO
import Foundation

var property = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices), mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal), mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
var enabled: UInt32 = 1
let status = CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &property, 0, nil, UInt32(MemoryLayout.size(ofValue: enabled)), &enabled)
print("CoreMediaIO screen source opt-in OSStatus: \(status)")
let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.external], mediaType: nil, position: .unspecified)
RunLoop.current.run(until: Date().addingTimeInterval(2))
print("Camera permission (0 notDetermined, 1 restricted, 2 denied, 3 authorized): \(AVCaptureDevice.authorizationStatus(for: .video).rawValue)")
for device in discovery.devices {
    print("\(device.localizedName) | \(device.uniqueID) | video=\(device.hasMediaType(.video)) muxed=\(device.hasMediaType(.muxed)) continuity=\(device.isContinuityCamera)")
}
print("External sources: \(discovery.devices.count)")
