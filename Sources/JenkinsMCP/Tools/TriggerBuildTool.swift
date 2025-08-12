import ArgumentParser
import JenkinsSDK
import MCP

struct TriggerBuildTool: JenkinsTool {
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
                "waitForBuildToStart": .object([
                    "type": "boolean",
                    "default": false,
                    "description": """
                        If true, the tool will wait for the build to start and return the queue item \
                        reference. If false, it will return immediately with the queue item reference. \
                        The tool will wait for up to 30 seconds for the build to start before returning.
                        """
                ]),
            ],
            "required": ["path"],
        ])
    }

    let jenkinsClient: JenkinsClient
    let name = "trigger_build"
    let description = """
        Trigger a build for a job with optional parameters. Returns a queue item reference that can be used to track \
        the build status using the get_queue_item tool. The build will be queued and executed according to Jenkins scheduling and resource \
        availability.
        """

    func execute(arguments: [String: Value]) async throws -> QueueItem {
        guard let path = arguments["path"]?.stringValue else {
            throw JenkinsAPIError.invalidPath("path is required")
        }

        let parameters: [String: String]
        if let parametersValue = arguments["parameters"]?.objectValue {
            parameters = parametersValue.compactMapValues { $0.stringValue }
        } else {
            parameters = [:]
        }

        let ref = try await jenkinsClient.job(at: path).builds.trigger(parameters: parameters)
        var item = try await jenkinsClient.queue.item(referencedBy: ref)
        
        let waitForStart = arguments["waitForBuildToStart"]?.boolValue ?? false

        if !waitForStart {
            return item
        }

        let deadline = ContinuousClock.now + .seconds(30)

        while item.executable?.number == nil && .now < deadline{
            try await Task.sleep(for: .seconds(1))
            item = try await jenkinsClient.queue.item(forId: item.id)
        }

        return item
    }
}
