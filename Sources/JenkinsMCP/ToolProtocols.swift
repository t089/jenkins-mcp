import MCP
import JenkinsSDK

protocol ToolProtocol: Sendable {
    associatedtype Output: Encodable, Sendable
    static var inputSchema: Value { get }

    var name: String { get }
    var description: String { get }

    func execute(arguments: [String: Value]) async throws -> Output
}

protocol JenkinsTool : ToolProtocol {
    var jenkinsClient: JenkinsClient { get }
}