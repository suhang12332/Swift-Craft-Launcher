import Foundation

protocol YggdrasilProfileListParser {
    var id: YggdrasilProfileParserID { get }

    func parse(data: Data) -> [YggdrasilProfileCandidate]?
}

protocol YggdrasilProfileParserProvider {
    func makeParser(for id: YggdrasilProfileParserID) -> (any YggdrasilProfileListParser)?
}

enum YggdrasilProfileParsers {
    private static var provider: YggdrasilProfileParserProvider?

    static func configure(provider: YggdrasilProfileParserProvider) {
        self.provider = provider
    }

    static func make(_ id: YggdrasilProfileParserID) -> (any YggdrasilProfileListParser)? {
        provider?.makeParser(for: id)
    }
}
