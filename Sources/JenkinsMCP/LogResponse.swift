struct LogResponse: Encodable {
    let line_offset: Int
    let max_lines: Int
    let available_lines: Int
    let content: String
}
