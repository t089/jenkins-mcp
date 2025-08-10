import Testing
@testable import JenkinsMCP

struct LogGrepUtilityTests {
    
    @Test func grepFindsMatchingLines() async throws {
        let lines = SyncAsyncSequence(["line 1", "error: something", "line 3", "error: another", "line 5"])
        let options = LogGrepUtility.GrepOptions(pattern: "error:")
        
        let results = try await LogGrepUtility.grepLines(from: lines, options: options)
        
        #expect(results.count == 2)
        #expect(results[0].lineNumber == 2)
        #expect(results[0].match == "error: something")
        #expect(results[0].context == nil)
        #expect(results[1].lineNumber == 4)
        #expect(results[1].match == "error: another")
        #expect(results[1].context == nil)
    }
    
    @Test func grepWithContextBefore() async throws {
        let lines = SyncAsyncSequence(["line 1", "line 2", "error: something", "line 4", "line 5"])
        let options = LogGrepUtility.GrepOptions(pattern: "error:", context: 2)
        
        let results = try await LogGrepUtility.grepLines(from: lines, options: options)
        
        #expect(results.count == 5) // 2 context before + match + 2 context after
        #expect(results[0].lineNumber == 1)
        #expect(results[0].match == nil)
        #expect(results[0].context == "line 1")
        #expect(results[1].lineNumber == 2)
        #expect(results[1].match == nil)
        #expect(results[1].context == "line 2")
        #expect(results[2].lineNumber == 3)
        #expect(results[2].match == "error: something")
        #expect(results[2].context == nil)
        #expect(results[3].lineNumber == 4)
        #expect(results[3].match == nil)
        #expect(results[3].context == "line 4")
        #expect(results[4].lineNumber == 5)
        #expect(results[4].match == nil)
        #expect(results[4].context == "line 5")
    }
    
    @Test func grepWithOffset() async throws {
        let lines = SyncAsyncSequence(["line 1", "error: first", "line 3", "error: second", "line 5"])
        let options = LogGrepUtility.GrepOptions(pattern: "error:", offset: 2)
        
        let results = try await LogGrepUtility.grepLines(from: lines, options: options)
        
        #expect(results.count == 1)
        #expect(results[0].lineNumber == 4)
        #expect(results[0].match == "error: second")
    }
    
    @Test func grepWithMaxLines() async throws {
        let lines = SyncAsyncSequence([
            "error: 1", "error: 2", "error: 3", "error: 4", "error: 5"
        ])
        let options = LogGrepUtility.GrepOptions(pattern: "error:", maxLines: 3)
        
        let results = try await LogGrepUtility.grepLines(from: lines, options: options)
        
        #expect(results.count == 3)
        #expect(results[0].match == "error: 1")
        #expect(results[1].match == "error: 2")
        #expect(results[2].match == "error: 3")
    }
    
    @Test func grepNoMatches() async throws {
        let lines = SyncAsyncSequence(["line 1", "line 2", "line 3"])
        let options = LogGrepUtility.GrepOptions(pattern: "error:")
        
        let results = try await LogGrepUtility.grepLines(from: lines, options: options)
        
        #expect(results.isEmpty)
    }
    
    @Test func grepInvalidRegexPattern() async throws {
        let lines = SyncAsyncSequence(["line 1", "line 2"])
        let options = LogGrepUtility.GrepOptions(pattern: "[invalid regex")
        
        await #expect {
            _ = try await LogGrepUtility.grepLines(from: lines, options: options)
        } throws: { _ in true }
        
    }
    
    @Test func grepContextWithMultipleMatches() async throws {
        let lines = SyncAsyncSequence([
            "line 1",    // 1
            "error: A",  // 2 - match
            "line 3",    // 3
            "line 4",    // 4
            "error: B",  // 5 - match
            "line 6"     // 6
        ])
        let options = LogGrepUtility.GrepOptions(pattern: "error:", context: 1)
        
        let results = try await LogGrepUtility.grepLines(from: lines, options: options)
        
        #expect(results.count == 6)
        // Context before first match
        #expect(results[0].lineNumber == 1)
        #expect(results[0].context == "line 1")
        // First match
        #expect(results[1].lineNumber == 2)
        #expect(results[1].match == "error: A")
        // Context after first match
        #expect(results[2].lineNumber == 3)
        #expect(results[2].context == "line 3")
        // Context before second match (line 4)
        #expect(results[3].lineNumber == 4)
        #expect(results[3].context == "line 4")
        // Second match
        #expect(results[4].lineNumber == 5)
        #expect(results[4].match == "error: B")
        // Context after second match
        #expect(results[5].lineNumber == 6)
        #expect(results[5].context == "line 6")
    }
    
    @Test func grepEmptyInput() async throws {
        let lines = SyncAsyncSequence<String>([])
        let options = LogGrepUtility.GrepOptions(pattern: "error:")
        
        let results = try await LogGrepUtility.grepLines(from: lines, options: options)
        
        #expect(results.isEmpty)
    }
}

// Helper AsyncSequence for testing
struct SyncAsyncSequence<Element>: AsyncSequence {
    private let elements: [Element]
    
    init(_ elements: [Element]) {
        self.elements = elements
    }
    
    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(elements: elements)
    }
    
    struct AsyncIterator: AsyncIteratorProtocol {
        private let elements: [Element]
        private var index = 0
        
        init(elements: [Element]) {
            self.elements = elements
        }
        
        mutating func next() async throws -> Element? {
            guard index < elements.count else { return nil }
            defer { index += 1 }
            return elements[index]
        }
    }
}