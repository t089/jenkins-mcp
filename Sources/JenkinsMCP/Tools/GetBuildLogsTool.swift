import ArgumentParser
import JenkinsSDK
import MCP
import NIOCore

#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

struct GetBuildLogsTool: JenkinsTool {
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
                "maxLines": .object([
                    "type": "integer",
                    "description": "Maximum number of lines to return (default: 200)",
                ]),
                "position": .object([
                    "type": "string",
                    "enum": ["head", "tail"],
                    "description": "Where to take logs from: 'head' for beginning, 'tail' for end (default: 'tail')",
                ]),
            ],
            "required": ["path", "buildNumber"],
        ])
    }

    let jenkinsClient: JenkinsClient
    let name = "get_build_logs"
    let description = """
        Get console output of a build. Use this tool to retrieve Jenkins build logs for debugging failed builds,
        monitoring build progress, or extracting build information. You can get logs from the beginning ('head')
        or end ('tail') of the output, and limit the number of lines returned. Returns structured log data with
        line offsets and total line counts.
        """

    func execute(arguments: [String: Value]) async throws -> LogResponse {
        guard let path = arguments["path"]?.stringValue,
            let buildNumber = arguments["buildNumber"]?.intValue
        else {
            throw ValidationError("Missing required parameters: path, buildNumber")
        }
        let maxLines = arguments["maxLines"]?.intValue ?? 200
        let position = arguments["position"]?.stringValue ?? "tail"

        let fullLogs = try await jenkinsClient.job(at: path).builds.logs(number: buildNumber)

        let lines = fullLogs.split(separator: "\n", omittingEmptySubsequences: false)
        let sampledLines: [Substring]
        let startOffset: Int

        if lines.count <= maxLines {
            sampledLines = Array(lines)
            startOffset = 0
        } else {
            switch position {
            case "head":
                sampledLines = Array(lines.prefix(maxLines))
                startOffset = 0
            case "tail":
                sampledLines = Array(lines.suffix(maxLines))
                startOffset = lines.count - maxLines
            default:
                throw ValidationError("Invalid position value: \(position). Must be 'head' or 'tail'")
            }
        }

        let content = sampledLines.joined(separator: "\n")
        let response = LogResponse(
            line_offset: startOffset,
            max_lines: maxLines,
            available_lines: lines.count,
            content: content
        )
        return response
    }
}

struct GrepBuildLogsTool: JenkinsTool {
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
                "context": .object([
                    "type": "integer",
                    "description": "The number of lines of context to include around matches (default: 0)",
                ]),
                "offset": .object([
                    "type": "integer",
                    "description": "The line offset to start from (default: 0)",
                ]),
                "maxLines": .object([
                    "type": "integer",
                    "description": "Maximum number of matched lines to return (default: 200)",
                ]),
                "pattern": .object([
                    "type": "string",
                    "description": """
                        The pattern to search for in the logs. Supports regular expressions
                        (e.g., 'ERROR', 'Test.*failed', 'BUILD SUCCESSFUL').
                        """,
                ]),
            ],
            "required": ["path", "buildNumber", "pattern"],
        ])
    }

    let jenkinsClient: JenkinsClient
    let name = "grep_build_logs"
    let description = """
        Grep the console output of a build for a given pattern. Use this tool to search through Jenkins build logs
        for specific error messages, warnings, test results, or other patterns. More efficient than getting full logs
        when you're looking for specific content. Supports regex patterns and includes configurable context lines
        around matches. Returns matched lines with line numbers and optional surrounding context.
        """

    func execute(arguments: [String: Value]) async throws -> [GrepLine] {
        guard let path = arguments["path"]?.stringValue,
            let buildNumber = arguments["buildNumber"]?.intValue
        else {
            throw ValidationError("Missing required parameters: path, buildNumber")
        }
        let context = arguments["context"]?.intValue ?? 0
        let offset = arguments["offset"]?.intValue ?? 0
        let maxLines = arguments["maxLines"]?.intValue ?? 200
        guard let pattern = arguments["pattern"]?.stringValue else {
            throw ValidationError("Missing required parameter: pattern")
        }

        let grepOptions = LogGrepUtility.GrepOptions(
            pattern: pattern,
            context: context,
            offset: offset,
            maxLines: maxLines
        )

        let matches = try await jenkinsClient.job(at: path).builds
            .streamLogs(number: buildNumber) { _, lines in
                return try await LogGrepUtility.grepLines(from: lines, options: grepOptions)
            }

        return matches
    }
}

struct GrepLine: Codable, Sendable {
    var lineNumber: Int
    var match: String?
    var context: String?
}
