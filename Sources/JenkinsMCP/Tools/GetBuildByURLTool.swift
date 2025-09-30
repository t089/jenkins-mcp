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
                    "description": "Jenkins build URL",
                ])
            ],
            "required": ["url"],
        ])
    }

    let jenkinsClient: JenkinsClient
    let name = "get_build_by_url"
    let description = "Get build details by URL. Returns status, duration, parameters, and metadata."

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
