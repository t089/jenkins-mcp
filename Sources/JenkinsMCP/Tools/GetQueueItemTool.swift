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
    let description = """
        Get information about a specific item in the Jenkins build queue. This includes details such as the job name,
        the reason for being queued, and the time spent in the queue. This is useful for monitoring and managing
        Jenkins jobs, especially in environments with high build activity.
        """

    func execute(arguments: [String: Value]) async throws -> QueueItem {
        guard let queueItemId = arguments["queueItemId"]?.intValue else {
            throw ValidationError("Missing required parameter: queueItemId")
        }
        return try await jenkinsClient.queue.item(forId: queueItemId)
    }
}
