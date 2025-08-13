import Testing

@testable import JenkinsSDK

struct FormURLEncodedTests {

    // MARK: - Dictionary Tests

    @Test("Dictionary with simple key-value pairs (sorted)")
    func dictionarySimpleKeyValuesSorted() {
        let dict = ["key2": "value2", "key1": "value1"]
        let result = dict.formUrlEncoded(sortedKeys: true)

        #expect(result == "key1=value1&key2=value2")
    }

    @Test("Dictionary with simple key-value pairs (unsorted)")
    func dictionarySimpleKeyValuesUnsorted() {
        let dict = ["key2": "value2", "key1": "value1"]
        let result = dict.formUrlEncoded(sortedKeys: false)

        // Should contain both pairs but order is not guaranteed
        #expect(result.contains("key1=value1"))
        #expect(result.contains("key2=value2"))
        #expect(result.contains("&"))
    }

    @Test("Dictionary with empty values")
    func dictionaryEmptyValues() {
        let dict = ["key2": "", "key1": "value1"]
        let result = dict.formUrlEncoded()

        #expect(result == "key1=value1&key2=")
    }

    @Test("Dictionary with empty keys")
    func dictionaryEmptyKeys() {
        let dict = ["": "value1", "key2": "value2"]
        let result = dict.formUrlEncoded()

        #expect(result == "=value1&key2=value2")
    }

    @Test("Empty dictionary")
    func emptyDictionary() {
        let dict: [String: String] = [:]
        let result = dict.formUrlEncoded()

        #expect(result == "")
    }

    @Test("Dictionary with special characters requiring encoding")
    func dictionarySpecialCharacters() {
        let dict = ["key with spaces": "value with spaces", "key@symbol": "value+plus"]
        let result = dict.formUrlEncoded()

        #expect(result == "key+with+spaces=value+with+spaces&key%40symbol=value%2Bplus")
    }

    @Test("Dictionary with unicode characters")
    func dictionaryUnicodeCharacters() {
        let dict = ["café": "naïve", "测试": "🚀"]
        let result = dict.formUrlEncoded()

        #expect(result == "caf%C3%A9=na%C3%AFve&%E6%B5%8B%E8%AF%95=%F0%9F%9A%80")
    }

    @Test("Single key-value pair")
    func dictionarySinglePair() {
        let dict = ["single": "value"]
        let result = dict.formUrlEncoded()

        #expect(result == "single=value")
    }

    // MARK: - String Tests

    @Test("String with allowed characters")
    func stringAllowedCharacters() {
        let input = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        let result = input.formUrlEncoded()

        #expect(result == input)
    }

    @Test("String with spaces")
    func stringWithSpaces() {
        let input = "hello world test"
        let result = input.formUrlEncoded()

        #expect(result == "hello+world+test")
    }

    @Test("String with special characters")
    func stringSpecialCharacters() {
        let input = "!@#$%^&*()"
        let result = input.formUrlEncoded()

        #expect(result == "%21%40%23%24%25%5E%26%2A%28%29")
    }

    @Test("Empty string")
    func emptyString() {
        let input = ""
        let result = input.formUrlEncoded()

        #expect(result == "")
    }

    @Test("String with mixed content")
    func stringMixedContent() {
        let input = "param=value&other param"
        let result = input.formUrlEncoded()

        #expect(result == "param%3Dvalue%26other+param")
    }

    @Test("String with unicode characters")
    func stringUnicode() {
        let input = "café"
        let result = input.formUrlEncoded()

        #expect(result == "caf%C3%A9")
    }

    @Test("String with emoji")
    func stringEmoji() {
        let input = "🚀"
        let result = input.formUrlEncoded()

        #expect(result == "%F0%9F%9A%80")
    }

    @Test("String with newlines and tabs")
    func stringNewlinesAndTabs() {
        let input = "line1\nline2\tindented"
        let result = input.formUrlEncoded()

        #expect(result == "line1%0Aline2%09indented")
    }

    @Test("String with control characters")
    func stringControlCharacters() {
        let input = "\u{01}\u{02}\u{1F}"
        let result = input.formUrlEncoded()

        #expect(result == "%01%02%1F")
    }

    // MARK: - StringProtocol.formUrlEncoded with skipAlreadyEncoded

    @Test("Skip already encoded - false (default)")
    func skipAlreadyEncodedFalse() {
        let input = "already%20encoded"
        let result = input.formUrlEncoded(skipAlreadyEncoded: false)

        #expect(result == "already%2520encoded")
    }

    @Test("Skip already encoded - true")
    func skipAlreadyEncodedTrue() {
        let input = "already%20encoded"
        let result = input.formUrlEncoded(skipAlreadyEncoded: true)

        #expect(result == "already%20encoded")
    }

    @Test("Skip already encoded with mixed content")
    func skipAlreadyEncodedMixed() {
        let input = "normal text %20 more text"
        let result = input.formUrlEncoded(skipAlreadyEncoded: true)

        #expect(result == "normal+text+%20+more+text")
    }

    @Test("Skip already encoded with invalid percent encoding")
    func skipAlreadyEncodedInvalid() {
        let input = "invalid%GG%20valid"
        let result = input.formUrlEncoded(skipAlreadyEncoded: true)

        #expect(result == "invalid%25GG%20valid")
    }

    @Test("Skip already encoded at string boundaries")
    func skipAlreadyEncodedBoundaries() {
        let input = "%20start middle%20 end%20"
        let result = input.formUrlEncoded(skipAlreadyEncoded: true)

        #expect(result == "%20start+middle%20+end%20")
    }

    @Test("Skip already encoded with incomplete percent at end")
    func skipAlreadyEncodedIncompleteEnd() {
        let input = "text%2"
        let result = input.formUrlEncoded(skipAlreadyEncoded: true)

        #expect(result == "text%252")
    }

    @Test("Skip already encoded with percent but no hex")
    func skipAlreadyEncodedPercentNoHex() {
        let input = "text%ZZ"
        let result = input.formUrlEncoded(skipAlreadyEncoded: true)

        #expect(result == "text%25ZZ")
    }

    // MARK: - Edge Cases

    @Test("Very long string")
    func veryLongString() {
        let input = String(repeating: "a", count: 1000)
        let result = input.formUrlEncoded()

        #expect(result == input)
        #expect(result.count == 1000)
    }

    @Test("String with all spaces")
    func stringAllSpaces() {
        let input = "   "
        let result = input.formUrlEncoded()

        #expect(result == "+++")
    }

    @Test("String with consecutive special characters")
    func stringConsecutiveSpecialChars() {
        let input = "!!!"
        let result = input.formUrlEncoded()

        #expect(result == "%21%21%21")
    }

    @Test("Dictionary with complex values")
    func dictionaryComplexValues() {
        let dict = [
            "simple": "value",
            "with spaces": "hello world",
            "special": "a@b.com",
            "unicode": "café",
        ]
        let result = dict.formUrlEncoded()

        #expect(result == "simple=value&special=a%40b.com&unicode=caf%C3%A9&with+spaces=hello+world")
    }

    @Test("Dictionary key sorting with special characters")
    func dictionaryKeySortingSpecialChars() {
        let dict = [
            "z": "last",
            "a": "first",
            "@": "symbol",
        ]
        let result = dict.formUrlEncoded()

        #expect(result == "%40=symbol&a=first&z=last")
    }
}
