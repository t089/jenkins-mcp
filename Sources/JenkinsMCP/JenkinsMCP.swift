import ArgumentParser
import AsyncHTTPClient
import HTTPTransport
import JenkinsSDK
import Logging
import MCP
import Netrc
import ServiceLifecycle
import SystemPackage

#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#else
    #error("Unsupported platform")
#endif

@main
struct JenkinsMCP: AsyncParsableCommand {

    @Option(name: .shortAndLong, help: "The Jenkins base URL (e.g. http://localhost:8080)")
    var jenkinsUrl: String

    @Option(name: .long, help: "The path to the Netrc file for authentication (optional, defaults to ~/.netrc)")
    var netrcFile: String?

    mutating func validate() throws {
        guard let url = URL(string: jenkinsUrl), url.scheme != nil else {
            throw ValidationError("Invalid Jenkins URL provided.")
        }
    }

    private func loadJenkinsCredentials() throws -> JenkinsCredentials {
        if let username = ProcessInfo.processInfo.environment["JENKINS_USERNAME"],
            let password = ProcessInfo.processInfo.environment["JENKINS_PASSWORD"]
        {
            return JenkinsCredentials(username: username, password: password)
        } else {
            let netrcFile =
                netrcFile
                ?? FileManager
                .default
                .homeDirectoryForCurrentUser
                .appendingPathComponent(".netrc")
                .path

            if !FileManager.default.fileExists(atPath: netrcFile) {
                throw ValidationError("Netrc file does not exist at \(netrcFile)")
            }

            var st = stat()
            if stat(netrcFile, &st) != 0 {
                throw ValidationError(
                    "Failed to get attributes of netrc file at \(netrcFile): \(String(cString: strerror(errno)))"
                )
            }

            let filePermissions = FilePermissions(rawValue: st.st_mode)
            guard filePermissions.isDisjoint(with: [.groupRead, .otherRead]) else {
                throw ValidationError("Netrc file at \(netrcFile) must be user readable only")
            }

            let data = FileManager.default.contents(atPath: netrcFile) ?? Data()

            let netrc = try Netrc.parse(String(decoding: data, as: UTF8.self))

            guard let credentials = netrc.authorization(for: URL(string: jenkinsUrl)!) else {
                throw ValidationError("No credentials found for \(jenkinsUrl) in \(netrcFile)")
            }

            return JenkinsCredentials(
                username: credentials.login,
                password: credentials.password
            )
        }
    }

    func run() async throws {
        LoggingSystem.bootstrap(StreamLogHandler.standardError(label:))

        let logger = Logger(label: "main")

        // Create a server with given capabilities
        let server = Server(
            name: "JenkinsMCP",
            version: "0.0.4-beta",
            capabilities: .init(
                prompts: nil,
                resources: nil,
                tools: .init(listChanged: false)
            )
        )

        var config = HTTPClient.Configuration.singletonConfiguration
        config.decompression = .enabled(limit: .none)
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton, configuration: config)
        defer {
            Task {
                try await httpClient.shutdown()
            }
        }

        let jenkinsClient = JenkinsClient(
            baseURL: URL(string: jenkinsUrl)!,
            transport: HTTPClientTransport(client: httpClient, defaultTimeout: .seconds(30)),
            credentials: try loadJenkinsCredentials(),
        )

        let toolRegistry = ToolRegistry()
        toolRegistry.register(
            GetOverviewTool(jenkinsClient: jenkinsClient),
            ListJobsTool(jenkinsClient: jenkinsClient),
            GetJobTool(jenkinsClient: jenkinsClient),
            GetJobByURLTool(jenkinsClient: jenkinsClient),
            GetBuildTool(jenkinsClient: jenkinsClient),
            GetBuildByURLTool(jenkinsClient: jenkinsClient),
            GetBuildLogsTool(jenkinsClient: jenkinsClient),
            GetBuildLogsOffsetTool(jenkinsClient: jenkinsClient),
            GrepBuildLogsTool(jenkinsClient: jenkinsClient),
            BuildTestReportTool(jenkinsClient: jenkinsClient),
            TriggerBuildTool(jenkinsClient: jenkinsClient),
            StopBuildTool(jenkinsClient: jenkinsClient),
            GetQueueTool(jenkinsClient: jenkinsClient),
            CancelQueueItemTool(jenkinsClient: jenkinsClient)
        )

        await server.withMethodHandler(ListTools.self) { _ in
            return .init(tools: toolRegistry.toolDefinitions())
        }

        await server.withMethodHandler(CallTool.self) { params in
            do {
                return try await toolRegistry.callTool(named: params.name, with: params.arguments ?? [:])
            } catch let error as JenkinsAPIError {
                switch error {
                case .httpError(let code):
                    return .init(content: [.text("Jenkins API HTTP error: \(code)")])
                case .noData:
                    return .init(content: [.text("No data received from Jenkins API")])
                case .decodingError(let decodingError):
                    return .init(content: [.text("Failed to decode Jenkins response: \(decodingError)")])
                case .invalidURL:
                    return .init(content: [.text("Invalid URL provided")])
                case .buildNotFound:
                    return .init(content: [.text("Build not found")])
                case .jobNotFound:
                    return .init(content: [.text("Job not found")])
                case .invalidPath(let path):
                    return .init(content: [.text("Invalid path provided: \(path)")])
                case .invalidPattern(let pattern):
                    return .init(content: [.text("Invalid regex pattern: \(pattern)")])
                }
            } catch {
                logger.error("Error in tool \(params.name): \(error)")
                throw error
            }
        }

        // Create transport and start server
        let transport = StdioTransport()

        let serviceGroup = ServiceGroup(
            services: [
                MCPService(server: server, transport: transport, logger: logger)
            ],
            gracefulShutdownSignals: [.sigterm, .sigint],
            logger: logger
        )

        try await serviceGroup.run()
    }
}

struct MCPService: Service {
    let server: Server
    let transport: Transport
    let logger: Logger

    func run() async throws {
        try await server.start(transport: transport)

        logger.info("Server ready")

        // wait for grateful shutdown signal
        try await gracefulShutdown()

        logger.info("Shutting down server...")
        // stop the server
        await server.stop()

        // wait for server to complete
        await server.waitUntilCompleted()
        logger.info("Server stopped")
    }
}
