import HTTPTransport
import HTTPTypes

#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

public struct JenkinsClient: Sendable {
    private let transport: any HTTPTransport
    private let baseURL: URL
    internal let credentials: JenkinsCredentials?
    private let decoder: JSONDecoder

    public init(
        baseURL: URL,
        transport: any HTTPTransport,
        credentials: JenkinsCredentials? = nil
    ) {
        self.baseURL = baseURL
        self.transport = transport
        self.credentials = credentials
        self.decoder = JSONDecoder()
    }

    public struct JobClient {
        private let client: JenkinsClient
        public let path: String

        public init(client: JenkinsClient, path: String) {
            self.client = client
            self.path = path
        }
        
        /// Navigate to a nested job by appending a name/path to the current path
        public func job(named name: String) -> JobClient {
            let nestedPath = path.isEmpty ? name : "\(path)/\(name)"
            return JobClient(client: client, path: nestedPath)
        }

        public func get() async throws -> Job {
            let jobPath = path.split(separator: "/").map { "job/\($0)" }.joined(separator: "/")
            let request = try self.client.buildRequest(path: "/\(jobPath)/api/json")
            let (_, job): (HTTPResponse, Job) = try await self.client.performJSONRequest(request)
            return job
        }

        public func get(byURL url: String) async throws -> Job {
            let apiURL = self.client.makeAPIURL(from: url, tree: nil)
            let (_, job): (HTTPResponse, Job) = try await self.client.performJSONRequestForURL(apiURL)
            return job
        }

        public func get(from jobSummary: JobSummary) async throws -> Job {
            return try await get(byURL: jobSummary.url)
        }

        public struct BuildClient {
            private let client: JenkinsClient
            private let jobPath: String

            init(client: JenkinsClient, jobPath: String) {
                self.client = client
                self.jobPath = jobPath
            }

            public func trigger(parameters: [String: String] = [:]) async throws -> QueueItemRef {
                func trigger(candidate: String) async throws -> QueueItemRef {
                    let jobPathComponents = jobPath.split(separator: "/").map { "job/\($0)" }.joined(separator: "/")
                    var request = try self.client.buildRequest(
                        path: "/\(jobPathComponents)/\(candidate)",
                        method: .post
                    )

                    let formBody: HTTPBody?
                    if !parameters.isEmpty {
                        request.headerFields[.contentType] = "application/x-www-form-urlencoded"
                        let parameterString = parameters.formUrlEncoded()
                        formBody = .init(bytes: parameterString.utf8)
                    } else {
                        formBody = nil
                    }
                    let (response, _) = try await self.client.transport.send(request, body: formBody, baseUrl: self.client.baseURL)

                    guard response.status == .created else {
                        throw JenkinsAPIError.httpError(response.status.code)
                    }

                    guard let location = response.headerFields[.location] else {
                        throw JenkinsAPIError.noData
                    }

                    return QueueItemRef(url: location)
                }

                let candidates: [String]
                if parameters.isEmpty {
                    candidates = ["build", "buildWithParameters"]
                } else {
                    candidates = ["buildWithParameters", "build"]
                }

                var error: JenkinsAPIError? = nil
                for candidate in candidates {
                    do {
                        return try await trigger(candidate: candidate)
                    } catch JenkinsAPIError.httpError(let code) where code / 100 == 4 {
                        // Method not allowed, try next candidate
                        error = JenkinsAPIError.httpError(code)
                        continue
                    }
                }

                if let error = error {
                    throw error
                } else {
                    fatalError("Unreachable: must have thrown an error here")
                }
            }

            public func get(number buildNumber: Int) async throws -> Build {
                let jobPath = jobPath.split(separator: "/").map { "job/\($0)" }.joined(separator: "/")
                let request = try self.client.buildRequest(path: "/\(jobPath)/\(buildNumber)/api/json")
                let (_, build): (HTTPResponse, Build) = try await self.client.performJSONRequest(request)
                return build
            }

            public func get(byURL url: String) async throws -> Build {
                let apiURL = self.client.makeAPIURL(from: url)
                let (_, build): (HTTPResponse, Build) = try await self.client.performJSONRequestForURL(apiURL)
                return build
            }

            public func stop(number buildNumber: Int) async throws {
                let jobPath = jobPath.split(separator: "/").map { "job/\($0)" }.joined(separator: "/")
                let request = try self.client.buildRequest(path: "/\(jobPath)/\(buildNumber)/stop", method: .post)
                let (response, _) = try await self.client.transport.send(request, body: nil, baseUrl: self.client.baseURL)

                guard response.status == .found || response.status == .ok else {
                    throw JenkinsAPIError.httpError(response.status.code)
                }
            }

            public func logs(number buildNumber: Int) async throws -> String {
                let jobPath = jobPath.split(separator: "/").map { "job/\($0)" }.joined(separator: "/")
                let request = try self.client.buildRequest(path: "/\(jobPath)/\(buildNumber)/consoleText")
                let (_, data) = try await self.client.performRawRequest(request)
                return String(decoding: data, as: UTF8.self)
            }

            public func streamLogs<R>(
                number buildNumber: Int,
                startOffset: Int = 0,
                execute: (_ nextOffset: Int?, _ lines: AsyncLineSequence) async throws -> R
            ) async throws -> R {
                let jobPath = self.jobPath.split(separator: "/").map { "job/\($0)" }.joined(separator: "/")
                let logPath = "/\(jobPath)/\(buildNumber)/logText/progressiveText?start=\(startOffset)"
                
                let request = try self.client.buildRequest(path: logPath)
                let (body, hasMoreData, textSize) = try await self.client.performProgressiveRequest(request)
                
                let nextOffset = hasMoreData ? textSize : nil
                let lines = AsyncLineSequence(body: body)
                
                return try await execute(nextOffset, lines)
            }

            public func grepLogs(
                number buildNumber: Int,
                pattern: String,
                context: Int = 0,
                offset: Int = 0,
                maxCount: Int = 200
            ) async throws -> [GrepMatch] {
                return try await streamLogs(number: buildNumber) { _, lines in
                    return try await lines.grep(
                        pattern: pattern,
                        context: context,
                        offset: offset,
                        maxCount: maxCount
                    )
                }
            }
        }

        public var builds: BuildClient {
            return BuildClient(client: self.client, jobPath: self.path)
        }
    }

    public func job(at path: String = "") -> JobClient {
        return JobClient(client: self, path: path)
    }
    
    public func job(byURL url: String) throws -> JobClient {
        // Parse the URL to extract the job path
        let jobPath = try extractJobPath(from: url)
        return JobClient(client: self, path: jobPath)
    }
    
    private func extractJobPath(from urlString: String) throws -> String {
        let (jobPath, _) = try parseJenkinsURL(urlString)
        return jobPath
    }
    
    private func parseJenkinsURL(_ urlString: String) throws -> (jobPath: String, buildNumber: Int?) {
        // Handle both absolute URLs and relative paths
        let path: String
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            guard let url = URL(string: urlString) else {
                throw JenkinsAPIError.invalidURL
            }
            path = url.path
        } else {
            path = urlString
        }
        
        // Remove trailing slash if present
        let normalizedPath = path.hasSuffix("/") ? String(path.dropLast()) : path
        
        // Parse Jenkins job path format: /job/folder/job/subfolder/job/jobname/123
        let components = normalizedPath.split(separator: "/")
        var jobPathComponents: [String] = []
        var buildNumber: Int? = nil
        var i = 0
        
        while i < components.count {
            if components[i] == "job" && i + 1 < components.count {
                jobPathComponents.append(String(components[i + 1]))
                i += 2
            } else if i == components.count - 1 {
                // Check if last component is a build number
                if let number = Int(components[i]) {
                    buildNumber = number
                }
                i += 1
            } else {
                i += 1
            }
        }
        
        guard !jobPathComponents.isEmpty else {
            throw JenkinsAPIError.invalidPath("No job path found in URL: \(urlString)")
        }
        
        return (jobPathComponents.joined(separator: "/"), buildNumber)
    }


    public struct QueueClient {
        private let client: JenkinsClient

        public init(client: JenkinsClient) {
            self.client = client
        }

        public func info() async throws -> QueueInfo {
            let request = try self.client.buildRequest(path: "/queue/api/json")
            let (_, info): (HTTPResponse, QueueInfo) = try await self.client.performJSONRequest(request)
            return info
        }

        public func item(forId id: Int) async throws -> QueueItem {
            let request = try self.client.buildRequest(path: "/queue/item/\(id)/api/json")
            let (_, item): (HTTPResponse, QueueItem) = try await self.client.performJSONRequest(request)
            return item
        }

        public func item(referencedBy ref: QueueItemRef) async throws -> QueueItem {
            return try await item(byURL: ref.url)
        }

        public func item(byURL url: String) async throws -> QueueItem {
            let apiURL = self.client.makeAPIURL(from: url)
            let (_, item): (HTTPResponse, QueueItem) = try await self.client.performJSONRequestForURL(apiURL)
            return item
        }

        public func cancel(id: Int) async throws {
            let request = try self.client.buildRequest(path: "/queue/cancelItem?id=\(id)", method: .post)
            let (response, _) = try await self.client.transport.send(request, body: nil, baseUrl: self.client.baseURL)

            guard response.status == .found || response.status == .ok else {
                throw JenkinsAPIError.httpError(response.status.code)
            }
        }
    }

    public var queue: QueueClient {
        return QueueClient(client: self)
    }
    
    public func get() async throws -> JenkinsOverview {
        let request = try buildRequest(path: "/api/json")
        let (response, overview): (HTTPResponse, JenkinsOverview) = try await performJSONRequest(request)
        
        // Extract version from X-Jenkins header
        let version = response.headerFields[.init("X-Jenkins")!]
        
        // Create a new JenkinsOverview with the version field populated
        return JenkinsOverview(
            version: version,
            jobs: overview.jobs,
            description: overview.description,
            nodeName: overview.nodeName,
            nodeDescription: overview.nodeDescription,
            numExecutors: overview.numExecutors,
            mode: overview.mode
        )
    }

    internal func buildRequest(path: String, method: HTTPRequest.Method = .get) throws -> HTTPRequest {

        let components = URLComponents(string: path)
        guard let components = components else {
            throw JenkinsAPIError.invalidPath(path)
        }

        var path: String
        if let query = components.percentEncodedQuery {
            path = components.percentEncodedPath + "?" + query
        } else {
            path = components.percentEncodedPath
        }

        if !path.starts(with: "/") {
            // Ensure the path is absolute
            path = "/" + path
        }

        var request = HTTPRequest(
            method: method,
            scheme: nil,
            authority: nil,
            path: path
        )

        if let credentials = credentials {
            let authString = "\(credentials.username):\(credentials.password)"
            let authData = Data(authString.utf8)
            let base64Auth = authData.base64EncodedString()
            request.headerFields.append(.init(name: .authorization, value: "Basic \(base64Auth)"))
        }

        request.headerFields.append(.init(name: .accept, value: "application/json"))

        return request
    }

    internal func makeAPIURL(from url: String, tree: String? = nil) -> String {
        var apiURL = url
        // Remove trailing slash if present
        if apiURL.hasSuffix("/") {
            apiURL.removeLast()
        }

        // Add api/json
        apiURL += "/api/json"

        // Add tree parameter if provided
        if let tree = tree {
            apiURL += "?\(tree)"
        }

        return apiURL
    }
}

extension JenkinsClient {

    internal func performJSONRequest<T: Decodable>(_ request: HTTPRequest) async throws -> (HTTPResponse, T) {
        let (response, data) = try await performRawRequest(request)
        do {
            return (response, try decoder.decode(T.self, from: Data(data)))
        } catch {
            throw JenkinsAPIError.decodingError(error)
        }
    }

    internal func performRawRequest(_ request: HTTPRequest) async throws -> (HTTPResponse, ArraySlice<UInt8>) {
        let (response, body) = try await transport.send(request, body: nil, baseUrl: baseURL)

        guard response.status.code == 200 else {
            throw JenkinsAPIError.httpError(response.status.code)
        }

        guard let body = body else {
            throw JenkinsAPIError.noData
        }

        return (response, try await body.collect(upTo: 100_000_000))
    }

    internal func performProgressiveRequest(_ request: HTTPRequest) async throws -> (
        HTTPBody, hasMoreData: Bool, textSize: Int
    ) {
        let (response, body) = try await transport.send(request, body: nil, baseUrl: baseURL)

        guard response.status.code == 200 else {
            throw JenkinsAPIError.httpError(response.status.code)
        }

        guard let body = body else {
            throw JenkinsAPIError.noData
        }

        let hasMoreData = response.headerFields[.init("X-More-Data")!]?.lowercased() == "true"
        let textSize = Int(response.headerFields[.init("X-Text-Size")!] ?? "0") ?? 0

        return (body, hasMoreData, textSize)
    }

    internal func performJSONRequestForURL<T: Decodable>(_ urlString: String) async throws -> (HTTPResponse, T) {
        guard let url = URL(string: urlString) else {
            throw JenkinsAPIError.invalidURL
        }

        // For Jenkins URLs, we need to build a relative path from the root
        let relativePath = url.path + (url.query.map { "?\($0)" } ?? "")
        var request = HTTPRequest(method: .get, scheme: nil, authority: nil, path: relativePath)

        if let credentials = credentials {
            let authString = "\(credentials.username):\(credentials.password)"
            let authData = Data(authString.utf8)
            let base64Auth = authData.base64EncodedString()
            request.headerFields.append(.init(name: .authorization, value: "Basic \(base64Auth)"))
        }

        request.headerFields.append(.init(name: .accept, value: "application/json"))

        // Use the same baseURL as the client
        let (response, body) = try await transport.send(request, body: nil, baseUrl: baseURL)

        guard response.status.code == 200 else {
            throw JenkinsAPIError.httpError(response.status.code)
        }

        guard let body = body else {
            throw JenkinsAPIError.noData
        }

        let data = try await body.collect(upTo: 100_000_000)
        do {
            return (response, try decoder.decode(T.self, from: Data(data)))
        } catch {
            throw JenkinsAPIError.decodingError(error)
        }
    }
}



public struct QueueItemRef: Codable, Sendable {
    public var url: String
    public var queueItemId: Int?


    public init(url: String) {
        self.url = url
        let queryStart = url.firstIndex(of: "?") ?? url.endIndex
        let id = url[..<queryStart].split(separator: "/").last.flatMap({ Int($0) })
        self.queueItemId = id
    }
}

public struct GrepMatch: Codable, Sendable {
    public let elementNumber: Int
    public let content: String
    public let isMatch: Bool
    
    public init(elementNumber: Int, content: String, isMatch: Bool) {
        self.elementNumber = elementNumber
        self.content = content
        self.isMatch = isMatch
    }
}
