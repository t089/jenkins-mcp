import AsyncHTTPClient
import Foundation
import HTTPTransport
import JenkinsSDK
import Netrc

var httpClientConfig: HTTPClient.Configuration = .singletonConfiguration
httpClientConfig.decompression = .enabled(limit: .none)
let httpClient = HTTPClient(eventLoopGroup: HTTPClient.defaultEventLoopGroup, configuration: httpClientConfig)

let netrc = try Netrc.parse(String(data: Data(contentsOf: URL(fileURLWithPath: ".netrc")), encoding: .utf8) ?? "")
let url =  URL(string: ProcessInfo.processInfo.environment["JENKINS_URL"] ?? "")!

guard let authz = netrc.authorization(for: url) else {
    fatalError("No authorization found for \(url)")
}

let jenkins = JenkinsClient(
    baseURL: url,
    transport: HTTPClientTransport(client: httpClient),
    credentials: JenkinsCredentials(username: authz.login, password: authz.password)
)
