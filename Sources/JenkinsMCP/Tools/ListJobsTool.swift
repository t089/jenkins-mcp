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
                    "description": "Folder path (e.g. 'folder/subfolder'). Empty for root level",
                ])
            ],
            "required": [],
        ])
    }

    let jenkinsClient: JenkinsClient
    let name = "list_jobs"
    let description = "List jobs in folder or root level. Returns jobs and subfolders"

    func execute(arguments: [String: Value]) async throws -> [JobSummary] {
        let path = arguments["path"]?.stringValue ?? ""
        let job = try await jenkinsClient.job(at: path).get()
        return job.childJobs
    }
}
