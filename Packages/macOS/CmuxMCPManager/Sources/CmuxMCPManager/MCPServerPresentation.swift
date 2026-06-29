// MCPServerPresentation.swift
import Foundation
import AgentDeckCore

/// UI-agnostic health for a server row, decoupling the settings UI from
/// AgentDeckCore's `HealthStatus` so `CmuxSettingsUI` need not import the library.
public enum MCPRowHealth: Sendable {
    case connected, needsAuth, failed, idle
}

/// Presentation-ready data for one MCP server row. `onToggle`/`onTest` are
/// pre-bound to the owning view model + server, so the renderer stays library-free.
public struct MCPServerRowData: Identifiable {
    public let id: String
    public let name: String
    public let detail: String
    public let health: MCPRowHealth
    public let isEnabled: Bool
    public let onToggle: () -> Void
    public let onTest: () -> Void
}

/// A scope grouping (User/Local/Project/Cloud) with its non-empty rows.
public struct MCPScopeGroup: Identifiable {
    public var id: String { label }
    public let label: String
    public let rows: [MCPServerRowData]
}

@MainActor
public extension MCPManagerViewModel {
    /// True once `load()` has produced an inventory (nil = still loading).
    var isLoaded: Bool { inventory != nil }

    /// Human-readable config-source problems (empty when none).
    var configIssues: [String] { inventory?.sourceErrors.map(\.reason) ?? [] }

    /// Duplicate server names surfaced by discovery (empty when none).
    var duplicateNames: [String] { inventory?.duplicates ?? [] }

    /// Servers grouped by scope in a fixed order, each row pre-bound to this
    /// view model. Reads `inventory` + `health`, so `@Observable` re-evaluates
    /// it whenever either changes.
    var scopeGroups: [MCPScopeGroup] {
        guard let servers = inventory?.servers else { return [] }
        return Self.scopeOrder.compactMap { label, matches in
            let group = servers.filter { matches($0.origin) }
            guard !group.isEmpty else { return nil }
            // index-based id: two local projects can hold same-named servers,
            // so `name` could collide within a scope group.
            let rows = group.enumerated().map { index, server in
                MCPServerRowData(
                    id: "\(label)-\(index)",
                    name: server.name,
                    detail: Self.detail(for: server),
                    health: Self.rowHealth(health[server.name]),
                    isEnabled: server.enablement != .disabled,
                    onToggle: { [weak self] in self?.toggle(server) },
                    onTest: { [weak self] in Task { await self?.testHealth(server) } }
                )
            }
            return MCPScopeGroup(label: label, rows: rows)
        }
    }

    private static var scopeOrder: [(String, (MCPServerOrigin) -> Bool)] {
        [
            ("User",    { if case .user = $0 { return true }; return false }),
            ("Local",   { if case .local = $0 { return true }; return false }),
            ("Project", { if case .project = $0 { return true }; return false }),
            ("Cloud",   { if case .cloud = $0 { return true }; return false }),
        ]
    }

    private static func detail(for server: MCPServer) -> String {
        if case .object(let o) = server.raw, case .string(let url)? = o["url"] {
            return url
        }
        return String(describing: server.transport)
    }

    private static func rowHealth(_ status: HealthStatus?) -> MCPRowHealth {
        switch status {
        case .connected:   return .connected
        case .needsAuth:   return .needsAuth
        case .failed:      return .failed
        case .idle, .none: return .idle
        }
    }
}
