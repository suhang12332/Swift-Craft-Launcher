import Foundation
import SwiftUI

class GameSettingsManager: ObservableObject {
    @Published public var allJavaPaths: [String: String] = [:]
    
    private static func detectJavaPath() -> String {
        // 使用 /usr/libexec/java_home 获取 JAVA_HOME
        if let taskOutput = try? shell(["/usr/libexec/java_home"]) {
            let javaHome = taskOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            if !javaHome.isEmpty {
                return javaHome + "/bin"
            }
        }
        // 或者使用 which java
        if let taskOutput = try? shell(["which", "java"]) {
            let javaBin = taskOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            if !javaBin.isEmpty {
                let javaDir = (javaBin as NSString).deletingLastPathComponent
                return javaDir
            }
        }
        // 默认路径
        return "/usr/bin"
    }
    
    private static func detectAllJavaPaths() -> [String: String] {
        var dict: [String: String] = [:]
        guard let output = try? shell(["/usr/libexec/java_home", "-V"]) else { return dict }
        /*
        输出类似：
        Matching Java Virtual Machines (2):
            17.0.2, x86_64:   "OpenJDK 17.0.2" /Library/Java/JavaVirtualMachines/temurin-17.0.2.jdk/Contents/Home
            1.8.0_292, x86_64:    "AdoptOpenJDK 8" /Library/Java/JavaVirtualMachines/adoptopenjdk-8.jdk/Contents/Home
        */
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // 匹配以类似 17.0.2, x86_64: 开头的行
            if let verRange = trimmed.range(of: "^[^,]+", options: .regularExpression),
               let pathRange = trimmed.range(of: "/Library/Java/JavaVirtualMachines/.*", options: .regularExpression) {
                let version = String(trimmed[verRange])
                let path = String(trimmed[pathRange]) + "/bin"
                dict[version] = path
            }
        }
        return dict
    }
    
    private static func shell(_ args: [String]) throws -> String {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        try task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    static let shared = GameSettingsManager()
    
    @AppStorage("defaultJavaPath") public var defaultJavaPath: String = GameSettingsManager.detectJavaPath() {
        didSet { objectWillChange.send() }
    }
    @AppStorage("defaultMemoryAllocation") public var defaultMemoryAllocation: Int = 512 {
        didSet { objectWillChange.send() }
    }
    @AppStorage("concurrentDownloads") public var concurrentDownloads: Int = 4 {
        didSet {
            if concurrentDownloads < 1 {
                concurrentDownloads = 1
            }
            objectWillChange.send()
        }
    }
    @AppStorage("autoDownloadDependencies") public var autoDownloadDependencies: Bool = false {
        didSet { objectWillChange.send() }
    }
    @AppStorage("minecraftVersionManifestURL") public var minecraftVersionManifestURL: String = "https://launchermeta.mojang.com/mc/game/version_manifest.json" {
        didSet { objectWillChange.send() }
    }
    @AppStorage("modrinthAPIBaseURL") public var modrinthAPIBaseURL: String = "https://api.modrinth.com/v2" {
        didSet { objectWillChange.send() }
    }
    @AppStorage("forgeMavenMirrorURL") public var forgeMavenMirrorURL: String = "" {
        didSet { objectWillChange.send() }
    }
    @AppStorage("gitProxyURL") public var gitProxyURL: String = "https://ghfast.top" {
        didSet { objectWillChange.send() }
    }
    @AppStorage("globalXms") public var globalXms: Int = 512 {
        didSet { objectWillChange.send() }
    }
    @AppStorage("globalXmx") public var globalXmx: Int = 4096 {
        didSet { objectWillChange.send() }
    }
    private init() {
        self.allJavaPaths = GameSettingsManager.detectAllJavaPaths()
    }
}
