import Foundation
import os.log

struct Logger {
    static let shared = Logger()
    private let logger = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "com.launcher",
        category: "Launcher"
    )

    private init() {}

    // MARK: - Public Logging Methods

    func debug(
        _ items: Any...,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            items,
            type: .debug,
            prefix: "🔍",
            file: file,
            function: function,
            line: line
        )
    }

    func info(
        _ items: Any...,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            items,
            type: .info,
            prefix: "ℹ️",
            file: file,
            function: function,
            line: line
        )
    }

    func warning(
        _ items: Any...,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            items,
            type: .default,
            prefix: "⚠️",
            file: file,
            function: function,
            line: line
        )
    }

    func error(
        _ items: Any...,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            items,
            type: .error,
            prefix: "❌",
            file: file,
            function: function,
            line: line
        )
    }

    // MARK: - Core Logging

    private func log(
        _ items: [Any],
        type: OSLogType,
        prefix: String,
        file: String,
        function: String,
        line: Int
    ) {
        let fileName = (file as NSString).lastPathComponent
        let message = items.map { Logger.stringify($0) }.joined(separator: " ")
        let logMessage =
            "\(prefix) [\(fileName):\(line)] \(function): \(message)"
        os_log("%{public}@", log: logger, type: type, logMessage)
    }

    // MARK: - Stringify Helper

    static func stringify(_ value: Any) -> String {
        switch value {
        case let string as String:
            return string
        case let int as Int:
            return String(int)
        case let double as Double:
            return String(double)
        case let bool as Bool:
            return String(bool)
        case let error as Error:
            return "Error: \(error.localizedDescription)"
        case let data as Data:
            return String(data: data, encoding: .utf8) ?? "<Data>"
        case let array as [Any]:
            return "[" + array.map { stringify($0) }.joined(separator: ", ")
                + "]"
        case let dict as [String: Any]:
            return dict.map { "\($0): \(stringify($1))" }.joined(
                separator: ", "
            )
        case let codable as Encodable:
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let data = try? encoder.encode(AnyEncodable(codable)),
                let json = String(data: data, encoding: .utf8)
            {
                return json
            }
            return "\(codable)"
        default:
            return String(describing: value)
        }
    }
}

// Helper for encoding any Encodable
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init<T: Encodable>(_ wrapped: T) {
        _encode = wrapped.encode
    }
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
