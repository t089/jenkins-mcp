import HTTPTypes
import HTTPTransport
import NIOCore

public struct AsyncLineSequence: AsyncSequence, Sendable {
    public typealias Element = String
    
    private let body: HTTPBody
    
    internal init(body: HTTPBody) {
        self.body = body
    }
    
    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(bodyIterator: body.makeAsyncIterator())
    }
    
    public struct AsyncIterator: AsyncIteratorProtocol {
        private var bodyIterator: HTTPBody.AsyncIterator
        private var buffer = ByteBuffer()
        
        internal init(bodyIterator: HTTPBody.AsyncIterator) {
            self.bodyIterator = bodyIterator
        }
        
        public mutating func next() async throws -> String? {
            func readLine(buffer: inout ByteBuffer) -> String? {
                var currentIndex: Int = buffer.readerIndex
                while currentIndex < buffer.writerIndex {
                    if buffer.getInteger(at: currentIndex, as: UInt8.self) == UInt8(ascii: "\n") {
                        var lineData = buffer.readSlice(length: Int(currentIndex - buffer.readerIndex))!
                        buffer.moveReaderIndex(forwardBy: 1) // Move past the newline character

                        if lineData.readableBytesView.last == UInt8(ascii: "\r") {
                            // If the line ends with \r, we need to remove it
                            lineData = lineData.readSlice(length: lineData.readableBytes - 1)!
                        }
                        return String(decoding: lineData.readableBytesView, as: UTF8.self)
                    }
                    currentIndex += 1
                }
                
                return nil
            }


            while let chunk = try await bodyIterator.next() {
                buffer.writeBytes(chunk)

                if let line = readLine(buffer: &buffer) {
                    return line
                }
            }
            
            
            if let line = readLine(buffer: &buffer) {
                return line
            } else {
                guard buffer.readableBytes > 0 else {
                    return nil
                }

                defer { buffer.clear() }
                return String(decoding: buffer.readableBytesView, as: UTF8.self)
            }
            

            
        }
    }
}

// MARK: - Grep Extension
extension AsyncSequence where Element == String {
    /// Searches for strings matching a regular expression pattern within the async sequence.
    /// 
    /// - Parameters:
    ///   - pattern: A regular expression pattern to match against each string element
    ///   - context: Number of context elements to include before and after matching elements (default: 0)
    ///   - offset: Number of elements to skip from the beginning before starting to search (default: 0)
    ///   - maxCount: Maximum number of matching elements to return (default: 200)
    /// - Returns: An array of `GrepMatch` objects containing matching elements and their context
    /// - Throws: `JenkinsAPIError.invalidPattern` if the regex pattern is malformed
    public func grep(
        pattern: String,
        context: Int = 0,
        offset: Int = 0,
        maxCount: Int = 200
    ) async throws -> [GrepMatch] {
        let regex: Regex<AnyRegexOutput>
        do {
            regex = try Regex(pattern)
        } catch {
            throw JenkinsAPIError.invalidPattern(pattern)
        }
        
        var contextBefore: [GrepMatch] = []
        var index = 0
        var matches: [GrepMatch] = []
        var iterator = self.makeAsyncIterator()
        var contextAfterRemaining = 0
        
        while let line = try await iterator.next() {
            defer { index += 1 }
            
            if index < offset {
                contextBefore.append(GrepMatch(elementNumber: index + 1, content: line, isMatch: false))
                if contextBefore.count > context {
                    contextBefore.removeFirst()
                }
                continue
            }
            
            if matches.count < maxCount && (try? regex.firstMatch(in: line)) != nil {
                matches.append(contentsOf: contextBefore)
                contextBefore.removeAll()
                matches.append(GrepMatch(elementNumber: index + 1, content: line, isMatch: true))
                contextAfterRemaining = context
            } else if contextAfterRemaining > 0 {
                matches.append(GrepMatch(elementNumber: index + 1, content: line, isMatch: false))
                contextAfterRemaining -= 1
            } else if matches.count < maxCount {
                contextBefore.append(GrepMatch(elementNumber: index + 1, content: line, isMatch: false))
                if contextBefore.count > context {
                    contextBefore.removeFirst()
                }
            } else {
                break
            }
        }
        
        return matches
    }
}