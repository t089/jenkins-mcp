import ArgumentParser
import JenkinsSDK
import MCP

struct GetJobTool: JenkinsTool {
    static var inputSchema: Value {
        .object([
            "type": "object",
            "properties": [
                "path": .object([
                    "type": "string",
                    "description": "Job path (e.g. 'folder/subfolder/job')",
                ])
            ],
            "required": ["path"],
        ])
    }

    let jenkinsClient: JenkinsClient
    let name = "get_job"
    let description = "Get job details by path. Returns configuration, build status, health metrics, history, and child jobs (if available)."

    func execute(arguments: [String: Value]) async throws -> Job {
        guard let path = arguments["path"]?.stringValue else {
            throw ValidationError("Missing required parameter: path")
        }
        let job = try await jenkinsClient.job(at: path).get()
        return job
    }
}
