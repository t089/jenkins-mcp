
import AsyncHTTPClient
import HTTPTypes
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIOCore
import Logging

public var noopLogger: Logger {
    return Logger(label: "noop", factory: SwiftLogNoOpLogHandler.init)
}

public struct HTTPClientTransport: HTTPTransport {

    public typealias TimeAmount = NIOCore.TimeAmount

    public var client: HTTPClient
    public var defaultTimeout: TimeAmount
    public var logger: Logger

    public init(client: HTTPClient, defaultTimeout: TimeAmount = .seconds(30), logger: Logger = noopLogger) {
        self.client = client
        self.defaultTimeout = defaultTimeout
        self.logger = logger
    }

    public func send(_ request: HTTPRequest, body: HTTPBody?, baseUrl: URL) async throws -> (HTTPResponse, HTTPBody?) {
        let request = try HTTPClientRequest(from: request, body: body, baseUrl: baseUrl)
        let response = try await client.execute(request, timeout: defaultTimeout)
        

        let body = response.body.map { ArraySlice($0.readableBytesView) }
        let length: HTTPBody.Length
        if let contentLength = response.headers.first(name: "Content-Length").flatMap({ Int64($0) }) {
            length = .known(contentLength)
        } else {
            length = .unknown
        }
        return (HTTPResponse(from: response), HTTPBody(stream: body, length: length))
    }
}

public struct InvalidUrlError: Error {
    public let request: HTTPRequest
    public let baseUrl: URL
}

extension HTTPClientRequest {
    init(from request: HTTPRequest, body: HTTPBody?, baseUrl: URL) throws {
        guard var baseUrlComponents = URLComponents(string: baseUrl.absoluteString),
        let requestUrlComponents = URLComponents(string: request.path ?? "") else {
            throw InvalidUrlError(request: request, baseUrl: baseUrl)
        }

        baseUrlComponents.percentEncodedPath += requestUrlComponents.percentEncodedPath
        baseUrlComponents.percentEncodedQuery = requestUrlComponents.percentEncodedQuery

        guard let requestUrl = baseUrlComponents.url else {
            throw InvalidUrlError(request: request, baseUrl: baseUrl)
        }

        self = HTTPClientRequest(url: requestUrl.absoluteString)
        self.method = .init(rawValue: request.method.rawValue)
        self.headers.reserveCapacity(Int(request.headerFields.count))
        for field in request.headerFields {
            self.headers.add(name: field.name.canonicalName, value: field.value)
        }
        if let body {
            let length: HTTPClientRequest.Body.Length
            switch body.length {
            case .unknown:
                length = .unknown
            case .known(let size):
                length = .known(Int64(size))
            }
            self.body = .stream(body.map { 
                var buffer = ByteBuffer()
                buffer.writeBytes($0)
                return buffer
            }, length: length)
        }
    }
}

extension HTTPResponse {
    init(from response: HTTPClientResponse) {
        self.init(status: Status(code: Int(response.status.code), reasonPhrase: response.status.reasonPhrase))
        for header in response.headers {
            self.headerFields.append(.init(name: .init(header.name)!, value: header.value))
        }
    }
}
