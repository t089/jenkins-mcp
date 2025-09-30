import ArgumentParser
import JenkinsSDK
import MCP

#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

struct GetBuildLogsOffsetTool: JenkinsTool {
    static var inputSchema: Value {
        .object([
            "type": "object",
            "properties": [
                "path": .object([
                    "type": "string",
                    "description": "Job path (e.g. 'folder/subfolder/job')",
                ]),
                "buildNumber": .object([
                    "type": "integer",
                    "description": "Build number",
                ]),
                "offset": .object([
                    "type": "integer",
                    "description": "Line offset (0-based). 0=first line, 100=skip first 100",
                ]),
                "maxLines": .object([
                    "type": "integer",
                    "description": "Max lines to return (default: 200)",
                ]),
            ],
            "required": ["path", "buildNumber", "offset"],
        ])
    }

    let jenkinsClient: JenkinsClient
    let name = "get_build_logs_offset"
    let description =
        "Get build logs from specific offset (0-based). For pagination or large log files. Use get_build_logs for general reading."

    func execute(arguments: [String: Value]) async throws -> LogResponse {
        guard let path = arguments["path"]?.stringValue,
            let buildNumber = arguments["buildNumber"]?.intValue,
            let offset = arguments["offset"]?.intValue
        else {
            throw ValidationError("Missing required parameters: path, buildNumber, offset")
        }
        let maxLines = arguments["maxLines"]?.intValue ?? 200

        let fullLogs = try await jenkinsClient.job(at: path).builds.logs(number: buildNumber)

        let lines = fullLogs.split(separator: "\n", omittingEmptySubsequences: false)

        guard offset >= 0 else {
            throw ValidationError("Offset must be non-negative")
        }

        let content: String
        let actualOffset: Int

        if offset >= lines.count {
            content = ""
            actualOffset = offset
        } else {
            let endIndex = min(offset + maxLines, lines.count)
            let sampledLines = Array(lines[offset..<endIndex])
            content = sampledLines.joined(separator: "\n")
            actualOffset = offset
        }

        let response = LogResponse(
            line_offset: actualOffset,
            max_lines: maxLines,
            available_lines: lines.count,
            content: content
        )
        return response
    }
}
