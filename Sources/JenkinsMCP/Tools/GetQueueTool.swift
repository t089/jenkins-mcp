import ArgumentParser
import JenkinsSDK
import MCP

struct GetQueueTool: JenkinsTool {
    static var inputSchema: Value {
        .object([
            "type": "object",
            "properties": [:],
            "required": [],
        ])
    }

    let jenkinsClient: JenkinsClient
    let name = "get_queue"
    let description = "Get current build queue status. Returns pending builds with position, wait time, blocking reasons, and parameters."

    func execute(arguments: [String: Value]) async throws -> QueueInfo {
        return try await jenkinsClient.queue.info()
    }
}
