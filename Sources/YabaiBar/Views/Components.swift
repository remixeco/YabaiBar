import SwiftUI

/// A coloured capsule showing whether yabai is running.
struct StatusPill: View {
    enum State {
        case running, stopped, busy, unknown

        var label: String {
            switch self {
            case .running: return "En cours"
            case .stopped: return "Arrêté"
            case .busy: return "Occupé"
            case .unknown: return "Inconnu"
            }
        }

        var color: Color {
            switch self {
            case .running: return .green
            case .stopped: return .secondary
            case .busy: return .blue
            case .unknown: return .orange
            }
        }
    }

    let state: State

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(state.color)
                .frame(width: 7, height: 7)
            Text(state.label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(state.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(state.color.opacity(0.12))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("État de yabai : \(state.label)")
    }
}

/// A labelled value used across the dashboard.
struct DetailRow: View {
    let title: String
    let value: String
    var monospaced = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(monospaced ? .system(size: 11, design: .monospaced) : .body)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

/// Button style for the primary call to action.
struct ProminentButtonStyle: ButtonStyle {
    var tint: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.75 : 1))
            )
            .foregroundStyle(.white)
            .contentShape(Rectangle())
    }
}

/// Button style for secondary actions inside the menu bar panel.
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.14 : 0.07))
            )
            .contentShape(Rectangle())
    }
}
