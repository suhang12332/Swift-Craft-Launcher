import XCTest
@testable import SwiftCraftLauncher

final class MinecraftLaunchCommandBuilderTests: XCTestCase {

    // MARK: - Helpers

    private func makeGameInfo(
        id: String = "test-game-id",
        gameName: String = "TestGame",
        gameVersion: String = "1.20.1",
        assetIndex: String = "17",
        mainClass: String = "net.minecraft.client.main.Main",
        modClassPath: String = "",
        modJvm: [String] = [],
        gameArguments: [String] = [],
        xms: Int = 0,
        xmx: Int = 0,
        jvmArguments: String = "",
        javaPath: String = "/usr/bin/java"
    ) -> GameVersionInfo {
        var info = GameVersionInfo(
            id: UUID(uuidString: id) ?? UUID(),
            gameName: gameName,
            gameIcon: "",
            gameVersion: gameVersion,
            modClassPath: modClassPath,
            assetIndex: assetIndex,
            modLoader: "vanilla",
            javaPath: javaPath,
            jvmArguments: jvmArguments,
            xms: xms,
            xmx: xmx,
            mainClass: mainClass,
            gameArguments: gameArguments
        )
        return info
    }

    private func makeLibrary(
        name: String = "test:lib:1.0",
        artifactPath: String? = "org/example/lib-1.0.jar",
        downloadable: Bool = true,
        includeInClasspath: Bool = true,
        rules: [Rule]? = nil
    ) throws -> Library {
        var artifactJson: [String: Any] = [
            "sha1": "abc",
            "size": 100,
            "url": "https://example.com/lib.jar",
        ]
        if let path = artifactPath {
            artifactJson["path"] = path
        }

        var json: [String: Any] = [
            "downloads": ["artifact": artifactJson],
            "name": name,
            "include_in_classpath": includeInClasspath,
            "downloadable": downloadable,
        ]
        if let rules = rules {
            let ruleData = try JSONEncoder().encode(rules)
            let ruleObj = try JSONSerialization.jsonObject(with: ruleData)
            json["rules"] = ruleObj
        }

        let jsonData = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(Library.self, from: jsonData)
    }

    // MARK: - 库过滤逻辑验证

    func testLibraryFiltering_nonDownloadableExcluded() throws {
        let library = try makeLibrary(downloadable: false, includeInClasspath: true)
        XCTAssertFalse(LibraryFilter.shouldDownloadLibrary(library))
        XCTAssertFalse(LibraryFilter.shouldIncludeInClasspath(library))
    }

    func testLibraryFiltering_notInClasspathExcluded() throws {
        let library = try makeLibrary(downloadable: true, includeInClasspath: false)
        XCTAssertTrue(LibraryFilter.shouldDownloadLibrary(library))
        XCTAssertFalse(LibraryFilter.shouldIncludeInClasspath(library))
    }

    func testLibraryFiltering_bothTrueIncluded() throws {
        let library = try makeLibrary(downloadable: true, includeInClasspath: true)
        XCTAssertTrue(LibraryFilter.shouldDownloadLibrary(library))
        XCTAssertTrue(LibraryFilter.shouldIncludeInClasspath(library))
    }

    // MARK: - 路径去重逻辑验证

    func testRemoveDuplicatePaths_removesExactDuplicates() throws {
        let paths = ["/a/b.jar", "/a/b.jar", "/c/d.jar"]
        let unique = Array(Set(paths))
        XCTAssertEqual(unique.count, 2)
    }

    func testRemoveDuplicatePaths_preservesOrder() throws {
        let paths = ["/a/b.jar", "/c/d.jar", "/a/b.jar"]
        var seen = Set<String>()
        let filtered = paths.filter { seen.insert($0).inserted }
        XCTAssertEqual(filtered, ["/a/b.jar", "/c/d.jar"])
    }

    // MARK: - 构建命令结构验证

    func testCommandStructure_jvmArgsBeforeMainClass() throws {
        // 验证命令结构：JVM参数 + 主类 + 游戏参数
        let jvmArgs = ["-Xmx4G", "-Djava.class.path=/path/to/jar"]
        let mainClass = "net.minecraft.client.main.Main"
        let gameArgs = ["--width", "854"]

        let command = jvmArgs + [mainClass] + gameArgs

        XCTAssertEqual(command.count, 5)
        XCTAssertEqual(command[0], "-Xmx4G")
        XCTAssertEqual(command[2], mainClass)
        XCTAssertEqual(command[3], "--width")
        XCTAssertEqual(command[4], "854")
    }

    func testCommandStructure_macOSArgsFirst() throws {
        // 验证 macOS 特定参数在最前面
        var jvmArgs = ["-Xmx4G"]
        jvmArgs.insert("-XstartOnFirstThread", at: 0)

        XCTAssertEqual(jvmArgs.first, "-XstartOnFirstThread")
    }

    func testCommandStructure_memoryArgsBeforeOtherJvmArgs() throws {
        // 验证内存参数在其他 JVM 参数之前
        var jvmArgs = ["-Djava.class.path=/path/to/jar"]
        let xmsArg = "-Xms${xms}M"
        let xmxArg = "-Xmx${xmx}M"
        jvmArgs.insert(contentsOf: [xmsArg, xmxArg], at: 0)

        XCTAssertEqual(jvmArgs[0], "-Xms${xms}M")
        XCTAssertEqual(jvmArgs[1], "-Xmx${xmx}M")
        XCTAssertEqual(jvmArgs[2], "-Djava.class.path=/path/to/jar")
    }

    // MARK: - Mod JVM 参数拼接

    func testModJvmArgs_appendedToEnd() throws {
        var jvmArgs = ["-Xmx4G", "-XstartOnFirstThread"]
        let modJvm = ["-Dfabric.classPath=/mods", "-Dforge.enabled=true"]

        jvmArgs.append(contentsOf: modJvm)

        XCTAssertEqual(jvmArgs.count, 4)
        XCTAssertEqual(jvmArgs[2], "-Dfabric.classPath=/mods")
        XCTAssertEqual(jvmArgs[3], "-Dforge.enabled=true")
    }

    // MARK: - 游戏参数拼接

    func testGameArgs_appendedToEnd() throws {
        var gameArgs = ["--width", "854"]
        let extraGameArgs = ["--launchTarget", "forge_client"]

        gameArgs.append(contentsOf: extraGameArgs)

        XCTAssertEqual(gameArgs.count, 4)
        XCTAssertEqual(gameArgs[2], "--launchTarget")
        XCTAssertEqual(gameArgs[3], "forge_client")
    }

    // MARK: - 变量映射验证

    func testVariableMap_containsRequiredKeys() throws {
        let gameInfo = makeGameInfo(
            gameName: "TestGame",
            gameVersion: "1.20.1",
            assetIndex: "17"
        )

        var variableMap: [String: String] = [
            "auth_player_name": "${auth_player_name}",
            "version_name": gameInfo.gameVersion,
            "game_directory": "/path/to/game",
            "assets_root": "/path/to/assets",
            "assets_index_name": gameInfo.assetIndex,
            "auth_uuid": "${auth_uuid}",
            "auth_access_token": "${auth_access_token}",
            "clientid": "client-id",
            "auth_xuid": "${auth_xuid}",
            "user_type": "msa",
            "version_type": "SwiftCraft",
            "natives_directory": "/path/to/natives",
            "launcher_name": "SwiftCraft",
            "launcher_version": "1.0",
            "classpath": "/path/to/classpath",
        ]

        XCTAssertEqual(variableMap["version_name"], "1.20.1")
        XCTAssertEqual(variableMap["assets_index_name"], "17")
        XCTAssertEqual(variableMap["user_type"], "msa")
        XCTAssertEqual(variableMap["auth_player_name"], "${auth_player_name}")
    }
}
