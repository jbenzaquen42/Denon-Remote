import SwiftUI

struct SoundView: View {
    @EnvironmentObject var r: Receiver

    var body: some View {
        NavigationStack {
            List {
                Section {
                    StatusBar()
                }

                Section("Audyssey") {
                    PickRow(title: "MultEQ", key: "PSMULTEQ:", choices: [
                        Choice(label: "Reference", value: "AUDYSSEY", command: "PSMULTEQ:AUDYSSEY"),
                        Choice(label: "L/R Bypass", value: "BYP.LR", command: "PSMULTEQ:BYP.LR"),
                        Choice(label: "Flat", value: "FLAT", command: "PSMULTEQ:FLAT"),
                        Choice(label: "Off", value: "OFF", command: "PSMULTEQ:OFF")
                    ])
                    ToggleRow(title: "Dynamic EQ", key: "PSDYNEQ", on: "PSDYNEQ ON", off: "PSDYNEQ OFF")
                    PickRow(title: "Reference level offset", key: "PSREFLEV", choices: [
                        Choice(label: "0 dB", value: "0", command: "PSREFLEV 0"),
                        Choice(label: "5 dB", value: "5", command: "PSREFLEV 5"),
                        Choice(label: "10 dB", value: "10", command: "PSREFLEV 10"),
                        Choice(label: "15 dB", value: "15", command: "PSREFLEV 15")
                    ])
                    PickRow(title: "Dynamic Volume", key: "PSDYNVOL", choices: [
                        Choice(label: "Off", value: "OFF", command: "PSDYNVOL OFF"),
                        Choice(label: "Light", value: "LIT", command: "PSDYNVOL LIT"),
                        Choice(label: "Medium", value: "MED", command: "PSDYNVOL MED"),
                        Choice(label: "Heavy", value: "HEV", command: "PSDYNVOL HEV")
                    ])
                    ToggleRow(title: "LFC (low frequency containment)", key: "PSLFC", on: "PSLFC ON", off: "PSLFC OFF")
                    StepRow(
                        title: "LFC containment amount",
                        value: r.v["PSCNTAMT"].flatMap { Int($0) }.map { "\($0)" } ?? "—",
                        minus: { r.send("PSCNTAMT DOWN") },
                        plus: { r.send("PSCNTAMT UP") }
                    )
                }

                Section("Processing") {
                    PickRow(title: "Dynamic range compression", key: "PSDRC", choices: [
                        Choice(label: "Off", value: "OFF", command: "PSDRC OFF"),
                        Choice(label: "Auto", value: "AUTO", command: "PSDRC AUTO"),
                        Choice(label: "Low", value: "LOW", command: "PSDRC LOW"),
                        Choice(label: "Medium", value: "MID", command: "PSDRC MID"),
                        Choice(label: "High", value: "HI", command: "PSDRC HI")
                    ])
                    ToggleRow(title: "Cinema EQ", key: "PSCINEMA EQ.", on: "PSCINEMA EQ.ON", off: "PSCINEMA EQ.OFF")
                    ToggleRow(title: "Loudness management", key: "PSLOM", on: "PSLOM ON", off: "PSLOM OFF")
                    PickRow(title: "Restorer", key: "PSRSTR", choices: [
                        Choice(label: "Off", value: "OFF", command: "PSRSTR OFF"),
                        Choice(label: "Low", value: "LOW", command: "PSRSTR LOW"),
                        Choice(label: "Medium", value: "MED", command: "PSRSTR MED"),
                        Choice(label: "High", value: "HI", command: "PSRSTR HI")
                    ])
                    ToggleRow(title: "Graphic EQ", key: "PSGEQ", on: "PSGEQ ON", off: "PSGEQ OFF")
                    ToggleRow(title: "Headphone EQ", key: "PSHEQ", on: "PSHEQ ON", off: "PSHEQ OFF")
                    ToggleRow(title: "Subwoofer output in this mode", key: "PSSWR", on: "PSSWR ON", off: "PSSWR OFF")
                    StepRow(
                        title: "Audio delay (lip sync)",
                        value: r.v["PSDEL"].flatMap { Int($0) }.map { "\($0) ms" } ?? "—",
                        detail: "Whole-system delay, not speaker distances",
                        minus: { r.send("PSDEL DOWN") },
                        plus: { r.send("PSDEL UP") }
                    )
                }

                Section("Input decoding") {
                    PickRow(title: "Input mode", key: "SD", choices: [
                        Choice(label: "Auto", value: "AUTO", command: "SDAUTO"),
                        Choice(label: "HDMI", value: "HDMI", command: "SDHDMI"),
                        Choice(label: "Digital", value: "DIGITAL", command: "SDDIGITAL"),
                        Choice(label: "Analog", value: "ANALOG", command: "SDANALOG")
                    ])
                    PickRow(title: "Decode mode", key: "DC", choices: [
                        Choice(label: "Auto", value: "AUTO", command: "DCAUTO"),
                        Choice(label: "PCM", value: "PCM", command: "DCPCM"),
                        Choice(label: "DTS", value: "DTS", command: "DCDTS")
                    ])
                }

                Section("Video and HDMI") {
                    PickRow(title: "HDMI monitor out", key: "VSMONI", choices: [
                        Choice(label: "Auto", value: "AUTO", command: "VSMONIAUTO"),
                        Choice(label: "Monitor 1", value: "1", command: "VSMONI1"),
                        Choice(label: "Monitor 2", value: "2", command: "VSMONI2")
                    ])
                    PickRow(title: "HDMI audio out", key: "VSAUDIO", choices: [
                        Choice(label: "Receiver", value: "AMP", command: "VSAUDIO AMP"),
                        Choice(label: "TV", value: "TV", command: "VSAUDIO TV")
                    ])
                    PickRow(title: "Video processing", key: "VSVPM", choices: [
                        Choice(label: "Auto", value: "AUTO", command: "VSVPMAUTO"),
                        Choice(label: "Game", value: "GAME", command: "VSVPMGAME"),
                        Choice(label: "Movie", value: "MOVI", command: "VSVPMMOVI"),
                        Choice(label: "Bypass", value: "BYP", command: "VSVPMBYP")
                    ])
                    InfoRow(title: "Scaler resolution", value: r.v["VSSC"] ?? "—")
                    InfoRow(title: "Aspect", value: r.v["VSASP"] ?? "—")
                }

                Section("General") {
                    PickRow(title: "ECO mode", key: "ECO", choices: [
                        Choice(label: "Off", value: "OFF", command: "ECOOFF"),
                        Choice(label: "Auto", value: "AUTO", command: "ECOAUTO"),
                        Choice(label: "On", value: "ON", command: "ECOON")
                    ])
                    PickRow(title: "Front display", key: "DIM", choices: [
                        Choice(label: "Bright", value: "BRI", command: "DIM BRI"),
                        Choice(label: "Dim", value: "DIM", command: "DIM DIM"),
                        Choice(label: "Dark", value: "DAR", command: "DIM DAR"),
                        Choice(label: "Off", value: "OFF", command: "DIM OFF")
                    ])
                    PickRow(title: "Sleep timer", key: "SLP", choices: [
                        Choice(label: "Off", value: "OFF", command: "SLPOFF"),
                        Choice(label: "30 min", value: "030", command: "SLP030"),
                        Choice(label: "60 min", value: "060", command: "SLP060"),
                        Choice(label: "90 min", value: "090", command: "SLP090"),
                        Choice(label: "120 min", value: "120", command: "SLP120")
                    ])
                }
            }
            .navigationTitle("Sound")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
