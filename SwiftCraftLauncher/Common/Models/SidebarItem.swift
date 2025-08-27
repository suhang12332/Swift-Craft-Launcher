import Foundation

/// 侧边栏导航项
public enum SidebarItem: Hashable, Identifiable {
    case game(String)  // 游戏项，包含游戏ID
    case resource(ResourceType)  // 资源项
    
    public var id: String {
        switch self {
        case .game(let gameId):
            return "game_\(gameId)"
        case .resource(let type):
            return "resource_\(type.rawValue)"
        }
    }
    
    public var title: String {
        switch self {
        case .game(let gameId):
            return gameId  // 这里可以改为从游戏数据中获取名称
        case .resource(let type):
            return type.localizedName
        }
    }
}

/// 资源类型
public enum ResourceType: String, CaseIterable {
    case mod = "mod"
    case datapack = "datapack"
    case shader = "shader"
    case resourcepack = "resourcepack"
    case modpack = "modpack"
    
    public var localizedName: String {
        "resource.content.type.\(rawValue)".localized()
    }
} 