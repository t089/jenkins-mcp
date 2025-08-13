import Testing

@testable import JenkinsSDK

#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

struct TestReportTests {

    @Test func testReportModelDecoding() throws {
        let jsonData = """
            {
                "duration": 123.45,
                "failCount": 2,
                "passCount": 8,
                "skipCount": 1,
                "suites": [
                    {
                        "name": "TestSuite1",
                        "duration": 50.0,
                        "id": "suite1",
                        "timestamp": "2024-01-01T10:00:00Z",
                        "cases": [
                            {
                                "className": "com.example.TestClass",
                                "name": "testMethod1",
                                "duration": 10.5,
                                "status": "PASSED",
                                "age": 0,
                                "failedSince": 0,
                                "errorDetails": null,
                                "errorStackTrace": null,
                                "skipped": false,
                                "skippedMessage": null
                            },
                            {
                                "className": "com.example.TestClass",
                                "name": "testMethod2",
                                "duration": 5.2,
                                "status": "FAILED",
                                "age": 1,
                                "failedSince": 123,
                                "errorDetails": "Test assertion failed",
                                "errorStackTrace": "java.lang.AssertionError: Test assertion failed\\n\\tat com.example.TestClass.testMethod2(TestClass.java:25)",
                                "skipped": false,
                                "skippedMessage": null
                            }
                        ],
                        "stderr": null,
                        "stdout": null
                    }
                ]
            }
            """
            .data(using: .utf8)!

        let decoder = JSONDecoder()
        let testReport = try decoder.decode(TestReport.self, from: jsonData)

        #expect(testReport.duration == 123.45)
        #expect(testReport.failCount == 2)
        #expect(testReport.passCount == 8)
        #expect(testReport.skipCount == 1)
        #expect(testReport.totalCount == 11)
        #expect(testReport.hasFailures == true)
        #expect(abs(testReport.successRate - (8.0 / 11.0)) < 0.001)

        #expect(testReport.suites.count == 1)
        let suite = testReport.suites[0]
        #expect(suite.name == "TestSuite1")
        #expect(suite.duration == 50.0)
        #expect(suite.cases.count == 2)

        let passedCase = suite.cases[0]
        #expect(passedCase.className == "com.example.TestClass")
        #expect(passedCase.name == "testMethod1")
        #expect(passedCase.status == .passed)
        #expect(passedCase.isPassed == true)
        #expect(passedCase.isFailed == false)
        #expect(passedCase.isSkipped == false)
        #expect(passedCase.fullName == "com.example.TestClass.testMethod1")

        let failedCase = suite.cases[1]
        #expect(failedCase.status == .failed)
        #expect(failedCase.isPassed == false)
        #expect(failedCase.isFailed == true)
        #expect(failedCase.errorDetails == "Test assertion failed")
        #expect(failedCase.errorStackTrace?.contains("AssertionError") == true)
    }

    @Test func testStatusValues() {
        #expect(TestStatus.passed.rawValue == "PASSED")
        #expect(TestStatus.failed.rawValue == "FAILED")
        #expect(TestStatus.skipped.rawValue == "SKIPPED")
        #expect(TestStatus.fixed.rawValue == "FIXED")
        #expect(TestStatus.regression.rawValue == "REGRESSION")

        // Test equality
        #expect(TestStatus.passed == TestStatus.passed)
        #expect(TestStatus.passed != TestStatus.failed)

        // Test RawRepresentable
        let customStatus = TestStatus(rawValue: "CUSTOM_STATUS")
        #expect(customStatus.rawValue == "CUSTOM_STATUS")
        #expect(customStatus != TestStatus.passed)
    }

    @Test func testSuiteComputedProperties() throws {
        let passedCase = TestCase(
            age: 0,
            className: "Test1",
            duration: 1.0,
            failedSince: 0,
            name: "method1",
            skipped: false,
            status: .passed
        )

        let failedCase = TestCase(
            age: 1,
            className: "Test2",
            duration: 2.0,
            failedSince: 100,
            name: "method2",
            skipped: false,
            status: .failed,
            errorDetails: "Failed"
        )

        let skippedCase = TestCase(
            age: 0,
            className: "Test3",
            duration: 0.0,
            failedSince: 0,
            name: "method3",
            skipped: true,
            status: .skipped,
            skippedMessage: "Skipped for reason"
        )

        let suite = TestSuite(
            name: "TestSuite",
            cases: [passedCase, failedCase, skippedCase],
            duration: 10.0,
            id: "suite1"
        )

        #expect(suite.passedCount == 1)
        #expect(suite.failedCount == 1)
        #expect(suite.skippedCount == 1)
    }

    @Test func testEmptyTestReport() {
        let emptyReport = TestReport(
            duration: 0.0,
            failCount: 0,
            passCount: 0,
            skipCount: 0,
            suites: [],
            empty: true
        )

        #expect(emptyReport.totalCount == 0)
        #expect(emptyReport.hasFailures == false)
        #expect(emptyReport.successRate == 0)
    }
}
