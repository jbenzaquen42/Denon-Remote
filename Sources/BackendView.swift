import SwiftUI

/// What the calibration has written into the receiver (read-only) plus a live wire log,
/// so changes pushed by Evo32 or any other tool show up as they happen.
struct BackendView: View {
    @EnvironmentObject var r: Receiver
    @State private var page = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $page) {
                    Text("Calibration").tag(0)
                    Text("Live log").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                if page == 0 {
                    CalibrationList()
                } else {
                    LiveLog()
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Backend")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct CalibrationList: View {
    @EnvironmentObject var r: Receiver

    private let groups: [(String, String)] = [
        ("FRO", "Front"), ("CEN", "Center"), ("SUA", "Surround"), ("SBK", "Surround Back"),
        ("FRH", "Front Height"), ("TFR", "Top Front"), ("TPM", "Top Middle"),
        ("FRD", "Front Dolby"), ("SUD", "Surround Dolby")
    ]

    var body: some View {
        List {
            Group {
            StatusSection()

            Section {
                ForEach(r.channels, id: \.self) { ch in
                    InfoRow(title: Receiver.channelName(ch), value: Receiver.formatDB(r.trimDB("SSLEV" + ch)))
                }
            } header: {
                Text("Calibrated speaker trims")
            } footer: {
                Text("Read-only. These are the levels the calibration stored; the app re-reads them every few seconds and logs any change.")
            }

            Section("Speaker setup and crossovers") {
                ForEach(present, id: \.0) { group in
                    InfoRow(title: group.1, value: describe(group.0))
                }
                InfoRow(title: "Subwoofers", value: subText)
                InfoRow(title: "Subwoofer mode", value: r.v["SSSWM"] ?? "—")
            }

            Section {
                Text("Speaker distances are deliberately not read, shown or changeable anywhere in this app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            }
            .listRowBackground(Theme.card)
        }
        .themedList()
    }

    private var present: [(String, String)] {
        groups.filter { g in
            guard let s = r.v["SSSPC" + g.0] else { return false }
            return s != "NON"
        }
    }

    private func describe(_ code: String) -> String {
        let size: String
        let raw = r.v["SSSPC" + code] ?? ""
        switch raw {
        case "SMA": size = "Small"
        case "LAR": size = "Large"
        case "1SP": size = "1 speaker"
        case "2SP": size = "2 speakers"
        case "": size = "—"
        default: size = raw
        }
        if let x = r.v["SSCFR" + code], let hz = Int(x) {
            return "\(size) · \(hz) Hz"
        }
        return size
    }

    private var subText: String {
        let raw = r.v["SSSPCSWF"] ?? ""
        switch raw {
        case "2SP": return "2"
        case "1SP": return "1"
        case "NON": return "None"
        case "": return "—"
        default: return raw
        }
    }
}

private struct LiveLog: View {
    @EnvironmentObject var r: Receiver
    @State private var changesOnly = false
    @State private var command = ""

    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Toggle("Changes only", isOn: $changesOnly)
                    .font(.footnote)
                Button("Clear") { r.log.removeAll() }
                    .font(.footnote)
                    .padding(.leading, 12)
            }
            .padding(.horizontal)
            .padding(.bottom, 6)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        ForEach(shown) { line in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(LiveLog.clock.string(from: line.time))
                                    .foregroundStyle(.secondary)
                                Text(arrow(line.kind))
                                    .foregroundStyle(color(line.kind))
                                Text(line.text)
                                    .foregroundStyle(color(line.kind))
                                if let note = line.note {
                                    Text(note).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .font(.caption.monospaced())
                            .id(line.id)
                        }
                    }
                    .padding(.horizontal)
                }
                .onChange(of: r.log.count) { _ in
                    if let last = shown.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }

            Divider()
            HStack {
                TextField("Command, e.g. MV?", text: $command)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.body.monospaced())
                    .onSubmit(sendCommand)
                Button("Send", action: sendCommand)
                    .disabled(command.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var shown: [LogLine] {
        changesOnly ? r.log.filter { $0.kind == .changed || $0.kind == .blocked } : r.log
    }

    private func sendCommand() {
        let c = command.trimmingCharacters(in: .whitespaces)
        guard !c.isEmpty else { return }
        r.send(c)
        command = ""
    }

    private func arrow(_ kind: LogLine.Kind) -> String {
        switch kind {
        case .sent: return "→"
        case .received: return "←"
        case .changed: return "Δ"
        case .blocked: return "✕"
        }
    }

    private func color(_ kind: LogLine.Kind) -> Color {
        switch kind {
        case .sent: return Color(red: 0.45, green: 0.72, blue: 1.0)
        case .received: return .primary
        case .changed: return Theme.accent
        case .blocked: return Theme.warn
        }
    }
}
