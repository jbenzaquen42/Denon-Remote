import SwiftUI

struct SignalView: View {
    @EnvironmentObject var r: Receiver

    /// Bit order of the receiver's active-speaker report, inferred from this receiver's
    /// own layout (5.2 + front heights lights exactly these positions).
    private let speakerBits = ["FL", "FR", "C", "SW", "SL", "SR", "SBL", "SBR", "SB", "FHL", "FHR"]

    /// Where each speaker sits in the room sketch (0–1 across, 0–1 front to back).
    private let positions: [String: CGPoint] = [
        "FHL": CGPoint(x: 0.10, y: 0.10), "FL": CGPoint(x: 0.28, y: 0.12),
        "C": CGPoint(x: 0.50, y: 0.10),
        "FR": CGPoint(x: 0.72, y: 0.12), "FHR": CGPoint(x: 0.90, y: 0.10),
        "SW": CGPoint(x: 0.38, y: 0.30), "SW2": CGPoint(x: 0.62, y: 0.30),
        "SL": CGPoint(x: 0.10, y: 0.62), "SR": CGPoint(x: 0.90, y: 0.62),
        "SBL": CGPoint(x: 0.32, y: 0.90), "SB": CGPoint(x: 0.50, y: 0.90),
        "SBR": CGPoint(x: 0.68, y: 0.90),
        "TFL": CGPoint(x: 0.30, y: 0.40), "TFR": CGPoint(x: 0.70, y: 0.40),
        "TML": CGPoint(x: 0.30, y: 0.62), "TMR": CGPoint(x: 0.70, y: 0.62)
    ]

    var body: some View {
        NavigationStack {
            List {
                Group {
                    StatusSection()

                    Section {
                        flowCard(
                            icon: "arrow.down.to.line",
                            title: r.v["SI"].map { r.sourceName($0) } ?? "—",
                            badge: r.v["SYSDA"]
                        )
                        InfoRow(title: "Connection", value: r.v["SD"] ?? "—")
                        InfoRow(title: "Sample rate", value: sampleRate)
                        InfoRow(title: "Input channels", value: inputChannels)
                        InfoRow(title: "Video in", value: r.v["SSINFSIGRESI"] ?? "—")
                        InfoRow(title: "Signal code (raw)", value: r.v["SSINFAISSIG"] ?? "—")
                    } header: {
                        Text("Coming in")
                    }

                    Section {
                        flowCard(
                            icon: "arrow.up.forward",
                            title: (r.v["MS"] ?? "—").capitalized,
                            badge: r.v["SYSMI"]
                        )
                        InfoRow(title: "Volume", value: Receiver.formatDB(r.volumeDB))
                        InfoRow(title: "Room correction", value: r.v["PSMULTEQ:"] ?? "—")
                        InfoRow(title: "Dynamic EQ", value: r.v["PSDYNEQ"] ?? "—")
                        InfoRow(title: "Video out", value: r.v["SSINFSIGRESO"] ?? "—")
                    } header: {
                        Text("Going out")
                    }

                    Section {
                        room
                            .frame(height: 250)
                            .padding(.vertical, 6)
                    } header: {
                        Text("Speakers playing now")
                    } footer: {
                        Text("Lit speakers are being fed in the current mode. Both subwoofers share one flag.")
                    }
                }
                .listRowBackground(Theme.card)
            }
            .themedList()
            .navigationTitle("Signal")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func flowCard(icon: String, title: String, badge: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Theme.accent.opacity(0.16)))
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            if let badge = badge, !badge.isEmpty {
                Badge(text: badge)
            }
        }
        .padding(.vertical, 4)
    }

    private var room: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                Image(systemName: "sofa.fill")
                    .font(.title2)
                    .foregroundStyle(Color.white.opacity(0.25))
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.64)
                ForEach(r.channels, id: \.self) { ch in
                    if let p = positions[ch] {
                        speaker(ch, active: isActive(ch))
                            .position(x: geo.size.width * p.x, y: geo.size.height * p.y)
                    }
                }
            }
        }
    }

    private func speaker(_ name: String, active: Bool) -> some View {
        Text(name)
            .font(.caption.weight(.bold))
            .frame(width: 46, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(active ? AnyShapeStyle(Theme.glow) : AnyShapeStyle(Theme.chip))
            )
            .foregroundStyle(active ? Color.black : Color.secondary)
            .shadow(color: active ? Theme.accent.opacity(0.5) : .clear, radius: 7)
    }

    private func isActive(_ ch: String) -> Bool {
        let name = ch == "SW2" ? "SW" : ch
        guard let index = speakerBits.firstIndex(of: name), let s = r.v["OPINFASP"], index < s.count else {
            return false
        }
        return s[s.index(s.startIndex, offsetBy: index)] == "1"
    }

    private var sampleRate: String {
        guard let s = r.v["SSINFAISFSV"] else { return "—" }
        return s == "NON" ? "Not reported" : s
    }

    private var inputChannels: String {
        guard let s = r.v["OPINFINS"] else { return "—" }
        return "\(s.filter { $0 == "1" }.count) flagged"
    }
}
