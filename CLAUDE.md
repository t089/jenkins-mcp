# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Quick Reference

### Development Commands
```bash
swift build                     # Build all targets
swift test                      # Run all tests
swift test --filter TestName    # Run specific test
make docker                     # Build multi-platform Docker images
swift format --in-place -r .    # Format all Swift files
swift format lint -r .          # Check formatting issues
```

### Running Applications
```bash
swift run jenkins-mcp --jenkins-url <url>  # MCP server
swift run jenkinscli                       # CLI tool (testing/development)
```

## Key Development Notes

### Swift Package Lookup
When working with dependencies, search through `.build/checkouts/` folder for package syntax and usage examples.

### Resource-Scoped API Pattern
The SDK uses nested, path-scoped resources:
- `JenkinsClient.job(at: "path")` returns a `JobClient`
- `JobClient.builds` provides build operations
- `JobClient.job(named: "name")` allows hierarchical navigation

### Testing
- Uses swift-testing framework (NOT XCTest)
- Tests organized by component in `Tests/` directory
- Run specific tests with `--filter` flag

### Code Style
- Follow existing patterns in neighboring files
- Check imports and dependencies before adding libraries
- Use `.swift-format` rules for consistent formatting

### Platform support

Supported platform are Linux and macOS. Always make sure that code works on both.

When using `Foundation`, make sure to only use `FoundationEssentials` on linux!

```swift
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
```

Things that are available on `FoundationEssentials`: `URL`, `Data`, `FileManager`, `Decimal`, `JSONEncoder/JSONDecoder`, `Date`, `DateComponents`, `HTTPFormatStyle`, `ISO8601FormatStyle`, `ProcessInfo`.
Some of the other `Foundation` APIs are only available in the "full" Foundation unfortunately. Avoid extension provided by `Foundation` such as `String.data(using:)`, prefer `Array(string.utf8)` or `Data(stringutf8)` and `String(decoding:as:)`.

### MCP Tool Architecture
Each Jenkins operation in `Sources/JenkinsMCP/Tools/`:
- Implements `JenkinsTool` protocol
- Defines JSON schema for parameters
- Translates MCP calls to SDK operations

### Authentication Handling
MCP server supports:
- Environment variables: `JENKINS_USERNAME`, `JENKINS_PASSWORD`
- Netrc file: Default `~/.netrc` or custom via `--netrc-file`

### Important Reminders
- Never create files unless absolutely necessary
- Always prefer editing existing files
- Don't create documentation unless explicitly requested
- Follow security best practices - never log secrets