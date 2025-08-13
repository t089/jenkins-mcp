import Testing

@testable import JenkinsMCP
@testable import JenkinsSDK

struct TestReportFilterUtilityTests {

    // MARK: - Summary Level Tests

    @Test func testSummaryLevel() throws {
        let testReport = createSampleTestReport()
        let options = TestReportFilterUtility.FilterOptions(level: "summary")

        let result = try TestReportFilterUtility.filterTestReport(testReport, options: options)

        #expect(result.duration == 10.0)
        #expect(result.failCount == 1)
        #expect(result.passCount == 2)
        #expect(result.skipCount == 1)
        #expect(result.totalCount == 4)
        #expect(result.suites == nil)
    }

    // MARK: - Suite Level Tests

    @Test func testSuiteLevelAllStatus() throws {
        let testReport = createSampleTestReport()
        let options = TestReportFilterUtility.FilterOptions(level: "suite", status: "all")

        let result = try TestReportFilterUtility.filterTestReport(testReport, options: options)

        #expect(result.suites?.count == 2)
        #expect(result.suites?[0].name == "Suite1")
        #expect(result.suites?[0].cases == nil)
        #expect(result.suites?[1].name == "Suite2")
        #expect(result.suites?[1].cases == nil)
    }

    @Test func testSuiteLevelFailedStatus() throws {
        let testReport = createSampleTestReport()
        let options = TestReportFilterUtility.FilterOptions(level: "suite", status: "failed")

        let result = try TestReportFilterUtility.filterTestReport(testReport, options: options)

        #expect(result.suites?.count == 1)
        #expect(result.suites?[0].name == "Suite1")
        #expect(result.suites?[0].failedCount == 1)
    }

    @Test func testSuiteLevelPassedStatus() throws {
        let testReport = createSampleTestReport()
        let options = TestReportFilterUtility.FilterOptions(level: "suite", status: "passed")

        let result = try TestReportFilterUtility.filterTestReport(testReport, options: options)

        #expect(result.suites?.count == 2)
        // Both suites have passed tests
        #expect(result.suites?[0].name == "Suite1")
        #expect(result.suites?[1].name == "Suite2")
    }

    @Test func testSuiteLevelSkippedStatus() throws {
        let testReport = createSampleTestReport()
        let options = TestReportFilterUtility.FilterOptions(level: "suite", status: "skipped")

        let result = try TestReportFilterUtility.filterTestReport(testReport, options: options)

        #expect(result.suites?.count == 1)
        #expect(result.suites?[0].name == "Suite2")
        #expect(result.suites?[0].skippedCount == 1)
    }

    // MARK: - Pagination Tests

    @Test func testSuiteLevelPagination() throws {
        let testReport = createLargeTestReport()
        let options = TestReportFilterUtility.FilterOptions(level: "suite", limit: 2, offset: 1)

        let result = try TestReportFilterUtility.filterTestReport(testReport, options: options)

        #expect(result.suites?.count == 2)
        #expect(result.suites?[0].name == "Suite2")
        #expect(result.suites?[1].name == "Suite3")
    }

    @Test func testSuiteLevelPaginationOffsetBeyondBounds() throws {
        let testReport = createSampleTestReport()
        let options = TestReportFilterUtility.FilterOptions(level: "suite", limit: 10, offset: 5)

        let result = try TestReportFilterUtility.filterTestReport(testReport, options: options)

        #expect(result.suites?.count == 0)
    }

    // MARK: - Full Level Tests

    @Test func testFullLevelWithAllStatus() throws {
        let testReport = createSampleTestReport()
        let options = TestReportFilterUtility.FilterOptions(level: "full", status: "all")

        let result = try TestReportFilterUtility.filterTestReport(testReport, options: options)

        #expect(result.suites?.count == 2)
        #expect(result.suites?[0].cases?.count == 2)  // Suite1 has 2 tests
        #expect(result.suites?[1].cases?.count == 2)  // Suite2 has 2 tests
    }

    @Test func testFullLevelWithFailedStatus() throws {
        let testReport = createSampleTestReport()
        let options = TestReportFilterUtility.FilterOptions(level: "full", status: "failed")

        let result = try TestReportFilterUtility.filterTestReport(testReport, options: options)

        #expect(result.suites?.count == 1)
        #expect(result.suites?[0].name == "Suite1")
        #expect(result.suites?[0].cases?.count == 1)  // Only failed test
        #expect(result.suites?[0].cases?[0].status == "FAILED")
    }

    // MARK: - Error Truncation Tests

    @Test func testErrorTruncation() throws {
        let testReport = createTestReportWithLongErrors()
        let options = TestReportFilterUtility.FilterOptions(level: "full", maxErrorLength: 10)

        let result = try TestReportFilterUtility.filterTestReport(testReport, options: options)

        #expect(result.suites?.count == 1)
        let testCase = result.suites?[0].cases?[0]
        #expect(testCase?.errorDetails == "Very lo...")
        #expect(testCase?.errorStackTrace == "Stack t...")
    }

    @Test func testErrorTruncationDisabled() throws {
        let testReport = createTestReportWithLongErrors()
        let options = TestReportFilterUtility.FilterOptions(level: "full", maxErrorLength: 0)

        let result = try TestReportFilterUtility.filterTestReport(testReport, options: options)

        #expect(result.suites?.count == 1)
        let testCase = result.suites?[0].cases?[0]
        #expect(testCase?.errorDetails == "Very long error message that should not be truncated")
        #expect(testCase?.errorStackTrace == "Stack trace that is also very long and detailed")
    }

    // MARK: - Name Pattern Tests

    @Test func testNamePatternFiltering() throws {
        let testReport = createSampleTestReport()
        let options = TestReportFilterUtility.FilterOptions(level: "suite", namePattern: "Suite1")

        let result = try TestReportFilterUtility.filterTestReport(testReport, options: options)

        #expect(result.suites?.count == 1)
        #expect(result.suites?[0].name == "Suite1")
    }

    @Test func testInvalidRegexPattern() throws {
        let testReport = createSampleTestReport()
        let options = TestReportFilterUtility.FilterOptions(level: "suite", namePattern: "[invalid")

        #expect {
            try TestReportFilterUtility.filterTestReport(testReport, options: options)
        } throws: { error in
            if let validationError = error as? ValidationError {
                return validationError.message.contains("Invalid regex pattern")
            }
            return false
        }
    }

    // MARK: - Max Tests Limit Tests

    @Test func testMaxTestsLimit() throws {
        let testReport = createLargeTestReport()
        let options = TestReportFilterUtility.FilterOptions(level: "full", maxTests: 3)

        let result = try TestReportFilterUtility.filterTestReport(testReport, options: options)

        let totalTests =
            result.suites?
            .reduce(0) { sum, suite in
                sum + (suite.cases?.count ?? 0)
            } ?? 0

        #expect(totalTests <= 3)
    }

    // MARK: - Invalid Level Tests

    @Test func testInvalidLevel() throws {
        let testReport = createSampleTestReport()
        let options = TestReportFilterUtility.FilterOptions(level: "invalid")

        #expect {
            try TestReportFilterUtility.filterTestReport(testReport, options: options)
        } throws: { error in
            if let validationError = error as? ValidationError {
                return validationError.message.contains("Invalid level value")
            }
            return false
        }
    }
}

// MARK: - Test Data Helpers

extension TestReportFilterUtilityTests {

    private func createSampleTestReport() -> TestReport {
        let testCase1 = TestCase(
            age: 0,
            className: "TestClass1",
            duration: 1.0,
            failedSince: 0,
            name: "testMethod1",
            skipped: false,
            status: .failed,
            testActions: nil,
            errorDetails: "Test failed",
            errorStackTrace: "Stack trace here",
            properties: nil,
            skippedMessage: nil,
            stderr: nil,
            stdout: nil
        )

        let testCase2 = TestCase(
            age: 0,
            className: "TestClass1",
            duration: 2.0,
            failedSince: 0,
            name: "testMethod2",
            skipped: false,
            status: .passed
        )

        let testCase3 = TestCase(
            age: 0,
            className: "TestClass2",
            duration: 3.0,
            failedSince: 0,
            name: "testMethod3",
            skipped: false,
            status: .passed
        )

        let testCase4 = TestCase(
            age: 0,
            className: "TestClass2",
            duration: 0.0,
            failedSince: 0,
            name: "testMethod4",
            skipped: true,
            status: .skipped,
            skippedMessage: "Test skipped"
        )

        let suite1 = TestSuite(
            name: "Suite1",
            cases: [testCase1, testCase2],
            duration: 5.0,
            id: "suite1"
        )

        let suite2 = TestSuite(
            name: "Suite2",
            cases: [testCase3, testCase4],
            duration: 5.0,
            id: "suite2"
        )

        return TestReport(
            duration: 10.0,
            failCount: 1,
            passCount: 2,
            skipCount: 1,
            suites: [suite1, suite2]
        )
    }

    private func createLargeTestReport() -> TestReport {
        var suites: [TestSuite] = []

        for i in 1...5 {
            let testCase = TestCase(
                age: 0,
                className: "TestClass\(i)",
                duration: 1.0,
                failedSince: 0,
                name: "testMethod\(i)",
                skipped: false,
                status: .passed
            )

            let suite = TestSuite(
                name: "Suite\(i)",
                cases: [testCase],
                duration: 1.0,
                id: "suite\(i)"
            )

            suites.append(suite)
        }

        return TestReport(
            duration: 5.0,
            failCount: 0,
            passCount: 5,
            skipCount: 0,
            suites: suites
        )
    }

    private func createTestReportWithLongErrors() -> TestReport {
        let testCase = TestCase(
            age: 0,
            className: "TestClass",
            duration: 1.0,
            failedSince: 0,
            name: "testMethod",
            skipped: false,
            status: .failed,
            errorDetails: "Very long error message that should not be truncated",
            errorStackTrace: "Stack trace that is also very long and detailed"
        )

        let suite = TestSuite(
            name: "Suite1",
            cases: [testCase],
            duration: 1.0,
            id: "suite1"
        )

        return TestReport(
            duration: 1.0,
            failCount: 1,
            passCount: 0,
            skipCount: 0,
            suites: [suite]
        )
    }
}
