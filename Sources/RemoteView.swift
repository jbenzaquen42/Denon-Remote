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

    var body: some View {
        NavigationStack {
            List {
                Section {
                    StatusBar()
                }

                Section {
                    VStack(spacing: 14) {
                        HStack {
                            Button {
                                r.send(r.v["ZM"] == "ON" ? "ZMOFF" : "ZMON")
                            } label: {
                                Image(systemName: "power")
                                    .font(.title2)
                                    .foregroundStyle(r.v["ZM"] == "ON" ? Color.green : Color.red)
                            }
                            .buttonStyle(.borderless)
                            Spacer()
                            VStack(spacing: 0) {
                                Text(volumeText)
                                    .font(.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit())
                                Text(r.v["MU"] == "ON" ? "MUTED" : "Volume")
                                    .font(.caption)
                                    .foregroundStyle(r.v["MU"] == "ON" ? Color.orange : Color.secondary)
                            }
                            Spacer()
                            Button {
                                r.send(r.v["MU"] == "ON" ? "MUOFF" : "MUON")
                            } label: {
                                Image(systemName: r.v["MU"] == "ON" ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .font(.title2)
                            }
                            .buttonStyle(.borderless)
                        }
                        HStack(spacing: 14) {
                            Button { r.send("MVDOWN") } label: {
                                Image(systemName: "minus.circle.fill").font(.largeTitle)
                            }
                            .buttonStyle(.borderless)
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
                            Button { r.send("MVUP") } label: {
                                Image(systemName: "plus.circle.fill").font(.largeTitle)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Input") {
                    let visible = r.sources.filter { r.v["SSSOD" + $0] != "DEL" }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                        ForEach(visible + ["TUNER", "NET", "BT"], id: \.self) { code in
                            Button {
                                r.send("SI" + code)
                            } label: {
                                Text(r.sourceName(code))
                                    .font(.subheadline)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(
                                        RoundedRectangle(cornerRadius: 9)
                                            .fill(r.v["SI"] == code ? Color.accentColor : Color.gray.opacity(0.25))
                                    )
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Sound mode") {
                    InfoRow(title: "Now playing as", value: r.v["MS"] ?? "—")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                        ForEach(modes, id: \.1) { mode in
                            Button {
                                r.send(mode.1)
                            } label: {
                                Text(mode.0)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(RoundedRectangle(cornerRadius: 9).fill(Color.gray.opacity(0.25)))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Quick select") {
                    HStack(spacing: 8) {
                        ForEach(1...4, id: \.self) { n in
                            Button {
                                r.send("MSQUICK\(n)")
                            } label: {
                                Text("\(n)")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(RoundedRectangle(cornerRadius: 9).fill(Color.gray.opacity(0.25)))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                Section("Navigation") {
                    VStack(spacing: 10) {
                        padButton("chevron.up", "MNCUP")
                        HStack(spacing: 10) {
                            padButton("chevron.left", "MNCLT")
                            Button { r.send("MNENT") } label: {
                                Text("OK")
                                    .font(.headline)
                                    .frame(width: 64, height: 52)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.borderless)
                            padButton("chevron.right", "MNCRT")
                        }
                        padButton("chevron.down", "MNCDN")
                        HStack(spacing: 10) {
                            textButton("Back", "MNRTN")
                            textButton("Option", "MNOPT")
                            textButton("Info", "MNINF")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }

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
            .navigationTitle(r.v["NSFRN"] ?? "Denon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        r.send(r.v["PW"] == "ON" ? "PWSTANDBY" : "PWON")
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

    private var volumeText: String {
        if let d = dragging { return Receiver.formatDB(d - 80) }
        return Receiver.formatDB(r.volumeDB)
    }

    private func padButton(_ icon: String, _ cmd: String) -> some View {
        Button { r.send(cmd) } label: {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 64, height: 52)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.25)))
                .foregroundStyle(.white)
        }
        .buttonStyle(.borderless)
    }

    private func textButton(_ title: String, _ cmd: String) -> some View {
        Button { r.send(cmd) } label: {
            Text(title)
                .font(.subheadline)
                .frame(width: 80, height: 40)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.25)))
                .foregroundStyle(.white)
        }
        .buttonStyle(.borderless)
    }
}

struct SettingsSheet: View {
    @EnvironmentObject var r: Receiver
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""

    var body: some View {
        NavigationStack {
            Form {
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
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { address = r.host }
        }
    }
}
