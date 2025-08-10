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
    let description = """
        Get the current Jenkins build queue status and information. Returns details about all pending builds including 
        queue position, estimated wait time, blocking reasons, and build parameters. Use this to monitor build pipeline 
        health, diagnose delays, identify resource constraints, or verify that triggered builds are properly queued.
        """

    func execute(arguments: [String: Value]) async throws -> QueueInfo {
        return try await jenkinsClient.queue.info()
    }
}
