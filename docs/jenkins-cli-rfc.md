# RFC: Jenkins CLI Rewrite using ArgumentParser

## Status: Draft
**Author**: Claude Code  
**Date**: 2025-01-09  
**Supersedes**: Current `Sources/JenkinsCLI/JenkinsCLI.swift`

## Abstract

This RFC proposes a complete rewrite of the Jenkins CLI to create a comprehensive, user-friendly command-line interface that exposes the full capabilities of the JenkinsSDK using Swift ArgumentParser. The new CLI will replace the current hardcoded development script with a production-ready tool suitable for CI/CD automation, development workflows, and Jenkins administration.

## Motivation

### Current State Problems
- **Security Issues**: Hardcoded Jenkins URL and credentials
- **Limited Functionality**: Only demonstrates basic SDK usage
- **No Argument Parsing**: Requires code modification for different operations
- **Development-Only**: Not suitable for production or distribution

### Desired Outcomes
- **Comprehensive API Coverage**: Expose all JenkinsSDK operations through intuitive commands
- **Security**: Proper authentication handling without hardcoded credentials
- **Usability**: Intuitive CLI following industry best practices
- **Automation-Ready**: Support for CI/CD scripts and batch operations
- **Extensibility**: Easy to add new commands as SDK evolves

## Design Overview

### Command Structure
```bash
jenkins-cli [global-options] <command> <subcommand> [options] [arguments]
```

### Command Groups
```
jenkins-cli
├── server   # Server operations (status, info, version)
├── job      # Job management (list, get, trigger, status)
├── build    # Build operations (get, logs, stop, grep, stream)
├── queue    # Queue management (list, cancel, info)
└── config   # CLI configuration (credentials, profiles)
```

### Global Options
- `--jenkins-url <URL>` / `-u <URL>`: Jenkins instance URL
- `--username <USER>` / `-U <USER>`: Authentication username
- `--password <PASS>` / `-P <PASS>`: Authentication password
- `--netrc-file <FILE>`: Path to netrc file (default: ~/.netrc)
- `--timeout <SECONDS>`: Request timeout (default: 30)
- `--output <FORMAT>` / `-o <FORMAT>`: Output format (json|yaml|table|compact)
- `--verbose` / `-v`: Verbose output
- `--quiet` / `-q`: Suppress non-essential output
- `--no-color`: Disable colored output

## Detailed Command Specifications

### Server Commands
```bash
jenkins-cli server status              # Health check + basic info
jenkins-cli server info                # Detailed instance information
jenkins-cli server version             # Jenkins version and build info
```

**Authentication**: All commands support global auth options with precedence:
1. Command-line arguments (`--username`, `--password`)
2. Environment variables (`JENKINS_USERNAME`, `JENKINS_PASSWORD`)
3. Netrc file (default `~/.netrc` or `--netrc-file`)

### Job Commands
```bash
# Job Information
jenkins-cli job list [path]            # List jobs (hierarchical)
jenkins-cli job get <path>              # Get job details
jenkins-cli job status <path>           # Quick status check
jenkins-cli job builds <path>           # List job builds

# Job Operations  
jenkins-cli job trigger <path>          # Trigger build
jenkins-cli job trigger <path> --param key=value --param key2=value2
jenkins-cli job watch <path>            # Watch job status changes
```

**Key Features**:
- **Hierarchical Navigation**: Support folder paths like `folder/subfolder/job`
- **Build References**: Latest build info with each job
- **Smart Completion**: Shell completion for job paths
- **Bulk Operations**: Multiple job operations with glob patterns

### Build Commands
```bash
# Build Information
jenkins-cli build get <job-path> <number>       # Get build details
jenkins-cli build get <job-path> latest         # Get latest build
jenkins-cli build get <job-path> @-1            # Previous build
jenkins-cli build status <job-path> <number>    # Quick status

# Build Operations
jenkins-cli build stop <job-path> <number>      # Stop running build
jenkins-cli build wait <job-path> <number>      # Wait for completion

# Build Logs
jenkins-cli build logs <job-path> <number>      # Get complete logs
jenkins-cli build logs <job-path> <number> --follow    # Stream logs
jenkins-cli build logs <job-path> <number> --tail 100  # Last N lines
jenkins-cli build grep <job-path> <number> <pattern>   # Search logs
jenkins-cli build grep <job-path> <number> <pattern> --context 3
```

**Key Features**:
- **Smart Build Resolution**: `latest`, `last-successful`, `@-N` syntax
- **Real-time Streaming**: Follow logs as they're written
- **Advanced Search**: Regex patterns with context lines
- **Progress Indicators**: For long-running operations

### Queue Commands
```bash
jenkins-cli queue list                  # Show current queue
jenkins-cli queue info <id>             # Get queue item details
jenkins-cli queue cancel <id>           # Cancel queued item
jenkins-cli queue wait <id>             # Wait for item to start building
jenkins-cli queue watch                 # Watch queue changes
```

**Key Features**:
- **Real-time Updates**: Watch queue state changes
- **Bulk Operations**: Cancel multiple items
- **Smart Waiting**: Automatic transition to build monitoring

### Configuration Commands
```bash
jenkins-cli config init                 # Initialize configuration
jenkins-cli config set jenkins-url <url>
jenkins-cli config set username <user>
jenkins-cli config profiles list       # List saved profiles
jenkins-cli config profiles add <name> --url <url> --username <user>
jenkins-cli config profiles use <name>
```

## Implementation Architecture

### Core Components

#### 1. Main Entry Point
```swift
@main
struct JenkinsCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "jenkins-cli",
        abstract: "A comprehensive Jenkins command-line interface",
        discussion: "Manage Jenkins jobs, builds, and queues from the command line.",
        version: "2.0.0",
        subcommands: [
            ServerCommand.self,
            JobCommand.self, 
            BuildCommand.self,
            QueueCommand.self,
            ConfigCommand.self
        ]
    )
}
```

#### 2. Global Options Group
```swift
struct GlobalOptions: ParsableArguments {
    @Option(name: [.short, .long], help: "Jenkins instance URL")
    var jenkinsUrl: String?
    
    @Option(name: [.short, .long], help: "Username for authentication") 
    var username: String?
    
    @Option(name: [.short, .long], help: "Password for authentication")
    var password: String?
    
    @Option(help: "Path to netrc file")
    var netrcFile: String?
    
    @Option(help: "Request timeout in seconds")
    var timeout: TimeInterval = 30
    
    @Option(name: [.short, .long], help: "Output format")
    var output: OutputFormat = .table
    
    @Flag(name: [.short, .long], help: "Verbose output")
    var verbose: Bool = false
    
    @Flag(name: [.short, .long], help: "Quiet mode")
    var quiet: Bool = false
    
    @Flag(help: "Disable colored output")
    var noColor: Bool = false
}
```

#### 3. Jenkins Client Factory
```swift
struct JenkinsClientFactory {
    static func create(from options: GlobalOptions) async throws -> JenkinsClient {
        let credentials = try resolveCredentials(from: options)
        let transport = createTransport(timeout: options.timeout)
        
        guard let url = resolveJenkinsURL(from: options) else {
            throw CLIError.missingJenkinsURL
        }
        
        return JenkinsClient(
            baseURL: url,
            transport: transport,
            credentials: credentials
        )
    }
}
```

#### 4. Output Formatting System
```swift
protocol OutputFormatter {
    func format<T: Encodable>(_ data: T) throws -> String
}

struct TableFormatter: OutputFormatter { /* ... */ }
struct JSONFormatter: OutputFormatter { /* ... */ }
struct YAMLFormatter: OutputFormatter { /* ... */ }
struct CompactFormatter: OutputFormatter { /* ... */ }
```

#### 5. Streaming and Real-time Features
```swift
actor LogStreamer {
    func streamLogs(
        client: JenkinsClient, 
        jobPath: String, 
        buildNumber: Int,
        follow: Bool
    ) async throws {
        // Implementation using BuildLogStream and AsyncLineSequence
    }
}

actor StatusWatcher {
    func watchJobStatus(
        client: JenkinsClient,
        jobPath: String
    ) async throws {
        // Periodic polling with intelligent intervals
    }
}
```

### Command Implementation Pattern

Each command group follows a consistent pattern:

```swift
struct JobCommand: AsyncParsableCommand {
    @OptionGroup var globalOptions: GlobalOptions
    
    static let configuration = CommandConfiguration(
        commandName: "job",
        abstract: "Job management operations",
        subcommands: [
            JobListCommand.self,
            JobGetCommand.self,
            JobTriggerCommand.self,
            JobStatusCommand.self,
            JobBuildsCommand.self,
            JobWatchCommand.self
        ]
    )
}

struct JobGetCommand: AsyncParsableCommand {
    @OptionGroup var globalOptions: GlobalOptions
    
    @Argument(help: "Job path (e.g., 'folder/job-name')")
    var jobPath: String
    
    @Flag(help: "Include build history")
    var includeBuids: Bool = false
    
    func run() async throws {
        let client = try await JenkinsClientFactory.create(from: globalOptions)
        let job = try await client.job(at: jobPath).get()
        
        let formatter = OutputFormatterFactory.create(globalOptions.output)
        let output = try formatter.format(job)
        print(output)
    }
}
```

## User Experience Enhancements

### 1. Intelligent Build Resolution
- `latest` → Most recent build
- `last-successful` → Most recent successful build  
- `last-failed` → Most recent failed build
- `@-N` → Nth build from latest (e.g., `@-1` = previous build)
- `#N` → Specific build number

### 2. Progress Indicators
```bash
$ jenkins-cli job trigger my-job --wait
⠋ Triggering build for my-job...
✓ Build #123 queued (ID: 456)
⠋ Waiting in queue... (position: 2)
⠋ Build #123 started...  
⠋ Building... (5m 23s)
✓ Build #123 completed: SUCCESS
```

### 3. Follow/Watch Features
```bash
# Follow logs as they're written
$ jenkins-cli build logs my-job latest --follow

# Watch job status changes  
$ jenkins-cli job watch my-job
[14:23:45] Build #123 started
[14:28:12] Build #123 completed: SUCCESS
[14:30:01] Build #124 queued
```

### 4. Shell Integration
- **Bash/Zsh Completion**: Auto-complete job paths, build numbers
- **Exit Codes**: Proper exit codes for scripting
- **Color Support**: Colored output with `--no-color` override
- **Pager Integration**: Automatic paging for long output

## Security and Authentication

### Authentication Precedence
1. **Command-line arguments**: `--username` / `--password`
2. **Environment variables**: `JENKINS_USERNAME` / `JENKINS_PASSWORD`  
3. **Netrc file**: Default `~/.netrc` or `--netrc-file`
4. **Configuration profiles**: Saved credentials (encrypted)

### Security Features
- **No credential logging**: Sensitive data never appears in logs
- **Netrc validation**: Verify proper file permissions (600)
- **Profile encryption**: Store credentials securely
- **Session handling**: Efficient credential reuse

## Error Handling and User Feedback

### Error Categories
- **Connection Errors**: Network issues, authentication failures
- **API Errors**: Jenkins API errors with context
- **User Input Errors**: Invalid paths, missing arguments
- **CLI Errors**: Configuration issues, missing files

### User-Friendly Messages
```bash
Error: Could not connect to Jenkins at https://jenkins.example.com
└─ Connection refused. Is Jenkins running?

Error: Job 'nonexistent-job' not found
└─ Available jobs: my-job, other-job, folder/nested-job

Error: Build #999 does not exist for job 'my-job'  
└─ Available builds: #1-#45 (latest: #45)
```

## Testing Strategy

### Unit Tests
- **Command Parsing**: Verify ArgumentParser configurations
- **Client Factory**: Authentication resolution logic
- **Formatters**: Output format consistency
- **Error Handling**: Proper error propagation

### Integration Tests  
- **SDK Integration**: Real Jenkins API calls
- **Authentication**: Multiple auth methods
- **Streaming**: Log following and status watching
- **Cross-platform**: macOS, Linux compatibility

### CLI Testing
- **Command Execution**: Full command workflows
- **Output Validation**: Format and content verification
- **Error Scenarios**: Network failures, invalid input
- **Performance**: Large log files, long operations

## Migration and Deployment

### Migration from Current CLI
1. **Backup**: Save current `JenkinsCLI.swift` as reference
2. **Gradual Rollout**: New CLI alongside current for testing
3. **Feature Parity**: Ensure all current functionality covered
4. **Documentation**: Update README and help text

### Deployment Strategy
- **Package Manager**: Swift Package Manager integration
- **Homebrew**: Formula for easy installation
- **Docker**: Container images for CI/CD
- **GitHub Releases**: Binary releases for multiple platforms

### Backward Compatibility
- **Environment Variables**: Continue supporting existing env vars
- **Configuration**: Migrate existing configurations
- **Scripts**: Provide migration guide for existing scripts

## Implementation Phases

### Phase 1: Foundation (Week 1-2)
- [ ] Main CLI structure with ArgumentParser
- [ ] Global options and configuration
- [ ] Authentication system
- [ ] Basic output formatting
- [ ] Error handling framework

### Phase 2: Core Commands (Week 3-4)
- [ ] Server commands (status, info)
- [ ] Job commands (list, get, trigger)
- [ ] Build commands (get, logs, stop)
- [ ] Queue commands (list, cancel)

### Phase 3: Enhanced Features (Week 5-6)  
- [ ] Real-time streaming (logs, status)
- [ ] Advanced search and filtering
- [ ] Progress indicators
- [ ] Shell completion

### Phase 4: Polish and Distribution (Week 7-8)
- [ ] Comprehensive testing
- [ ] Documentation and help text
- [ ] Performance optimization
- [ ] Package and release preparation

## Conclusion

This RFC proposes a comprehensive rewrite of the Jenkins CLI that transforms it from a development script into a production-ready, user-friendly command-line tool. The new CLI will:

- **Expose** the full JenkinsSDK API through intuitive commands
- **Eliminate** security issues with proper authentication handling
- **Provide** enhanced user experience with real-time features
- **Support** automation and scripting workflows  
- **Follow** CLI best practices and conventions

The phased implementation approach ensures steady progress while maintaining quality and testability. The resulting CLI will be suitable for distribution and will significantly improve the developer experience when working with Jenkins from the command line.

## References

- [Swift ArgumentParser Documentation](https://apple.github.io/swift-argument-parser/)
- [Jenkins REST API Documentation](https://www.jenkins.io/doc/book/using/remote-access-api/)
- [CLI Design Guidelines](https://clig.dev/)
- Current JenkinsSDK Implementation
- Existing MCP Tool Implementations (for reference patterns)