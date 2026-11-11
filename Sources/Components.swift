import SwiftUI

/// A level row: name, the receiver's actual current value, and −/+ buttons.
struct StepRow: View {
    let title: String
    let value: String
    var detail: String? = nil
    let minus: () -> Void
    let plus: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let detail = detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            Text(value)
                .font(.body.monospacedDigit().weight(.semibold))
                .foregroundStyle(Theme.accent)
                .lineLimit(1)
                .frame(minWidth: 76, alignment: .trailing)
            Button {
                Haptics.tap()
                minus()
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(RoundKeyStyle(size: 36))
            Button {
                Haptics.tap()
                plus()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(RoundKeyStyle(size: 36))
        }
        .padding(.vertical, 2)
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
                HStack(spacing: 4) {
                    Text(currentLabel)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                }
                .foregroundStyle(Theme.accent)
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

/// Appears at the top of a page only while the receiver is not connected.
struct StatusSection: View {
    @EnvironmentObject var r: Receiver

    var body: some View {
        if r.status != .connected {
            Section {
                HStack(spacing: 10) {
                    Circle()
                        .fill(r.status == .connecting ? Color.yellow : Theme.warn)
                        .frame(width: 9, height: 9)
                    Text(r.status.label)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer()
                    if r.status != .connecting {
                        Button("Connect") { r.connect() }
                            .font(.footnote.weight(.semibold))
                            .buttonStyle(.borderless)
                    }
                }
            }
        }
    }
}
