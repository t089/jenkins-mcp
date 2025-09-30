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
                    "description": "Queue item ID to cancel (from get_queue)",
                ])
            ],
            "required": ["id"],
        ])
    }

    let jenkinsClient: JenkinsClient
    let name = "cancel_queue_item"
    let description = "Cancel queued build before execution. Removes pending builds from queue."

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
