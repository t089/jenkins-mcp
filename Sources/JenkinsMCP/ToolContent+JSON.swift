import MCP

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension Tool.Content {
    static func json(_ value: Encodable, encoder: JSONEncoder) throws -> Tool.Content {
        let data = try encoder.encode(value)
        return .text(String(decoding: data, as: UTF8.self))
    }
}