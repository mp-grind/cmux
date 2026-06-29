// MCPManagerViewModelTests.swift
import XCTest
@testable import CmuxMCPManager

// @MainActor: the view-model is @MainActor-isolated, so the whole test class is too.
// This lets the synchronous tests call load()/toggle()/makeVM directly (no await), and
// keeps the async health test correct under strict concurrency.
@MainActor
final class MCPManagerViewModelTests: XCTestCase {
    func test_manualProvider_returnsChosenPath() {
        let p = ManualActiveProjectProvider(initial: nil)
        XCTAssertNil(p.activeProjectPath)
        p.choose("/tmp/proj")
        XCTAssertEqual(p.activeProjectPath, "/tmp/proj")
    }
}

import AgentDeckCore

extension MCPManagerViewModelTests {
    func test_load_listsUserServers() throws {
        let dir = try TempConfig.make(claudeJSON: """
        {"mcpServers": {"alpha": {"type": "http", "url": "https://a.example/mcp"}}}
        """)
        defer { TempConfig.cleanup(dir) }
        let vm = TempConfig.makeVM(home: dir, activeProject: nil)
        vm.load()
        XCTAssertEqual(vm.inventory?.servers.map(\.name), ["alpha"])
    }
}

extension MCPManagerViewModelTests {
    func test_toggle_disablesUserServer_underActiveProject() throws {
        let dir = try TempConfig.make(claudeJSON: """
        {"mcpServers": {"alpha": {"type": "http", "url": "https://a.example/mcp"}}}
        """)
        defer { TempConfig.cleanup(dir) }
        let vm = TempConfig.makeVM(home: dir, activeProject: "/tmp/agentdeck-proj")
        vm.load()
        let alpha = try XCTUnwrap(vm.inventory?.servers.first { $0.name == "alpha" })
        XCTAssertNotEqual(alpha.enablement, .disabled, "starts enabled")
        vm.toggle(alpha)
        let after = try XCTUnwrap(vm.inventory?.servers.first { $0.name == "alpha" })
        XCTAssertEqual(after.enablement, .disabled, "toggle persisted + re-read")
        XCTAssertNil(vm.toggleError)
    }

    func test_toggle_noActiveProject_isNoOp() throws {
        let dir = try TempConfig.make(claudeJSON: """
        {"mcpServers": {"alpha": {"type": "http", "url": "https://a.example/mcp"}}}
        """)
        defer { TempConfig.cleanup(dir) }
        let before = try String(contentsOfFile: dir + "/.claude.json", encoding: .utf8)
        let vm = TempConfig.makeVM(home: dir, activeProject: nil)
        vm.load()
        let alpha = try XCTUnwrap(vm.inventory?.servers.first { $0.name == "alpha" })
        XCTAssertFalse(vm.canToggle)
        vm.toggle(alpha)
        XCTAssertNotNil(vm.toggleError, "no-project toggle surfaces an error, not a silent no-op")
        let after = try String(contentsOfFile: dir + "/.claude.json", encoding: .utf8)
        XCTAssertEqual(before, after, "config file untouched")
    }

    func test_toggle_writeFailure_surfacesError_keepsState() throws {
        let dir = try TempConfig.make(claudeJSON: """
        {"mcpServers": {"alpha": {"type": "http", "url": "https://a.example/mcp"}}}
        """)
        defer { TempConfig.cleanup(dir) }
        let vm = TempConfig.makeVM(home: dir, activeProject: "/tmp/agentdeck-proj", fileOps: FailingFileOps())
        vm.load()
        let alpha = try XCTUnwrap(vm.inventory?.servers.first { $0.name == "alpha" })
        vm.toggle(alpha)
        XCTAssertNotNil(vm.toggleError, "write failure surfaced")
        let after = try XCTUnwrap(vm.inventory?.servers.first { $0.name == "alpha" })
        XCTAssertNotEqual(after.enablement, .disabled, "state unchanged on failure")
    }
}

extension MCPManagerViewModelTests {
    func test_testHealth_remoteServer_reportsConnected() async throws {
        let dir = try TempConfig.make(claudeJSON: """
        {"mcpServers": {"alpha": {"type": "http", "url": "https://a.example/mcp"}}}
        """)
        defer { TempConfig.cleanup(dir) }
        let probe = FakeHTTPProbe(outcome: .response(status: 200, contentType: "application/json", latencyMs: 12))
        let vm = TempConfig.makeVM(home: dir, activeProject: "/tmp/agentdeck-proj", http: probe)
        vm.load()
        let alpha = try XCTUnwrap(vm.inventory?.servers.first { $0.name == "alpha" })
        await vm.testHealth(alpha)
        guard case .connected = vm.health["alpha"] else {
            return XCTFail("expected .connected, got \(String(describing: vm.health["alpha"]))")
        }
    }
}
