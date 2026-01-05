import Foundation
import Security
import AppKit
import ZIPFoundation

/// EasyTier 联机服务
/// 负责管理 EasyTier 网络连接
@MainActor
class EasyTierService {
    static let shared = EasyTierService()

    // MARK: - Properties

    /// EasyTier 公共服务器地址
    private let publicServer = "tcp://public.easytier.cn:11010"

    /// 当前房间
    private(set) var currentRoom: EasyTierRoom?

    /// 当前运行的进程
    private var currentProcess: Process?

    /// 授权引用
    private var authRef: AuthorizationRef?

    // 进度回调 - 使用actor来确保线程安全
    private let progressActor = EasyTierProgressActor()
    // 取消检查回调 - 使用actor来确保线程安全
    private let cancelActor = EasyTierCancelActor()

    // MARK: - Initialization

    private init() {
        // 初始化授权引用
        var authRef: AuthorizationRef?
        let status = AuthorizationCreate(nil, nil, [], &authRef)
        if status == errAuthorizationSuccess {
            self.authRef = authRef
        }
    }

    deinit {
        if let authRef = authRef {
            AuthorizationFree(authRef, [])
        }
    }

    // MARK: - Public Methods

    /// 创建新房间
    /// - Returns: 新创建的房间
    func createRoom() -> EasyTierRoom {
        let roomCode = RoomCodeGenerator.generate()
        let room = EasyTierRoom(roomCode: roomCode)
        return room
    }

    /// 加入房间
    /// - Parameter roomCode: 房间码
    /// - Returns: 房间对象，如果房间码无效则返回 nil
    func joinRoom(roomCode: String) -> EasyTierRoom? {
        guard RoomCodeGenerator.validate(roomCode) else {
            Logger.shared.warning("无效的房间码: \(roomCode)")
            return nil
        }

        let room = EasyTierRoom(roomCode: roomCode)
        Logger.shared.info("加入房间: \(roomCode)")
        return room
    }

    /// 使用房间码启动 EasyTier 网络
    /// - Parameter roomCode: 房间码
    /// - Throws: GlobalError 当启动失败时
    func startNetwork(roomCode: String) async throws {
        // 验证房间码
        guard RoomCodeGenerator.validate(roomCode) else {
            throw GlobalError.configuration(
                chineseMessage: "无效的房间码格式",
                i18nKey: "error.configuration.invalid_room_code",
                level: .notification
            )
        }

        // 创建房间对象
        let room = EasyTierRoom(roomCode: roomCode)

        // 启动网络
        try await startNetwork(room: room)
    }

    /// 启动 EasyTier 网络（内部方法，使用房间对象）
    /// - Parameters:
    ///   - room: 房间对象
    /// - Throws: GlobalError 当启动失败时
    internal func startNetwork(room: EasyTierRoom) async throws {
        // 如果已有连接，先断开
        if currentRoom != nil {
            await stopNetwork()
        }

        // 构建命令参数
        let arguments: [String] = [
            "-d",  // 自动分配虚拟 IP
            "--network-name", room.networkName,
            "--network-secret", room.networkSecret,
            "--hostname", room.hostName,
            "-p", publicServer,
        ]

        Logger.shared.info("启动 EasyTier 网络: \(room.roomCode)")
        Logger.shared.debug("命令: \(AppPaths.easytierCorePath) \(arguments.joined(separator: " "))")

        // 更新房间状态
        var updatedRoom = room
        updatedRoom.status = .connecting

        // 在执行连接之前，确保 EasyTier core 和 cli 文件已下载并安装
        await EasyTierDownloadManager.shared.downloadEasyTier()

        // 使用管理员权限执行命令
        do {
            let pid = try await executeWithAdminPrivileges(
                executable: AppPaths.easytierCorePath,
                arguments: arguments
            )

            // executeWithAdminPrivileges 已经验证了进程是否运行，如果失败会抛出异常
            // 所以这里直接使用返回的 PID
            updatedRoom.processID = pid

            // 等待网络初始化，然后检查是否有合法的联机中心
            try await Task.sleep(nanoseconds: 2_000_000_000) // 等待2秒让网络初始化

            // 检查网络中是否有合法的联机中心
            try await verifyConnectionCenterExists()

            updatedRoom.status = .connected
            currentRoom = updatedRoom
            Logger.shared.info("EasyTier 网络启动成功，PID: \(pid)")
        } catch {
            Logger.shared.error("启动 EasyTier 时发生异常: \(error.localizedDescription)")
            updatedRoom.status = .error(error.localizedDescription)
            throw error
        }
    }

    /// 停止 EasyTier 网络
    func stopNetwork() async {
        guard let room = currentRoom else {
            return
        }

        Logger.shared.info("停止 EasyTier 网络: \(room.roomCode)")

        // 通过 PID 使用 kill -9 终止进程（使用管理员权限）
        if let pid = room.processID {
            do {
                try await executeKillWithAdminPrivileges(pid: pid)
                Logger.shared.debug("使用管理员权限终止进程 PID: \(pid)")
            } catch {
                Logger.shared.warning("终止进程失败: \(error.localizedDescription)")
            }
        }

        // 清理 Process 对象引用
        currentProcess = nil

        // 更新状态
        currentRoom?.status = .disconnected
        currentRoom = nil

        Logger.shared.info("EasyTier 网络已停止")
    }

    /// 获取当前网络状态
    /// - Returns: 当前房间的网络状态，如果没有活动房间则返回 nil
    func getNetworkStatus() -> EasyTierNetworkStatus? {
        return currentRoom?.status
    }

    /// 获取当前房间码
    /// - Returns: 当前房间码，如果没有活动房间则返回 nil
    func getCurrentRoomCode() -> String? {
        return currentRoom?.roomCode
    }

    /// 查询对等节点列表
    /// - Returns: 对等节点列表
    /// - Throws: GlobalError 当查询失败时
    func queryPeers() async throws -> [EasyTierPeer] {
        // 检查 easytier-cli 是否存在
        guard FileManager.default.fileExists(atPath: AppPaths.easytierCliPath) else {
            throw GlobalError.resource(
                chineseMessage: "EasyTier CLI 程序不存在: \(AppPaths.easytierCliPath)",
                i18nKey: "error.resource.easytier_cli_not_found",
                level: .notification
            )
        }

        // 确保有执行权限
        try ensureExecutablePermissions(at: AppPaths.easytierCliPath)

        // 执行命令
        let process = Process()
        process.executableURL = URL(fileURLWithPath: AppPaths.easytierCliPath)
        process.arguments = ["peer"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            // 读取输出
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            // 读取错误输出
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

            // 检查进程退出状态
            if process.terminationStatus != 0 {
                Logger.shared.error("easytier-cli peer 执行失败，退出码: \(process.terminationStatus)，错误: \(errorOutput)")
                throw GlobalError.configuration(
                    chineseMessage: "查询对等节点失败: \(errorOutput.isEmpty ? "未知错误" : errorOutput)",
                    i18nKey: "error.configuration.query_peers_failed",
                    level: .notification
                )
            }

            // 解析输出
            return parsePeerOutput(output)
        } catch {
            if error is GlobalError {
                throw error
            }
            Logger.shared.error("执行 easytier-cli peer 时发生异常: \(error.localizedDescription)")
            throw GlobalError.configuration(
                chineseMessage: "执行查询命令失败: \(error.localizedDescription)",
                i18nKey: "error.configuration.query_peers_execution_failed",
                level: .notification
            )
        }
    }

    /// 解析对等节点输出
    /// - Parameter output: easytier-cli peer 命令的输出
    /// - Returns: 对等节点列表
    private func parsePeerOutput(_ output: String) -> [EasyTierPeer] {
        let lines = output.components(separatedBy: .newlines)
        var peers: [EasyTierPeer] = []

        for line in lines {
            // 跳过空行和表头分隔行（包含 - 的行）
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("|") == false || trimmed.contains("---") {
                continue
            }

            // 跳过表头
            if trimmed.contains("ipv4") || trimmed.contains("IPv4") {
                continue
            }

            // 解析对等节点信息
            if let peer = EasyTierPeer(fromTableLine: trimmed) {
                peers.append(peer)
            }
        }

        return peers
    }

    // MARK: - Private Helpers

    /// 使用管理员权限执行命令
    /// - Parameters:
    ///   - executable: 可执行文件路径
    ///   - arguments: 命令参数
    /// - Returns: 进程 PID
    /// - Throws: GlobalError 当执行失败时
    private func executeWithAdminPrivileges(executable: String, arguments: [String]) async throws -> Int32 {
        // 检查授权引用
        guard let authRef = authRef else {
            throw GlobalError.configuration(
                chineseMessage: "授权引用未初始化",
                i18nKey: "error.configuration.authorization_failed",
                level: .popup
            )
        }

        // 请求管理员权限
        let rightName = kAuthorizationRightExecute
        // Use withCString to get a pointer that's valid for the duration of the call
        let status = rightName.withCString { namePointer -> OSStatus in
            var authItem = AuthorizationItem(
                name: UnsafeMutablePointer(mutating: namePointer),
                valueLength: 0,
                value: nil,
                flags: 0
            )
            return withUnsafeMutablePointer(to: &authItem) { itemPointer -> OSStatus in
                var authRights = AuthorizationRights(count: 1, items: itemPointer)
                let authFlags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]
                return AuthorizationCopyRights(authRef, &authRights, nil, authFlags, nil)
            }
        }
        guard status == errAuthorizationSuccess else {
            if status == errAuthorizationCanceled {
                throw GlobalError.configuration(
                    chineseMessage: "用户取消了管理员权限请求",
                    i18nKey: "error.configuration.authorization_denied",
                    level: .popup
                )
            }
            throw GlobalError.configuration(
                chineseMessage: "授权失败: \(status)",
                i18nKey: "error.configuration.authorization_failed",
                level: .popup
            )
        }

        Logger.shared.debug("执行管理员命令: \(executable) \(arguments.joined(separator: " "))")

        // 创建临时脚本文件
        let tempScript = createTempScript(executablePath: executable, arguments: arguments)
        defer {
            try? FileManager.default.removeItem(at: tempScript)
        }

        // 使用 osascript 执行脚本（需要管理员权限）
        // 注意：AuthorizationExecuteWithPrivileges 在 macOS 10.9 之后已废弃
        // 因此使用 osascript 的 with administrator privileges，但我们已经通过 Authorization API 请求了权限
        do {
            // 创建输出文件用于检查进程是否成功启动
            let tempDir = FileManager.default.temporaryDirectory
            let outputFile = tempDir.appendingPathComponent("easytier_output_\(UUID().uuidString).log")
            defer {
                try? FileManager.default.removeItem(at: outputFile)
            }

            // 创建带输出文件的脚本
            let scriptWithOutput = createScriptWithOutput(scriptURL: tempScript, outputFile: outputFile)
            defer {
                try? FileManager.default.removeItem(at: scriptWithOutput)
            }

            try await executeScript(at: scriptWithOutput)

            // 等待进程启动并检查输出，最多等待 10 秒（每 0.5 秒检查一次）
            var processStarted = false
            for _ in 0..<20 {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒

                // 检查输出文件是否包含成功标志
                if let outputContent = try? String(contentsOf: outputFile, encoding: .utf8),
                   outputContent.contains("tun device ready") {
                    processStarted = true
                    Logger.shared.debug("检测到进程启动成功：tun device ready")
                    break
                }
            }

            if !processStarted {
                // 检查输出文件内容，提供更多错误信息
                if let outputContent = try? String(contentsOf: outputFile, encoding: .utf8), !outputContent.isEmpty {
                    Logger.shared.debug("进程输出: \(outputContent)")
                }
                Logger.shared.warning("未检测到 tun device ready，但继续查找进程 PID")
            }

            // 通过进程名查找 PID
            let pid = try await findProcessID(executableName: "easytier-core")

            guard let processID = pid else {
                // 如果没找到 PID，但检测到成功标志，再等待一下重试
                if processStarted {
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 再等待1秒
                    if let retryPid = try await findProcessID(executableName: "easytier-core") {
                        Logger.shared.debug("找到进程 PID: \(retryPid)")
                        return retryPid
                    }
                }

                Logger.shared.error("无法找到进程 PID")
                throw GlobalError.configuration(
                    chineseMessage: "无法找到进程 PID",
                    i18nKey: "error.configuration.process_start_failed",
                    level: .popup
                )
            }

            Logger.shared.debug("找到进程 PID: \(processID)")
            return processID
        } catch {
            if error is GlobalError {
                throw error
            }
            Logger.shared.error("执行管理员命令时发生异常: \(error.localizedDescription)")
            throw GlobalError.configuration(
                chineseMessage: "执行管理员命令失败: \(error.localizedDescription)",
                i18nKey: "error.configuration.process_start_failed",
                level: .popup
            )
        }
    }

    /// 创建临时脚本文件
    /// - Parameters:
    ///   - executablePath: 可执行文件路径
    ///   - arguments: 命令参数
    /// - Returns: 脚本文件的 URL
    private func createTempScript(executablePath: String, arguments: [String]) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let scriptURL = tempDir.appendingPathComponent("run_easytier_\(UUID().uuidString).sh")

        // 转义参数
        let escapedPath = executablePath.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedArgs = arguments
            .map { arg in
                "\"\(arg.replacingOccurrences(of: "\"", with: "\\\""))\""
            }
            .joined(separator: " ")

        // 让命令在后台运行（不使用 nohup，因为在 osascript 环境中 nohup 无法工作）
        let scriptContent = """
        #!/bin/bash
        "\(escapedPath)" \(escapedArgs) > /dev/null 2>&1 &
        """

        try? scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        return scriptURL
    }

    /// 创建带输出文件的脚本
    /// - Parameters:
    ///   - scriptURL: 原始脚本文件的 URL
    ///   - outputFile: 输出文件的 URL
    /// - Returns: 新脚本文件的 URL
    private func createScriptWithOutput(scriptURL: URL, outputFile: URL) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let newScriptURL = tempDir.appendingPathComponent("run_easytier_output_\(UUID().uuidString).sh")

        // 读取原始脚本内容
        guard let originalContent = try? String(contentsOf: scriptURL, encoding: .utf8) else {
            return scriptURL
        }

        // 替换输出重定向到文件（将 > /dev/null 2>&1 替换为 > outputFile 2>&1）
        // 同时移除 nohup（因为在使用 osascript 时 nohup 无法工作）
        let escapedOutputFile = outputFile.path.replacingOccurrences(of: "\"", with: "\\\"")
        var newContent = originalContent.replacingOccurrences(
            of: "> /dev/null 2>&1",
            with: "> \"\(escapedOutputFile)\" 2>&1"
        )
        // 移除 nohup（在 osascript 环境中 nohup 无法工作）
        newContent = newContent.replacingOccurrences(of: "nohup ", with: "")

        try? newContent.write(to: newScriptURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: newScriptURL.path)

        return newScriptURL
    }

    /// 使用管理员权限执行 AppleScript 命令（通用方法）
    /// - Parameters:
    ///   - script: AppleScript 源代码
    ///   - successMessage: 成功时的日志消息
    ///   - failureMessage: 失败时的日志消息
    /// - Returns: 执行是否成功
    private func executeAppleScript(
        script: String,
        successMessage: String? = nil,
        failureMessage: String? = nil
    ) async -> (success: Bool, errorMessage: String?) {
        return await Task.detached(priority: .utility) {
            let appleScript = NSAppleScript(source: script)
            var error: NSDictionary?

            if appleScript?.executeAndReturnError(&error) != nil {
                if let message = successMessage {
                    Logger.shared.debug(message)
                }
                return (true, nil)
            }

            let errorMessage = error?[NSAppleScript.errorMessage] as? String ?? "未知错误"
            if let message = failureMessage {
                Logger.shared.warning(message + ": \(errorMessage)")
            } else {
                Logger.shared.error("AppleScript 执行失败: \(errorMessage)")
            }
            return (false, errorMessage)
        }.value
    }

    private func executeScript(at scriptURL: URL) async throws {
        let appleScript = """
        do shell script "\(scriptURL.path)" with administrator privileges
        """

        let result = await executeAppleScript(script: appleScript)

        guard result.success else {
            let errorMessage = result.errorMessage ?? "未知错误"

            if errorMessage.contains("User canceled")
                || errorMessage.contains("canceled")
                || errorMessage.contains("取消") {
                throw GlobalError.configuration(
                    chineseMessage: "用户取消了管理员权限请求",
                    i18nKey: "error.configuration.authorization_denied",
                    level: .popup
                )
            }

            throw GlobalError.configuration(
                chineseMessage: "脚本执行失败: \(errorMessage)",
                i18nKey: "error.configuration.process_start_failed",
                level: .popup
            )
        }

        Logger.shared.debug("脚本执行成功")
    }

    /// 使用管理员权限执行 kill 命令
    /// - Parameter pid: 进程 ID
    /// - Throws: GlobalError 当执行失败时
    private func executeKillWithAdminPrivileges(pid: Int32) async throws {
        let appleScript = """
        do shell script "kill -9 \(pid)" with administrator privileges
        """

        _ = await executeAppleScript(
            script: appleScript,
            successMessage: "使用管理员权限终止进程成功，PID: \(pid)",
            failureMessage: "使用管理员权限终止进程失败"
        )
        // kill -9 进程不存在是可接受情况，不抛异常
    }

    /// 使用管理员权限执行 killall 命令
    /// - Throws: GlobalError 当执行失败时
    private func executeKillallWithAdminPrivileges() async throws {
        let appleScript = """
        do shell script "killall -9 easytier-core" with administrator privileges
        """

        _ = await executeAppleScript(
            script: appleScript,
            successMessage: "使用管理员权限清理进程成功",
            failureMessage: "使用管理员权限清理进程（进程可能已不存在）"
        )
    }

    /// 验证网络中是否存在合法的联机中心
    /// 合法的联机中心主机名格式：scaffolding-mc-server-{port}，其中 1024 < port <= 65535
    /// - Throws: GlobalError 当找不到合法的联机中心时
    private func verifyConnectionCenterExists() async throws {
        // 最多尝试5次，每次间隔1秒
        for attempt in 1...5 {
            do {
                let peers = try await queryPeers()

                // 查找匹配的主机名（需要完全匹配 scaffolding-mc-server-{port} 格式）
                let validCenters = peers.filter { peer in
                    // 检查 hostname 是否匹配 scaffolding-mc-server-{port} 格式
                    if peer.hostname.hasPrefix("scaffolding-mc-server-") {
                        let suffix = String(peer.hostname.dropFirst("scaffolding-mc-server-".count))
                        // 检查后缀是否为合法的端口号（1024 < port <= 65535）
                        if let port = UInt16(suffix), port > 1024 && port <= 65535 {
                            return true
                        }
                    }
                    return false
                }

                if !validCenters.isEmpty {
                    Logger.shared.info("找到合法的联机中心: \(validCenters.map { $0.hostname }.joined(separator: ", "))")
                    return
                }

                // 如果还没找到，等待一下再重试
                if attempt < 5 {
                    Logger.shared.debug("未找到合法的联机中心，等待重试（尝试 \(attempt)/5）...")
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 等待1秒
                }
            } catch {
                // 如果查询失败，也等待一下再重试
                if attempt < 5 {
                    Logger.shared.warning("查询对等节点失败，等待重试（尝试 \(attempt)/5）: \(error.localizedDescription)")
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } else {
                    throw error
                }
            }
        }

        // 如果5次尝试都失败，停止网络并抛出错误
        Logger.shared.error("联机中心发现失败：未找到合法的联机中心（hostname 格式：scaffolding-mc-server-{port}，port: 1024 < port <= 65535）")
        await stopNetwork()

        throw GlobalError.configuration(
            chineseMessage: "联机中心发现失败：未找到合法的联机中心。请确保网络中有符合 scaffolding-mc-server-{端口} 格式的联机中心（端口范围：1024 < 端口 <= 65535）。",
            i18nKey: "error.configuration.connection_center_not_found",
            level: .popup
        )
    }

    /// 通过进程名查找进程 ID
    /// - Parameter executableName: 可执行文件名
    /// - Returns: 进程 ID，如果未找到则返回 nil
    private func findProcessID(executableName: String) async throws -> Int32? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", executableName]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        // pgrep 如果没找到进程会返回非零状态码，这是正常的
        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let pidString = output.trimmingCharacters(in: .whitespacesAndNewlines)

        // 如果有多个进程，取第一个
        if let firstLine = pidString.components(separatedBy: .newlines).first,
           let pid = Int32(firstLine) {
            return pid
        }

        return nil
    }

    // MARK: - Progress Callback Methods

    /// 设置进度回调
    func setProgressCallback(_ callback: @escaping (String, Int, Int) -> Void) {
        Task {
            await progressActor.setCallback(callback)
        }
    }

    /// 设置取消检查回调
    func setCancelCallback(_ callback: @escaping () -> Bool) {
        Task {
            await cancelActor.setCallback(callback)
        }
    }

    // MARK: - Download Methods

    /// 下载并安装 EasyTier core 和 cli 文件
    /// - Throws: GlobalError 当下载或安装失败时
    func downloadAndInstallEasyTier() async throws {
        let fileManager = FileManager.default

        // 检查文件是否已存在
        let corePath = AppPaths.easytierCorePath
        let cliPath = AppPaths.easytierCliPath

        if fileManager.fileExists(atPath: corePath) && fileManager.fileExists(atPath: cliPath) {
            Logger.shared.info("EasyTier core 和 cli 文件已存在，跳过下载")
            // 确保文件有执行权限
            try ensureExecutablePermissions(at: corePath)
            try ensureExecutablePermissions(at: cliPath)
            return
        }

        // 根据架构选择正确的架构名称
        let arch = Architecture.current.javaArch

        // 通过 GitHub API 获取最新版本
        let latestReleaseURL = URLConfig.API.GitHub.easyTierLatestRelease()
        let releaseData = try await APIClient.get(url: latestReleaseURL)
        let release = try JSONDecoder().decode(GitHubRelease.self, from: releaseData)
        let version = release.tagName // 例如 "v2.5.0"

        // 构建下载 URL
        let downloadURL = URLConfig.API.GitHub.easyTierDownloadURL(version: version, architecture: arch)
        let zipFileName = "easytier-macos-\(arch)-\(version).zip"

        Logger.shared.info("开始下载 EasyTier: \(zipFileName)")

        // 创建临时目录
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("easytier_download_\(UUID().uuidString)")
        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // 下载 zip 文件到临时位置
        let zipFileURL = tempDir.appendingPathComponent(zipFileName)

        // 获取文件大小
        let fileSize = try await getFileSize(from: downloadURL)

        // 设置初始进度
        await progressActor.callProgressUpdate(zipFileName, 0, Int(fileSize))

        // 创建进度跟踪器
        let progressCallback: (Int64, Int64) -> Void = { [progressActor] downloadedBytes, totalBytes in
            Task {
                await progressActor.callProgressUpdate(zipFileName, Int(downloadedBytes), Int(totalBytes))
            }
        }
        let progressTracker = EasyTierDownloadProgressTracker(totalSize: fileSize, progressCallback: progressCallback)

        // 创建 URLSession 配置
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: progressTracker, delegateQueue: nil)

        // 使用 downloadTask 方式下载，配合进度回调
        do {
            try await downloadZipWithProgress(
                session: session,
                from: downloadURL,
                to: zipFileURL,
                progressTracker: progressTracker
            )
        } catch {
            Logger.shared.error("下载 EasyTier zip 文件失败: \(error.localizedDescription)")
            if error is GlobalError {
                throw error
            }
            throw GlobalError.download(
                chineseMessage: "下载 EasyTier 失败: \(error.localizedDescription)",
                i18nKey: "error.download.general_failure",
                level: .popup
            )
        }

        // 解压 zip 文件并提取 core 和 cli
        Logger.shared.info("开始解压 EasyTier zip 文件")

        let extractDir = tempDir.appendingPathComponent("extracted")
        try fileManager.createDirectory(at: extractDir, withIntermediateDirectories: true)

        let archive: Archive
        do {
            archive = try Archive(url: zipFileURL, accessMode: .read)
        } catch {
            throw GlobalError.fileSystem(
                chineseMessage: "无法打开 zip 文件: \(error.localizedDescription)",
                i18nKey: "error.filesystem.zip_open_failed",
                level: .popup
            )
        }

        // 查找 easytier-core 和 easytier-cli 文件
        var coreEntry: Entry?
        var cliEntry: Entry?

        for entry in archive {
            // 只查找文件，跳过目录
            guard entry.type == .file else {
                continue
            }

            let entryPath = entry.path
            let fileName = (entryPath as NSString).lastPathComponent

            // 精确匹配文件名
            if fileName == "easytier-core" {
                coreEntry = entry
            } else if fileName == "easytier-cli" {
                cliEntry = entry
            }
        }

        guard let core = coreEntry, let cli = cliEntry else {
            throw GlobalError.fileSystem(
                chineseMessage: "zip 文件中未找到 easytier-core 或 easytier-cli",
                i18nKey: "error.filesystem.easytier_files_not_found",
                level: .popup
            )
        }

        // 解压 core 文件
        let tempCorePath = extractDir.appendingPathComponent("easytier-core")
        _ = try archive.extract(core, to: tempCorePath)

        // 解压 cli 文件
        let tempCliPath = extractDir.appendingPathComponent("easytier-cli")
        _ = try archive.extract(cli, to: tempCliPath)

        // 创建目标目录
        let coreDir = AppPaths.easytierCoreDirectory
        try fileManager.createDirectory(at: coreDir, withIntermediateDirectories: true)

        // 移动文件到目标位置
        let finalCorePath = URL(fileURLWithPath: corePath)
        let finalCliPath = URL(fileURLWithPath: cliPath)

        // 使用 replaceItem 原子性地替换已存在的文件，如果不存在则使用 moveItem
        if fileManager.fileExists(atPath: finalCorePath.path) {
            try fileManager.replaceItem(at: finalCorePath, withItemAt: tempCorePath, backupItemName: nil, options: [], resultingItemURL: nil)
        } else {
            try fileManager.moveItem(at: tempCorePath, to: finalCorePath)
        }

        if fileManager.fileExists(atPath: finalCliPath.path) {
            try fileManager.replaceItem(at: finalCliPath, withItemAt: tempCliPath, backupItemName: nil, options: [], resultingItemURL: nil)
        } else {
            try fileManager.moveItem(at: tempCliPath, to: finalCliPath)
        }

        // 设置执行权限
        try ensureExecutablePermissions(at: corePath)
        try ensureExecutablePermissions(at: cliPath)

        Logger.shared.info("EasyTier core 和 cli 下载并安装成功")
    }
}
