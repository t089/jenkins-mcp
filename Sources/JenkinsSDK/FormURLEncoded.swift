extension Dictionary where Key == String, Value == String {
    func formUrlEncoded(sortedKeys: Bool = true) -> String {
        func encode(_ pairs: some Collection<Element>) -> String {
            pairs
                .map { "\($0.key.formUrlEncoded())=\($0.value.formUrlEncoded())" }
                .joined(separator: "&")
        }

        if sortedKeys {
            return encode(self.sorted(by: { $0.key < $1.key }))
        } else {
            return encode(self)
        }
    }
}

extension StringProtocol {
    func formUrlEncoded(skipAlreadyEncoded: Bool = false) -> String {
        let fastResult = self.utf8.withContiguousStorageIfAvailable { utf8Buffer in
            addPercentEncoding(
                utf8Buffer: utf8Buffer,
                skipAlreadyEncoded: skipAlreadyEncoded,
                spaceAsPlus: true
            )
        }
        if let fastResult {
            return fastResult
        } else {
            // Fallback for non-contiguous storage
            return addPercentEncoding(
                utf8Buffer: self.utf8,
                skipAlreadyEncoded: skipAlreadyEncoded,
                spaceAsPlus: true
            )
        }
    }
}

func addPercentEncoding(utf8Buffer: some Collection<UInt8>, skipAlreadyEncoded: Bool = false, spaceAsPlus: Bool = false)
    -> String
{
    let percent = UInt8(ascii: "%")
    let maxLength = utf8Buffer.count * 3
    return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: maxLength) { outputBuffer -> String in
        var i = 0
        var index = utf8Buffer.startIndex
        while index != utf8Buffer.endIndex {
            let v = utf8Buffer[index]
            if v.isFormUrlAllowed {
                outputBuffer[i] = v
                i += 1
            } else if v == UInt8(ascii: " ") && spaceAsPlus {
                outputBuffer[i] = UInt8(ascii: "+")
                i += 1
            } else if skipAlreadyEncoded, v == percent,
                utf8Buffer.index(index, offsetBy: 1) != utf8Buffer.endIndex,
                utf8Buffer[utf8Buffer.index(index, offsetBy: 1)].isValidHexDigit,
                utf8Buffer.index(index, offsetBy: 2) != utf8Buffer.endIndex,
                utf8Buffer[utf8Buffer.index(index, offsetBy: 2)].isValidHexDigit
            {
                let inclusiveEnd = utf8Buffer.index(index, offsetBy: 2)
                i = outputBuffer[i...i + 2].initialize(fromContentsOf: utf8Buffer[index...inclusiveEnd])
                index = inclusiveEnd  // Incremented below, too
            } else {
                i = outputBuffer[i...i + 2]
                    .initialize(fromContentsOf: [percent, hexToAscii(v >> 4), hexToAscii(v & 0xF)])
            }
            index = utf8Buffer.index(after: index)
        }
        return String(decoding: outputBuffer[..<i], as: UTF8.self)
    }
}

extension UInt8 {
    var isFormUrlAllowed: Bool {
        (48...57).contains(self)  // 0-9
            || (65...90).contains(self)  // A-Z
            || (97...122).contains(self)  // a-z
            || self == 45  // -
            || self == 46  // .
            || self == 95  // _
            || self == 126  // ~
    }
}

private func hexToAscii(_ hex: UInt8) -> UInt8 {
    switch hex {
    case 0x0:
        return UInt8(ascii: "0")
    case 0x1:
        return UInt8(ascii: "1")
    case 0x2:
        return UInt8(ascii: "2")
    case 0x3:
        return UInt8(ascii: "3")
    case 0x4:
        return UInt8(ascii: "4")
    case 0x5:
        return UInt8(ascii: "5")
    case 0x6:
        return UInt8(ascii: "6")
    case 0x7:
        return UInt8(ascii: "7")
    case 0x8:
        return UInt8(ascii: "8")
    case 0x9:
        return UInt8(ascii: "9")
    case 0xA:
        return UInt8(ascii: "A")
    case 0xB:
        return UInt8(ascii: "B")
    case 0xC:
        return UInt8(ascii: "C")
    case 0xD:
        return UInt8(ascii: "D")
    case 0xE:
        return UInt8(ascii: "E")
    case 0xF:
        return UInt8(ascii: "F")
    default:
        fatalError("Invalid hex digit: \(hex)")
    }
}

internal var _asciiNumbers: ClosedRange<UInt8> { UInt8(ascii: "0")...UInt8(ascii: "9") }
internal var _hexCharsUpper: ClosedRange<UInt8> { UInt8(ascii: "A")...UInt8(ascii: "F") }
internal var _hexCharsLower: ClosedRange<UInt8> { UInt8(ascii: "a")...UInt8(ascii: "f") }
internal var _allLettersUpper: ClosedRange<UInt8> { UInt8(ascii: "A")...UInt8(ascii: "Z") }
internal var _allLettersLower: ClosedRange<UInt8> { UInt8(ascii: "a")...UInt8(ascii: "z") }

extension UInt8 {
    internal var hexDigitValue: UInt8? {
        switch self {
        case _asciiNumbers:
            return self - _asciiNumbers.lowerBound
        case _hexCharsUpper:
            // uppercase letters
            return self - _hexCharsUpper.lowerBound &+ 10
        case _hexCharsLower:
            // lowercase letters
            return self - _hexCharsLower.lowerBound &+ 10
        default:
            return nil
        }
    }

    internal var isValidHexDigit: Bool {
        switch self {
        case _asciiNumbers, _hexCharsUpper, _hexCharsLower:
            return true
        default:
            return false
        }
    }
}
