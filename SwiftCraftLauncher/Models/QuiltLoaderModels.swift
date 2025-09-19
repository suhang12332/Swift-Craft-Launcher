import Foundation

struct QuiltLoaderResponse: Codable {
    struct Loader: Codable {
        let version: String
    }

    let loader: Loader
}
