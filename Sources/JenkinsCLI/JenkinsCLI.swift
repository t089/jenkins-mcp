import JenkinsSDK
import HTTPTransport
import Foundation
import AsyncHTTPClient

var httpClientConfig: HTTPClient.Configuration = .singletonConfiguration
httpClientConfig.decompression = .enabled(limit: .none)
let httpClient = HTTPClient(eventLoopGroup: HTTPClient.defaultEventLoopGroup, configuration: httpClientConfig)

