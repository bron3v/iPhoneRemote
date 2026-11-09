import Foundation
import CoreGraphics

/// Uses the production client. --home optionally checks the Home command.
@main struct LiveProbe {
    static func main() async {
        let client = WDAClient()
        do {
            let size = try await client.connect()
            print("Production Swift client connected: \(Int(size.width)) x \(Int(size.height)) iOS points")
            if CommandLine.arguments.contains("--home") {
                try await client.home()
                print("Production Swift Home command completed")
            }
            await client.disconnect()
        } catch {
            print("Live check failed: \(error.localizedDescription)")
            await client.disconnect()
            exit(1)
        }
    }
}
