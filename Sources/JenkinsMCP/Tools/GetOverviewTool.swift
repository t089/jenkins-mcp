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
    let description = """
        Get high-level overview information about the Jenkins server instance. Returns server details including 
        version, node information, job counts, and system status. This is useful for understanding the Jenkins 
        environment before performing other operations or when troubleshooting connectivity issues. Use this as a 
        first step when connecting to a new Jenkins instance to understand its configuration and verify connectivity.
        """

    func execute(arguments: [String: Value]) async throws -> JenkinsOverview {
        return try await jenkinsClient.get()
    }
}
