# Jenkins CLI Queue and Logs Commands Design

## Overview

This document outlines the design for "queue" and "logs" command groups for the Jenkins CLI using ArgumentParser, leveraging the existing JenkinsSDK capabilities.

## SDK Analysis

### Queue Operations (QueueClient)

The `QueueClient` class in `JenkinsSDK/JenkinsClient.swift` provides:

- `info() async throws -> QueueInfo` - Get current queue status
- `item(forId:) async throws -> QueueItem` - Get specific queue item
- `item(byURL:) async throws -> QueueItem` - Get queue item by URL
- `cancel(id:) async throws` - Cancel a queued item

**Queue Models:**
- `QueueInfo`: Contains array of `QueueItem`
- `QueueItem`: Full queue item details with id, task, status, timestamps
- `QueueTask`: Job information associated with queue item
- `QueueExecutable`: Build info if item has started executing

### Log Operations (BuildClient)

The `BuildClient` nested in `JobClient` provides sophisticated logging capabilities:

- `logs(number:) async throws -> String` - Get complete build logs
- `streamLogs(number:startOffset:execute:) async throws -> R` - Stream logs with progressive loading
- `grepLogs(number:pattern:context:offset:maxCount:) async throws -> [GrepMatch]` - Search logs with regex

**Streaming Infrastructure:**
- `AsyncLineSequence`: Converts HTTP body chunks into async line sequence
- Progressive text API: Uses Jenkins `/logText/progressiveText` endpoint
- Built-in grep functionality with regex support and context lines

## Command Group Design

### Queue Commands

```swift
@main
struct JenkinsCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "jenkins-cli",
        abstract: "Jenkins CLI for managing jobs, builds, and queue",
        subcommands: [QueueCommand.self, LogsCommand.self]
    )
}

struct QueueCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "queue",
        abstract: "Manage Jenkins build queue",
        subcommands: [ListQueue.self, CancelQueue.self]
    )
}
```

#### `jenkins-cli queue list`

```swift
struct ListQueue: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List current build queue items"
    )
    
    @Option(help: "Jenkins server URL")
    var jenkinsURL: String
    
    @Option(help: "Output format")
    var format: OutputFormat = .table
    
    @Flag(help: "Show detailed information")
    var verbose = false
    
    mutating func run() async throws {
        let client = try await createJenkinsClient(url: jenkinsURL)
        let queueInfo = try await client.queue.info()
        
        switch format {
        case .table:
            print(formatQueueTable(queueInfo.items, verbose: verbose))
        case .json:
            print(try JSONEncoder().encode(queueInfo))
        }
    }
}
```

**Key Features:**
- Table format with columns: ID, Job Name, Status, Queue Time, Reason
- JSON output for scripting
- Verbose mode showing build parameters and detailed timestamps
- Color-coded status indicators

#### `jenkins-cli queue cancel <id>`

```swift
struct CancelQueue: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cancel",
        abstract: "Cancel a queued build item"
    )
    
    @Argument(help: "Queue item ID to cancel")
    var itemId: Int
    
    @Option(help: "Jenkins server URL")
    var jenkinsURL: String
    
    @Flag(help: "Confirm cancellation without prompt")
    var force = false
    
    mutating func run() async throws {
        let client = try await createJenkinsClient(url: jenkinsURL)
        
        // Get item details first for confirmation
        let item = try await client.queue.item(forId: itemId)
        
        if !force {
            print("Cancel queue item \(itemId) (\(item.task.name))? [y/N]")
            // Handle confirmation logic
        }
        
        try await client.queue.cancel(id: itemId)
        print("Queue item \(itemId) cancelled successfully")
    }
}
```

### Logs Commands

```swift
struct LogsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "logs",
        abstract: "Access Jenkins build logs",
        subcommands: [GetLogs.self, StreamLogs.self, GrepLogs.self]
    )
}
```

#### `jenkins-cli logs get <job> <build>`

```swift
struct GetLogs: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Get build console logs"
    )
    
    @Argument(help: "Job path (e.g., 'folder/job-name')")
    var jobPath: String
    
    @Argument(help: "Build number")
    var buildNumber: Int
    
    @Option(help: "Jenkins server URL")
    var jenkinsURL: String
    
    @Option(help: "Maximum lines to return")
    var maxLines: Int = 1000
    
    @Option(help: "Position to read from")
    var position: LogPosition = .tail
    
    @Flag(help: "Follow log output (for running builds)")
    var follow = false
    
    mutating func run() async throws {
        let client = try await createJenkinsClient(url: jenkinsURL)
        
        if follow {
            try await followLogs(client: client, job: jobPath, build: buildNumber)
        } else {
            let logs = try await client.job(at: jobPath).builds.logs(number: buildNumber)
            let lines = logs.split(separator: "\n")
            
            let displayLines = switch position {
            case .head: Array(lines.prefix(maxLines))
            case .tail: Array(lines.suffix(maxLines))
            }
            
            for line in displayLines {
                print(line)
            }
        }
    }
    
    private func followLogs(client: JenkinsClient, job: String, build: Int) async throws {
        var offset = 0
        var isRunning = true
        
        while isRunning {
            try await client.job(at: job).builds.streamLogs(
                number: build,
                startOffset: offset
            ) { nextOffset, lines in
                for try await line in lines {
                    print(line)
                }
                
                if let nextOffset = nextOffset {
                    offset = nextOffset
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                } else {
                    isRunning = false
                }
            }
        }
    }
}

enum LogPosition: String, CaseIterable, ExpressibleByArgument {
    case head, tail
}
```

#### `jenkins-cli logs stream <job> <build>`

```swift
struct StreamLogs: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stream",
        abstract: "Stream build logs in real-time"
    )
    
    @Argument(help: "Job path (e.g., 'folder/job-name')")
    var jobPath: String
    
    @Argument(help: "Build number")
    var buildNumber: Int
    
    @Option(help: "Jenkins server URL")
    var jenkinsURL: String
    
    @Option(help: "Start from byte offset")
    var startOffset: Int = 0
    
    @Option(help: "Refresh interval in seconds")
    var interval: Double = 2.0
    
    mutating func run() async throws {
        let client = try await createJenkinsClient(url: jenkinsURL)
        
        var currentOffset = startOffset
        var buildIsRunning = true
        
        while buildIsRunning {
            try await client.job(at: jobPath).builds.streamLogs(
                number: buildNumber,
                startOffset: currentOffset
            ) { nextOffset, lines in
                for try await line in lines {
                    print(line)
                }
                
                if let nextOffset = nextOffset {
                    currentOffset = nextOffset
                } else {
                    buildIsRunning = false
                }
            }
            
            if buildIsRunning {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }
}
```

#### `jenkins-cli logs grep <job> <build> <pattern>`

```swift
struct GrepLogs: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "grep",
        abstract: "Search build logs with regex pattern"
    )
    
    @Argument(help: "Job path (e.g., 'folder/job-name')")
    var jobPath: String
    
    @Argument(help: "Build number") 
    var buildNumber: Int
    
    @Argument(help: "Regex search pattern")
    var pattern: String
    
    @Option(help: "Jenkins server URL")
    var jenkinsURL: String
    
    @Option(help: "Lines of context around matches")
    var context: Int = 0
    
    @Option(help: "Maximum number of matches")
    var maxMatches: Int = 200
    
    @Option(help: "Start search from line offset")
    var offset: Int = 0
    
    @Flag(help: "Case insensitive matching")
    var ignoreCase = false
    
    @Flag(help: "Invert match (show non-matching lines)")
    var invertMatch = false
    
    @Flag(help: "Show line numbers")
    var showLineNumbers = false
    
    mutating func run() async throws {
        let client = try await createJenkinsClient(url: jenkinsURL)
        
        let searchPattern = ignoreCase ? "(?i)" + pattern : pattern
        
        let matches = try await client.job(at: jobPath).builds.grepLogs(
            number: buildNumber,
            pattern: searchPattern,
            context: context,
            offset: offset,
            maxCount: maxMatches
        )
        
        for match in matches {
            let linePrefix = showLineNumbers ? "\(match.elementNumber):" : ""
            let colorPrefix = match.isMatch ? "\u{001B}[31m" : "\u{001B}[37m" // Red for matches, white for context
            let colorSuffix = "\u{001B}[0m"
            
            if invertMatch != match.isMatch {
                print("\(linePrefix)\(colorPrefix)\(match.content)\(colorSuffix)")
            }
        }
        
        if matches.isEmpty {
            print("No matches found for pattern: \(pattern)")
        }
    }
}
```

## SDK Streaming Mechanisms

### Progressive Text API Integration

The SDK uses Jenkins' `/logText/progressiveText` endpoint which provides:

- **HTTP Headers:**
  - `X-More-Data`: "true" if more log data is available
  - `X-Text-Size`: Current total log size in bytes
- **Streaming Response:** Raw log text that can be consumed incrementally

### AsyncLineSequence Implementation

The `AsyncLineSequence` converts HTTP body chunks into individual log lines:

```swift
// From AsyncLineSequence.swift
public struct AsyncLineSequence: AsyncSequence {
    public func makeAsyncIterator() -> AsyncIterator
    
    // Built-in grep functionality with regex support
    public func grep(
        pattern: String,
        context: Int = 0,
        offset: Int = 0, 
        maxCount: Int = 200
    ) async throws -> [GrepMatch]
}
```

**Key Features:**
- Handles both `\n` and `\r\n` line endings
- Processes log data as it streams (no memory buffering of entire log)
- Built-in regex search with context lines
- Line-by-line iteration for real-time processing

### Memory-Efficient Processing

The streaming design allows processing of large log files without loading everything into memory:

```swift
try await client.job(at: path).builds.streamLogs(number: build) { nextOffset, lines in
    for try await line in lines {
        // Process each line as it arrives
        processLine(line)
    }
    
    // nextOffset indicates if more data is available
    return result
}
```

## Authentication & Configuration

### Credentials Loading
```swift
func createJenkinsClient(url: String) async throws -> JenkinsClient {
    let transport = HTTPClientTransport(client: httpClient)
    
    let credentials = try loadCredentials()
    
    return JenkinsClient(
        baseURL: URL(string: url)!,
        transport: transport,
        credentials: credentials
    )
}

func loadCredentials() throws -> JenkinsCredentials? {
    // Priority order:
    // 1. Environment variables (JENKINS_USERNAME, JENKINS_PASSWORD)
    // 2. Netrc file (~/.netrc)
    // 3. Interactive prompt
    
    if let username = ProcessInfo.processInfo.environment["JENKINS_USERNAME"],
       let password = ProcessInfo.processInfo.environment["JENKINS_PASSWORD"] {
        return JenkinsCredentials(username: username, password: password)
    }
    
    // Load from netrc file...
    // Prompt for credentials...
    
    return nil
}
```

## Output Formatting

### Table Format for Queue List
```
ID    Job Name                     Status    Queue Time    Reason
1234  project/build-main          Waiting   2m 15s        Waiting for executor
1235  project/test-feature-x      Blocked   5m 32s        Upstream project building  
1236  deploy/production          Buildable  1m 8s         -
```

### JSON Output Support
All commands support `--format json` for programmatic use:

```json
{
  "items": [
    {
      "id": 1234,
      "task": {
        "name": "project/build-main",
        "url": "https://jenkins.example.com/job/project/job/build-main/"
      },
      "stuck": false,
      "buildable": true,
      "inQueueSince": 1642681200000
    }
  ]
}
```

## Error Handling

### Comprehensive Error Types
```swift
enum CLIError: Error {
    case jenkinsConnectionFailed(String)
    case invalidJobPath(String) 
    case buildNotFound(Int)
    case authenticationRequired
    case patternSyntaxError(String)
}
```

### User-Friendly Messages
```swift
catch JenkinsAPIError.httpError(let code) {
    switch code {
    case 401: print("Error: Authentication failed. Check credentials.")
    case 404: print("Error: Job or build not found.")
    default: print("Error: HTTP \(code)")
    }
    ExitCode.failure.exit()
}
```

## Integration with Existing SDK

The design leverages all existing SDK capabilities:

1. **QueueClient** - Direct mapping to queue subcommands
2. **BuildClient.streamLogs** - Powers real-time log streaming
3. **AsyncLineSequence** - Enables efficient log processing
4. **Built-in grep functionality** - Provides regex search with context
5. **Progressive text API** - Supports following running builds

This design provides a comprehensive CLI interface that exposes the full power of the JenkinsSDK for queue management and log analysis.