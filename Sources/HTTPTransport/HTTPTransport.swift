import HTTPTypes

#if canImport(FoundationEssentials)
    import FoundationEssentials
#else
    import Foundation
#endif

public protocol HTTPTransport: Sendable {
    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseUrl: URL
    ) async throws -> (
        HTTPResponse, HTTPBody?
    )
}

public struct HTTPBody: AsyncSequence, Sendable {

    public typealias ByteChunk = ArraySlice<UInt8>

    public enum Length: Sendable {
        case unknown
        case known(Int64)
    }

    let sequence: AnyAsyncSequence<ByteChunk>
    let length: Length

    public init(bytes: some Sequence<ByteChunk> & Sendable, length: Length = .unknown) {
        self.sequence = .init(WrappedSequence(sequence: bytes))
        self.length = length
    }

    public init(bytes: some Sequence<UInt8>) {
        let chunk = ByteChunk(bytes)
        self.sequence = .init(WrappedSequence(sequence: [chunk]))
        self.length = .known(Int64(chunk.count))
    }

    public init<Stream: AsyncSequence>(stream: Stream, length: Length = .unknown)
    where Stream.Element == ByteChunk, Stream: Sendable {
        self.sequence = .init(stream)
        self.length = length
    }

    public func makeAsyncIterator() -> AsyncIterator {
        return AsyncIterator(iterator: sequence.makeAsyncIterator())
    }
}

public struct HTTPBodyError: Error {
    public let message: String

    public static let bodyTooLarge = HTTPBodyError(
        message: "HTTP body size exceeds maximum allowed"
    )
}

extension HTTPBody {
    public func collect(upTo maxSize: Int) async throws -> ByteChunk {
        // Fail fast if we know the content length exceeds maxSize
        if case .known(let knownSize) = length, knownSize > maxSize {
            throw HTTPBodyError.bodyTooLarge
        }

        var result = [UInt8]()
        // Reserve capacity based on known size or a reasonable default
        if case .known(let knownSize) = length {
            result.reserveCapacity(Int(knownSize))
        } else {
            result.reserveCapacity(Swift.min(maxSize, 1024))
        }

        for try await chunk in self {
            if result.count + chunk.count > maxSize {
                throw HTTPBodyError.bodyTooLarge
            }
            result.append(contentsOf: chunk)
        }

        return ByteChunk(result)
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private let produceNext: () async throws -> ByteChunk?

        init(iterator: any AsyncIteratorProtocol<ArraySlice<UInt8>, any Error>) {
            var iterator = iterator
            self.produceNext = {
                return try await iterator.next()
            }
        }

        init(bytes: some Sequence<ByteChunk>) {
            var iterator = bytes.makeIterator()
            self.produceNext = {
                return iterator.next()
            }
        }

        public mutating func next() async throws -> ByteChunk? {
            return try await produceNext()
        }
    }
}

@usableFromInline
struct AnyAsyncIterator<Element: Sendable>: AsyncIteratorProtocol {
    @usableFromInline
    let produceNext: () async throws -> Element?

    init<I: AsyncIteratorProtocol>(_ iterator: I) where I.Element == Element {
        var iterator = iterator
        self.produceNext = {
            return try await iterator.next()
        }
    }

    @usableFromInline
    mutating func next() async throws -> Element? {
        return try await produceNext()
    }
}

@usableFromInline
struct AnyAsyncSequence<Element: Sendable>: AsyncSequence, Sendable {
    @usableFromInline typealias AsyncIterator = AnyAsyncIterator<Element>

    @usableFromInline
    let _makeAsyncIterator: @Sendable () -> AnyAsyncIterator<Element>

    @usableFromInline
    init<S: AsyncSequence>(_ sequence: S) where S.Element == Element, S: Sendable {
        self._makeAsyncIterator = { AnyAsyncIterator(sequence.makeAsyncIterator()) }
    }

    @usableFromInline
    func makeAsyncIterator() -> AnyAsyncIterator<Element> {
        return _makeAsyncIterator()
    }
}

@usableFromInline
struct WrappedSequence<Upstream: Sequence & Sendable>: AsyncSequence, Sendable
where Upstream.Element: Sendable {

    @usableFromInline
    typealias Element = Upstream.Element

    @usableFromInline
    typealias AsyncIterator = Iterator<Element>

    @usableFromInline
    struct Iterator<Element: Sendable>: AsyncIteratorProtocol {
        private var iterator: any IteratorProtocol<Element>

        @usableFromInline
        init(iterator: any IteratorProtocol<Element>) {
            self.iterator = iterator
        }

        @usableFromInline
        mutating func next() async throws -> Element? {
            return iterator.next()
        }
    }

    @usableFromInline
    let sequence: Upstream

    @usableFromInline
    init(sequence: Upstream) {
        self.sequence = sequence
    }

    @usableFromInline
    func makeAsyncIterator() -> AsyncIterator {
        return Iterator(iterator: sequence.makeIterator())
    }
}
