import ArgumentParser
import JenkinsSDK
import MCP

struct GetJobByURLTool: JenkinsTool {
    static var inputSchema: Value {
        .object([
            "type": "object",
            "properties": [
                "url": .object([
                    "type": "string",
                    "format": "uri",
                    "description": "Jenkins job URL",
                ])
            ],
            "required": ["url"],
        ])
    }

    let jenkinsClient: JenkinsClient
    let name = "get_job_by_url"
    let description = "Get job details by URL. Returns configuration, builds, and status."

    func execute(arguments: [String: Value]) async throws -> Job {
        guard let url = arguments["url"]?.stringValue else {
            throw ValidationError("Missing required parameter: url")
        }
        let job = try await jenkinsClient.job(byURL: url).get()
        return job
    }
}
