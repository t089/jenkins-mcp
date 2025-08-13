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
                    "description": """
                    The Jenkins job URL (e.g., 'https://jenkins.example.com/job/my-project/' or \
                    'https://jenkins.example.com/job/folder/job/subfolder/job/my-project/')
                    """,
                ])
            ],
            "required": ["url"],
        ])
    }

    let jenkinsClient: JenkinsClient
    let name = "get_job_by_url"
    let description = """
        Get job details by URL. Retrieves comprehensive information about a Jenkins job including its \
        configuration, recent builds, and status using the job's full URL. Use this tool when you have a \
        Jenkins job URL and need to inspect the job's properties and build history.
        """

    func execute(arguments: [String: Value]) async throws -> Job {
        guard let url = arguments["url"]?.stringValue else {
            throw ValidationError("Missing required parameter: url")
        }
        let job = try await jenkinsClient.job(byURL: url).get()
        return job
    }
}
