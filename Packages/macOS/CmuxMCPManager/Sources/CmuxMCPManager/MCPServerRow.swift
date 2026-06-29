// MCPServerRow.swift
import SwiftUI
import AgentDeckCore

// NOTE (2026-06-26): No longer used by cmux settings. The MCP Servers section now
// renders via CmuxSettingsUI.MCPServersSection using the native settings chrome +
// the view model's presentation accessors (see MCPServerPresentation.swift). This
// standalone view is retained intentionally as a possible reusable surface; if it
// stays unused, it can be removed later.
struct MCPServerRow: View {
    let server: MCPServer
    let health: HealthStatus?
    let canToggle: Bool
    let onToggle: () -> Void
    let onTest: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            healthDot
            VStack(alignment: .leading, spacing: 2) {
                Text(server.name).font(.body)
                if let url = Self.urlString(server.raw) {
                    Text(url).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(String(describing: server.transport)).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Test", action: onTest)
                .buttonStyle(.bordered)
                .controlSize(.small)
            Toggle("", isOn: Binding(
                get: { server.enablement != .disabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .disabled(!canToggle)
        }
        .padding(.vertical, 4)
    }

    private var healthDot: some View {
        let color: Color
        switch health {
        case .connected: color = .green
        case .needsAuth: color = .yellow
        case .failed:    color = .red
        case .idle, .none: color = .gray
        }
        return Circle().fill(color).frame(width: 8, height: 8)
    }

    static func urlString(_ raw: JSONValue) -> String? {
        guard case .object(let o) = raw, case .string(let url)? = o["url"] else { return nil }
        return url
    }
}
