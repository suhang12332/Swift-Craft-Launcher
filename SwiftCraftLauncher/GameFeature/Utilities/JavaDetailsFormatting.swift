import Foundation

enum JavaDetailsFormatting {

    static func description(javaExecutablePath: String, versionOutput: String) -> String {
        let versionPart = versionOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathPart = javaExecutablePath.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
        return [pathPart, versionPart]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
