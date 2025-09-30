import ArgumentParser
import JenkinsSDK
import MCP

struct StopBuildTool: JenkinsTool {
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
                    "description": "Build number to stop",
                ]),
            ],
            "required": ["path", "buildNumber"],
        ])
    }

    let jenkinsClient: JenkinsClient
    let name = "stop_build"
    let description = "Stop running build. Terminates execution and marks as aborted. Only applies to active builds."

    struct StopBuildResult: Codable, Sendable {
        let success: Bool
        let message: String
    }

    func execute(arguments: [String: Value]) async throws -> StopBuildResult {
        guard let path = arguments["path"]?.stringValue else {
            throw JenkinsAPIError.invalidPath("path is required")
        }

        guard let buildNumber = arguments["buildNumber"]?.intValue else {
            throw JenkinsAPIError.invalidPath("buildNumber is required")
        }

        try await jenkinsClient.job(at: path).builds.stop(number: buildNumber)

        return StopBuildResult(
            success: true,
            message: "Build \(buildNumber) for job '\(path)' has been stopped"
        )
    }
}
