import Foundation

/// 通用的解析器 Provider（LittleSkin / MUA / Ely.by）
struct CommonYggdrasilProfileParserProvider: YggdrasilProfileParserProvider {
    func makeParser(
        for id: YggdrasilProfileParserID,
        baseURL: String
    ) -> (any YggdrasilProfileListParser)? {
        switch id {
        case .littleskin:
            return CommonYggdrasilStyleProfileListParser(baseURL: baseURL)
        case .mua:
            return CommonBlessingSkinStyleProfileListParser(baseURL: baseURL)
        case .ely:
            return ElyflyProfileStyleProfileListParser(baseURL: baseURL)
        }
    }
}

/// 统一的注入入口
enum CommonYggdrasilProfileParsersConfigurator {
    static func bootstrap() {
        YggdrasilProfileParsers.configure(provider: CommonYggdrasilProfileParserProvider())
    }
}
