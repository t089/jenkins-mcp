# Jenkins MCP Server

A Model Context Protocol (MCP) server for Jenkins automation, enabling AI assistants to interact with Jenkins instances seamlessly.

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Available Tools](#available-tools)
- [Running the Server](#running-the-server)
- [Authentication](#authentication)
- [Building and Development](#building-and-development)

## Overview

This project provides a stdio MCP server that exposes Jenkins functionality to AI assistants through the Model Context Protocol, enabling seamless automation and interaction with Jenkins instances.

The server includes efficient tools for working with large log outputs, using grep patterns and pagination to explore logs progressively without overwhelming context windows.

## Installation

### From source

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
      "type": "stdio",
      "command": "/path/to/jenkins-mcp/.build/release/jenkins-mcp",
      "args": ["--jenkins-url", "https://your-jenkins.com"]
    }
  }
}
```

### Using docker

1. Store credential in a netrc file. See [Authentication](#authentication) section.

2. Add to your MCP configuration (e.g., Claude Desktop):
```json
{
  "mcpServers": {
    "jenkins": {
      "type": "stdio",
      "command": "docker",
      "args": [
        "run",
        "--rm",
        "-i",
        "-v",
        "/path/to/.netrc:/var/jenkins/.netrc",
        "ghcr.io/t089/jenkins-mcp:0.0.1-beta",
        "--jenkins-url",
        "https://your-jenkins.com",
        "--netrc-file",
        "/var/jenkins/.netrc"
      ]
    }
  }
}
```

## Available Tools

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

## Running the Server

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

## Authentication

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
```


---
Copyright 2025 Tobias Haeberle
