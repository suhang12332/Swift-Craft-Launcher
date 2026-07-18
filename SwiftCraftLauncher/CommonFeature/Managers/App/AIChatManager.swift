//
//  AIChatManager.swift
//  CommonFeature
//
//  Manages AI chat interactions including message sending and streaming responses.
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

@MainActor
class AIChatManager: ObservableObject {
    init() { }

    /// Sends a message to the AI service and streams the response.
    /// - Parameters:
    ///   - text: The message text to send.
    ///   - attachments: File attachments to include with the message.
    ///   - chatState: The current chat state to update.
    func sendMessage(_ text: String, attachments: [MessageAttachmentType] = [], chatState: ChatState) async {
        guard !DIContainer.shared.ui.aiSettingsManager.apiKey.isEmpty else {
            let error = GlobalError.configuration(
                i18nKey: "error.configuration.ai_service_not_configured",
                level: .notification,
                message: "AI service API key is empty",
            )
            await MainActor.run {
                chatState.isSending = false
                DIContainer.shared.core.errorHandler.handle(error)
            }
            return
        }

        guard !DIContainer.shared.ui.aiSettingsManager.getModel().isEmpty else {
            let error = GlobalError.configuration(
                i18nKey: "error.configuration.ai_model_not_configured",
                level: .notification,
                message: "AI model is empty for provider \(DIContainer.shared.ui.aiSettingsManager.selectedProvider.rawValue)",
            )
            await MainActor.run {
                chatState.isSending = false
                DIContainer.shared.core.errorHandler.handle(error)
            }
            return
        }

        let userMessage = ChatMessage(
            role: .user,
            content: text,
            attachments: attachments,
        )
        await MainActor.run {
            chatState.addMessage(userMessage)

            let assistantMessage = ChatMessage(role: .assistant, content: "")
            chatState.addMessage(assistantMessage)
            chatState.isSending = true
        }

        let historyMessages = chatState.messages.dropLast(2)
        var allMessages: [ChatMessage] = Array(historyMessages)
        allMessages.append(userMessage)

        do {
            switch DIContainer.shared.ui.aiSettingsManager.selectedProvider.apiFormat {
            case .openAI:
                try await sendOpenAIMessage(messages: allMessages, chatState: chatState)
            case .ollama:
                try await sendOllamaMessage(messages: allMessages, chatState: chatState)
//            case .gemini:
//                try await sendGeminiMessage(messages: allMessages, chatState: chatState)
            }
        } catch {
            AppLog.common.error("Failed to send message: \(error.localizedDescription)")
            await MainActor.run {
                chatState.isSending = false

                if let globalError = error as? GlobalError {
                    DIContainer.shared.core.errorHandler.handle(globalError)
                    if let lastIndex = chatState.messages.indices.last {
                        let userFriendlyMessage = globalError.localizedDescription
                        chatState.messages[lastIndex].content = userFriendlyMessage
                    }
                } else {
                    let globalError = GlobalError.network(
                        i18nKey: "error.network.ai_request_failed",
                        level: .notification,
                        message: "AI request failed: \(error.localizedDescription)",
                    )
                    DIContainer.shared.core.errorHandler.handle(globalError)
                    if let lastIndex = chatState.messages.indices.last {
                        let userFriendlyMessage = globalError.localizedDescription
                        chatState.messages[lastIndex].content = userFriendlyMessage
                    }
                }
            }
        }
    }

    private func sendOpenAIMessage(messages: [ChatMessage], chatState: ChatState) async throws {
        let apiURL = DIContainer.shared.ui.aiSettingsManager.getAPIURL()
        guard let url = URL(string: apiURL) else {
            throw GlobalError.network(
                i18nKey: "error.network.invalid_url",
                level: .notification,
                message: "Invalid OpenAI API URL: \(apiURL)",
            )
        }

        let requestBody: [String: Any] = [
            "model": DIContainer.shared.ui.aiSettingsManager.getModel(),
            "stream": true,
            "messages": try await buildOpenAIMessages(messages: messages),
        ]

        var request = URLRequest(url: url)
        request.httpMethod = APIClient.HTTPMethods.post
        request.setValue(APIClient.MimeType.json, forHTTPHeaderField: APIClient.Header.contentType)
        request.setValue(APIClient.bearer(DIContainer.shared.ui.aiSettingsManager.apiKey), forHTTPHeaderField: APIClient.Header.authorization)

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = jsonData

        let (asyncBytes, httpResponse) = try await APIClient.performStreamRequest(request: request)

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let errorData = try await asyncBytes.reduce(into: Data()) { $0.append($1) }
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw GlobalError.network(
                i18nKey: "error.network.api_error",
                level: .notification,
                message: "OpenAI API returned HTTP \(httpResponse.statusCode) for \(url.absoluteString): \(errorMessage)",
            )
        }

        var accumulatedContent = ""

        for try await line in asyncBytes.lines {
            guard !line.isEmpty else { continue }

            // SSE format: "data: {...}"
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

    private func buildOpenAIMessages(messages: [ChatMessage]) async throws -> [[String: Any]] {
        var apiMessages: [[String: Any]] = []

        for message in messages {
            var messageDict: [String: Any] = [
                "role": message.apiRoleString,
            ]

            var contentParts: [String] = []

            if !message.content.isEmpty {
                contentParts.append(message.content)
            }

            for attachment in message.attachments {
                if case let .file(url, fileName) = attachment {
                    let fileText = await processFile(url: url, fileName: fileName)
                    contentParts.append(fileText)
                }
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

    private func sendOllamaMessage(messages: [ChatMessage], chatState: ChatState) async throws {
        let baseURL = DIContainer.shared.ui.aiSettingsManager.selectedProvider == .ollama
            ? (DIContainer.shared.ui.aiSettingsManager.ollamaBaseURL.isEmpty ? DIContainer.shared.ui.aiSettingsManager.selectedProvider.baseURL : DIContainer.shared.ui.aiSettingsManager.ollamaBaseURL)
            : DIContainer.shared.ui.aiSettingsManager.selectedProvider.baseURL
        let apiURL = baseURL + DIContainer.shared.ui.aiSettingsManager.selectedProvider.apiPath

        guard let url = URL(string: apiURL) else {
            throw GlobalError.network(
                i18nKey: "error.network.invalid_url",
                level: .notification,
                message: "Invalid Ollama API URL: \(apiURL)",
            )
        }

        let requestBody: [String: Any] = [
            "model": DIContainer.shared.ui.aiSettingsManager.getModel(),
            "stream": true,
            "messages": try await buildOllamaMessages(messages: messages),
        ]

        var request = URLRequest(url: url)
        request.httpMethod = APIClient.HTTPMethods.post
        request.setValue(APIClient.MimeType.json, forHTTPHeaderField: APIClient.Header.contentType)

        if !DIContainer.shared.ui.aiSettingsManager.apiKey.isEmpty {
            request.setValue(DIContainer.shared.ui.aiSettingsManager.apiKey, forHTTPHeaderField: APIClient.Header.authorization)
        }

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = jsonData

        let (asyncBytes, httpResponse) = try await APIClient.performStreamRequest(request: request)

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let errorData = try await asyncBytes.reduce(into: Data()) { $0.append($1) }
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw GlobalError.network(
                i18nKey: "error.network.api_error",
                level: .notification,
                message: "Ollama API returned HTTP \(httpResponse.statusCode) for \(url.absoluteString): \(errorMessage)",
            )
        }

        var accumulatedContent = ""
        for try await line in asyncBytes.lines {
            guard !line.isEmpty,
                  let jsonData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                continue
            }

            // Ollama format: {"message": {"content": "..."}, "done": false}
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

    private func buildOllamaMessages(messages: [ChatMessage]) async throws -> [[String: Any]] {
        var apiMessages: [[String: Any]] = []

        for message in messages {
            var messageDict: [String: Any] = [
                "role": message.apiRoleString,
            ]

            var contentParts: [String] = []

            if !message.content.isEmpty {
                contentParts.append(message.content)
            }

            for attachment in message.attachments {
                if case let .file(url, fileName) = attachment {
                    let fileText = await processFile(url: url, fileName: fileName)
                    contentParts.append(fileText)
                }
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

    private func sendGeminiMessage(messages: [ChatMessage], chatState: ChatState) async throws {
        let model = DIContainer.shared.ui.aiSettingsManager.getModel()
        let apiKey = DIContainer.shared.ui.aiSettingsManager.apiKey
        let apiURL = "\(DIContainer.shared.ui.aiSettingsManager.selectedProvider.baseURL)/v1/models/\(model):streamGenerateContent?key=\(apiKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? apiKey)"

        guard let url = URL(string: apiURL) else {
            throw GlobalError.network(
                i18nKey: "error.network.invalid_url",
                level: .notification,
                message: "Invalid Gemini API URL: \(apiURL)",
            )
        }

        let requestBody: [String: Any] = [
            "contents": try await buildGeminiContents(messages: messages),
        ]

        var request = URLRequest(url: url)
        request.httpMethod = APIClient.HTTPMethods.post
        request.setValue(APIClient.MimeType.json, forHTTPHeaderField: APIClient.Header.contentType)

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = jsonData

        let (asyncBytes, httpResponse) = try await APIClient.performStreamRequest(request: request)

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let errorData = try await asyncBytes.reduce(into: Data()) { $0.append($1) }
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw GlobalError.network(
                i18nKey: "error.network.api_error",
                level: .notification,
                message: "Gemini API returned HTTP \(httpResponse.statusCode) for \(url.absoluteString): \(errorMessage)",
            )
        }

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

    private func buildGeminiContents(messages: [ChatMessage]) async throws -> [[String: Any]] {
        var contents: [[String: Any]] = []

        for message in messages {
            var parts: [[String: Any]] = []

            if !message.content.isEmpty {
                parts.append(["text": message.content])
            }

            for attachment in message.attachments {
                if case let .file(url, fileName) = attachment {
                    let fileText = await processFile(url: url, fileName: fileName)
                    parts.append(["text": fileText])
                }
            }

            guard !parts.isEmpty else { continue }

            var contentDict: [String: Any] = [
                "parts": parts,
            ]

            // Gemini uses "user" and "model" for roles
            if message.role == .assistant {
                contentDict["role"] = "model"
            } else {
                contentDict["role"] = "user"
            }

            contents.append(contentDict)
        }

        return contents
    }

    private func processFile(url: URL, fileName: String) async -> String {
        let maxFileSizeForReading: Int64 = 100_000

        guard let fileSize = await getFileSize(url: url) else {
            return await readFileContent(url: url, fileName: fileName) ??
                String(format: "ai.file.cannot_read".localized(), fileName)
        }

        if fileSize <= maxFileSizeForReading {
            return await readFileContent(url: url, fileName: fileName) ??
                String(format: "ai.file.cannot_read_text".localized(), fileName)
        } else {
            let sizeDescription = formatFileSize(fileSize)
            return String(format: "ai.file.too_large".localized(), fileName, sizeDescription)
        }
    }

    private func readFileContent(url: URL, fileName: String) async -> String? {
        guard let fileContent = await loadFileAsText(url: url) else { return nil }

        let maxLength = 5000
        let truncatedContent = fileContent.count > maxLength
            ? "\(String(fileContent.prefix(maxLength)))\n... \("ai.file.content_truncated".localized())"
            : fileContent

        return String(format: "ai.file.content".localized(), fileName, truncatedContent)
    }

    private func getFileSize(url: URL) async -> Int64? {
        await Task.detached(priority: .utility) {
            guard url.startAccessingSecurityScopedResource() else { return nil }
            defer { url.stopAccessingSecurityScopedResource() }

            guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
                return nil
            }

            if let size = attributes[.size] as? Int64 { return size }
            if let size = attributes[.size] as? Int { return Int64(size) }
            if let size = attributes[.size] as? NSNumber { return size.int64Value }
            return nil
        }.value
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let sizeInKB = Double(bytes) / 1024.0
        if sizeInKB < 1024 {
            return String(format: "%.1f KB", sizeInKB)
        } else {
            let sizeInMB = sizeInKB / 1024.0
            return String(format: "%.2f MB", sizeInMB)
        }
    }

    private func loadFileAsText(url: URL) async -> String? {
        await Task.detached(priority: .utility) {
            guard url.startAccessingSecurityScopedResource() else { return nil }
            defer { url.stopAccessingSecurityScopedResource() }

            return try? String(contentsOf: url, encoding: .utf8)
        }.value
    }

    /// Opens the AI chat window with a fresh chat state.
    func openChatWindow() {
        let chatState = ChatState()
        DIContainer.shared.ui.windowDataStore.aiChatState = chatState
        DIContainer.shared.ui.windowManager.openWindow(id: .aiChat)
    }
}
