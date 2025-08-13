import ArgumentParser
import JenkinsSDK
import MCP

struct CancelQueueItemTool: JenkinsTool {
    static var inputSchema: Value {
        .object([
            "type": "object",
            "properties": [
                "id": .object([
                    "type": "integer",
                    "description": """
                    The queue item ID to cancel. You can find queue item IDs using the get_queue tool, \
                    which lists all currently queued builds with their IDs.
                    """,
                ])
            ],
            "required": ["id"],
        ])
    }

    let jenkinsClient: JenkinsClient
    let name = "cancel_queue_item"
    let description = """
        Cancel a queued build item that is waiting to start execution. Use this tool when you need to \
        remove a build from the Jenkins queue before it begins running. Queue items are builds that have \
        been scheduled but haven't started yet due to resource constraints or dependencies.
        """

    struct CancelQueueItemResult: Codable, Sendable {
        let success: Bool
        let message: String
    }

    func execute(arguments: [String: Value]) async throws -> CancelQueueItemResult {
        guard let id = arguments["id"]?.intValue else {
            throw JenkinsAPIError.invalidPath("id is required")
        }

        try await jenkinsClient.queue.cancel(id: id)

        return CancelQueueItemResult(
            success: true,
            message: "Queue item \(id) has been cancelled"
        )
    }
}
