import SwiftUI

struct SignalView: View {
    @EnvironmentObject var r: Receiver

    /// Bit order of the receiver's active-speaker report, inferred from this receiver's
    /// own layout (5.2 + front heights lights exactly these positions).
    private let speakerOrder = ["FL", "FR", "C", "SW", "SL", "SR", "SBL", "SBR", "SB", "FHL", "FHR"]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    StatusBar()
                }

                Section("Coming in") {
                    InfoRow(title: "Input", value: r.v["SI"].map { r.sourceName($0) } ?? "—")
                    InfoRow(title: "Connection", value: r.v["SD"] ?? "—")
                    InfoRow(title: "Audio format", value: r.v["SYSDA"] ?? "—")
                    InfoRow(title: "Sample rate", value: sampleRate)
                    InfoRow(title: "Input channels", value: inputChannels)
                    InfoRow(title: "Video in", value: r.v["SSINFSIGRESI"] ?? "—")
                    InfoRow(title: "Signal code (raw)", value: r.v["SSINFAISSIG"] ?? "—")
                }

                Section("Going out") {
                    InfoRow(title: "Sound mode", value: r.v["MS"] ?? "—")
                    InfoRow(title: "Decoder", value: r.v["SYSMI"] ?? "—")
                    InfoRow(title: "Video out", value: r.v["SSINFSIGRESO"] ?? "—")
                    InfoRow(title: "Volume", value: Receiver.formatDB(r.volumeDB))
                }

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 62), spacing: 8)], spacing: 8) {
                        ForEach(Array(speakerOrder.enumerated()), id: \.offset) { index, name in
                            let active = bit(r.v["OPINFASP"], index)
                            Text(name)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 9)
                                        .fill(active ? Color.green.opacity(0.75) : Color.gray.opacity(0.18))
                                )
                                .foregroundStyle(active ? Color.white : Color.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    InfoRow(title: "Raw", value: String((r.v["OPINFASP"] ?? "—").prefix(16)))
                } header: {
                    Text("Speakers playing now")
                } footer: {
                    Text("Green speakers are receiving signal in the current mode.")
                }
            }
            .navigationTitle("Signal")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var sampleRate: String {
        guard let s = r.v["SSINFAISFSV"] else { return "—" }
        if s == "NON" { return "Not reported" }
        return s
    }

    private var inputChannels: String {
        guard let s = r.v["OPINFINS"] else { return "—" }
        let count = s.filter { $0 == "1" }.count
        return "\(count) flagged"
    }

    private func bit(_ s: String?, _ index: Int) -> Bool {
        guard let s = s, index < s.count else { return false }
        return s[s.index(s.startIndex, offsetBy: index)] == "1"
    }
}
