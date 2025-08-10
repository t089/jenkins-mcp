# Jenkins CLI Build Commands Design

## Overview

This document outlines the design for the "build" command group for the Jenkins CLI using Swift's ArgumentParser, leveraging the JenkinsSDK module. The design focuses on providing comprehensive build operations through the `JobClient.BuildClient` class while maintaining consistency with the existing CLI patterns.

## Architecture Analysis

### JenkinsSDK Build Operations

Based on analysis of `Sources/JenkinsSDK/JenkinsClient.swift` and `Sources/JenkinsSDK/Models.swift`, the SDK provides:

#### BuildClient Methods
- `get(number: Int) -> Build` - Retrieve build details
- `get(byURL: String) -> Build` - Retrieve build by Jenkins URL
- `stop(number: Int)` - Stop a running build
- `trigger(parameters: [String: String]) -> QueueItemRef` - Start a new build
- `logs(number: Int) -> String` - Get complete build logs
- `streamLogs(number: Int, startOffset: Int, execute: (...) -> R) -> R` - Stream logs progressively
- `grepLogs(number: Int, pattern: String, context: Int, offset: Int, maxCount: Int) -> [GrepMatch]` - Search logs

#### Build Model Properties
The `Build` struct provides rich information including:
- **Identity**: `number`, `url`, `displayName`, `fullDisplayName`
- **Status**: `building`, `result`, `status` (computed), `isRunning`, `isSuccess`, `isFailure`
- **Timing**: `timestamp`, `duration`, `estimatedDuration`, `startTime`, `durationTimeInterval`
- **Metadata**: `description`, `builtOn`, `changeSet`, `actions`
- **Parameters**: `buildParameters` (computed from actions)
- **Causes**: `buildCauses`, `triggeredByUser`, `upstreamBuild` (computed)

## Command Group Design

### Main Build Command Structure

```swift
@main
struct JenkinsCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "jenkins-cli",
        abstract: "Jenkins CLI tool",
        subcommands: [BuildCommand.self, /* other commands */]
    )
}

struct BuildCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Manage Jenkins builds",
        subcommands: [
            GetBuildCommand.self,
            StopBuildCommand.self,
            LogsCommand.self,
            GrepLogsCommand.self,
            TriggerBuildCommand.self,
            StreamLogsCommand.self
        ]
    )
}
```

### Build Identification Strategies

#### 1. Path + Number Approach (Primary)
Most commands use `<job-path> <build-number>` format:
```bash
jenkins-cli build get "folder/job-name" 42
jenkins-cli build stop "My Folder/My Job" 123
```

#### 2. URL-based Approach (Alternative)
Support Jenkins build URLs for convenience:
```bash
jenkins-cli build get --url "https://jenkins.example.com/job/folder/job/my-job/42/"
```

#### 3. Build Resolution Helpers
- Latest build: `--latest` flag
- Last successful: `--last-successful`
- Last failed: `--last-failed`

## Individual Command Designs

### 1. Get Build Command

```swift
struct GetBuildCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Get detailed information about a build"
    )
    
    @Argument(help: "Job path (e.g., 'folder/job-name')")
    var jobPath: String
    
    @Argument(help: "Build number")
    var buildNumber: Int
    
    @Option(name: .long, help: "Jenkins build URL (alternative to path/number)")
    var url: String?
    
    @Flag(name: .long, help: "Get the latest build")
    var latest: Bool = false
    
    @Flag(name: .long, help: "Get the last successful build")
    var lastSuccessful: Bool = false
    
    @Flag(name: .long, help: "Output as JSON")
    var json: Bool = false
    
    func run() async throws {
        let client = try await createJenkinsClient()
        
        let build: Build
        if let url = url {
            build = try await client.job(at: "").builds.get(byURL: url)
        } else if latest {
            let job = try await client.job(at: jobPath).get()
            guard let lastBuildNumber = job.lastBuildNumber else {
                throw ValidationError("No builds found for job")
            }
            build = try await client.job(at: jobPath).builds.get(number: lastBuildNumber)
        } else if lastSuccessful {
            let job = try await client.job(at: jobPath).get()
            guard let lastSuccessfulNumber = job.lastSuccessfulBuildNumber else {
                throw ValidationError("No successful builds found")
            }
            build = try await client.job(at: jobPath).builds.get(number: lastSuccessfulNumber)
        } else {
            build = try await client.job(at: jobPath).builds.get(number: buildNumber)
        }
        
        if json {
            try printJSON(build)
        } else {
            printBuildSummary(build)
        }
    }
}
```

**Output Format:**
```
Build #42: My Job » folder/job-name
Status: SUCCESS (completed)
Started: 2024-01-15 14:30:25 UTC
Duration: 2m 34s
Built on: jenkins-agent-01

Parameters:
  BRANCH: main
  DEPLOY_ENV: staging

Changes:
  - abc1234 Fix critical bug in payment processor (John Doe)
  - def5678 Update dependency versions (Jane Smith)

Build Causes:
  - Started by user: john.doe
  - Upstream project: deployment-pipeline #156
```

### 2. Stop Build Command

```swift
struct StopBuildCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stop",
        abstract: "Stop a running build"
    )
    
    @Argument(help: "Job path (e.g., 'folder/job-name')")
    var jobPath: String
    
    @Argument(help: "Build number")
    var buildNumber: Int
    
    @Option(name: .long, help: "Jenkins build URL (alternative to path/number)")
    var url: String?
    
    @Flag(name: .long, help: "Stop the latest build")
    var latest: Bool = false
    
    @Flag(name: .long, help: "Force stop without confirmation")
    var force: Bool = false
    
    func run() async throws {
        let client = try await createJenkinsClient()
        
        // Resolve build number if needed
        let actualBuildNumber: Int
        if let url = url {
            let build = try await client.job(at: "").builds.get(byURL: url)
            actualBuildNumber = build.number
        } else if latest {
            let job = try await client.job(at: jobPath).get()
            guard let lastBuildNumber = job.lastBuildNumber else {
                throw ValidationError("No builds found for job")
            }
            actualBuildNumber = lastBuildNumber
        } else {
            actualBuildNumber = buildNumber
        }
        
        // Check if build is actually running
        let build = try await client.job(at: jobPath).builds.get(number: actualBuildNumber)
        guard build.isRunning else {
            print("Build #\(actualBuildNumber) is not running (status: \(build.status))")
            return
        }
        
        // Confirm stop unless forced
        if !force {
            print("Stop build #\(actualBuildNumber) of \(jobPath)? (y/N): ", terminator: "")
            guard let response = readLine()?.lowercased(), response == "y" || response == "yes" else {
                print("Cancelled")
                return
            }
        }
        
        try await client.job(at: jobPath).builds.stop(number: actualBuildNumber)
        print("Build #\(actualBuildNumber) stop request sent")
    }
}
```

### 3. Logs Command

```swift
struct LogsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "logs",
        abstract: "Get build console logs"
    )
    
    @Argument(help: "Job path (e.g., 'folder/job-name')")
    var jobPath: String
    
    @Argument(help: "Build number")
    var buildNumber: Int
    
    @Option(name: .long, help: "Jenkins build URL (alternative to path/number)")
    var url: String?
    
    @Flag(name: .long, help: "Get logs from the latest build")
    var latest: Bool = false
    
    @Option(name: .long, help: "Maximum number of lines to return")
    var maxLines: Int?
    
    @Option(name: .long, help: "Position to read from", transform: LogPosition.init)
    var position: LogPosition = .tail
    
    @Flag(name: .long, help: "Follow logs (for running builds)")
    var follow: Bool = false
    
    func run() async throws {
        let client = try await createJenkinsClient()
        
        // Resolve build number
        let actualBuildNumber = try await resolveBuildNumber(client: client)
        
        if follow {
            try await followLogs(client: client, buildNumber: actualBuildNumber)
        } else {
            try await getStaticLogs(client: client, buildNumber: actualBuildNumber)
        }
    }
    
    private func followLogs(client: JenkinsClient, buildNumber: Int) async throws {
        var offset = 0
        var isComplete = false
        
        while !isComplete {
            let result = try await client.job(at: jobPath).builds.streamLogs(
                number: buildNumber,
                startOffset: offset
            ) { nextOffset, lines in
                var lineCount = 0
                for try await line in lines {
                    print(line)
                    lineCount += 1
                }
                return (nextOffset, lineCount)
            }
            
            if let nextOffset = result.0 {
                offset = nextOffset
                // Wait before polling again
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            } else {
                isComplete = true
            }
        }
    }
}

enum LogPosition: String, CaseIterable {
    case head, tail
    
    init(_ string: String) throws {
        guard let position = LogPosition(rawValue: string.lowercased()) else {
            throw ValidationError("Invalid position: \(string). Must be 'head' or 'tail'")
        }
        self = position
    }
}
```

### 4. Grep Logs Command

```swift
struct GrepLogsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "grep",
        abstract: "Search build logs for patterns"
    )
    
    @Argument(help: "Job path (e.g., 'folder/job-name')")
    var jobPath: String
    
    @Argument(help: "Build number")
    var buildNumber: Int
    
    @Argument(help: "Search pattern (regex supported)")
    var pattern: String
    
    @Option(name: .short, help: "Context lines around matches")
    var context: Int = 0
    
    @Option(name: .long, help: "Maximum number of matches to return")
    var maxCount: Int = 200
    
    @Option(name: .long, help: "Line offset to start searching from")
    var offset: Int = 0
    
    @Flag(name: .long, help: "Case insensitive search")
    var ignoreCase: Bool = false
    
    @Flag(name: .long, help: "Show line numbers")
    var lineNumbers: Bool = true
    
    func run() async throws {
        let client = try await createJenkinsClient()
        
        let searchPattern = ignoreCase ? "(?i)\(pattern)" : pattern
        
        let matches = try await client.job(at: jobPath).builds.grepLogs(
            number: buildNumber,
            pattern: searchPattern,
            context: context,
            offset: offset,
            maxCount: maxCount
        )
        
        if matches.isEmpty {
            print("No matches found for pattern: \(pattern)")
            return
        }
        
        for match in matches {
            if lineNumbers {
                let prefix = match.isMatch ? "→" : " "
                print("\(prefix) \(match.elementNumber): \(match.content)")
            } else {
                print(match.content)
            }
        }
        
        print("\nFound \(matches.filter { $0.isMatch }.count) matches")
    }
}
```

### 5. Trigger Build Command

```swift
struct TriggerBuildCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "trigger",
        abstract: "Trigger a new build"
    )
    
    @Argument(help: "Job path (e.g., 'folder/job-name')")
    var jobPath: String
    
    @Option(name: [.short, .long], help: "Build parameters (key=value)")
    var parameter: [String] = []
    
    @Option(name: .long, help: "Parameters from JSON file")
    var parametersFile: String?
    
    @Flag(name: .long, help: "Wait for build to complete")
    var wait: Bool = false
    
    @Flag(name: .long, help: "Follow logs while waiting")
    var followLogs: Bool = false
    
    func run() async throws {
        let client = try await createJenkinsClient()
        
        // Parse parameters
        var parameters: [String: String] = [:]
        
        // From command line
        for param in parameter {
            let components = param.split(separator: "=", maxSplits: 1)
            guard components.count == 2 else {
                throw ValidationError("Invalid parameter format: \(param). Use key=value")
            }
            parameters[String(components[0])] = String(components[1])
        }
        
        // From file
        if let file = parametersFile {
            let fileParams = try loadParametersFromFile(file)
            parameters.merge(fileParams) { _, new in new }
        }
        
        // Trigger build
        let queueRef = try await client.job(at: jobPath).builds.trigger(parameters: parameters)
        print("Build queued: \(queueRef.url)")
        
        if wait || followLogs {
            try await waitForBuild(client: client, queueRef: queueRef)
        }
    }
    
    private func waitForBuild(client: JenkinsClient, queueRef: QueueItemRef) async throws {
        // Implementation to poll queue item and then build status
        // Follow logs if requested
    }
}
```

### 6. Stream Logs Command

```swift
struct StreamLogsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stream",
        abstract: "Stream build logs in real-time"
    )
    
    @Argument(help: "Job path (e.g., 'folder/job-name')")
    var jobPath: String
    
    @Argument(help: "Build number")
    var buildNumber: Int
    
    @Option(name: .long, help: "Start offset for streaming")
    var startOffset: Int = 0
    
    @Flag(name: .long, help: "Continue streaming until build completes")
    var follow: Bool = true
    
    func run() async throws {
        let client = try await createJenkinsClient()
        
        var currentOffset = startOffset
        
        repeat {
            let (nextOffset, hasMore) = try await client.job(at: jobPath).builds.streamLogs(
                number: buildNumber,
                startOffset: currentOffset
            ) { nextOffset, lines in
                var lineCount = 0
                for try await line in lines {
                    print(line)
                    lineCount += 1
                }
                return (nextOffset, lineCount > 0)
            }
            
            if let nextOffset = nextOffset {
                currentOffset = nextOffset
                if follow && hasMore {
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
            } else {
                break
            }
        } while follow
    }
}
```

## Implementation Considerations

### 1. Client Configuration
- Support for environment variables: `JENKINS_URL`, `JENKINS_USERNAME`, `JENKINS_PASSWORD`
- Netrc file support for authentication
- Custom timeout and retry configurations
- SSL/TLS certificate handling

### 2. Error Handling
- Network connectivity issues
- Authentication failures  
- Build not found scenarios
- Permission denied cases
- Invalid job paths

### 3. Output Formatting
- Human-readable default format
- JSON output option for programmatic use
- Colored output for terminal (success=green, failure=red, etc.)
- Progress indicators for long-running operations

### 4. Performance Optimizations
- Streaming for large log files
- Progressive log loading
- Connection reuse
- Concurrent operations where applicable

### 5. User Experience
- Shell completion support
- Helpful error messages with suggestions
- Confirmation prompts for destructive operations
- Progress indicators for long operations

## Usage Examples

```bash
# Get build information
jenkins-cli build get "my-project/main" 42
jenkins-cli build get --url "https://jenkins.example.com/job/my-project/job/main/42/"
jenkins-cli build get "my-project" --latest
jenkins-cli build get "my-project" --last-successful --json

# Stop builds
jenkins-cli build stop "my-project/main" 42
jenkins-cli build stop "my-project" --latest --force

# View logs
jenkins-cli build logs "my-project/main" 42
jenkins-cli build logs "my-project" --latest --max-lines 100
jenkins-cli build logs "my-project/main" 42 --follow

# Search logs
jenkins-cli build grep "my-project/main" 42 "ERROR"
jenkins-cli build grep "my-project/main" 42 "test.*failed" --context 3 --ignore-case

# Trigger builds
jenkins-cli build trigger "my-project/main"
jenkins-cli build trigger "my-project/main" -p "BRANCH=feature/new-feature" -p "DEPLOY=true"
jenkins-cli build trigger "my-project/main" --parameters-file params.json --wait --follow-logs

# Stream logs
jenkins-cli build stream "my-project/main" 42
jenkins-cli build stream "my-project/main" 42 --start-offset 1000
```

## Integration with Existing Patterns

The design follows patterns established in the MCP tools:
- Similar parameter validation and error handling
- Consistent use of JenkinsSDK BuildClient methods
- Reuse of existing models (Build, GrepMatch, etc.)
- Same authentication and client configuration approaches
- Compatible output formats for integration with other tools

This design provides a comprehensive, user-friendly CLI interface for Jenkins build management while leveraging the full capabilities of the JenkinsSDK.