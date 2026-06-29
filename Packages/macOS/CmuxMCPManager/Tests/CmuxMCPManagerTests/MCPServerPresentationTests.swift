// MCPServerPresentationTests.swift
import XCTest
import AgentDeckCore
@testable import CmuxMCPManager

@MainActor
final class MCPServerPresentationTests: XCTestCase {
    func test_scopeGroups_groupsUserServer_withURLDetail() throws {
        let dir = try TempConfig.make(claudeJSON: """
        {"mcpServers": {"alpha": {"type": "http", "url": "https://a.example/mcp"}}}
        """)
        defer { TempConfig.cleanup(dir) }
        let vm = TempConfig.makeVM(home: dir, activeProject: nil)
        vm.load()

        XCTAssertTrue(vm.isLoaded)
        XCTAssertEqual(vm.scopeGroups.map(\.label), ["User"])
        let rows = try XCTUnwrap(vm.scopeGroups.first).rows
        XCTAssertEqual(rows.map(\.name), ["alpha"])
        XCTAssertEqual(rows.first?.detail, "https://a.example/mcp")
        XCTAssertEqual(rows.first?.isEnabled, true)
        XCTAssertEqual(rows.first?.health, .idle, "no probe yet → idle")
        XCTAssertTrue(vm.configIssues.isEmpty)
        XCTAssertTrue(vm.duplicateNames.isEmpty)
    }

    func test_isLoaded_falseBeforeLoad() {
        let vm = TempConfig.makeVM(home: NSTemporaryDirectory(), activeProject: nil)
        XCTAssertFalse(vm.isLoaded, "nil inventory before load()")
        XCTAssertTrue(vm.scopeGroups.isEmpty)
    }

    func test_scopeGroups_reflectsHealthAfterProbe() async throws {
        let dir = try TempConfig.make(claudeJSON: """
        {"mcpServers": {"alpha": {"type": "http", "url": "https://a.example/mcp"}}}
        """)
        defer { TempConfig.cleanup(dir) }
        let probe = FakeHTTPProbe(outcome: .response(status: 200, contentType: "application/json", latencyMs: 9))
        let vm = TempConfig.makeVM(home: dir, activeProject: "/tmp/agentdeck-proj", http: probe)
        vm.load()
        let alpha = try XCTUnwrap(vm.inventory?.servers.first { $0.name == "alpha" })
        await vm.testHealth(alpha)
        XCTAssertEqual(vm.scopeGroups.first?.rows.first?.health, .connected)
    }
}
