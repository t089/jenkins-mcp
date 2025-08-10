# Jenkins CLI Job Command Group Design

## Overview

The `jenkins-cli job` command group provides comprehensive job management capabilities for Jenkins. This design leverages the JenkinsSDK's resource-scoped API pattern with `JenkinsClient.job(at:)` and `JobClient` operations.

## Architecture

### Core Components

1. **JenkinsClient Navigation**
   - `JenkinsClient.job(at: "path")` → Returns `JobClient` 
   - `JenkinsClient.job(byURL: "url")` → Returns `JobClient` from URL
   - `JobClient.job(named: "name")` → Navigate hierarchically

2. **JobClient Capabilities**
   - `JobClient.get()` → Fetch complete `Job` details
   - `JobClient.builds` → Access `BuildClient` for build operations
   - Path-based navigation using forward slash separators

3. **Job Model Properties** (from Models.swift)
   - Core: `name`, `url`, `description`, `buildable`
   - Build References: `lastBuild`, `lastCompletedBuild`, `lastSuccessfulBuild`, etc.
   - Status: `color` (health indicator), `nextBuildNumber`
   - Hierarchy: `jobs` (child jobs for folder-type jobs)
   - Computed: `isHealthy`, `isFailing`, `isBuilding`, `hasChildJobs`

## Command Structure

```
jenkins-cli job <subcommand> [options]
```

### Subcommands

#### 1. `get` - Get Job Details
```bash
jenkins-cli job get <path> [--format <format>] [--url]
```

**Purpose**: Retrieve comprehensive job information
**Implementation**: Uses `JobClient.get()`

**Parameters**:
- `path` (required): Job path using forward slash separators (e.g., "folder/subfolder/jobname")
- `--format`: Output format (`json`, `yaml`, `table`) - default: `table`
- `--url`: Get job by URL instead of path (uses `job(byURL:)`)

**Output Fields**:
- Basic info: name, description, buildable status
- Health: color-coded status, is healthy/failing/building
- Build numbers: last, last completed, last successful, last failed
- Child jobs count (if folder)
- Next build number

#### 2. `list` - List Jobs in Folder
```bash
jenkins-cli job list [path] [--recursive] [--format <format>] [--status <status>]
```

**Purpose**: Navigate and explore job hierarchy
**Implementation**: Uses `JobClient.get()` then accesses `job.childJobs`

**Parameters**:
- `path` (optional): Folder path - defaults to root
- `--recursive`: Recursively list all nested jobs
- `--format`: Output format (`json`, `yaml`, `table`) - default: `table`
- `--status`: Filter by status (`healthy`, `failing`, `building`, `disabled`)

**Output**: Table/list of `JobSummary` objects showing:
- Name, health status (color-coded), buildable status
- Description (truncated)
- Type indicator (folder vs job)

#### 3. `trigger` - Trigger Job Build
```bash
jenkins-cli job trigger <path> [--param key=value]... [--wait] [--follow-logs]
```

**Purpose**: Start new job build with parameters
**Implementation**: Uses `JobClient.builds.trigger(parameters:)`

**Parameters**:
- `path` (required): Job path
- `--param`: Build parameters as key=value pairs (repeatable)
- `--wait`: Wait for build to complete before returning
- `--follow-logs`: Stream build logs in real-time

**Output**:
- Queue item reference
- Build number (once started)
- Final status (if --wait)

#### 4. `status` - Get Job Status
```bash
jenkins-cli job status <path> [--watch] [--format <format>]
```

**Purpose**: Quick status check with key metrics
**Implementation**: Uses `JobClient.get()` with focused output

**Parameters**:
- `path` (required): Job path
- `--watch`: Continuously monitor status
- `--format`: Output format - default: `compact`

**Output**:
- Health status, last build result
- Build numbers and timestamps
- Currently building indicator

#### 5. `info` - Detailed Job Information
```bash
jenkins-cli job info <path> [--builds <count>] [--format <format>]
```

**Purpose**: Comprehensive job details with build history
**Implementation**: Uses `JobClient.get()` with full detail rendering

**Parameters**:
- `path` (required): Job path  
- `--builds`: Number of recent builds to include (default: 5)
- `--format`: Output format - default: `detailed`

**Output**: Full job information including:
- Complete job configuration details
- Recent build history with status/duration
- Parameter definitions (if parameterized job)
- SCM information

## Path Handling

### Path Format
- Forward slash separated: `"folder/subfolder/jobname"`
- Root level jobs: `"jobname"`  
- URL format: Full Jenkins job URLs automatically parsed

### Path Resolution
```swift
// Internal path conversion (from JenkinsClient.swift)
let jobPath = path.split(separator: "/").map { "job/\($0)" }.joined(separator: "/")
// "folder/jobname" → "job/folder/job/jobname"
```

### Navigation Examples
```swift
// Direct path access
let client = jenkins.job(at: "folder/subfolder/jobname")
let job = try await client.get()

// Hierarchical navigation  
let folderClient = jenkins.job(at: "folder")
let jobClient = folderClient.job(named: "jobname")
let job = try await jobClient.get()

// URL-based access
let client = try jenkins.job(byURL: "https://jenkins.example.com/job/folder/job/jobname/")
let job = try await client.get()
```

## Parameter Handling for Builds

### Build Parameters
- String parameters: `--param "BRANCH=main"`
- Boolean parameters: `--param "SKIP_TESTS=true"`
- Choice parameters: `--param "ENVIRONMENT=staging"`

### Implementation
```swift
// From StartBuildTool pattern
let parameters: [String: String] = parseParameters(from: paramArgs)
let queueItem = try await jenkinsClient.job(at: path).builds.trigger(parameters: parameters)
```

## Error Handling

### Common Scenarios
- **Job not found**: `JenkinsAPIError.jobNotFound`
- **Invalid path**: `JenkinsAPIError.invalidPath` 
- **Build not buildable**: Check `job.buildable` before triggering
- **Permission errors**: HTTP 403 errors from Jenkins API
- **Network issues**: Connection timeouts, DNS resolution

### User-Friendly Messages
- Clear indication when job doesn't exist
- Suggestions for similar job names
- Path format examples on invalid input
- Build parameter validation with expected formats

## Output Formatting

### Table Format (Default)
```
NAME           STATUS   LAST BUILD   LAST SUCCESS   BUILDABLE
my-job         ✓        #123 (2h)    #123 (2h)      Yes
failing-job    ✗        #45 (1d)     #44 (2d)       Yes  
folder/        📁       -            -              N/A
```

### JSON Format
- Complete Job/JobSummary model serialization
- Consistent with MCP tool output format
- Machine-readable for scripting

### YAML Format  
- Human-readable structured output
- Good for configuration review

## Integration with Existing SDK

### Leveraging JobClient
```swift
extension JobClient {
    // Available operations:
    func get() async throws -> Job
    func job(named name: String) -> JobClient  
    var builds: BuildClient
}
```

### Leveraging BuildClient
```swift  
extension JobClient.BuildClient {
    // Available operations:
    func trigger(parameters: [String: String]) async throws -> QueueItemRef
    func get(number buildNumber: Int) async throws -> Build
    func stop(number buildNumber: Int) async throws
    func logs(number buildNumber: Int) async throws -> String
}
```

### Job Model Usage
```swift
// Rich model with computed properties
job.isHealthy       // Health status from color
job.isFailing       // Failure status  
job.isBuilding      // Currently building
job.hasChildJobs    // Folder detection
job.childJobs       // Navigation
job.buildReferences // Build history
```

## Command Examples

### Basic Usage
```bash
# Get job details
jenkins-cli job get "my-project/main-branch"

# List root jobs  
jenkins-cli job list

# List jobs in folder
jenkins-cli job list "my-project" 

# Trigger build
jenkins-cli job trigger "my-project/main-branch"

# Trigger with parameters
jenkins-cli job trigger "my-project/feature" --param "BRANCH=feature-123" --param "DEPLOY=false"

# Monitor status
jenkins-cli job status "my-project/main-branch" --watch
```

### Advanced Usage
```bash  
# Recursive listing with filtering
jenkins-cli job list "projects" --recursive --status failing

# Detailed info with build history
jenkins-cli job info "critical-service" --builds 10

# Trigger and wait for completion
jenkins-cli job trigger "deploy-staging" --wait --follow-logs

# JSON output for scripting
jenkins-cli job get "service-x" --format json | jq '.lastBuild.number'
```

## Implementation Notes

### ArgumentParser Integration
- Use `@Argument` for required path parameters
- Use `@Option` for optional parameters and flags  
- Use `@Flag` for boolean switches
- Leverage argument validation and help generation

### Async/Await Support
- All SDK operations are async
- Use `AsyncParsableCommand` for ArgumentParser integration
- Handle cancellation and timeouts appropriately

### Configuration
- Inherit Jenkins URL and credentials from parent command
- Support environment variable overrides
- Integrate with netrc authentication handling

This design provides comprehensive job management capabilities while maintaining consistency with the existing JenkinsSDK patterns and MCP tool architecture.