// MCPServersSection.swift
import AppKit
import CmuxMCPManager
import SwiftUI

/// Settings section hosting the AgentDeck MCP manager, rendered with the
/// native settings chrome (SettingsSectionHeader / SettingsCard /
/// SettingsCardRow / SettingsCardDivider) so it matches sibling sections.
/// Library types stay inside `CmuxMCPManager`: this view consumes only the
/// view model's presentation accessors (scopeGroups, configIssues, …).
@MainActor
struct MCPServersSection: View {
    @State private var viewModel = MCPManagerViewModel(projectProvider: ManualActiveProjectProvider())

    var body: some View {
        Group {
            SettingsSectionHeader("MCP Servers", section: .mcpServers)
            messages
            // One card for the whole section (mirroring BrowserSection): the
            // Project/Servers controls, then each discovered scope as a
            // divider-fenced sub-block. No second card, so no stray inter-card
            // gap — the scope labels read as subordinate to the single header.
            SettingsCard {
                configRows
                if viewModel.isLoaded {
                    scopeBlocks
                } else {
                    SettingsCardDivider()
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 10)
                }
            }
        }
        .onAppear { viewModel.load() }
    }

    @ViewBuilder
    private var configRows: some View {
        SettingsCardRow(
            "Project",
            subtitle: "Enable/disable applies to the selected project.",
            controlWidth: 330
        ) {
            HStack(spacing: 8) {
                Text(viewModel.activeProject ?? "none (enable/disable disabled)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(viewModel.activeProject == nil ? Color.orange : Color.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Button("Choose…") { chooseProject() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        SettingsCardDivider()
        SettingsCardRow(
            "Servers",
            subtitle: "Reload MCP servers discovered across all scopes."
        ) {
            Button("Refresh") { viewModel.load() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    @ViewBuilder
    private var messages: some View {
        if let error = viewModel.toggleError {
            Text(error).font(.callout).foregroundStyle(.red).padding(.leading, 2)
        }
        ForEach(viewModel.configIssues, id: \.self) { issue in
            Text("Config issue: \(issue)").font(.caption).foregroundStyle(.orange).padding(.leading, 2)
        }
        if !viewModel.duplicateNames.isEmpty {
            Text("Duplicate server names: \(viewModel.duplicateNames.joined(separator: ", "))")
                .font(.caption).foregroundStyle(.orange).padding(.leading, 2)
        }
    }

    /// Scope sub-blocks, emitted INSIDE the section's single card after the
    /// config rows. Each scope leads with a divider (separating it from the
    /// Servers control above, or the previous scope), then a primary
    /// 13pt-semibold label — NOT a SettingsSectionHeader (the gray, top-level
    /// look) — then its rows, mirroring the "Import Browser Data" sub-section
    /// in BrowserSection. So scope labels read as subordinate to the single
    /// "MCP Servers" header, not as sibling sections.
    @ViewBuilder
    private var scopeBlocks: some View {
        let groups = viewModel.scopeGroups
        if groups.isEmpty {
            SettingsCardDivider()
            Text("No MCP servers found.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        } else {
            ForEach(Array(groups.enumerated()), id: \.element.id) { _, group in
                SettingsCardDivider()
                scopeLabel(group.label)
                ForEach(Array(group.rows.enumerated()), id: \.element.id) { rowIndex, row in
                    if rowIndex > 0 { SettingsCardDivider() }
                    serverRow(row)
                }
            }
        }
    }

    private func scopeLabel(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 13, weight: .semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 2)
    }

    private func serverRow(_ row: MCPServerRowData) -> some View {
        SettingsCardRow(row.name, subtitle: row.detail) {
            HStack(spacing: 10) {
                Circle().fill(color(for: row.health)).frame(width: 8, height: 8)
                Button("Test") { row.onTest() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Toggle("", isOn: Binding(get: { row.isEnabled }, set: { _ in row.onToggle() }))
                    .labelsHidden()
                    .disabled(!viewModel.canToggle)
            }
        }
    }

    private func color(for health: MCPRowHealth) -> Color {
        switch health {
        case .connected: return .green
        case .needsAuth: return .yellow
        case .failed:    return .red
        case .idle:      return .gray
        }
    }

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
