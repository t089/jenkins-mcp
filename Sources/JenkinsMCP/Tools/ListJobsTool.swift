import ArgumentParser
import JenkinsSDK
import MCP

struct ListJobsTool: JenkinsTool {
    static var inputSchema: Value {
        .object([
            "type": "object",
            "properties": [
                "path": .object([
                    "type": "string",
                    "description": """
                    The folder path (e.g. 'folder/subfolder'). Leave empty for root level. \
                    Use forward slashes to separate nested folders.
                    """,
                ])
            ],
            "required": [],
        ])
    }

    let jenkinsClient: JenkinsClient
    let name = "list_jobs"
    let description = """
        List jobs in a folder or at the root level. Returns all jobs and subfolders within the \
        specified Jenkins folder path. Use this to explore the Jenkins job hierarchy, find \
        available jobs, or navigate through folder structures.
        """

    func execute(arguments: [String: Value]) async throws -> [JobSummary] {
        let path = arguments["path"]?.stringValue ?? ""
        let job = try await jenkinsClient.job(at: path).get()
        return job.childJobs
    }
}
