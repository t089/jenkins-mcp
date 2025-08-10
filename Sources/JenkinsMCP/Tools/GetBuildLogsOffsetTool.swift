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
                    "description": "The job path (e.g. 'folder/subfolder/job')",
                ]),
                "buildNumber": .object([
                    "type": "integer",
                    "description": "The build number",
                ]),
                "offset": .object([
                    "type": "integer",
                    "description":
                        "Line offset to start from (0-based). Use 0 for first line, 100 to skip first 100 lines, etc.",
                ]),
                "maxLines": .object([
                    "type": "integer",
                    "description": "Maximum number of lines to return (default: 200)",
                ]),
            ],
            "required": ["path", "buildNumber", "offset"],
        ])
    }

    let jenkinsClient: JenkinsClient
    let name = "get_build_logs_offset"
    let description = """
        Get console output of a build from specific offset. Use this when you need to read build logs starting from a \
        particular line number, which is useful for pagination, continuing from where you left off, or focusing on \
        specific sections of large log files. The offset is 0-based (first line is offset 0). For general log reading, \
        use get_build_logs instead.
        """

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
