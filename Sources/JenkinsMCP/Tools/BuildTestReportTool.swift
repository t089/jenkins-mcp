import ArgumentParser
import JenkinsSDK
import MCP

#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

struct BuildTestReportTool: JenkinsTool {
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
                "level": .object([
                    "type": "string",
                    "enum": ["summary", "suite", "full"],
                    "description":
                        "Detail level: 'summary' (counts), 'suite' (no tests), 'full' (all). Default: 'suite'",
                ]),
                "status": .object([
                    "type": "string",
                    "enum": ["all", "failed", "passed", "skipped"],
                    "description": "Filter by status. Default: 'all'",
                ]),
                "namePattern": .object([
                    "type": "string",
                    "description":
                        "Regex to filter test names (suite/class/method)",
                ]),
                "maxTests": .object([
                    "type": "integer",
                    "description":
                        "Max test cases (default: 100, level='full' only)",
                ]),
                "maxErrorLength": .object([
                    "type": "integer",
                    "description":
                        "Max length for error details/traces (default: 1000, 0=no limit)",
                ]),
                "limit": .object([
                    "type": "integer",
                    "description":
                        "Max test suites. Default: 50",
                ]),
                "offset": .object([
                    "type": "integer",
                    "description":
                        "Test suites to skip for pagination. Default: 0",
                ]),
            ],
            "required": ["path", "buildNumber"],
        ])
    }

    let jenkinsClient: JenkinsClient
    let name = "get_build_test_report"
    let description = """
        Get build test report with filtering. Returns pass/fail counts, suites, and cases. Null if unavailable.
        """

    func execute(arguments: [String: Value]) async throws -> TestReportResponse? {
        guard let path = arguments["path"]?.stringValue,
            let buildNumber = arguments["buildNumber"]?.intValue
        else {
            throw ValidationError("Missing required parameters: path, buildNumber")
        }

        let level = arguments["level"]?.stringValue ?? "suite"
        let status = arguments["status"]?.stringValue ?? "all"
        let namePattern = arguments["namePattern"]?.stringValue
        let maxTests = arguments["maxTests"]?.intValue ?? 100
        let maxErrorLength = arguments["maxErrorLength"]?.intValue ?? 1000
        let limit = arguments["limit"]?.intValue ?? 50
        let offset = arguments["offset"]?.intValue ?? 0

        // Get the test report from Jenkins
        guard let testReport = try await jenkinsClient.job(at: path).builds.testReport(number: buildNumber) else {
            return nil
        }

        // Apply filtering based on the parameters
        let options = TestReportFilterUtility.FilterOptions(
            level: level,
            status: status,
            namePattern: namePattern,
            maxTests: maxTests,
            maxErrorLength: maxErrorLength,
            limit: limit,
            offset: offset
        )

        return try TestReportFilterUtility.filterTestReport(testReport, options: options)
    }

}
