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
                    "description": "The job path (e.g. 'folder/subfolder/job')",
                ]),
                "buildNumber": .object([
                    "type": "integer",
                    "description": "The build number (integer, starting from 1 for the first build)",
                ]),
            ],
            "required": ["path", "buildNumber"],
        ])
    }

    let jenkinsClient: JenkinsClient
    let name = "get_build"
    let description =
        "Get detailed information about a specific build, including its status (SUCCESS, FAILURE, ABORTED, etc.), "
        + "duration, timestamp, result, and other metadata. Use this tool when you need to inspect the details of a "
        + "particular build to understand its outcome or gather information for analysis."

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
