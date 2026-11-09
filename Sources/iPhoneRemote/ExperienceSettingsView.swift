import SwiftUI
import AppKit

struct ExperienceSettingsView: View {
    @ObservedObject var remote: RemoteModel
    @ObservedObject var automation: LocalAutomation
    @ObservedObject var archive: CaptureArchive
    @ObservedObject var shortcuts: Shortcuts
    @Binding var compact: Bool
    @Binding var onTop: Bool
    @Binding var buttonSize: Double
    @Binding var buttonOpacity: Double
    @Binding var folderPath: String
    @Binding var autoReconnect: Bool
    let videoReady: Bool
    let renew: () -> Void
    var folder: URL { folderPath.isEmpty ? CaptureArchive.defaultFolder : URL(fileURLWithPath: folderPath) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Label("Finestra e pulsanti", systemImage: "macwindow").font(.headline)
            Toggle("Finestra compatta", isOn: $compact)
            Toggle("Sempre in primo piano", isOn: $onTop)
            Text("Scala pillole: \(Int(buttonSize / 28 * 100))%").font(.caption)
            Slider(value: $buttonSize, in: 22...44, step: 2)
            Text("Opacità pulsanti: \(Int(buttonOpacity * 100))% ").font(.caption)
            Slider(value: $buttonOpacity, in: 0.25...1, step: 0.05)
            Toggle("Riconnessione automatica", isOn: $autoReconnect)
            Text("Dopo Scollega, usa Collega WDA per riattivare la connessione. Tocchi e testo interrotti non vengono ripetuti.")
                .font(.caption).foregroundStyle(.secondary)
            if let latency = remote.lastLatencyMS {
                Text("Ultimo comando: \(latency) ms · coda: \(remote.pendingCount)").font(.caption).foregroundStyle(.secondary)
            }
            if !remote.unconfirmedText.isEmpty {
                Text("Testo non confermato conservato in memoria. Verifica il telefono prima di reinserirlo.").font(.caption).foregroundStyle(.orange)
                HStack {
                    Button("Copia testo") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(remote.unconfirmedText, forType: .string)
                    }
                    Button("Scarta") { remote.clearUnconfirmedText() }
                }
            }
            Divider()
            Label("Screenshot e registrazioni", systemImage: "record.circle").font(.headline)
            HStack {
                Button("Screenshot") { archive.screenshot(in: folder) }.disabled(!videoReady)
                Button(archive.isRecording ? "Ferma video" : "Registra video") {
                    if archive.isRecording { archive.stop() } else { archive.start(in: folder) }
                }.disabled(archive.isFinishing || (!videoReady && !archive.isRecording))
            }
            Text(archive.message).font(.caption).textSelection(.enabled)
            Text("Solo il video dell’iPhone, senza audio e senza i pulsanti sovrapposti.").font(.caption).foregroundStyle(.secondary)
            Text(folder.path).font(.caption).lineLimit(2).truncationMode(.middle).textSelection(.enabled)
            HStack {
                Button("Scegli cartella…") { chooseFolder() }
                Button("Apri cartella") {
                    do {
                        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        NSWorkspace.shared.open(folder)
                    } catch { NSSound.beep() }
                }
            }
            if let saved = archive.lastSavedURL {
                Button("Mostra ultimo file nel Finder") { NSWorkspace.shared.activateFileViewerSelecting([saved]) }
            }
            Divider()
            Label("Scorciatoie", systemImage: "keyboard").font(.headline)
            ForEach(RemoteAction.allCases) { action in
                HStack {
                    Text(action.title).font(.caption)
                    Spacer()
                    Button(shortcuts.editing == action ? "Premi i tasti…" : shortcuts.bindings[action]?.label ?? "Assegna…") {
                        shortcuts.editing = shortcuts.editing == action ? nil : action
                    }.font(.caption.monospaced())
                }
            }
            Text(shortcuts.message).font(.caption).foregroundStyle(.secondary)
            Button("Ripristina scorciatoie") { shortcuts.reset() }.font(.caption)
            if automation.isConfigured {
                Divider()
                Label("Firma del controllo", systemImage: "checkmark.seal").font(.headline)
                if let expiry = automation.profileExpiry {
                    Text("Scadenza: \(expiry.formatted(date: .abbreviated, time: .shortened))").font(.caption)
                } else { Text("Scadenza non disponibile").font(.caption) }
                if let warning = automation.profileWarning { Text(warning).font(.caption).foregroundStyle(.orange) }
                Button(automation.renewing ? "Rinnovo in corso…" : "Tenta rinnovo firma") { renew() }
                    .disabled(automation.starting || remote.busy)
                Text("Interrompe temporaneamente il controllo e chiede a Xcode di aggiornare la firma. La nuova scadenza dipende dal provisioning Apple.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.canCreateDirectories = true; panel.allowsMultipleSelection = false
        panel.directoryURL = folder
        panel.message = "Scegli dove salvare screenshot e video dell’iPhone."
        if panel.runModal() == .OK, let url = panel.url { folderPath = url.path }
    }
}
