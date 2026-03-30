import Foundation

/// 通用的 Yggdrasil 多用户列表解析（LittleSkin/MUA 同格式）
enum CommonYggdrasilProfileListParser {
    static func parse(data: Data) -> [YggdrasilProfileCandidate]? {
        struct Prop: Codable { let name: String; let value: String }
        struct Item: Codable {
            let id: String
            let name: String
            let properties: [Prop]?
        }
        struct TexturesPayload: Codable {
            let textures: TexturesInner?
        }
        struct TexturesInner: Codable {
            let SKIN: SkinEntry?
            let CAPE: SkinEntry?
        }
        struct SkinEntry: Codable {
            let url: String
            let metadata: SkinMeta?
        }
        struct SkinMeta: Codable {
            let model: String?
        }
        struct ProfileListWrapper: Decodable {
            let data: [Item]

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                data = try c.decodeIfPresent([Item].self, forKey: .data)
                    ?? c.decodeIfPresent([Item].self, forKey: .profiles)
                    ?? []
            }
            private enum CodingKeys: String, CodingKey { case data, profiles }
        }

        let items: [Item]

        if let list = try? JSONDecoder().decode([Item].self, from: data) {
            items = list
        } else if let wrapper = try? JSONDecoder().decode(ProfileListWrapper.self, from: data), !wrapper.data.isEmpty {
            items = wrapper.data
        } else {
            return nil
        }
        guard !items.isEmpty else { return nil }

        var result: [YggdrasilProfileCandidate] = []
        for item in items {
            var skins: [Skin] = []
            var capes: [Cape] = []

            if let props = item.properties {
                for prop in props where prop.name == "textures" {
                    guard let decoded = Data(base64Encoded: prop.value),
                          let json = try? JSONDecoder().decode(TexturesPayload.self, from: decoded),
                          let tex = json.textures else { continue }
                    if let s = tex.SKIN {
                        skins.append(Skin(
                            state: "ACTIVE",
                            url: s.url,
                            variant: s.metadata?.model ?? "classic"
                        ))
                    }
                    if let c = tex.CAPE {
                        capes.append(Cape(
                            id: UUID().uuidString,
                            state: "ACTIVE",
                            url: c.url,
                            alias: nil
                        ))
                    }
                }
            }

            if skins.isEmpty {
                skins.append(Skin(state: "ACTIVE", url: "", variant: "classic"))
            }

            result.append(YggdrasilProfileCandidate(
                id: item.id,
                name: item.name,
                skins: skins,
                capes: capes.isEmpty ? nil : capes
            ))
        }
        return result
    }
}

/// LittleSkin 通用解析器
struct CommonYggdrasilStyleProfileListParser: YggdrasilProfileListParser {
    let id: YggdrasilProfileParserID = .littleskin
    private let baseURL: String

    init(baseURL: String) {
        self.baseURL = baseURL
    }

    func parse(data: Data) -> [YggdrasilProfileCandidate]? {
        CommonYggdrasilProfileListParser.parse(data: data)
    }
}

/// 通用的解析器 Provider（LittleSkin / MUA 同格式）
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
        }
    }
}

/// 统一的注入入口
enum CommonYggdrasilProfileParsersConfigurator {
    static func bootstrap() {
        YggdrasilProfileParsers.configure(provider: CommonYggdrasilProfileParserProvider())
    }
}
