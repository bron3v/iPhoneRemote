import Foundation
import Combine
import IOKit

struct USBPhone: Identifiable {
    let id: String
    let name: String
}

final class DeviceMonitor: ObservableObject {
    @Published private(set) var devices: [USBPhone] = []
    private var timer: Timer?
    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
    }
    deinit { timer?.invalidate() }
    func refresh() {
        // IOUSBHostDevice checks the physical bus, unlike paired/network devicectl records.
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOUSBHostDevice"), &iterator) == KERN_SUCCESS else { return }
        defer { IOObjectRelease(iterator) }
        var result: [USBPhone] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            func property(_ key: String) -> Any? { IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() }
            let name = property("USB Product Name") as? String ?? ""
            guard name.localizedCaseInsensitiveContains("iPhone"), (property("idVendor") as? NSNumber)?.intValue == 0x05ac else { continue }
            let serial = property("USB Serial Number") as? String ?? ""
            // Registry entry ID gives a stable UI identifier if the serial is unavailable.
            var registryID: UInt64 = 0
            IORegistryEntryGetRegistryEntryID(service, &registryID)
            result.append(USBPhone(id: serial.isEmpty ? String(registryID) : serial, name: name))
        }
        devices = result
    }
}
