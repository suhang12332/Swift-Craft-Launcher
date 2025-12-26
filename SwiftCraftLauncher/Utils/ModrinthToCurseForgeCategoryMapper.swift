import Foundation

/// Modrinth 分类到 CurseForge 分类 ID 的映射器
enum ModrinthToCurseForgeCategoryMapper {
    /// 将 Modrinth 分类名称映射到 CurseForge 分类 ID
    /// - Parameter modrinthCategoryName: Modrinth 分类名称
    /// - Parameter projectType: 项目类型（mod、modpack、resourcepack、shader、datapack）
    /// - Returns: CurseForge 分类 ID，如果找不到映射则返回 nil
    static func mapToCurseForgeCategoryId(
        modrinthCategoryName: String,
        projectType: String
    ) -> Int? {
        let key = modrinthCategoryName.lowercased()
        // 根据项目类型选择映射表
        switch projectType.lowercased() {
        case "mod", "modpack":
            return modCategoryMap[key]
        case "resourcepack":
            return resourcepackCategoryMap[key]
        case "shader":
            return shaderCategoryMap[key]
        case "datapack":
            // 数据包：采用 Modrinth 的 mod 分类 key，映射到 CurseForge Data Packs（classId=6945）
            return datapackCategoryMap[key]
        default:
            return nil
        }
    }

    /// 将多个 Modrinth 分类名称映射到 CurseForge 分类 ID 列表
    /// - Parameters:
    ///   - modrinthCategoryNames: Modrinth 分类名称列表
    ///   - projectType: 项目类型
    /// - Returns: CurseForge 分类 ID 列表（最多 10 个，符合 API 限制）
    static func mapToCurseForgeCategoryIds(
        modrinthCategoryNames: [String],
        projectType: String
    ) -> [Int] {
        let mappedIds = modrinthCategoryNames.compactMap { name in
            mapToCurseForgeCategoryId(modrinthCategoryName: name, projectType: projectType)
        }
        // API 限制：最多 10 个分类 ID
        return Array(mappedIds.prefix(10))
    }

    // MARK: - Mod 分类映射表
    /// Modrinth mod / modpack 分类到 CurseForge 分类 ID 的映射
    /// 主要依据：`gen_category_mapping.py` 的自动结果 + 手动补充的近似分类
    private static let modCategoryMap: [String: Int] = [
        // 冒险类 -> Adventure and RPG
        "adventure": 422,
        // 奇葩 / 恶搞类，归为杂项
        "cursed": 425,           // Miscellaneous
        // 装饰类 -> Cosmetic
        "decoration": 424,
        // 经济类，无直接 Mod 分类，临时归为杂项
        "economy": 425,          // Miscellaneous
        // 装备类 -> Armor, Tools, and Weapons
        "equipment": 434,
        // 食物类 -> Food
        "food": 436,
        // 游戏机制，归为杂项
        "game-mechanics": 425,   // Miscellaneous
        // 库 / API 类 -> API and Library
        "library": 421,
        // 魔法类 -> Magic
        "magic": 419,
        // 管理类 -> Server Utility
        "management": 435,
        // 小游戏 -> 杂项
        "minigame": 425,         // Miscellaneous
        // 生物类 -> Mobs
        "mobs": 411,
        // 优化类 -> Performance
        "optimization": 6814,
        // 社交类 -> Utility & QoL
        "social": 5191,          // Utility & QoL
        // 存储类 -> Storage
        "storage": 420,
        // 科技类 -> Technology
        "technology": 412,
        // 交通类 -> Player Transport
        "transportation": 414,
        // 工具 / 服务器实用工具 -> Server Utility
        "utility": 435,
        // 世界生成 -> World Gen
        "worldgen": 406,
    ]

    // MARK: - Resourcepack 分类映射表
    /// Modrinth resourcepack 分类到 CurseForge 分类 ID 的映射
    /// 主要依据：`gen_category_mapping.py` 的自动结果 + 手动补充的近似分类
    private static let resourcepackCategoryMap: [String: Int] = [
        // 分辨率（Resolution）映射到 Texture Packs 对应分辨率分类
        "128x": 396,             // 128x -> 128x
        "16x": 393,              // 16x  -> 16x
        "256x": 397,             // 256x -> 256x
        "32x": 394,              // 32x  -> 32x
        "64x": 395,              // 64x  -> 64x
        // 其他分辨率，近似归类
        "48x": 395,              // 接近 64x
        "512x+": 398,            // -> 512x and Higher
        "8x-": 393,              // 低分辨率，归到 16x
        // 风格类
        "realistic": 400,        // Realistic -> Photo Realistic
        "simplistic": 403,       // -> Traditional
        "themed": 399,           // -> Steampunk (主题包)
        "vanilla-like": 403,     // -> Traditional (接近原版风格)
        // 功能 / 内容相关，统一归到 Miscellaneous 或更接近的类型
        "audio": 405,            // 声音效果，暂归 Miscellaneous
        "blocks": 405,
        "combat": 405,
        "core-shaders": 404,     // 与渲染相关，归 Animated
        "cursed": 405,
        "decoration": 405,
        "entities": 405,
        "environment": 405,
        "equipment": 405,
        "gui": 401,              // 界面相关，近似 Modern
        "items": 405,
        "locale": 405,
        "models": 405,
        "tweaks": 405,
        "utility": 405,
        // 特殊：
        "fonts": 5244,           // -> Font Packs
        "modded": 4465,          // -> Mod Support
    ]

    // MARK: - Shader 分类映射表
    /// Modrinth shader 分类到 CurseForge 分类 ID 的映射
    /// 主要依据：`gen_category_mapping.py` 的自动结果 + 手动补充的近似分类（CF 端只有 Fantasy / Realistic / Vanilla 三类）
    private static let shaderCategoryMap: [String: Int] = [
        // 风格 / 质量（自动映射）
        "fantasy": 6554,         // Fantasy
        "realistic": 6553,       // Realistic
        "semi-realistic": 6553,  // Semi-realistic -> Realistic
        "vanilla-like": 6555,    // Vanilla-like -> Vanilla
        // 其余标签，根据风格/性能大致归类
        "atmosphere": 6553,
        "bloom": 6553,
        "cartoon": 6554,
        "colored-lighting": 6553,
        "cursed": 6554,
        "foliage": 6553,
        "high": 6553,
        "low": 6555,
        "medium": 6555,
        "path-tracing": 6553,
        "pbr": 6553,
        "potato": 6555,
        "reflections": 6553,
        "screenshot": 6553,
        "shadows": 6553,
    ]

    // MARK: - Datapack 分类映射表
    /// Modrinth datapack 使用与 mod 相同的一组分类 key（adventure/magic/technology/...），
    /// 这里将这些 key 映射到 CurseForge Data Packs（classId=6945）的分类 ID
    /// 参考 `cf.json` 中 classId=6945 下的分类：
    /// - 6948 Adventure
    /// - 6949 Fantasy
    /// - 6950 Library
    /// - 6952 Magic
    /// - 6947 Miscellaneous
    /// - 6946 Mod Support
    /// - 6951 Tech
    /// - 6953 Utility
    private static let datapackCategoryMap: [String: Int] = [
        // 直接对应的几类（与 Data Packs 的官方分类一一对应）
        "adventure": 6948,        // Adventure
        "library": 6950,          // Library
        "magic": 6952,            // Magic
        "technology": 6951,       // Tech
        "utility": 6953,          // Utility

        // 语义相近的映射（尽量避免全部归到杂项）
        "worldgen": 6948,         // 世界生成，多数是冒险/探索向 -> Adventure
        "mobs": 6948,             // 生物相关事件/生成 -> Adventure
        "optimization": 6953,     // 性能类规则 -> Utility
        "storage": 6951,          // 存储/技术系统规则 -> Tech
        "management": 6953,       // 管理/自动化 -> Utility
        "economy": 6953,          // 经济/货币规则 -> Utility
        "transportation": 6951,   // 交通/传送规则 -> Tech

        // 其余暂时归到 Miscellaneous（将来可以按需要再细分）
        "cursed": 6947,
        "decoration": 6947,
        "equipment": 6947,
        "food": 6947,
        "game-mechanics": 6947,
        "minigame": 6947,
        "social": 6947,
    ]

    /// 从 CurseForge API 获取分类并更新映射表（可选）
    /// 这个方法可以在运行时动态获取分类来完善映射
    static func updateCategoryMapFromAPI() async {
        // NOTE: 预留实现，从 CurseForge API 获取分类并更新映射表
        // 当前版本使用静态映射表，避免在运行时增加额外依赖
    }
}
