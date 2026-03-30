import Foundation

protocol YggdrasilProfileListParser {
    var id: YggdrasilProfileParserID { get }

    func parse(data: Data) async -> [YggdrasilProfileCandidate]?
}

protocol YggdrasilProfileParserProvider {
    func makeParser(
        for id: YggdrasilProfileParserID,
        baseURL: String
    ) -> (any YggdrasilProfileListParser)?
}

enum YggdrasilProfileParsers {
    private static var provider: YggdrasilProfileParserProvider?

    static func configure(provider: YggdrasilProfileParserProvider) {
        self.provider = provider
    }

    static func make(_ id: YggdrasilProfileParserID, baseURL: String) -> (any YggdrasilProfileListParser)? {
        provider?.makeParser(for: id, baseURL: baseURL)
    }
}
