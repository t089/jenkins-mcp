import ArgumentParser
import JenkinsSDK
import MCP

struct GetBuildTool: JenkinsTool {
    static var inputSchema: Value {
        .object([
            "type": "object",
            "properties": [
                "path": .object([
                    "type": "string",
                    "description": "Job path (e.g. 'folder/subfolder/job')",
                ]),
                "buildNumber": .object([
                    "type": "integer",
                    "description": "Build number",
                ]),
            ],
            "required": ["path", "buildNumber"],
        ])
    }

    let jenkinsClient: JenkinsClient
    let name = "get_build"
    let description =
        "Get detailed build information including status, duration, timestamp, and metadata."

    func execute(arguments: [String: Value]) async throws -> Build {
        guard let path = arguments["path"]?.stringValue,
            let buildNumber = arguments["buildNumber"]?.intValue
        else {
            throw ValidationError("Missing required parameters: path, buildNumber")
        }
        let build = try await jenkinsClient.job(at: path).builds.get(number: buildNumber)
        return build
    }
}
