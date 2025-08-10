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
                    "description": """
                        The job path (e.g. 'folder/subfolder/job'). Use forward slashes to separate nested folders. \
                        For jobs at the root level, use just the job name.
                        """,
                ])
            ],
            "required": ["path"],
        ])
    }

    let jenkinsClient: JenkinsClient
    let name = "get_job"
    let description = """
        Get job details by path. Returns comprehensive job information including configuration, \
        last build status, health metrics, and build history. Use this to inspect job settings, \
        check current status, or gather information before performing operations.
        """

    func execute(arguments: [String: Value]) async throws -> Job {
        guard let path = arguments["path"]?.stringValue else {
            throw ValidationError("Missing required parameter: path")
        }
        let job = try await jenkinsClient.job(at: path).get()
        return job
    }
}
