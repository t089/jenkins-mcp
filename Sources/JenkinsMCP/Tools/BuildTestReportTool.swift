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
                    "description": "The job path (e.g. 'folder/subfolder/job')",
                ]),
                "buildNumber": .object([
                    "type": "integer",
                    "description": "The build number",
                ]),
                "level": .object([
                    "type": "string",
                    "enum": ["summary", "suite", "full"],
                    "description":
                        "Output detail level: 'summary' for overall counts, 'suite' for test suites without individual tests, 'full' for complete details (default: 'suite')",
                ]),
                "status": .object([
                    "type": "string",
                    "enum": ["all", "failed", "passed", "skipped"],
                    "description": "Filter tests by status (default: 'all')",
                ]),
                "namePattern": .object([
                    "type": "string",
                    "description":
                        "Optional regex pattern to filter test names (applies to suite names or test class/method names)",
                ]),
                "maxTests": .object([
                    "type": "integer",
                    "description":
                        "Maximum number of test cases to return (default: 100, only applies when level is 'full')",
                ]),
                "maxErrorLength": .object([
                    "type": "integer",
                    "description":
                        "Maximum length for error details and stack traces (default: 1000, 0 = no truncation)",
                ]),
                "limit": .object([
                    "type": "integer",
                    "description":
                        "Maximum number of test suites to return (default: 50)",
                ]),
                "offset": .object([
                    "type": "integer",
                    "description":
                        "Number of test suites to skip for pagination (default: 0)",
                ]),
            ],
            "required": ["path", "buildNumber"],
        ])
    }

    let jenkinsClient: JenkinsClient
    let name = "get_build_test_report"
    let description = """
        Get test report for a build with filtering options to control output size. Returns test results including
        pass/fail counts, test suites, and individual test cases. Use filtering options to reduce context size
        for large test suites. Returns null if no test report is available for the build.
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
