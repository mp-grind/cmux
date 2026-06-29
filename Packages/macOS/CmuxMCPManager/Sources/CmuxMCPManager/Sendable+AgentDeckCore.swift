import AgentDeckCore

// AgentDeckCore predates Swift 6 strict concurrency. MCPServer and MCPHealthProber are
// value types (copied when sent across actors), so sending them off the main actor is safe.
extension MCPServer: @retroactive @unchecked Sendable {}
extension MCPHealthProber: @retroactive @unchecked Sendable {}
