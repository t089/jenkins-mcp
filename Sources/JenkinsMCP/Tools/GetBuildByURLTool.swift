import ArgumentParser
import JenkinsSDK
import MCP

struct GetBuildByURLTool: JenkinsTool {
    static var inputSchema: Value {
        .object([
            "type": "object",
            "properties": [
                "url": .object([
                    "type": "string",
                    "format": "uri",
                    "description": """
                        The Jenkins build URL (e.g., 'https://jenkins.example.com/job/project/123/' or \
                        'https://jenkins.example.com/job/folder/job/subfolder/job/project/456/')
                        """,
                ])
            ],
            "required": ["url"],
        ])
    }

    let jenkinsClient: JenkinsClient
    let name = "get_build_by_url"
    let description = """
        Get build details by URL. Retrieves comprehensive information about a specific Jenkins build including \
        status, duration, parameters, and metadata. Use this when you have a direct build URL from Jenkins. \
        Returns build number, status (SUCCESS, FAILURE, etc.), start time, duration, parameters, and other \
        build metadata.
        """

    func execute(arguments: [String: Value]) async throws -> Build {
        guard let url = arguments["url"]?.stringValue else {
            throw ValidationError("Missing required parameter: url")
        }
        // For now, use the existing method in JobClient.BuildClient
        // This could be improved by adding a builds(byURL:) method to JenkinsClient
        let jobClient = try jenkinsClient.job(byURL: url)
        let build = try await jobClient.builds.get(byURL: url)
        return build
    }
}
