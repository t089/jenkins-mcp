import ArgumentParser
import JenkinsSDK
import MCP

struct StartBuildTool: JenkinsTool {
    static var inputSchema: Value {
        .object([
            "type": "object",
            "properties": [
                "path": .object([
                    "type": "string",
                    "description":
                        "The job path (e.g. 'folder/subfolder/job'). Use forward slashes to separate nested folders and jobs.",
                ]),
                "parameters": .object([
                    "type": "object",
                    "description":
                        "Build parameters as key-value pairs. Only string values are supported, use \"true\"/\"false\" for booleans, and \"x\" for numbers (where x is the number). If the job has no parameters, this can be omitted.",
                    "additionalProperties": .object([
                        "type": "string"
                    ]),
                ]),
            ],
            "required": ["path"],
        ])
    }

    let jenkinsClient: JenkinsClient
    let name = "start_build"
    let description = """
        Start a build for a job with optional parameters. Returns a queue item reference that can be used to track \
        the build status. The build will be queued and executed according to Jenkins scheduling and resource \
        availability.
        """

    func execute(arguments: [String: Value]) async throws -> QueueItemRef {
        guard let path = arguments["path"]?.stringValue else {
            throw JenkinsAPIError.invalidPath("path is required")
        }

        let parameters: [String: String]
        if let parametersValue = arguments["parameters"]?.objectValue {
            parameters = parametersValue.compactMapValues { $0.stringValue }
        } else {
            parameters = [:]
        }

        return try await jenkinsClient.job(at: path).builds.trigger(parameters: parameters)
    }
}
