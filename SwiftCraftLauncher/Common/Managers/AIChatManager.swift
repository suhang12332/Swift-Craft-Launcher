//
//  AIChatManager.swift
//  SwiftCraftLauncher
//
//  Created by AI Assistant
//

import Foundation
import SwiftUI

@MainActor
class AIChatManager: ObservableObject {
    static let shared = AIChatManager()

    private let settings = AISettingsManager.shared
    private var urlSession: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300
        self.urlSession = URLSession(configuration: configuration)
    }

    // MARK: - 发送消息

    /// 发送消息
    func sendMessage(_ text: String, attachments: [MessageAttachmentType] = [], chatState: ChatState) async {
        guard !settings.apiKey.isEmpty else {
            let error = GlobalError.configuration(
                chineseMessage: "AI 服务未配置，请检查 API Key",
                i18nKey: "error.configuration.ai_service_not_configured",
                level: .notification
            )
            Logger.shared.error("AI 服务未配置，请检查 API Key")
            await MainActor.run {
                chatState.isSending = false
                GlobalErrorHandler.shared.handle(error)
            }
            return
        }

        guard !settings.getModel().isEmpty else {
            let error = GlobalError.configuration(
                chineseMessage: "AI 模型未配置，请在设置中填写模型名称",
                i18nKey: "error.configuration.ai_model_not_configured",
                level: .notification
            )
            Logger.shared.error("AI 模型未配置，请在设置中填写模型名称")
            await MainActor.run {
                chatState.isSending = false
                GlobalErrorHandler.shared.handle(error)
            }
            return
        }

        // 添加用户消息
        let userMessage = ChatMessage(
            role: .user,
            content: text,
            attachments: attachments
        )
        await MainActor.run {
            chatState.addMessage(userMessage)

            // 添加空的助手消息用于流式更新
            let assistantMessage = ChatMessage(role: .assistant, content: "")
            chatState.addMessage(assistantMessage)
            chatState.isSending = true
        }

        // 构建消息历史
        let historyMessages = chatState.messages.dropLast(2)
        var allMessages: [ChatMessage] = Array(historyMessages)
        allMessages.append(userMessage)

        do {
            switch settings.selectedProvider.apiFormat {
            case .openAI:
                try await sendOpenAIMessage(messages: allMessages, chatState: chatState)
            case .ollama:
                try await sendOllamaMessage(messages: allMessages, chatState: chatState)
//            case .gemini:
//                try await sendGeminiMessage(messages: allMessages, chatState: chatState)
            }
        } catch {
            Logger.shared.error("发送消息失败: \(error.localizedDescription)")
            await MainActor.run {
                chatState.isSending = false

                if let globalError = error as? GlobalError {
                    GlobalErrorHandler.shared.handle(globalError)
                    // 在消息中显示错误
                    if let lastIndex = chatState.messages.indices.last {
                        let userFriendlyMessage = globalError.localizedDescription
                        chatState.messages[lastIndex].content = userFriendlyMessage
                    }
                } else {
                    // 其他错误转换为 GlobalError
                    let globalError = GlobalError.network(
                        chineseMessage: error.localizedDescription,
                        i18nKey: "error.network.ai_request_failed",
                        level: .notification
                    )
                    GlobalErrorHandler.shared.handle(globalError)
                    // 在消息中显示错误
                    if let lastIndex = chatState.messages.indices.last {
                        let userFriendlyMessage = globalError.localizedDescription
                        chatState.messages[lastIndex].content = userFriendlyMessage
                    }
                }
            }
        }
    }

    // MARK: - OpenAI 格式（兼容 DeepSeek 等）

    private func sendOpenAIMessage(messages: [ChatMessage], chatState: ChatState) async throws {
        let apiURL = settings.getAPIURL()
        guard let url = URL(string: apiURL) else {
            throw GlobalError.network(
                chineseMessage: "无效的 API URL",
                i18nKey: "error.network.invalid_url",
                level: .notification
            )
        }

        // 构建请求体
        let requestBody: [String: Any] = [
            "model": settings.getModel(),
            "stream": true,
            "messages": try await buildOpenAIMessages(messages: messages),
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = jsonData

        // 发送流式请求
        let (asyncBytes, response) = try await urlSession.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GlobalError.network(
                chineseMessage: "无效的 HTTP 响应",
                i18nKey: "error.network.invalid_response",
                level: .notification
            )
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorData = try await asyncBytes.reduce(into: Data()) { $0.append($1) }
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "未知错误"
            throw GlobalError.network(
                chineseMessage: "API 错误: \(errorMessage)",
                i18nKey: "error.network.api_error",
                level: .notification
            )
        }

        // 处理流式响应（SSE 格式）
        var accumulatedContent = ""

        for try await line in asyncBytes.lines {
            guard !line.isEmpty else { continue }

            // OpenAI 流式响应格式：data: {...}
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                if jsonString == "[DONE]" {
                    break
                }

                guard !jsonString.isEmpty,
                      let jsonData = jsonString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let delta = firstChoice["delta"] as? [String: Any],
                      let content = delta["content"] as? String else {
                    continue
                }

                accumulatedContent += content
                await MainActor.run {
                    chatState.updateLastMessage(accumulatedContent)
                }
            }
        }

        await MainActor.run {
            chatState.isSending = false
        }
    }

    /// 构建 OpenAI 格式的消息数组
    private func buildOpenAIMessages(messages: [ChatMessage]) async throws -> [[String: Any]] {
        var apiMessages: [[String: Any]] = []

        for message in messages {
            var messageDict: [String: Any] = [
                "role": message.apiRoleString
            ]

            // 处理文本内容和文件附件
            var contentParts: [String] = []

            if !message.content.isEmpty {
                contentParts.append(message.content)
            }

            // 处理文件附件（跳过图片）
            for attachment in message.attachments {
                if case .file(let url, let fileName) = attachment {
                    let fileText = await processFile(url: url, fileName: fileName)
                    contentParts.append(fileText)
                }
                // 忽略图片附件
            }

            if contentParts.isEmpty {
                messageDict["content"] = ""
            } else if contentParts.count == 1 {
                messageDict["content"] = contentParts[0]
            } else {
                messageDict["content"] = contentParts.joined(separator: "\n\n")
            }

            apiMessages.append(messageDict)
        }

        return apiMessages
    }

    // MARK: - Ollama 格式

    private func sendOllamaMessage(messages: [ChatMessage], chatState: ChatState) async throws {
        let baseURL = settings.selectedProvider == .ollama
            ? (settings.ollamaBaseURL.isEmpty ? settings.selectedProvider.baseURL : settings.ollamaBaseURL)
            : settings.selectedProvider.baseURL
        let apiURL = baseURL + settings.selectedProvider.apiPath

        guard let url = URL(string: apiURL) else {
            throw GlobalError.network(
                chineseMessage: "无效的 API URL",
                i18nKey: "error.network.invalid_url",
                level: .notification
            )
        }

        // 构建请求体
        let requestBody: [String: Any] = [
            "model": settings.getModel(),
            "stream": true,
            "messages": try await buildOllamaMessages(messages: messages),
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Ollama 可能不需要 API Key，但如果有就加上
        if !settings.apiKey.isEmpty {
            request.setValue(settings.apiKey, forHTTPHeaderField: "Authorization")
        }

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = jsonData

        // 发送流式请求
        let (asyncBytes, response) = try await urlSession.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GlobalError.network(
                chineseMessage: "无效的 HTTP 响应",
                i18nKey: "error.network.invalid_response",
                level: .notification
            )
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorData = try await asyncBytes.reduce(into: Data()) { $0.append($1) }
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "未知错误"
            throw GlobalError.network(
                chineseMessage: "API 错误: \(errorMessage)",
                i18nKey: "error.network.api_error",
                level: .notification
            )
        }

        // 处理流式响应
        var accumulatedContent = ""
        for try await line in asyncBytes.lines {
            guard !line.isEmpty,
                  let jsonData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                continue
            }

            // Ollama 流式响应格式：{"message": {"content": "..."}, "done": false}
            if let message = json["message"] as? [String: Any],
               let content = message["content"] as? String {
                accumulatedContent += content
                await MainActor.run {
                    chatState.updateLastMessage(accumulatedContent)
                }
            }

            if let done = json["done"] as? Bool, done {
                break
            }
        }

        await MainActor.run {
            chatState.isSending = false
        }
    }

    /// 构建 Ollama 格式的消息数组
    private func buildOllamaMessages(messages: [ChatMessage]) async throws -> [[String: Any]] {
        var apiMessages: [[String: Any]] = []

        for message in messages {
            var messageDict: [String: Any] = [
                "role": message.apiRoleString
            ]

            // 处理文本内容和文件附件
            var contentParts: [String] = []

            if !message.content.isEmpty {
                contentParts.append(message.content)
            }

            // 处理文件附件（跳过图片）
            for attachment in message.attachments {
                if case .file(let url, let fileName) = attachment {
                    let fileText = await processFile(url: url, fileName: fileName)
                    contentParts.append(fileText)
                }
                // 忽略图片附件
            }

            if contentParts.isEmpty {
                messageDict["content"] = ""
            } else {
                messageDict["content"] = contentParts.joined(separator: "\n\n")
            }

            apiMessages.append(messageDict)
        }

        return apiMessages
    }

    // MARK: - Gemini 格式

    private func sendGeminiMessage(messages: [ChatMessage], chatState: ChatState) async throws {
        let model = settings.getModel()
        // Gemini API 需要将 key 作为查询参数
        let apiURL = "\(settings.selectedProvider.baseURL)/v1/models/\(model):streamGenerateContent?key=\(settings.apiKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? settings.apiKey)"

        guard let url = URL(string: apiURL) else {
            throw GlobalError.network(
                chineseMessage: "无效的 API URL",
                i18nKey: "error.network.invalid_url",
                level: .notification
            )
        }

        // 构建请求体
        let requestBody: [String: Any] = [
            "contents": try await buildGeminiContents(messages: messages)
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = jsonData

        // 发送流式请求
        let (asyncBytes, response) = try await urlSession.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GlobalError.network(
                chineseMessage: "无效的 HTTP 响应",
                i18nKey: "error.network.invalid_response",
                level: .notification
            )
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorData = try await asyncBytes.reduce(into: Data()) { $0.append($1) }
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "未知错误"
            throw GlobalError.network(
                chineseMessage: "API 错误: \(errorMessage)",
                i18nKey: "error.network.api_error",
                level: .notification
            )
        }

        // 处理流式响应
        var accumulatedContent = ""
        for try await line in asyncBytes.lines {
            guard !line.isEmpty,
                  let jsonData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let firstPart = parts.first,
                  let text = firstPart["text"] as? String else {
                continue
            }

            accumulatedContent += text
            await MainActor.run {
                chatState.updateLastMessage(accumulatedContent)
            }
        }

        await MainActor.run {
            chatState.isSending = false
        }
    }

    /// 构建 Gemini 格式的内容数组
    private func buildGeminiContents(messages: [ChatMessage]) async throws -> [[String: Any]] {
        var contents: [[String: Any]] = []

        for message in messages {
            var parts: [[String: Any]] = []

            // 处理文本内容
            if !message.content.isEmpty {
                parts.append(["text": message.content])
            }

            // 处理文件附件
            for attachment in message.attachments {
                if case .file(let url, let fileName) = attachment {
                    let fileText = await processFile(url: url, fileName: fileName)
                    parts.append(["text": fileText])
                }
            }

            guard !parts.isEmpty else { continue }

            var contentDict: [String: Any] = [
                "parts": parts
            ]

            // 设置角色（Gemini 使用 "user" 和 "model"）
            if message.role == .assistant {
                contentDict["role"] = "model"
            } else {
                contentDict["role"] = "user"
            }

            contents.append(contentDict)
        }

        return contents
    }

    // MARK: - 文件处理

    /// 处理文件：读取文本内容
    private func processFile(url: URL, fileName: String) async -> String {
        // 文件大小阈值：100KB
        let maxFileSizeForReading: Int64 = 100_000

        // 获取文件大小
        guard let fileSize = await getFileSize(url: url) else {
            return await readFileContent(url: url, fileName: fileName) ??
                   String(format: "ai.file.cannot_read".localized(), fileName)
        }

        // 根据大小决定处理方式
        if fileSize <= maxFileSizeForReading {
            // 小文件：读取文本内容
            return await readFileContent(url: url, fileName: fileName) ??
                   String(format: "ai.file.cannot_read_text".localized(), fileName)
        } else {
            // 大文件：返回文件信息
            let sizeDescription = formatFileSize(fileSize)
            return String(format: "ai.file.too_large".localized(), fileName, sizeDescription)
        }
    }

    /// 读取文件内容（小文件）
    private func readFileContent(url: URL, fileName: String) async -> String? {
        guard let fileContent = await loadFileAsText(url: url) else { return nil }

        let maxLength = 5000
        // 使用字符串插值而非字符串拼接
        let truncatedContent = fileContent.count > maxLength
            ? "\(String(fileContent.prefix(maxLength)))\n... \("ai.file.content_truncated".localized())"
            : fileContent

        return String(format: "ai.file.content".localized(), fileName, truncatedContent)
    }

    /// 获取文件大小（字节）
    private func getFileSize(url: URL) async -> Int64? {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return nil
        }
        return size
    }

    /// 格式化文件大小
    private func formatFileSize(_ bytes: Int64) -> String {
        let sizeInKB = Double(bytes) / 1024.0
        if sizeInKB < 1024 {
            return String(format: "%.1f KB", sizeInKB)
        } else {
            let sizeInMB = sizeInKB / 1024.0
            return String(format: "%.2f MB", sizeInMB)
        }
    }

    /// 将文件加载为文本
    private func loadFileAsText(url: URL) async -> String? {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }

        return try? String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - 打开聊天窗口

    /// 打开聊天窗口
    func openChatWindow() {
        let chatState = ChatState()
        // 存储到 WindowDataStore
        WindowDataStore.shared.aiChatState = chatState
        // 打开窗口
        WindowManager.shared.openWindow(id: .aiChat)
    }
}
