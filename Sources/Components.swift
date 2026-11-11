import SwiftUI

/// A level row: name, the receiver's actual current value, and −/+ buttons.
struct StepRow: View {
    let title: String
    let value: String
    var detail: String? = nil
    let minus: () -> Void
    let plus: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let detail = detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(value)
                .font(.body.monospacedDigit().weight(.semibold))
                .frame(minWidth: 78, alignment: .trailing)
            Button(action: minus) {
                Image(systemName: "minus.circle.fill").font(.title2)
            }
            .buttonStyle(.borderless)
            Button(action: plus) {
                Image(systemName: "plus.circle.fill").font(.title2)
            }
            .buttonStyle(.borderless)
        }
    }
}

/// On/off switch bound to a receiver value; flips only when the receiver confirms.
struct ToggleRow: View {
    @EnvironmentObject var r: Receiver
    let title: String
    let key: String
    let on: String
    let off: String

    var body: some View {
        Toggle(title, isOn: Binding(
            get: { r.isOn(key) },
            set: { r.send($0 ? on : off) }
        ))
    }
}

struct Choice: Identifiable {
    let label: String
    let value: String
    let command: String
    var id: String { command }
}

/// A menu of fixed options showing the receiver's current choice.
struct PickRow: View {
    @EnvironmentObject var r: Receiver
    let title: String
    let key: String
    let choices: [Choice]

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Menu {
                ForEach(choices) { c in
                    Button {
                        r.send(c.command)
                    } label: {
                        if c.value == r.v[key] {
                            Label(c.label, systemImage: "checkmark")
                        } else {
                            Text(c.label)
                        }
                    }
                }
            } label: {
                Text(currentLabel).foregroundStyle(.tint)
            }
        }
    }

    private var currentLabel: String {
        guard let cur = r.v[key] else { return "—" }
        return choices.first(where: { $0.value == cur })?.label ?? cur
    }
}

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct StatusBar: View {
    @EnvironmentObject var r: Receiver

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text(r.status.label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            if r.status != .connected && r.status != .connecting {
                Button("Connect") { r.connect() }
                    .font(.caption)
            }
        }
    }

    private var color: Color {
        switch r.status {
        case .connected: return .green
        case .connecting: return .yellow
        default: return .red
        }
    }
}
