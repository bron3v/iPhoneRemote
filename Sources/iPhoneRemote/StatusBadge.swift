import SwiftUI

struct StatusBadge: View {
    @ObservedObject var remote: RemoteModel
    @ObservedObject var archive: CaptureArchive
    let videoReady: Bool
    private var label: String {
        if !videoReady { return "Video scollegato" }
        if remote.localInputSuspended { return "Guida tastierino · solo touch fisico" }
        if !remote.connected { return "Solo video" }
        if !remote.controlRequested { return "Controllo sospeso" }
        if !remote.controlEnabled { return "Controllo in attesa" }
        return remote.busy ? "Comando in corso" : "Pronto"
    }
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(remote.controlEnabled ? Color.green : Color.orange).frame(width: 6, height: 6)
            Text(label)
            if remote.pendingCount > 0 { Text("· \(remote.pendingCount) in coda") }
            if archive.isRecording {
                Circle().fill(.red).frame(width: 6, height: 6)
                if let start = archive.recordingStartedAt { Text(start, style: .timer).monospacedDigit() }
            }
            if archive.isFinishing { Text("Salvataggio…") }
        }
        .font(.system(size: 10, weight: .medium)).foregroundStyle(.white)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(.black.opacity(0.7), in: Capsule())
        .fixedSize()
    }
}
