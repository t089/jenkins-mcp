import Foundation

// MARK: - Tokens

private enum Tok<Input: Collection> where Input.Element == UInt8 {
    case word(Input.SubSequence)
    case newline
    case eof
}

// MARK: - Byte helpers

@inline(__always) private func isSpaceOrTab(_ b: UInt8) -> Bool {
    b == 0x20 || b == 0x09  // ' ' or '\t'
}

@inline(__always) private func isLF(_ b: UInt8) -> Bool { b == 0x0A }  // \n
@inline(__always) private func isCR(_ b: UInt8) -> Bool { b == 0x0D }  // \r
@inline(__always) private func isHash(_ b: UInt8) -> Bool { b == 0x23 }  // '#'

// MARK: - Generic Lexer over bytes

private struct Lexer<Input: Collection> where Input.Element == UInt8 {
    let input: Input
    private(set) var i: Input.Index

    init(_ input: Input) {
        self.input = input
        self.i = input.startIndex
    }

    mutating func next() -> Tok<Input> {
        skipSpacesAndComments()

        guard i < input.endIndex else { return .eof }

        // Newline token?
        if peekIsLFOrCRLF() {
            consumeNewline()
            return .newline
        }

        // Word: [^#\s\n]+ as bytes
        let start = i
        while i < input.endIndex {
            let b = input[i]
            if isLF(b) || isCR(b) || isHash(b) || isSpaceOrTab(b) { break }
            input.formIndex(after: &i)
        }
        if start == i {
            // Shouldn't happen because we consumed spaces/comments/newlines above,
            // but guard against pathological inputs.
            input.formIndex(after: &i)
            return .newline
        }
        return .word(input[start..<i])
    }

    // MARK: internals

    private mutating func skipSpacesAndComments() {
        while i != input.endIndex {
            let b = input[i]

            // newline => stop; the caller will emit it
            if isLF(b) || isCR(b) { return }

            // comment to end of line
            if isHash(b) {
                // skip until LF or CR or EOF
                repeat {
                    input.formIndex(after: &i)
                } while i != input.endIndex && !(isLF(input[i]) || isCR(input[i]))
                return  // next() will see newline and emit it
            }

            // space / tab => skip and continue
            if isSpaceOrTab(b) {
                input.formIndex(after: &i)
                continue
            }

            // anything else => word starts here
            return
        }
    }

    private func peekIsLFOrCRLF() -> Bool {
        guard i != input.endIndex else { return false }
        if isLF(input[i]) { return true }
        if isCR(input[i]) {
            var j = i
            input.formIndex(after: &j)
            return j != input.endIndex && isLF(input[j])
        }
        return false
    }

    private mutating func consumeNewline() {
        // Normalize CRLF and LF to a single newline
        if i == input.endIndex { return }
        if isLF(input[i]) {
            input.formIndex(after: &i)
            return
        }
        if isCR(input[i]) {
            input.formIndex(after: &i)
            if i != input.endIndex, isLF(input[i]) { input.formIndex(after: &i) }
        }
    }
}

// MARK: - Parser (only diffs: it consumes SubSequence and decodes lazily)

public enum NetrcError: Error, CustomStringConvertible, Equatable {
    case expectedValue(after: String)
    case unexpectedToken(String)
    public var description: String {
        switch self {
        case .expectedValue(let k): return "Expected value after '\(k)'."
        case .unexpectedToken(let t): return "Unexpected token: \(t)"
        }
    }
}

public struct Netrc: Sendable {
    public struct Machine: Sendable {
        public var name: String?  // nil for `default`
        public var login: String?
        public var password: String?
        public var account: String?
        public var port: Int?
    }
    public let machines: [Machine]

    public struct Authorization: Sendable {
        public let login: String
        public let password: String
    }

    public func authorization(for url: URL) -> Authorization? {
        let host = url.host
        let port = url.port
        let exact =
            machines.first { $0.name == host && ($0.port == nil || $0.port == port) }
            ?? machines.first { $0.name == host }
            ?? machines.first { $0.name == nil }
        guard let login = exact?.login, let pw = exact?.password else { return nil }
        return Authorization(login: login, password: pw)
    }

    public static func parse(_ input: String) throws -> Netrc {
        let parser = NetrcParser()
        return try parser.parse(input)
    }
}

public struct NetrcParser {
    public init() {}

    public func parse(_ input: String) throws -> Netrc {
        let fastResult = try input.utf8.withContiguousStorageIfAvailable { bytes in
            return try parse(bytes: bytes)
        }
        if let result = fastResult {
            return result
        } else {
            return try parse(bytes: input.utf8)
        }
    }

    // Generic entrypoint over any Collection<UInt8>
    public func parse<Input: Collection>(bytes: Input) throws -> Netrc where Input.Element == UInt8 {
        func dec(_ s: Input.SubSequence) -> String {
            String(decoding: s, as: UTF8.self)
        }

        var lx = Lexer(bytes)
        var machines: [Netrc.Machine] = []
        var current = Netrc.Machine(name: nil, login: nil, password: nil, account: nil, port: nil)
        var haveCurrent = false

        func flushIfNeeded() {
            if haveCurrent {
                machines.append(current)
                haveCurrent = false
                current = Netrc.Machine(name: nil, login: nil, password: nil, account: nil, port: nil)
            }
        }

        func nextWord(_ key: String) throws -> Input.SubSequence {
            switch lx.next() {
            case .word(let s): return s
            default: throw NetrcError.expectedValue(after: key)
            }
        }

        while true {
            switch lx.next() {
            case .eof:
                flushIfNeeded()
                return Netrc(machines: mergeDefault(into: machines))

            case .newline:
                continue

            case .word(let w):
                let kw = dec(w)
                switch kw {
                case "machine":
                    flushIfNeeded()
                    current.name = dec(try nextWord("machine"))
                    haveCurrent = true

                case "default":
                    flushIfNeeded()
                    current.name = nil
                    haveCurrent = true

                case "login":
                    current.login = dec(try nextWord("login"))
                    haveCurrent = true

                case "password":
                    current.password = dec(try nextWord("password"))
                    haveCurrent = true

                case "account":
                    current.account = dec(try nextWord("account"))
                    haveCurrent = true

                case "port":
                    let pstr = dec(try nextWord("port"))
                    guard let p = Int(pstr) else { throw NetrcError.expectedValue(after: "port") }
                    current.port = p
                    haveCurrent = true

                case "macdef":
                    _ = lx.next()  // macro name (optional)
                    // consume until blank line
                    var sawNewline = false
                    while true {
                        switch lx.next() {
                        case .eof: break
                        case .newline:
                            if sawNewline { break }
                            sawNewline = true
                            continue
                        case .word:
                            sawNewline = false
                            continue
                        }
                        break
                    }

                default:
                    // unknown key: best-effort swallow one value
                    if case .word = lx.next() { /* ignore value */  }
                }
            }
        }
    }

    private func mergeDefault(into machines: [Netrc.Machine]) -> [Netrc.Machine] {
        guard let def = machines.last(where: { $0.name == nil }) else { return machines }
        return machines.map { m in
            guard m.name != nil else { return m }
            return Netrc.Machine(
                name: m.name,
                login: m.login ?? def.login,
                password: m.password ?? def.password,
                account: m.account ?? def.account,
                port: m.port ?? def.port
            )
        }
    }
}
