import Foundation

public enum CSVParsingError: Error, Equatable, LocalizedError {
    case missingHeader
    case unterminatedQuotedField(line: Int)
    case inconsistentColumnCount(line: Int, expected: Int, actual: Int)

    public var errorDescription: String? {
        switch self {
        case .missingHeader:
            "CSV has no header row."
        case let .unterminatedQuotedField(line):
            "CSV line \(line) has an unterminated quoted field."
        case let .inconsistentColumnCount(line, expected, actual):
            "CSV line \(line) has \(actual) columns; expected \(expected)."
        }
    }
}

public struct CSVTable: Equatable, Sendable {
    public let headers: [String]
    public let rows: [[String: String]]
}

public enum CommentedCSVParser {
    public static func parse(_ text: String) throws -> CSVTable {
        let meaningfulLines = text
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .enumerated()
            .filter { !$0.element.trimmingCharacters(in: .whitespaces).isEmpty }
            .filter { !$0.element.trimmingCharacters(in: .whitespaces).hasPrefix("#") }

        guard let headerLine = meaningfulLines.first else {
            throw CSVParsingError.missingHeader
        }

        let headers = try fields(in: headerLine.element, lineNumber: headerLine.offset + 1)
        var rows: [[String: String]] = []

        for line in meaningfulLines.dropFirst() {
            let values = try fields(in: line.element, lineNumber: line.offset + 1)
            guard values.count == headers.count else {
                throw CSVParsingError.inconsistentColumnCount(
                    line: line.offset + 1,
                    expected: headers.count,
                    actual: values.count
                )
            }
            rows.append(Dictionary(uniqueKeysWithValues: zip(headers, values)))
        }

        return CSVTable(headers: headers, rows: rows)
    }

    private static func fields(in line: String, lineNumber: Int) throws -> [String] {
        var result: [String] = []
        var field = ""
        var insideQuotes = false
        var index = line.startIndex

        while index < line.endIndex {
            let character = line[index]
            if character == "\"" {
                let next = line.index(after: index)
                if insideQuotes, next < line.endIndex, line[next] == "\"" {
                    field.append("\"")
                    index = line.index(after: next)
                    continue
                }
                insideQuotes.toggle()
            } else if character == ",", !insideQuotes {
                result.append(field)
                field = ""
            } else {
                field.append(character)
            }
            index = line.index(after: index)
        }

        guard !insideQuotes else {
            throw CSVParsingError.unterminatedQuotedField(line: lineNumber)
        }
        result.append(field)
        return result
    }
}
