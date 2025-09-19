// MARK: - Fabric Loader API 响应模型
import Foundation

struct FabricLoader: Codable {
    let loader: LoaderInfo

    struct LoaderInfo: Codable {
        let version: String
    }
}
