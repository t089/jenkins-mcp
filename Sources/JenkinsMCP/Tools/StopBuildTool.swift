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
                    "description": "The job path (e.g. 'folder/subfolder/job')",
                ]),
                "buildNumber": .object([
                    "type": "integer",
                    "description": "The build number to stop",
                ]),
            ],
            "required": ["path", "buildNumber"],
        ])
    }

    let jenkinsClient: JenkinsClient
    let name = "stop_build"
    let description = """
        Stop a running build for a Jenkins job. This action immediately terminates the build execution and marks it as \
        aborted. Use this when you need to cancel a build that is taking too long, consuming too many resources, or was \
        started with incorrect parameters. Note that only actively running builds can be stopped - completed, failed, or \
        already aborted builds cannot be stopped.
        """

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
