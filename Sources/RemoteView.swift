import SwiftUI

struct RemoteView: View {
    @EnvironmentObject var r: Receiver
    @State private var dragging: Double? = nil
    @State private var showSettings = false

    /// The slider stops at -10 dB so a slipped thumb can't blast the room; + goes higher.
    private let sliderMax: Double = 70

    private let modes: [(String, String)] = [
        ("Movie", "MSMOVIE"), ("Music", "MSMUSIC"), ("Game", "MSGAME"),
        ("Auto", "MSAUTO"), ("Direct", "MSDIRECT"), ("Pure Direct", "MSPURE DIRECT"),
        ("Stereo", "MSSTEREO"), ("Multi Ch Stereo", "MSMCH STEREO"),
        ("Dolby", "MSDOLBY DIGITAL"), ("DTS", "MSDTS SURROUND")
    ]

    private let grid = [GridItem(.adaptive(minimum: 98), spacing: 8)]

    var body: some View {
        NavigationStack {
            List {
                Group {
                    StatusSection()
                    heroSection
                    inputSection
                    modeSection
                    quickSection
                    navigationSection
                    zone2Section
                }
                .listRowBackground(Theme.card)
            }
            .themedList()
            .navigationTitle(r.v["NSFRN"] ?? "Denon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        act(r.v["PW"] == "ON" ? "PWSTANDBY" : "PWON")
                    } label: {
                        Text(r.v["PW"] == "ON" ? "Standby" : "Wake")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
            }
        }
    }

    // MARK: - Sections

    private var heroSection: some View {
        Section {
            VStack(spacing: 16) {
                HStack(alignment: .top) {
                    Button {
                        act(zoneOn ? "ZMOFF" : "ZMON")
                    } label: {
                        Image(systemName: "power")
                    }
                    .buttonStyle(RoundKeyStyle(
                        size: 50,
                        fill: AnyShapeStyle(zoneOn ? Theme.live.opacity(0.18) : Theme.warn.opacity(0.18)),
                        foreground: zoneOn ? Theme.live : Theme.warn
                    ))
                    Spacer()
                    VolumeDial(
                        fraction: dialFraction,
                        text: volumeText,
                        caption: muted ? "MUTED" : "Volume",
                        muted: muted
                    )
                    Spacer()
                    Button {
                        act(muted ? "MUOFF" : "MUON")
                    } label: {
                        Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    }
                    .buttonStyle(RoundKeyStyle(
                        size: 50,
                        fill: AnyShapeStyle(muted ? Theme.warn.opacity(0.18) : Theme.chip),
                        foreground: muted ? Theme.warn : .white
                    ))
                }

                VStack(spacing: 8) {
                    Text(r.v["SI"].map { r.sourceName($0) } ?? "—")
                        .font(.title3.weight(.semibold))
                    HStack(spacing: 6) {
                        if let format = r.v["SYSDA"], !format.isEmpty {
                            Badge(text: format)
                        }
                        if let mode = r.v["MS"], !mode.isEmpty {
                            Badge(text: mode.capitalized, color: .white.opacity(0.75))
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button { act("MVDOWN") } label: { Image(systemName: "minus") }
                        .buttonStyle(RoundKeyStyle(size: 48))
                    Slider(
                        value: Binding(
                            get: { dragging ?? min(Receiver.number(r.v["MV"]) ?? 0, sliderMax) },
                            set: { dragging = $0 }
                        ),
                        in: 0...sliderMax,
                        step: 0.5,
                        onEditingChanged: { editing in
                            if !editing, let d = dragging {
                                r.setVolume(raw: d)
                                dragging = nil
                            }
                        }
                    )
                    Button { act("MVUP") } label: { Image(systemName: "plus") }
                        .buttonStyle(RoundKeyStyle(size: 48))
                }
            }
            .padding(.vertical, 10)
        }
    }

    private var inputSection: some View {
        Section("Input") {
            LazyVGrid(columns: grid, spacing: 8) {
                ForEach(inputCodes, id: \.self) { code in
                    Button(r.sourceName(code)) { act("SI" + code) }
                        .buttonStyle(ChipStyle(selected: r.v["SI"] == code))
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var modeSection: some View {
        Section("Sound mode") {
            LazyVGrid(columns: grid, spacing: 8) {
                ForEach(modes, id: \.1) { mode in
                    Button(mode.0) { act(mode.1) }
                        .buttonStyle(ChipStyle())
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var quickSection: some View {
        Section("Quick select") {
            HStack(spacing: 8) {
                ForEach(1...4, id: \.self) { n in
                    Button("\(n)") { act("MSQUICK\(n)") }
                        .buttonStyle(ChipStyle())
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var navigationSection: some View {
        Section("Navigation") {
            VStack(spacing: 10) {
                key("chevron.up", "MNCUP")
                HStack(spacing: 22) {
                    key("chevron.left", "MNCLT")
                    Button { act("MNENT") } label: { Text("OK").font(.headline) }
                        .buttonStyle(RoundKeyStyle(size: 66, fill: AnyShapeStyle(Theme.glow), foreground: .black))
                    key("chevron.right", "MNCRT")
                }
                key("chevron.down", "MNCDN")
                HStack(spacing: 8) {
                    Button("Back") { act("MNRTN") }.buttonStyle(ChipStyle())
                    Button("Option") { act("MNOPT") }.buttonStyle(ChipStyle())
                    Button("Info") { act("MNINF") }.buttonStyle(ChipStyle())
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private var zone2Section: some View {
        Section("Zone 2") {
            Toggle("Power", isOn: Binding(
                get: { r.v["Z2"] == "ON" },
                set: { r.send($0 ? "Z2ON" : "Z2OFF") }
            ))
            StepRow(
                title: "Volume",
                value: r.v["Z2VOL"] ?? "—",
                minus: { r.send("Z2DOWN") },
                plus: { r.send("Z2UP") }
            )
            Toggle("Mute", isOn: Binding(
                get: { r.v["Z2MU"] == "ON" },
                set: { r.send($0 ? "Z2MUON" : "Z2MUOFF") }
            ))
        }
    }

    // MARK: - Helpers

    private var zoneOn: Bool { r.v["ZM"] == "ON" }
    private var muted: Bool { r.v["MU"] == "ON" }

    private var inputCodes: [String] {
        r.sources.filter { r.v["SSSOD" + $0] != "DEL" } + ["TUNER", "NET", "BT"]
    }

    private var currentRaw: Double {
        dragging ?? (Receiver.number(r.v["MV"]) ?? 0)
    }

    /// Full ring at 0 dB (raw 80).
    private var dialFraction: Double { currentRaw / 80 }

    private var volumeText: String {
        if dragging == nil && r.v["MV"] == nil { return "—" }
        return Receiver.formatDB(currentRaw - 80)
    }

    private func act(_ cmd: String) {
        Haptics.tap()
        r.send(cmd)
    }

    private func key(_ icon: String, _ cmd: String) -> some View {
        Button { act(cmd) } label: { Image(systemName: icon) }
            .buttonStyle(RoundKeyStyle(size: 56))
    }
}

struct SettingsSheet: View {
    @EnvironmentObject var r: Receiver
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section {
                        TextField("10.0.0.7", text: $address)
                            .keyboardType(.numbersAndPunctuation)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } header: {
                        Text("Receiver address")
                    } footer: {
                        Text("The phone must be on the same network as the receiver.")
                    }
                    Section {
                        Button("Save and reconnect") {
                            r.host = address.trimmingCharacters(in: .whitespaces)
                            r.connect()
                            dismiss()
                        }
                        Button("Re-read everything from receiver") {
                            r.refreshAll()
                            dismiss()
                        }
                    }
                    Section("Receiver") {
                        InfoRow(title: "Name", value: r.v["NSFRN"] ?? "—")
                        InfoRow(title: "Firmware", value: r.v["SSINFFRMAVR"] ?? "—")
                        InfoRow(title: "Link", value: r.status.label)
                    }
                }
                .listRowBackground(Theme.card)
            }
            .themedList()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { address = r.host }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
    }
}
