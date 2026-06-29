// MCPManagerViewModel.swift
import Foundation
import Observation
import AgentDeckCore

@MainActor
@Observable
public final class MCPManagerViewModel {
    public private(set) var inventory: MCPInventory?
    public private(set) var health: [String: HealthStatus] = [:]
    public private(set) var activeProject: String?
    public private(set) var toggleError: String?
    public private(set) var isWorking: Bool = false

    private let env: [String: String]
    private let home: String
    private let fileOps: FileOps
    private let prober: MCPHealthProber
    private let projectProvider: ActiveProjectProviding

    public init(env: [String: String] = ProcessInfo.processInfo.environment,
                home: String = NSHomeDirectory(),
                fileOps: FileOps = RealFileOps(),
                http: HTTPProbing = URLSessionHTTPProbe(),
                secrets: SecretStore = InMemorySecretStore(namespace: "dev.cmux"),
                projectProvider: ActiveProjectProviding) {
        self.env = env
        self.home = home
        self.fileOps = fileOps
        self.prober = MCPHealthProber(secrets: secrets, http: http)
        self.projectProvider = projectProvider
        self.activeProject = projectProvider.activeProjectPath
    }

    public var canToggle: Bool { activeProject != nil }

    public func setActiveProject(_ path: String?) {
        activeProject = path
        load()
    }

    /// Flip a server's enablement under the active project, then re-read to reflect the truth.
    /// No optimistic mutation — the UI follows the model, so a failure leaves state correct.
    public func toggle(_ server: MCPServer) {
        guard let active = activeProject else {
            toggleError = "Select a project to change MCP server enablement."
            return
        }
        isWorking = true
        defer { isWorking = false }
        let enable = (server.enablement == .disabled)   // disabled → turn on; otherwise → turn off
        let request = MCPEditRequest(server: server, change: .setEnabled(enable))
        switch MCPMutator.apply(request, env: env, home: home, activeProject: active, fileOps: fileOps) {
        case .success:
            toggleError = nil
            load()
        case .failure(let error):
            toggleError = "Could not change \"\(server.name)\": \(error)"
        }
    }

    /// Probe a remote server's health off the main actor and publish the verdict.
    /// stdio/cloud servers return `.idle` from the prober — an honest "not probeable here".
    public func testHealth(_ server: MCPServer) async {
        let prober = self.prober
        let result = await Task.detached { prober.probe(server) }.value
        health[server.name] = result.status
    }

    /// Discover MCP servers across user/local (+ project, when an active project is set).
    public func load() {
        let claudeJSONPath = MCPConfigPaths.claudeJSON(env: env, home: home)
        let reader = ClaudeJSONReader(path: claudeJSONPath)
        var sources: [MCPSource] = [UserConfigSource(reader: reader), LocalConfigSource(reader: reader)]
        if let proj = activeProject {
            sources.append(ProjectConfigSource(path: MCPConfigPaths.projectMCPJSON(projectDir: proj), projectDir: proj))
        }
        inventory = MCPDiscovery.discover(sources: sources, enablement: reader.enablement(), activeProject: activeProject)
    }
}
