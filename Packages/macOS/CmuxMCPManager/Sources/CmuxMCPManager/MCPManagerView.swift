// MCPManagerView.swift
import SwiftUI
import AppKit
import AgentDeckCore

// NOTE (2026-06-26): No longer used by cmux settings. The MCP Servers section now
// renders via CmuxSettingsUI.MCPServersSection using the native settings chrome +
// the view model's presentation accessors (see MCPServerPresentation.swift). This
// standalone view is retained intentionally as a possible reusable surface; if it
// stays unused, it can be removed later.
public struct MCPManagerView: View {
    // Plain `let` — the owner (MCPServersSection) holds it in @State. @Observable tracks
    // property reads in `body`, so the view still updates on change. (Avoids the
    // @State(initialValue:) footgun of ignoring later-injected instances.)
    let viewModel: MCPManagerViewModel
    public init(viewModel: MCPManagerViewModel) { self.viewModel = viewModel }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let error = viewModel.toggleError {
                Text(error).font(.callout).foregroundStyle(.red)
            }
            if let inv = viewModel.inventory {
                if !inv.sourceErrors.isEmpty {
                    ForEach(Array(inv.sourceErrors.enumerated()), id: \.offset) { _, err in
                        Text("Config issue: \(err.reason)").font(.caption).foregroundStyle(.orange)
                    }
                }
                if !inv.duplicates.isEmpty {
                    Text("Duplicate server names: \(inv.duplicates.joined(separator: ", "))")
                        .font(.caption).foregroundStyle(.orange)
                }
                if inv.servers.isEmpty {
                    Text("No MCP servers found.").foregroundStyle(.secondary)
                } else {
                    serverList(inv.servers)
                }
            } else {
                ProgressView()
            }
        }
        .padding()
        .onAppear { viewModel.load() }
    }

    private var header: some View {
        HStack {
            Text("MCP Servers").font(.title2).bold()
            Spacer()
            Button("Refresh") { viewModel.load() }
        }
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: 6) {
                Text("Project:").font(.caption).foregroundStyle(.secondary)
                Text(viewModel.activeProject ?? "none (enable/disable disabled)")
                    .font(.caption).foregroundStyle(viewModel.activeProject == nil ? .orange : .secondary)
                Button("Choose…") { chooseProject() }
                    .controlSize(.small)
            }
            .offset(y: 18)
        }
    }

    @ViewBuilder
    private func serverList(_ servers: [MCPServer]) -> some View {
        // Plain VStack/ForEach — deliberately NOT a `List`. The Settings window is one
        // tall ScrollView (SettingsWindowScene), and a `List` has no intrinsic height
        // there, so it collapses to zero and renders its rows invisibly. Every sibling
        // settings section renders rows with stacks for exactly this reason.
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Self.scopes, id: \.0) { label, predicate in
                let group = servers.filter { predicate($0.origin) }
                if !group.isEmpty {
                    Text(label)
                        .font(.caption).bold()
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                    // index-based id: two local projects can hold same-named servers,
                    // so `\.name` could collide within a scope group.
                    ForEach(Array(group.enumerated()), id: \.offset) { _, server in
                        MCPServerRow(
                            server: server,
                            health: viewModel.health[server.name],
                            canToggle: viewModel.canToggle,
                            onToggle: { viewModel.toggle(server) },
                            onTest: { Task { await viewModel.testHealth(server) } }
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static let scopes: [(String, (MCPServerOrigin) -> Bool)] = [
        ("User", { if case .user = $0 { return true }; return false }),
        ("Local", { if case .local = $0 { return true }; return false }),
        ("Project", { if case .project = $0 { return true }; return false }),
        ("Cloud", { if case .cloud = $0 { return true }; return false }),
    ]

    private func chooseProject() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.setActiveProject(url.path)
        }
    }
}
