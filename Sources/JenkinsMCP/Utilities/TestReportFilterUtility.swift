import JenkinsSDK

#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

struct TestReportFilterUtility {

    struct FilterOptions {
        let level: String
        let status: String
        let namePattern: String?
        let maxTests: Int
        let maxErrorLength: Int
        let limit: Int
        let offset: Int

        init(
            level: String = "suite",
            status: String = "all",
            namePattern: String? = nil,
            maxTests: Int = 100,
            maxErrorLength: Int = 1000,
            limit: Int = 50,
            offset: Int = 0
        ) {
            self.level = level
            self.status = status
            self.namePattern = namePattern
            self.maxTests = maxTests
            self.maxErrorLength = maxErrorLength
            self.limit = limit
            self.offset = offset
        }
    }

    static func filterTestReport(_ report: TestReport, options: FilterOptions) throws -> TestReportResponse {
        let nameRegex = try createNameRegex(from: options.namePattern)
        
        switch options.level {
        case "summary":
            return createSummaryResponse(from: report)
        case "suite":
            return try filterSuiteLevel(report: report, nameRegex: nameRegex, options: options)
        case "full":
            return try filterFullLevel(report: report, nameRegex: nameRegex, options: options)
        default:
            throw ValidationError("Invalid level value: \(options.level). Must be 'summary', 'suite', or 'full'")
        }
    }

    private static func createNameRegex(from pattern: String?) throws -> Regex<AnyRegexOutput>? {
        guard let pattern = pattern else { return nil }
        do {
            return try Regex(pattern)
        } catch {
            throw ValidationError("Invalid regex pattern: \(pattern)")
        }
    }

    private static func matchesNamePattern(_ name: String, regex: Regex<AnyRegexOutput>?) -> Bool {
        guard let regex = regex else { return true }
        return (try? regex.firstMatch(in: name)) != nil
    }

    private static func matchesStatus(_ testCase: TestCase, status: String) -> Bool {
        switch status {
        case "failed": return testCase.isFailed
        case "passed": return testCase.isPassed
        case "skipped": return testCase.isSkipped
        default: return true
        }
    }

    private static func createSummaryResponse(from report: TestReport) -> TestReportResponse {
        return TestReportResponse(
            duration: report.duration,
            failCount: report.failCount,
            passCount: report.passCount,
            skipCount: report.skipCount,
            totalCount: report.totalCount,
            successRate: report.successRate,
            suites: nil
        )
    }

    private static func filterSuiteLevel(
        report: TestReport,
        nameRegex: Regex<AnyRegexOutput>?,
        options: FilterOptions
    ) throws -> TestReportResponse {
        let filteredSuites = filterSuites(report.suites, nameRegex: nameRegex, status: options.status)
        let suiteResponses = filteredSuites.map { transformSuiteToResponse($0, includeCases: false) }
        let paginatedSuites = paginateArray(suiteResponses, limit: options.limit, offset: options.offset)

        return TestReportResponse(
            duration: report.duration,
            failCount: report.failCount,
            passCount: report.passCount,
            skipCount: report.skipCount,
            totalCount: report.totalCount,
            successRate: report.successRate,
            suites: paginatedSuites
        )
    }

    private static func filterSuites(
        _ suites: [TestSuite],
        nameRegex: Regex<AnyRegexOutput>?,
        status: String
    ) -> [TestSuite] {
        return suites.filter { suite in
            guard matchesNamePattern(suite.name, regex: nameRegex) else { return false }
            
            if status != "all" {
                return suite.cases.contains { matchesStatus($0, status: status) }
            }
            return true
        }
    }

    private static func transformSuiteToResponse(_ suite: TestSuite, includeCases: Bool) -> TestSuiteResponse {
        return TestSuiteResponse(
            name: suite.name,
            duration: suite.duration,
            failedCount: suite.failedCount,
            passedCount: suite.passedCount,
            skippedCount: suite.skippedCount,
            cases: includeCases ? [] : nil
        )
    }

    private static func filterFullLevel(
        report: TestReport,
        nameRegex: Regex<AnyRegexOutput>?,
        options: FilterOptions
    ) throws -> TestReportResponse {
        let filteredSuites = filterSuites(report.suites, nameRegex: nameRegex, status: options.status)
        let suiteData = prepareSuiteData(filteredSuites, nameRegex: nameRegex, status: options.status)
        let paginatedSuiteData = paginateArray(suiteData, limit: options.limit, offset: options.offset)
        let detailedSuites = createDetailedSuites(from: paginatedSuiteData, options: options)

        return TestReportResponse(
            duration: report.duration,
            failCount: report.failCount,
            passCount: report.passCount,
            skipCount: report.skipCount,
            totalCount: report.totalCount,
            successRate: report.successRate,
            suites: detailedSuites
        )
    }

    private static func prepareSuiteData(
        _ suites: [TestSuite],
        nameRegex: Regex<AnyRegexOutput>?,
        status: String
    ) -> [(suite: TestSuite, cases: [TestCase])] {
        return suites.compactMap { suite in
            let filteredCases = filterTestCases(in: suite, nameRegex: nameRegex, status: status)
            guard !filteredCases.isEmpty else { return nil }
            return (suite: suite, cases: filteredCases)
        }
    }

    private static func filterTestCases(
        in suite: TestSuite,
        nameRegex: Regex<AnyRegexOutput>?,
        status: String
    ) -> [TestCase] {
        return suite.cases
            .filter { matchesStatus($0, status: status) }
            .filter { matchesNamePattern($0.fullName, regex: nameRegex) }
    }

    private static func createDetailedSuites(
        from suiteData: [(suite: TestSuite, cases: [TestCase])],
        options: FilterOptions
    ) -> [TestSuiteResponse] {
        var totalTestsIncluded = 0
        
        return suiteData.compactMap { data in
            guard totalTestsIncluded < options.maxTests else { return nil }
            
            let remainingSlots = options.maxTests - totalTestsIncluded
            let limitedCases = Array(data.cases.prefix(remainingSlots))
            totalTestsIncluded += limitedCases.count
            
            let testCaseResponses = limitedCases.map { transformTestCase($0, maxErrorLength: options.maxErrorLength) }
            
            return TestSuiteResponse(
                name: data.suite.name,
                duration: data.suite.duration,
                failedCount: data.suite.failedCount,
                passedCount: data.suite.passedCount,
                skippedCount: data.suite.skippedCount,
                cases: testCaseResponses
            )
        }
    }

    private static func transformTestCase(_ testCase: TestCase, maxErrorLength: Int) -> TestCaseResponse {
        return TestCaseResponse(
            className: testCase.className,
            testName: testCase.name,
            duration: testCase.duration,
            status: testCase.status.rawValue,
            errorDetails: truncateString(testCase.errorDetails, maxLength: maxErrorLength),
            errorStackTrace: truncateString(testCase.errorStackTrace, maxLength: maxErrorLength),
            skippedMessage: truncateString(testCase.skippedMessage, maxLength: maxErrorLength)
        )
    }

    private static func paginateArray<T>(_ array: [T], limit: Int, offset: Int) -> [T] {
        let startIndex = min(offset, array.count)
        let endIndex = min(startIndex + limit, array.count)
        return Array(array[startIndex..<endIndex])
    }

    private static func truncateString(_ string: String?, maxLength: Int) -> String? {
        guard let string = string, maxLength > 0 else { return string }
        if string.count <= maxLength {
            return string
        }
        let endIndex = string.index(string.startIndex, offsetBy: maxLength - 3)
        return String(string[..<endIndex]) + "..."
    }
}

struct ValidationError: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }
}

struct TestReportResponse: Codable, Sendable {
    let duration: Double
    let failCount: Int
    let passCount: Int
    let skipCount: Int
    let totalCount: Int
    let successRate: Double
    let suites: [TestSuiteResponse]?
}

struct TestSuiteResponse: Codable, Sendable {
    let name: String
    let duration: Double?
    let failedCount: Int
    let passedCount: Int
    let skippedCount: Int
    let cases: [TestCaseResponse]?
}

struct TestCaseResponse: Codable, Sendable {
    let className: String
    let testName: String
    let duration: Double
    let status: String
    let errorDetails: String?
    let errorStackTrace: String?
    let skippedMessage: String?
}
