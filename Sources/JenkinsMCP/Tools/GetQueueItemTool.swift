import ArgumentParser
import JenkinsSDK
import MCP

struct GetQueueItemTool: JenkinsTool {
    static var inputSchema: Value {
        .object([
            "type": "object",
            "properties": [
                "queueItemId": .object([
                    "type": .string("integer")
                ])
            ],
            "required": ["queueItemId"],
        ])
    }

    let jenkinsClient: JenkinsClient
    let name = "get_queue_item"
    let description = "Get build queue item details. Returns job name, queue reason, and wait time."

    func execute(arguments: [String: Value]) async throws -> QueueItem {
        guard let queueItemId = arguments["queueItemId"]?.intValue else {
            throw ValidationError("Missing required parameter: queueItemId")
        }
        return try await jenkinsClient.queue.item(forId: queueItemId)
    }
}
