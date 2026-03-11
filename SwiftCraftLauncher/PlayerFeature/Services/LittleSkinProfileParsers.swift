import Foundation

/// LittleSkin 等多用户：数组 / 包装数组 + properties.textures(base64)
struct LittleSkinStyleProfileListParser: YggdrasilProfileListParser {
    let id: YggdrasilProfileParserID = .littleskin

    func parse(data: Data) -> [YggdrasilProfileCandidate]? {
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

/// LittleSkin 相关的解析器 Provider，实现通用协议并注册到 YggdrasilProfileParsers
struct LittleSkinProfileParserProvider: YggdrasilProfileParserProvider {
    func makeParser(for id: YggdrasilProfileParserID) -> (any YggdrasilProfileListParser)? {
        switch id {
        case .littleskin:
            return LittleSkinStyleProfileListParser()
        }
    }
}

/// 提供一个便捷的注入入口，供 PlayerFeature 在合适的时机调用
enum LittleSkinProfileParsersConfigurator {
    static func bootstrap() {
        YggdrasilProfileParsers.configure(provider: LittleSkinProfileParserProvider())
    }
}
