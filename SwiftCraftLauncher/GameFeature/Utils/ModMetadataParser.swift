import Foundation
import ZIPFoundation

enum ModMetadataParser {
    /// 解析 modid 和 version（静默版本）
    static func parseModMetadata(
        fileURL: URL,
        completion: @escaping (_ modid: String?, _ version: String?) -> Void
    ) {
        do {
            let result = try parseModMetadataThrowing(fileURL: fileURL)
            completion(result.0, result.1)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("解析 mod 元数据失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            completion(nil, nil)
        }
    }

    /// 解析 modid 和 version（抛出异常版本）
    static func parseModMetadataThrowing(fileURL: URL) throws -> (
        String?, String?
    ) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw GlobalError.resource(
                chineseMessage: "文件不存在: \(fileURL.lastPathComponent)",
                i18nKey: "error.resource.file_not_found",
                level: .silent
            )
        }

        let archive: Archive
        do {
            archive = try Archive(url: fileURL, accessMode: .read)
        } catch {
            throw GlobalError.validation(
                chineseMessage:
                    "无法打开压缩包: \(fileURL.lastPathComponent), 错误: \(error.localizedDescription)",
                i18nKey: "error.validation.archive_open_failed",
                level: .silent
            )
        }

        // 1. Forge (mods.toml)
        if let entry = archive["META-INF/mods.toml"] {
            if let (modid, version) = try parseForgeTomlThrowing(
                archive: archive,
                entry: entry
            ) {
                Logger.shared.info(
                    "ModMetadataParser: 解析 mods.toml 成功: \(modid) \(version)"
                )
                return (modid, version)
            } else {
                Logger.shared.warning(
                    "ModMetadataParser: 解析 mods.toml 失败: \(fileURL.lastPathComponent)"
                )
            }
        }

        // 2. Fabric (fabric.mod.json)
        if let entry = archive["fabric.mod.json"] {
            if let (modid, version) = try parseFabricJsonThrowing(
                archive: archive,
                entry: entry
            ) {
                Logger.shared.info(
                    "ModMetadataParser: 解析 fabric.mod.json 成功: \(modid) \(version)"
                )
                return (modid, version)
            } else {
                Logger.shared.warning(
                    "ModMetadataParser: 解析 fabric.mod.json 失败: \(fileURL.lastPathComponent)"
                )
            }
        }

        // 3. 旧 Forge (mcmod.info)
        if let entry = archive["mcmod.info"] {
            if let (modid, version) = try parseMcmodInfoThrowing(
                archive: archive,
                entry: entry
            ) {
                Logger.shared.info(
                    "ModMetadataParser: 解析 mcmod.info 成功: \(modid) \(version)"
                )
                return (modid, version)
            } else {
                Logger.shared.warning(
                    "ModMetadataParser: 解析 mcmod.info 失败: \(fileURL.lastPathComponent)"
                )
            }
        }

        Logger.shared.warning(
            "ModMetadataParser: 未能识别任何元数据: \(fileURL.lastPathComponent)"
        )
        return (nil, nil)
    }

    private static func parseForgeToml(archive: Archive, entry: Entry) -> (
        String, String
    )? {
        do {
            return try parseForgeTomlThrowing(archive: archive, entry: entry)
        } catch {
            return nil
        }
    }

    private static func parseForgeTomlThrowing(
        archive: Archive,
        entry: Entry
    ) throws -> (String, String)? {
        var data = Data()
        do {
            try _ = archive.extract(entry) { chunk in
                data.append(chunk)
            }
        } catch {
            throw GlobalError.validation(
                chineseMessage:
                    "提取 mods.toml 失败: \(error.localizedDescription)",
                i18nKey: "error.validation.mods_toml_extract_failed",
                level: .silent
            )
        }

        guard let tomlString = String(data: data, encoding: .utf8) else {
            throw GlobalError.validation(
                chineseMessage: "无法解码 mods.toml 内容",
                i18nKey: "error.validation.mods_toml_decode_failed",
                level: .silent
            )
        }

        let modid = matchFirst(
            in: tomlString,
            pattern: #"modId\s*=\s*[\"']([^\"']+)[\"']"#
        )
        let version = matchFirst(
            in: tomlString,
            pattern: #"version\s*=\s*[\"']([^\"']+)[\"']"#
        )

        if let modid = modid, let version = version {
            return (modid, version)
        }
        return nil
    }

    private static func parseFabricJson(archive: Archive, entry: Entry) -> (
        String, String
    )? {
        do {
            return try parseFabricJsonThrowing(archive: archive, entry: entry)
        } catch {
            return nil
        }
    }

    private static func parseFabricJsonThrowing(
        archive: Archive,
        entry: Entry
    ) throws -> (String, String)? {
        var data = Data()
        do {
            try _ = archive.extract(entry) { chunk in
                data.append(chunk)
            }
        } catch {
            throw GlobalError.validation(
                chineseMessage:
                    "提取 fabric.mod.json 失败: \(error.localizedDescription)",
                i18nKey: "error.validation.fabric_mod_json_extract_failed",
                level: .silent
            )
        }

        let json: [String: Any]
        do {
            json =
                try JSONSerialization.jsonObject(with: data) as? [String: Any]
                ?? [:]
        } catch {
            throw GlobalError.validation(
                chineseMessage:
                    "解析 fabric.mod.json 失败: \(error.localizedDescription)",
                i18nKey: "error.validation.fabric_mod_json_parse_failed",
                level: .silent
            )
        }

        guard let modid = json["id"] as? String,
            let version = json["version"] as? String
        else {
            throw GlobalError.validation(
                chineseMessage: "fabric.mod.json 缺少必要的字段",
                i18nKey: "error.validation.fabric_mod_json_missing_fields",
                level: .silent
            )
        }

        return (modid, version)
    }

    private static func parseMcmodInfo(archive: Archive, entry: Entry) -> (
        String, String
    )? {
        do {
            return try parseMcmodInfoThrowing(archive: archive, entry: entry)
        } catch {
            return nil
        }
    }

    private static func parseMcmodInfoThrowing(
        archive: Archive,
        entry: Entry
    ) throws -> (String, String)? {
        var data = Data()
        do {
            try _ = archive.extract(entry) { chunk in
                data.append(chunk)
            }
        } catch {
            throw GlobalError.validation(
                chineseMessage:
                    "提取 mcmod.info 失败: \(error.localizedDescription)",
                i18nKey: "error.validation.mcmod_info_extract_failed",
                level: .silent
            )
        }

        let arr: [[String: Any]]
        do {
            arr =
                try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
                ?? []
        } catch {
            throw GlobalError.validation(
                chineseMessage:
                    "解析 mcmod.info 失败: \(error.localizedDescription)",
                i18nKey: "error.validation.mcmod_info_parse_failed",
                level: .silent
            )
        }

        guard let first = arr.first else {
            throw GlobalError.validation(
                chineseMessage: "mcmod.info 为空",
                i18nKey: "error.validation.mcmod_info_empty",
                level: .silent
            )
        }

        guard let modid = first["modid"] as? String,
            let version = first["version"] as? String
        else {
            throw GlobalError.validation(
                chineseMessage: "mcmod.info 缺少必要的字段",
                i18nKey: "error.validation.mcmod_info_missing_fields",
                level: .silent
            )
        }

        return (modid, version)
    }

    private static func matchFirst(
        in text: String,
        pattern: String
    ) -> String? {
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsrange = NSRange(text.startIndex..., in: text)
        guard let match = regex?.firstMatch(in: text, range: nsrange),
            let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }
}
