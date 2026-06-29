// ActiveProjectProviding.swift
import Foundation

/// Supplies the active project directory (absolute path) that MCP enablement is keyed to.
/// Claude Code has no global enable/disable, so a non-nil value is required to toggle.
public protocol ActiveProjectProviding: AnyObject {
    var activeProjectPath: String? { get }
}

/// MVP provider: the user picks a project directory explicitly (see CmuxSettingsUI.MCPServersSection).
/// Auto-binding to the focused cmux session's cwd is a later slice.
public final class ManualActiveProjectProvider: ActiveProjectProviding {
    public private(set) var activeProjectPath: String?
    public init(initial: String? = nil) { self.activeProjectPath = initial }
    public func choose(_ path: String?) { self.activeProjectPath = path }
}
