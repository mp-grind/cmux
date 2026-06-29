// Fakes.swift
import Foundation
import XCTest
import AgentDeckCore
@testable import CmuxMCPManager

/// HTTPProbing double returning a scripted outcome.
struct FakeHTTPProbe: HTTPProbing {
    let outcome: ProbeOutcome
    func probe(url: String, headers: [String: String], body: Data, timeoutMs: Int) -> ProbeOutcome { outcome }
}

/// FileOps that delegates reads/copies to RealFileOps but fails every write (for the rollback test).
final class FailingFileOps: FileOps {
    private let inner = RealFileOps()
    func read(_ path: String) throws -> Data { try inner.read(path) }
    func write(_ data: Data, to path: String, atomic: Bool) throws { throw CocoaError(.fileWriteNoPermission) }
    func copy(_ from: String, to: String) throws { try inner.copy(from, to: to) }
    func remove(_ path: String) throws { try inner.remove(path) }
    func exists(_ path: String) -> Bool { inner.exists(path) }
}

enum TempConfig {
    /// Create a temp dir acting as HOME with a `.claude.json` containing `claudeJSON`.
    static func make(claudeJSON: String) throws -> String {
        let dir = NSTemporaryDirectory() + "cmuxmcp-" + UUID().uuidString
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try claudeJSON.data(using: .utf8)!.write(to: URL(fileURLWithPath: dir + "/.claude.json"))
        return dir
    }
    static func cleanup(_ dir: String) { try? FileManager.default.removeItem(atPath: dir) }

    @MainActor
    static func makeVM(home: String,
                       activeProject: String?,
                       fileOps: FileOps = RealFileOps(),
                       http: HTTPProbing = FakeHTTPProbe(outcome: .response(status: 200, contentType: "application/json", latencyMs: 7))) -> MCPManagerViewModel {
        MCPManagerViewModel(
            env: [:],
            home: home,
            fileOps: fileOps,
            http: http,
            secrets: InMemorySecretStore(namespace: "dev.cmux.test"),
            projectProvider: ManualActiveProjectProvider(initial: activeProject)
        )
    }
}
