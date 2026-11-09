import AppKit
for app in NSRunningApplication.runningApplications(withBundleIdentifier: "it.local.iphoneremote") {
    print("Normal quit requested:", app.processIdentifier, app.terminate())
}
