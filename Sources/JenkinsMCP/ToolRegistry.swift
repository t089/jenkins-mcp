import MCP
import Synchronization

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

final class ToolRegistry: Sendable {
    private let tools: Mutex<[String: any ToolProtocol]> = Mutex([:])

    func register(_ tool: any ToolProtocol) {
        self.tools.withLock { $0[tool.name] = tool }
    }

    func register(_ tools: [any ToolProtocol]) {
        self.tools.withLock { state in tools.forEach { state[$0.name] = $0 } }
    }
    
    func register(_ tools: any ToolProtocol...) {
        self.register(tools)
    }

    let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys ]
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    func callTool(named name: String, with arguments: [String: Value]) async throws -> CallTool.Result {
        guard let tool = tools.withLock({ $0[name] }) else {
            throw MCPError.methodNotFound(("Tool not found: \(name)"))
        }
        let output = try await tool.execute(arguments: arguments)
        return CallTool.Result(content: [try .json(output, encoder: encoder)])
    }

    func toolDefinitions() -> [Tool] {
        let tools = tools.withLock { $0.values }
        return tools.map { tool in
            Tool(name: tool.name, description: tool.description, inputSchema: type(of: tool).inputSchema)
        }
    }
}