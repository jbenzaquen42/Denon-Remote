import SwiftUI

struct LevelsView: View {
    @EnvironmentObject var r: Receiver

    var body: some View {
        NavigationStack {
            List {
                Group {
                StatusSection()

                Section {
                    ToggleRow(title: "Dialog level adjust", key: "PSDIL#", on: "PSDIL ON", off: "PSDIL OFF")
                    StepRow(
                        title: "Dialog level",
                        value: Receiver.formatDB(r.trimDB("PSDIL")),
                        detail: r.isOn("PSDIL#") ? nil : "Adjust is off — value is stored but not applied",
                        minus: { r.send("PSDIL DOWN") },
                        plus: { r.send("PSDIL UP") }
                    )
                } header: {
                    Text("Dialog")
                } footer: {
                    Text("Shows the value the receiver is actually holding, not a fresh zero.")
                }

                Section {
                    ToggleRow(title: "Subwoofer level adjust", key: "PSSWL#", on: "PSSWL ON", off: "PSSWL OFF")
                    StepRow(
                        title: "Subwoofer 1",
                        value: Receiver.formatDB(r.trimDB("PSSWL")),
                        minus: { r.send("PSSWL DOWN") },
                        plus: { r.send("PSSWL UP") }
                    )
                    if r.v["PSSWL2"] != nil {
                        StepRow(
                            title: "Subwoofer 2",
                            value: Receiver.formatDB(r.trimDB("PSSWL2")),
                            minus: { r.send("PSSWL2 DOWN") },
                            plus: { r.send("PSSWL2 UP") }
                        )
                    }
                    StepRow(
                        title: "LFE level",
                        value: lfeText,
                        detail: "Attenuation of the LFE track",
                        minus: { stepLFE(by: 1) },
                        plus: { stepLFE(by: -1) }
                    )
                } header: {
                    Text("Subwoofers")
                }

                Section {
                    if r.channels.isEmpty {
                        Text("No channels reported yet").foregroundStyle(.secondary)
                    }
                    ForEach(r.channels, id: \.self) { ch in
                        StepRow(
                            title: Receiver.channelName(ch),
                            value: Receiver.formatDB(r.trimDB("CV" + ch)),
                            minus: { r.send("CV\(ch) DOWN") },
                            plus: { r.send("CV\(ch) UP") }
                        )
                    }
                } header: {
                    Text("Channel level adjust (this input)")
                } footer: {
                    Text("These are the per-source offsets on top of the calibrated trims. The calibrated trims themselves are on the Backend tab and are read-only.")
                }

                Section("Tone") {
                    ToggleRow(title: "Tone control", key: "PSTONE CTRL", on: "PSTONE CTRL ON", off: "PSTONE CTRL OFF")
                    StepRow(
                        title: "Bass",
                        value: Receiver.formatDB(r.trimDB("PSBAS")),
                        minus: { r.send("PSBAS DOWN") },
                        plus: { r.send("PSBAS UP") }
                    )
                    StepRow(
                        title: "Treble",
                        value: Receiver.formatDB(r.trimDB("PSTRE")),
                        minus: { r.send("PSTRE DOWN") },
                        plus: { r.send("PSTRE UP") }
                    )
                }
                }
                .listRowBackground(Theme.card)
            }
            .themedList()
            .navigationTitle("Levels")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var lfeText: String {
        guard let s = r.v["PSLFE"], let n = Int(s) else { return "—" }
        return n == 0 ? "0 dB" : "-\(n) dB"
    }

    /// PSLFE is attenuation in dB, 00 (none) to 10.
    private func stepLFE(by delta: Int) {
        guard let s = r.v["PSLFE"], let n = Int(s) else { return }
        let next = max(0, min(10, n + delta))
        if next != n { r.send(String(format: "PSLFE %02d", next)) }
    }
}
