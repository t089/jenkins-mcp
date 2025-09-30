import ArgumentParser
import JenkinsSDK
import MCP

struct GetOverviewTool: JenkinsTool {
    static var inputSchema: Value {
        .object([
            "type": "object",
            "properties": [:],
            "required": [],
        ])
    }

    let jenkinsClient: JenkinsClient
    let name = "get_overview"
    let description = "Get Jenkins server overview. Returns version, nodes, job counts, and system status."

    func execute(arguments: [String: Value]) async throws -> JenkinsOverview {
        return try await jenkinsClient.get()
    }
}
