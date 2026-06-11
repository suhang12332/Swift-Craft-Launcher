import Foundation
import XCTest

private final class BundleToken {}

enum TestSupport {
    static var bundle: Bundle {
        Bundle(for: BundleToken.self)
    }

    static func fixtureURL(subdirectory: String, name: String, extension ext: String) -> URL {
        if let url = bundle.url(
            forResource: name,
            withExtension: ext,
            subdirectory: subdirectory
        ) {
            return url
        }

        // Xcode file-system synchronized groups flatten JSON fixtures into the bundle root.
        if let url = bundle.url(forResource: name, withExtension: ext) {
            return url
        }

        XCTFail("Missing fixture \(subdirectory)/\(name).\(ext)")
        fatalError("Missing fixture \(subdirectory)/\(name).\(ext)")
    }

    static func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("scl-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
