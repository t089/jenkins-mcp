import ArgumentParser
import DequeModule

#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

struct LogGrepUtility {
    struct GrepOptions {
        let pattern: String
        let context: Int
        let offset: Int
        let maxLines: Int
        
        init(pattern: String, context: Int = 0, offset: Int = 0, maxLines: Int = 200) {
            self.pattern = pattern
            self.context = context
            self.offset = offset
            self.maxLines = maxLines
        }
    }
    
    static func grepLines<S: AsyncSequence>(
        from lines: S,
        options: GrepOptions
    ) async throws -> [GrepLine] where S.Element == String {
        let regex: Regex<AnyRegexOutput>
        do {
            regex = try Regex(options.pattern)
        } catch {
            throw ValidationError("Invalid regex pattern: \(options.pattern)")
        }
        
        var contextBefore: Deque<GrepLine> = Deque(minimumCapacity: options.context)
        var index = 0
        var matches = [GrepLine]()
        var iterator = lines.makeAsyncIterator()
        var contextAfterRemaining = 0
        
        while true {
            defer { index += 1 }
            
            guard let line = try await iterator.next() else {
                break
            }
            
            if index < options.offset {
                contextBefore.append(GrepLine(lineNumber: index + 1, match: nil, context: line))
                if contextBefore.count > options.context {
                    contextBefore.removeFirst()
                }
                continue
            }
            
            if matches.count < options.maxLines, try regex.firstMatch(in: line) != nil {
                matches.append(contentsOf: contextBefore)
                contextBefore.removeAll(keepingCapacity: true)
                matches.append(GrepLine(lineNumber: index + 1, match: String(line), context: nil))
                contextAfterRemaining = options.context
            } else if contextAfterRemaining > 0 {
                matches.append(GrepLine(lineNumber: index + 1, match: nil, context: String(line)))
                contextAfterRemaining -= 1
            } else if matches.count < options.maxLines {
                contextBefore.append(GrepLine(lineNumber: index + 1, match: nil, context: line))
                if contextBefore.count > options.context {
                    contextBefore.removeFirst()
                }
            } else {
                assert(Bool(matches.count >= options.maxLines))
                break
            }
        }
        
        return matches
    }
}