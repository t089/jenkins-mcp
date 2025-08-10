# Jenkins CLI Architecture Design

## Executive Summary

This document outlines the architecture for a comprehensive Jenkins CLI tool built using Swift's ArgumentParser framework and the existing JenkinsSDK module. The CLI will provide a structured, hierarchical command interface for interacting with Jenkins servers, mirroring the resource-scoped API pattern used in the SDK.

## Current SDK Analysis

### JenkinsClient Architecture
The JenkinsSDK uses a resource-scoped pattern where operations are organized by resource type:

- **JenkinsClient**: Main entry point with authentication and transport
- **JobClient**: Job-specific operations (get, trigger builds, navigate hierarchies)
- **BuildClient**: Build-specific operations (get details, logs, stop)
- **QueueClient**: Queue operations (list, cancel items)

### Key SDK Components

1. **Authentication**: `JenkinsCredentials` with username/password
2. **Transport**: `HTTPClientTransport` wrapping AsyncHTTPClient
3. **Error Handling**: `JenkinsAPIError` enum with specific error types
4. **Models**: Rich data models with computed properties and helpers

## CLI Architecture Design

### 1. Main Entry Point Structure

```swift
@main
struct JenkinsCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "jenkins",
        abstract: "A comprehensive Jenkins CLI tool",
        discussion: """
        Interact with Jenkins servers using a hierarchical command structure.
        Supports authentication via environment variables or netrc files.
        """,
        version: "1.0.0",
        subcommands: [
            JobCommand.self,
            BuildCommand.self,
            QueueCommand.self,
            ServerCommand.self
        ],
        defaultSubcommand: ServerCommand.self
    )
}
```

### 2. Global Options System

All commands will inherit from a shared base that provides global configuration:

```swift
protocol GlobalOptions: ParsableCommand {
    var jenkinsUrl: String { get set }
    var username: String? { get set }
    var password: String? { get set }
    var netrcFile: String? { get set }
    var outputFormat: OutputFormat { get set }
    var verbose: Bool { get set }
}

struct SharedGlobalOptions: ParsableArguments, GlobalOptions {
    @Option(
        name: [.short, .long], 
        help: "Jenkins server URL (e.g., https://jenkins.example.com)",
        envKey: .jenkinsUrl
    )
    var jenkinsUrl: String
    
    @Option(
        name: .long,
        help: "Jenkins username (or use JENKINS_USERNAME env var)"
    )
    var username: String?
    
    @Option(
        name: .long,
        help: "Jenkins password (or use JENKINS_PASSWORD env var)"
    )
    var password: String?
    
    @Option(
        name: .long,
        help: "Path to netrc file (default: ~/.netrc)"
    )
    var netrcFile: String?
    
    @Option(
        name: [.short, .customLong("format")],
        help: "Output format"
    )
    var outputFormat: OutputFormat = .table
    
    @Flag(
        name: [.short, .long],
        help: "Enable verbose output"
    )
    var verbose: Bool = false
}

enum OutputFormat: String, CaseIterable, ExpressibleByArgument {
    case table, json, yaml, csv
}
```

### 3. Command Hierarchy

#### 3.1 Job Commands

```swift
struct JobCommand: AsyncParsableCommand, GlobalOptions {
    static let configuration = CommandConfiguration(
        abstract: "Manage Jenkins jobs",
        subcommands: [
            JobList.self,
            JobGet.self,
            JobBuild.self,
            JobStop.self,
            JobLogs.self,
            JobHistory.self
        ]
    )
    
    @OptionGroup var globalOptions: SharedGlobalOptions
}

struct JobList: AsyncParsableCommand, GlobalOptions {
    static let configuration = CommandConfiguration(
        abstract: "List jobs in a folder"
    )
    
    @OptionGroup var globalOptions: SharedGlobalOptions
    
    @Argument(help: "Job path or folder (optional, defaults to root)")
    var path: String?
    
    @Flag(name: .long, help: "Include child jobs recursively")
    var recursive: Bool = false
    
    @Flag(name: .long, help: "Show only failing jobs")
    var failing: Bool = false
}

struct JobGet: AsyncParsableCommand, GlobalOptions {
    static let configuration = CommandConfiguration(
        abstract: "Get detailed information about a job"
    )
    
    @OptionGroup var globalOptions: SharedGlobalOptions
    
    @Argument(help: "Job path (e.g., 'folder/subfolder/jobname')")
    var jobPath: String
    
    @Flag(name: .long, help: "Show build history")
    var showBuilds: Bool = false
}

struct JobBuild: AsyncParsableCommand, GlobalOptions {
    static let configuration = CommandConfiguration(
        abstract: "Trigger a job build"
    )
    
    @OptionGroup var globalOptions: SharedGlobalOptions
    
    @Argument(help: "Job path")
    var jobPath: String
    
    @Option(
        name: .shortAndLong,
        help: "Build parameters in key=value format",
        transform: parseKeyValue
    )
    var parameter: [String: String] = [:]
    
    @Flag(name: .long, help: "Wait for build to complete")
    var wait: Bool = false
    
    @Flag(name: .long, help: "Follow build logs if waiting")
    var follow: Bool = false
}
```

#### 3.2 Build Commands

```swift
struct BuildCommand: AsyncParsableCommand, GlobalOptions {
    static let configuration = CommandConfiguration(
        abstract: "Manage Jenkins builds",
        subcommands: [
            BuildGet.self,
            BuildLogs.self,
            BuildStop.self,
            BuildGrep.self
        ]
    )
    
    @OptionGroup var globalOptions: SharedGlobalOptions
}

struct BuildLogs: AsyncParsableCommand, GlobalOptions {
    static let configuration = CommandConfiguration(
        abstract: "Get build console logs"
    )
    
    @OptionGroup var globalOptions: SharedGlobalOptions
    
    @Argument(help: "Job path")
    var jobPath: String
    
    @Argument(help: "Build number")
    var buildNumber: Int
    
    @Flag(name: [.short, .long], help: "Follow logs (for running builds)")
    var follow: Bool = false
    
    @Option(name: .long, help: "Start from offset")
    var offset: Int?
    
    @Option(name: .long, help: "Maximum lines to display")
    var maxLines: Int?
}

struct BuildGrep: AsyncParsableCommand, GlobalOptions {
    static let configuration = CommandConfiguration(
        abstract: "Search build logs using regex patterns"
    )
    
    @OptionGroup var globalOptions: SharedGlobalOptions
    
    @Argument(help: "Job path")
    var jobPath: String
    
    @Argument(help: "Build number")  
    var buildNumber: Int
    
    @Argument(help: "Search pattern (regex)")
    var pattern: String
    
    @Option(name: [.short, .long], help: "Lines of context around matches")
    var context: Int = 0
    
    @Option(name: .long, help: "Maximum number of matches")
    var maxCount: Int = 200
}
```

#### 3.3 Queue Commands

```swift
struct QueueCommand: AsyncParsableCommand, GlobalOptions {
    static let configuration = CommandConfiguration(
        abstract: "Manage Jenkins build queue",
        subcommands: [
            QueueList.self,
            QueueCancel.self,
            QueueInfo.self
        ]
    )
    
    @OptionGroup var globalOptions: SharedGlobalOptions
}

struct QueueList: AsyncParsableCommand, GlobalOptions {
    static let configuration = CommandConfiguration(
        abstract: "List items in the build queue"
    )
    
    @OptionGroup var globalOptions: SharedGlobalOptions
    
    @Flag(name: .long, help: "Show only stuck items")
    var stuck: Bool = false
}
```

#### 3.4 Server Commands

```swift
struct ServerCommand: AsyncParsableCommand, GlobalOptions {
    static let configuration = CommandConfiguration(
        abstract: "Jenkins server operations",
        subcommands: [
            ServerInfo.self,
            ServerStatus.self
        ]
    )
    
    @OptionGroup var globalOptions: SharedGlobalOptions
}

struct ServerInfo: AsyncParsableCommand, GlobalOptions {
    static let configuration = CommandConfiguration(
        abstract: "Get Jenkins server information"
    )
    
    @OptionGroup var globalOptions: SharedGlobalOptions
}
```

### 4. JenkinsClient Lifecycle Management

#### 4.1 Client Factory

```swift
struct JenkinsClientFactory {
    static func createClient(from options: GlobalOptions) async throws -> JenkinsClient {
        // Validate Jenkins URL
        guard let baseURL = URL(string: options.jenkinsUrl),
              baseURL.scheme != nil else {
            throw CLIError.invalidJenkinsURL(options.jenkinsUrl)
        }
        
        // Set up HTTP client with configuration
        var httpClientConfig = HTTPClient.Configuration.singletonConfiguration
        httpClientConfig.decompression = .enabled(limit: .none)
        httpClientConfig.timeout = .init(
            connect: .seconds(10),
            read: .seconds(30)
        )
        
        let httpClient = HTTPClient(
            eventLoopGroupProvider: .singleton,
            configuration: httpClientConfig
        )
        
        let transport = HTTPClientTransport(
            client: httpClient,
            defaultTimeout: .seconds(30),
            logger: createLogger(verbose: options.verbose)
        )
        
        // Load credentials
        let credentials = try loadCredentials(from: options)
        
        return JenkinsClient(
            baseURL: baseURL,
            transport: transport,
            credentials: credentials
        )
    }
    
    private static func loadCredentials(from options: GlobalOptions) throws -> JenkinsCredentials? {
        // Priority order: CLI options > environment variables > netrc file
        
        // 1. Check CLI options
        if let username = options.username, let password = options.password {
            return JenkinsCredentials(username: username, password: password)
        }
        
        // 2. Check environment variables
        if let username = ProcessInfo.processInfo.environment["JENKINS_USERNAME"],
           let password = ProcessInfo.processInfo.environment["JENKINS_PASSWORD"] {
            return JenkinsCredentials(username: username, password: password)
        }
        
        // 3. Check netrc file
        let netrcPath = options.netrcFile ?? FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".netrc")
            .path
            
        if FileManager.default.fileExists(atPath: netrcPath) {
            return try loadNetrcCredentials(path: netrcPath, url: options.jenkinsUrl)
        }
        
        // 4. No credentials found - return nil (some Jenkins instances allow anonymous access)
        return nil
    }
    
    private static func createLogger(verbose: Bool) -> Logger {
        var logger = Logger(label: "jenkins-cli")
        logger.logLevel = verbose ? .debug : .info
        return logger
    }
}
```

#### 4.2 Client Context Management

```swift
@propertyWrapper
struct JenkinsClientContext {
    private var _client: JenkinsClient?
    
    var wrappedValue: JenkinsClient {
        get {
            guard let client = _client else {
                fatalError("JenkinsClient not initialized. This is a programming error.")
            }
            return client
        }
        set { _client = newValue }
    }
    
    var projectedValue: JenkinsClientContext {
        get { self }
        set { self = newValue }
    }
}

// Usage in commands:
struct JobGet: AsyncParsableCommand, GlobalOptions {
    @OptionGroup var globalOptions: SharedGlobalOptions
    @JenkinsClientContext var jenkinsClient
    
    func run() async throws {
        // Client is automatically initialized by the parent command
        let job = try await jenkinsClient.job(at: jobPath).get()
        try await OutputFormatter.format(job, as: globalOptions.outputFormat)
    }
}
```

### 5. Output Formatting System

#### 5.1 Formatter Protocol

```swift
protocol Formattable {
    func formatAsTable() -> String
    func formatAsJSON() throws -> String
    func formatAsYAML() throws -> String
    func formatAsCSV() throws -> String
}

struct OutputFormatter {
    static func format<T: Formattable>(_ object: T, as format: OutputFormat) async throws {
        let output: String
        
        switch format {
        case .table:
            output = object.formatAsTable()
        case .json:
            output = try object.formatAsJSON()
        case .yaml:
            output = try object.formatAsYAML()
        case .csv:
            output = try object.formatAsCSV()
        }
        
        print(output)
    }
}
```

#### 5.2 Model Extensions

```swift
extension Job: Formattable {
    func formatAsTable() -> String {
        var table = Table()
        table.header = ["Property", "Value"]
        table.rows = [
            ["Name", name],
            ["URL", url],
            ["Status", color ?? "Unknown"],
            ["Buildable", buildableValue ? "Yes" : "No"],
            ["Last Build", lastBuildNumber?.description ?? "None"],
            ["Next Build", nextBuildNumberValue.description]
        ]
        return table.render()
    }
    
    func formatAsJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }
}

extension Build: Formattable {
    func formatAsTable() -> String {
        var table = Table()
        table.header = ["Property", "Value"]
        table.rows = [
            ["Number", number.description],
            ["Status", status.rawValue],
            ["Duration", formatDuration(durationTimeInterval)],
            ["Started", DateFormatter.iso8601.string(from: startTime)],
            ["Built On", builtOn ?? "Unknown"]
        ]
        return table.render()
    }
}
```

### 6. Error Handling Strategy

#### 6.1 CLI Error Types

```swift
enum CLIError: Error, LocalizedError {
    case invalidJenkinsURL(String)
    case authenticationFailed
    case networkTimeout
    case jenkinsAPIError(JenkinsAPIError)
    case outputFormattingError(Error)
    case configurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidJenkinsURL(let url):
            return "Invalid Jenkins URL: \(url)"
        case .authenticationFailed:
            return "Authentication failed. Check credentials."
        case .networkTimeout:
            return "Network timeout. Check connection and Jenkins URL."
        case .jenkinsAPIError(let apiError):
            return "Jenkins API error: \(apiError.localizedDescription)"
        case .outputFormattingError(let error):
            return "Output formatting error: \(error.localizedDescription)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        }
    }
}
```

#### 6.2 Error Handler Extension

```swift
extension AsyncParsableCommand {
    func handleError(_ error: Error) -> Never {
        switch error {
        case let cliError as CLIError:
            print("Error: \(cliError.localizedDescription)", to: &stderr)
        case let jenkinsError as JenkinsAPIError:
            handleJenkinsError(jenkinsError)
        case let validationError as ValidationError:
            print("Validation Error: \(validationError.message)", to: &stderr)
        default:
            print("Unexpected error: \(error.localizedDescription)", to: &stderr)
        }
        exit(1)
    }
    
    private func handleJenkinsError(_ error: JenkinsAPIError) {
        switch error {
        case .httpError(404):
            print("Error: Resource not found (HTTP 404)", to: &stderr)
        case .httpError(401):
            print("Error: Authentication required (HTTP 401)", to: &stderr)
        case .httpError(403):
            print("Error: Access forbidden (HTTP 403)", to: &stderr)
        case .httpError(let code):
            print("Error: HTTP \(code)", to: &stderr)
        case .noData:
            print("Error: No data received from Jenkins", to: &stderr)
        case .decodingError(let decodingError):
            print("Error: Failed to parse Jenkins response: \(decodingError)", to: &stderr)
        case .invalidURL:
            print("Error: Invalid URL provided", to: &stderr)
        case .buildNotFound:
            print("Error: Build not found", to: &stderr)
        case .jobNotFound:
            print("Error: Job not found", to: &stderr)
        case .invalidPath(let path):
            print("Error: Invalid path: \(path)", to: &stderr)
        case .invalidPattern(let pattern):
            print("Error: Invalid regex pattern: \(pattern)", to: &stderr)
        }
    }
}
```

### 7. Configuration Management

#### 7.1 Configuration File Support

```swift
struct CLIConfiguration: Codable {
    var defaultJenkinsUrl: String?
    var defaultOutputFormat: OutputFormat?
    var profiles: [String: ProfileConfiguration]?
    
    static func load() -> CLIConfiguration {
        let configPath = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".jenkins-cli.json")
            
        guard let data = try? Data(contentsOf: configPath),
              let config = try? JSONDecoder().decode(CLIConfiguration.self, from: data) else {
            return CLIConfiguration(profiles: [:])
        }
        
        return config
    }
}

struct ProfileConfiguration: Codable {
    var jenkinsUrl: String
    var netrcFile: String?
    var outputFormat: OutputFormat?
}
```

#### 7.2 Environment Variable Support

```swift
extension EnvironmentKey {
    static let jenkinsUrl = EnvironmentKey("JENKINS_URL")
    static let jenkinsUsername = EnvironmentKey("JENKINS_USERNAME") 
    static let jenkinsPassword = EnvironmentKey("JENKINS_PASSWORD")
    static let jenkinsNetrcFile = EnvironmentKey("JENKINS_NETRC_FILE")
}
```

### 8. Integration with JenkinsSDK

#### 8.1 Command Execution Pattern

```swift
// Base protocol for Jenkins commands
protocol JenkinsCommand: AsyncParsableCommand, GlobalOptions {
    func executeWithClient(_ client: JenkinsClient) async throws
}

extension JenkinsCommand {
    func run() async throws {
        do {
            let client = try await JenkinsClientFactory.createClient(from: globalOptions)
            defer {
                // Clean up HTTP client
                Task {
                    if let transport = client.transport as? HTTPClientTransport {
                        try await transport.client.shutdown()
                    }
                }
            }
            
            try await executeWithClient(client)
        } catch {
            handleError(error)
        }
    }
}
```

#### 8.2 Resource Navigation

```swift
// Mirror the SDK's hierarchical navigation in CLI commands
extension JobCommand {
    func navigateToJob(_ path: String) -> JobClient {
        return jenkinsClient.job(at: path)
    }
    
    func navigateToJobByURL(_ url: String) throws -> JobClient {
        return try jenkinsClient.job(byURL: url)
    }
}

extension BuildCommand {
    func navigateToBuild(jobPath: String, buildNumber: Int) -> BuildClient {
        return jenkinsClient.job(at: jobPath).builds
    }
}
```

## Implementation Priority

### Phase 1: Core Infrastructure
1. Global options and client factory
2. Basic job commands (list, get)
3. Simple output formatting (table, JSON)
4. Error handling framework

### Phase 2: Build Operations  
1. Build commands (get, logs, stop)
2. Build triggering with parameters
3. Log streaming and grep functionality

### Phase 3: Advanced Features
1. Queue management
2. Server operations
3. Configuration file support
4. Enhanced output formats (YAML, CSV)

### Phase 4: Polish
1. Shell completion
2. Progress indicators
3. Interactive modes
4. Enhanced error messages

## Security Considerations

1. **Credential Handling**: Never log credentials, use secure environment variables
2. **Netrc Permissions**: Validate file permissions (600) for security
3. **HTTPS Enforcement**: Warn on HTTP URLs in production
4. **Input Validation**: Sanitize all user inputs before passing to SDK

## Testing Strategy

1. **Unit Tests**: Test each command's argument parsing and validation
2. **Integration Tests**: Test against mock Jenkins server
3. **End-to-End Tests**: Test against real Jenkins instance
4. **Error Path Testing**: Verify error handling for all failure scenarios

This architecture provides a solid foundation for a comprehensive Jenkins CLI that leverages the existing JenkinsSDK while providing an intuitive, hierarchical command structure that mirrors Jenkins' resource organization.