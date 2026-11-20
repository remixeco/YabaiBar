import SwiftUI

/// A live console of everything the app did, so a failure is never a mystery.
struct LogConsole: View {
    @EnvironmentObject private var controller: YabaiController
    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    isExpanded.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        Text("Journal")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                if controller.activity.isBusy {
                    HStack(spacing: 5) {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.7)
                        Text(controller.activity.label)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    controller.clearLog()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Vider le journal")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            if isExpanded {
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(controller.log) { entry in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(entry.time)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                    Text(entry.text)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(color(for: entry.kind))
                                        .textSelection(.enabled)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 0)
                                }
                                .id(entry.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .onChange(of: controller.log.count) { _, _ in
                        if let last = controller.log.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func color(for kind: LogEntry.Kind) -> Color {
        switch kind {
        case .info: return .primary
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        case .command: return .blue
        }
    }
}
