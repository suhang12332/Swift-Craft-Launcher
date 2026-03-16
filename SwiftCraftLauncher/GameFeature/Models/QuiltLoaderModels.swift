import Foundation

struct QuiltLoaderResponse: Codable, Sendable {
    struct Loader: Codable, Sendable {
        let version: String
    }

    let loader: Loader
}
