# Jenkins MCP Server

A Model Context Protocol (MCP) server and Swift SDK for Jenkins automation, enabling AI assistants to interact with Jenkins instances seamlessly.

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [MCP Server](#mcp-server)
  - [Available Tools](#available-tools)
  - [Running the Server](#running-the-server)
  - [Authentication](#authentication)
- [Swift SDK](#swift-sdk)
  - [Quick Start](#quick-start)
  - [API Reference](#api-reference)
- [Building and Development](#building-and-development)

## Overview

This project provides:
- An MCP server that exposes Jenkins functionality to AI assistants through a standardized protocol
- A comprehensive Swift SDK for Jenkins automation with modern Swift patterns

The MCP server includes efficient tools for working with large log outputs, using grep patterns and pagination to explore logs progressively without overwhelming context windows.

## Installation

### MCP Server Setup

1. Clone and build the project:
```bash
git clone https://github.com/your-org/jenkins-mcp.git
cd jenkins-mcp
swift build -c release
```

2. Set up authentication (see [Authentication](#authentication) section)

3. Add to your MCP configuration (e.g., Claude Desktop):
```json
{
  "mcpServers": {
    "jenkins": {
      "command": "/path/to/jenkins-mcp/.build/release/jenkins-mcp",
      "args": ["--jenkins-url", "https://your-jenkins.com"]
    }
  }
}
```

### Swift SDK Installation

Add to your `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/your-org/jenkins-mcp.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "JenkinsSDK", package: "jenkins-mcp"),
            .product(name: "HTTPTransport", package: "jenkins-mcp")
        ]
    )
]
```

## MCP Server

### Available Tools

**Job Management:**
- `get_overview` - Jenkins server overview
- `list_jobs` - List jobs in a folder
- `get_job` / `get_job_by_url` - Get job details
- `trigger_build` - Trigger builds with parameters

**Build Operations:**
- `get_build` / `get_build_by_url` - Get build details
- `stop_build` - Stop running builds
- `get_queue` - View build queue
- `get_queue_item` - Get specific queue item details
- `cancel_queue_item` - Cancel queued builds

**Log Analysis:**
- `get_build_logs` - Get console output with pagination
- `get_build_logs_offset` - Read logs from specific offset
- `grep_build_logs` - Search logs with regex patterns

### Running the Server

```bash
# Using default ~/.netrc authentication
swift run jenkins-mcp --jenkins-url https://your-jenkins.com

# Using custom netrc file
swift run jenkins-mcp --jenkins-url https://your-jenkins.com --netrc-file /path/to/.netrc

# Using environment variables
export JENKINS_USERNAME=your-username
export JENKINS_PASSWORD=your-api-token
swift run jenkins-mcp --jenkins-url https://your-jenkins.com
```

### Authentication

The server supports two authentication methods:

**Netrc File (Recommended):**

Create `~/.netrc`:
```
machine your-jenkins.com
login your-username
password your-api-token
```

Set permissions:
```bash
chmod 600 ~/.netrc
```

**Environment Variables:**
```bash
export JENKINS_USERNAME=your-username
export JENKINS_PASSWORD=your-api-token
```

## Swift SDK

### Quick Start

```swift
import JenkinsSDK
import HTTPTransport
import AsyncHTTPClient

let client = JenkinsClient(
    baseURL: URL(string: "https://your-jenkins.com")!,
    transport: HTTPClientTransport(client: HTTPClient.shared),
    credentials: JenkinsCredentials(username: "user", password: "api-token")
)

// Get server overview
let overview = try await client.get()

// Work with jobs
let job = try await client.job(at: "folder/my-project").get()

// Trigger a build
let queueRef = try await client.job(at: "my-project").builds.trigger(parameters: [
    "BRANCH": "main"
])
```

### API Reference

#### Jobs API

Access jobs through path-scoped instances:

```swift
// Direct path access
let job = client.job(at: "folder/my-project")

// Navigate nested structure
let nestedJob = client.job(at: "folder").job(named: "subfolder").job(named: "my-project")

// Get job details
let jobDetails = try await job.get()

// Get job by URL
let job = try await client.job(byURL: "https://jenkins.com/job/my-project/").get()
```

#### Builds API

Build operations are nested under jobs:

```swift
let builds = client.job(at: "my-project").builds

// Trigger build
let queueRef = try await builds.trigger(parameters: ["BRANCH": "main"])

// Get build details
let build = try await builds.get(number: 123)

// Stop running build
try await builds.stop(number: 123)
```

#### Build Logs

```swift
// Get complete logs
let logs = try await builds.logs(number: 123)

// Stream logs progressively
let result = try await builds.streamLogs(number: 123) { nextOffset, lines in
    for try await line in lines {
        print(line)
    }
    return someResult
}

// Search logs with grep
let matches = try await builds.grepLogs(
    number: 123,
    pattern: "ERROR.*database",
    context: 2,
    maxLines: 50
)
```

#### Queue Management

```swift
// Get queue info
let queueInfo = try await client.queue.info()

// Get specific queue item by ID
let item = try await client.queue.item(forId: 12345)

// Get queue item by reference (from trigger)
let item = try await client.queue.item(referencedBy: queueRef)

// Cancel queued build
try await client.queue.cancel(id: 12345)
```

#### Working with Build Objects

```swift
let build = try await builds.get(number: 123)

// Basic info
print("Status: \(build.status)")
print("Duration: \(build.durationTimeInterval) seconds")

// Status checks
if build.isRunning { /* ... */ }
if build.isSuccess { /* ... */ }

// Build parameters
let params = build.buildParameters
print("Branch: \(params["BRANCH"] ?? "main")")

// Build causes
if build.triggeredByUser {
    print("Triggered by user")
}
```

#### Error Handling

```swift
do {
    let build = try await builds.get(number: 999)
} catch JenkinsAPIError.buildNotFound {
    print("Build not found")
} catch JenkinsAPIError.httpError(let code) {
    print("HTTP error: \(code)")
}
```

## Building and Development

```bash
# Build all targets
swift build

# Run tests
swift test

# Build release version
swift build -c release

# Build Docker images
make docker

# Format code
swift format --in-place -r Sources/ Tests/

# Lint code
swift format lint -r Sources/ Tests/
```