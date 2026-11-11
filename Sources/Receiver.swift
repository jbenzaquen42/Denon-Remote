import Foundation
import Network

enum LinkStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case failed(String)

    var label: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting…"
        case .connected: return "Connected"
        case .failed(let why): return why
        }
    }
}

struct LogLine: Identifiable {
    enum Kind { case sent, received, changed, blocked }
    let id: Int
    let time: Date
    let kind: Kind
    let text: String
    let note: String?
}

/// Talks to the receiver over its plain-text control port (TCP 23).
/// Every value the receiver reports lands in `v`, keyed by command prefix.
@MainActor
final class Receiver: ObservableObject {
    @Published var host: String {
        didSet { UserDefaults.standard.set(host, forKey: "host") }
    }
    @Published var status: LinkStatus = .disconnected
    @Published var v: [String: String] = [:]
    @Published var log: [LogLine] = []
    /// Channels the receiver lists for level adjustment, in its own order (FL, FR, C, SW, …).
    @Published var channels: [String] = []
    /// Input source codes in the receiver's order (DVD, BD, TV, SAT/CBL, …).
    @Published var sources: [String] = []

    private var conn: NWConnection?
    private var buffer = Data()
    private var outbox: [(cmd: String, quiet: Bool)] = []
    private var pumping = false
    private var pollTask: Task<Void, Never>?
    private var nextLogID = 0

    init() {
        host = UserDefaults.standard.string(forKey: "host") ?? "10.0.0.7"
    }

    // MARK: - Safety

    /// Setup-level (`SS…`) values belong to the calibration (Evo32). The app never writes
    /// them, and only reads the families listed here. Speaker distances are in neither list,
    /// so they are never queried, opened or changed.
    static let readableSetup = ["SSLEV", "SSCFR", "SSSPC", "SSFUN", "SSSOD", "SSINF", "SSSWM",
                                "SSSMG", "SSANA", "SSHDM", "SSLOC", "SSQSN", "SSLAN"]

    static func blockedReason(_ raw: String) -> String? {
        let cmd = raw.trimmingCharacters(in: .whitespaces).uppercased()
        if cmd.isEmpty { return "empty command" }
        if cmd.hasPrefix("SS") {
            guard cmd.hasSuffix("?") else {
                return "setup/calibration values are read-only in this app"
            }
            guard readableSetup.contains(where: { cmd.hasPrefix($0) }) else {
                return "this setup area is not opened by this app"
            }
        }
        if cmd.hasPrefix("MNMEN") && !cmd.hasSuffix("?") && !cmd.hasSuffix("OFF") {
            return "the on-screen setup menu is not opened from this app"
        }
        return nil
    }

    // MARK: - Connection

    func connect() {
        disconnect()
        let h = host.trimmingCharacters(in: .whitespaces)
        guard !h.isEmpty else {
            status = .failed("No receiver address set")
            return
        }
        status = .connecting
        let c = NWConnection(host: NWEndpoint.Host(h), port: 23, using: .tcp)
        conn = c
        c.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self = self, self.conn === c else { return }
                switch state {
                case .ready:
                    self.status = .connected
                    self.refreshAll()
                    self.startPolling()
                case .waiting(let err):
                    self.status = .failed("Waiting: \(err.localizedDescription)")
                case .failed(let err):
                    self.status = .failed(err.localizedDescription)
                    self.drop()
                case .cancelled:
                    break
                default:
                    break
                }
            }
        }
        receive(on: c)
        c.start(queue: .main)
    }

    func disconnect() {
        conn?.cancel()
        drop()
        status = .disconnected
    }

    private func drop() {
        pollTask?.cancel()
        pollTask = nil
        conn = nil
        outbox.removeAll()
        buffer.removeAll()
    }

    private func receive(on c: NWConnection) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self = self, self.conn === c else { return }
                if let data = data, !data.isEmpty { self.ingest(data) }
                if isComplete || error != nil {
                    self.status = .failed("Receiver closed the connection")
                    self.drop()
                    return
                }
                self.receive(on: c)
            }
        }
    }

    // MARK: - Sending

    /// Queue a command. Anything the safety rules reject is logged and dropped.
    func send(_ cmd: String, quiet: Bool = false) {
        if let why = Receiver.blockedReason(cmd) {
            addLog(.blocked, cmd, note: why)
            return
        }
        guard conn != nil else { return }
        outbox.append((cmd, quiet))
        pump()
    }

    private func pump() {
        guard !pumping else { return }
        pumping = true
        Task { @MainActor in
            while !self.outbox.isEmpty, let c = self.conn {
                let item = self.outbox.removeFirst()
                if !item.quiet { self.addLog(.sent, item.cmd, note: nil) }
                c.send(content: Data((item.cmd + "\r").utf8), completion: .contentProcessed { _ in })
                try? await Task.sleep(nanoseconds: 70_000_000)
            }
            self.pumping = false
        }
    }

    static let fullQuery = [
        "PW?", "ZM?", "MV?", "MU?", "SI?", "SD?", "DC?", "SV?", "MS?", "CV?",
        "PSDIL ?", "PSSWL ?", "PSTONE CTRL ?", "PSBAS ?", "PSTRE ?",
        "PSMULTEQ: ?", "PSDYNEQ ?", "PSREFLEV ?", "PSDYNVOL ?", "PSLFC ?", "PSCNTAMT ?",
        "PSLFE ?", "PSDRC ?", "PSDEL ?", "PSRSTR ?", "PSCINEMA EQ. ?", "PSLOM ?", "PSSWR ?",
        "PSGEQ ?", "PSHEQ ?", "PSNEURAL ?", "PSFRONT?",
        "ECO?", "SLP?", "DIM ?", "VSMONI ?", "VSSC ?", "VSASP ?", "VSVPM ?", "VSAUDIO ?",
        "SSFUN ?", "SSSOD ?", "SSQSNZMA ?", "SSLEV ?", "SSCFR ?", "SSSPC ?", "SSSWM ?",
        "SSSMG ?", "SSINFFRM ?", "NSFRN ?", "Z2?", "Z2MU?",
        "SSINFAISSIG ?", "SSINFAISFSV ?", "SSINFSIGRES ?", "OPINFASP ?", "OPINFINS ?"
    ]

    func refreshAll() {
        for q in Receiver.fullQuery { send(q, quiet: true) }
    }

    /// Signal info and calibration trims are not always pushed as events, so re-read them.
    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { @MainActor in
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if Task.isCancelled || self.conn == nil { return }
                tick += 1
                for q in ["SSINFAISSIG ?", "SSINFAISFSV ?", "SSINFSIGRES ?", "OPINFASP ?", "OPINFINS ?"] {
                    self.send(q, quiet: true)
                }
                if tick % 3 == 0 {
                    self.send("SSLEV ?", quiet: true)
                    self.send("SSCFR ?", quiet: true)
                }
            }
        }
    }

    // MARK: - Receiving

    private func ingest(_ data: Data) {
        buffer.append(data)
        while let idx = buffer.firstIndex(of: 0x0D) {
            let lineData = buffer.subdata(in: buffer.startIndex..<idx)
            buffer.removeSubrange(buffer.startIndex...idx)
            let line = (String(data: lineData, encoding: .utf8) ?? String(decoding: lineData, as: UTF8.self))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !line.isEmpty { handle(line) }
        }
    }

    private static let polledFamilies = ["SSINF", "OPINF", "SYSDA", "SYSMI", "SSLEV", "SSCFR"]
    private static let dualKeys: Set<String> = ["PSDIL", "PSSWL"]
    private static let fixedPrefixes = [
        "PSTONE CTRL", "PSCINEMA EQ.", "PSMULTEQ:",
        "SSINFAISSIG", "SSINFAISFSV", "SSINFFRMAVR", "SSINFFRMDTS",
        "OPINFASP", "OPINFINS", "OPSTS", "MVMAX",
        "VSMONI", "VSSC", "VSASP", "VSVPM", "VSAUDIO",
        "SYSDA", "SYSMI", "NSFRN", "SSSWM", "SSSMG", "SSLOC",
        "STBY", "ECO", "SLP", "DIM",
        "PW", "ZM", "MV", "MU", "SI", "SD", "DC", "SV", "MS", "PV"
    ]

    /// Split a receiver line into (key, value). Returns nil for lines we only log.
    static func split(_ line: String) -> (String, String)? {
        if line.hasPrefix("Z2") {
            let rest = String(line.dropFirst(2))
            if rest.hasPrefix("MU") { return ("Z2MU", String(rest.dropFirst(2))) }
            if rest == "ON" || rest == "OFF" { return ("Z2", rest) }
            if !rest.isEmpty, rest.allSatisfy({ $0.isNumber }) { return ("Z2VOL", rest) }
            return ("Z2SRC", rest)
        }
        if line.hasPrefix("SSINFSIGRES ") {
            let rest = line.dropFirst("SSINFSIGRES ".count)
            guard let dir = rest.first else { return nil }
            return ("SSINFSIGRES" + String(dir), rest.dropFirst().trimmingCharacters(in: .whitespaces))
        }
        for p in fixedPrefixes where line.hasPrefix(p) {
            return (p, line.dropFirst(p.count).trimmingCharacters(in: .whitespaces))
        }
        if let sp = line.firstIndex(of: " ") {
            let key = String(line[..<sp])
            let value = line[line.index(after: sp)...].trimmingCharacters(in: .whitespaces)
            return (key, value)
        }
        return nil
    }

    private func handle(_ line: String) {
        guard let (rawKey, value) = Receiver.split(line) else {
            if line != "CVEND" { addLog(.received, line, note: nil) }
            return
        }
        let polled = Receiver.polledFamilies.contains(where: { rawKey.hasPrefix($0) })
        if value == "END" {
            return
        }
        var key = rawKey
        if Receiver.dualKeys.contains(rawKey) && (value == "ON" || value == "OFF") {
            key = rawKey + "#"
        }
        if rawKey.hasPrefix("CV"), rawKey.count > 2 {
            let ch = String(rawKey.dropFirst(2))
            if !channels.contains(ch) { channels.append(ch) }
        }
        if rawKey.hasPrefix("SSFUN"), rawKey.count > 5 {
            let src = String(rawKey.dropFirst(5))
            if !sources.contains(src) { sources.append(src) }
        }
        let old = v[key]
        if old == value {
            if !polled { addLog(.received, line, note: nil) }
            return
        }
        v[key] = value
        if let old = old {
            addLog(.changed, line, note: "was \(old)")
        } else {
            addLog(.received, line, note: nil)
        }
    }

    private func addLog(_ kind: LogLine.Kind, _ text: String, note: String?) {
        nextLogID += 1
        log.append(LogLine(id: nextLogID, time: Date(), kind: kind, text: text, note: note))
        if log.count > 600 { log.removeFirst(log.count - 600) }
    }

    // MARK: - Value helpers

    /// Denon level numbers: "50" = 50, "425" = 42.5.
    static func number(_ s: String?) -> Double? {
        guard let s = s, !s.isEmpty, let d = Double(s) else { return nil }
        return s.count >= 3 ? d / 10 : d
    }

    /// Trim-style values where 50 means 0 dB.
    func trimDB(_ key: String) -> Double? {
        guard let n = Receiver.number(v[key]) else { return nil }
        return n - 50
    }

    /// Master volume in dB (80 = 0 dB).
    var volumeDB: Double? {
        guard let n = Receiver.number(v["MV"]) else { return nil }
        return n - 80
    }

    func setVolume(raw: Double) {
        let clamped = max(0, min(raw, 98))
        let whole = Int(clamped)
        let half = clamped - Double(whole) >= 0.5
        send(String(format: "MV%02d", whole) + (half ? "5" : ""))
    }

    func isOn(_ key: String) -> Bool { v[key] == "ON" }

    func sourceName(_ code: String) -> String {
        let name = v["SSFUN" + code] ?? ""
        return name.isEmpty ? code : name
    }

    static func channelName(_ ch: String) -> String {
        let names = [
            "FL": "Front L", "FR": "Front R", "C": "Center", "SW": "Subwoofer 1", "SW2": "Subwoofer 2",
            "SL": "Surround L", "SR": "Surround R", "SBL": "Surr Back L", "SBR": "Surr Back R",
            "SB": "Surr Back", "FHL": "Front Height L", "FHR": "Front Height R",
            "TFL": "Top Front L", "TFR": "Top Front R", "TML": "Top Middle L", "TMR": "Top Middle R",
            "FDL": "Front Dolby L", "FDR": "Front Dolby R", "SDL": "Surr Dolby L", "SDR": "Surr Dolby R"
        ]
        return names[ch] ?? ch
    }

    static func formatDB(_ d: Double?) -> String {
        guard let d = d else { return "—" }
        if abs(d) < 0.05 { return "0.0 dB" }
        return String(format: "%+.1f dB", d)
    }
}
