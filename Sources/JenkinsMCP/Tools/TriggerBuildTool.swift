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
                    "description": "Job path (e.g. 'folder/subfolder/job')",
                ]),
                "parameters": .object([
                    "type": "object",
                    "description":
                        "Build parameters as key-value pairs (strings only: \"true\"/\"false\" for bools, \"123\" for numbers)",
                    "additionalProperties": .object([
                        "type": "string"
                    ]),
                ]),
                "waitForBuildToStart": .object([
                    "type": "boolean",
                    "default": false,
                    "description":
                        "Wait for build to start (max 30s). If false, returns immediately",
                ]),
            ],
            "required": ["path"],
        ])
    }

    let jenkinsClient: JenkinsClient
    let name = "trigger_build"
    let description =
        "Trigger job build with optional parameters. Returns queue item reference for tracking."

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

        while item.executable?.number == nil && .now < deadline {
            try await Task.sleep(for: .seconds(1))
            item = try await jenkinsClient.queue.item(forId: item.id)
        }

        return item
    }
}
