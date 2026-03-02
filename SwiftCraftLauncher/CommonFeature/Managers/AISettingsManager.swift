//
//  AISettingsManager.swift
//  SwiftCraftLauncher
//
//

import Foundation
import SwiftUI

// MARK: - Keychain 存储常量
private let aiSettingsAccount = "aiSettings"
private let aiApiKeyKeychainKey = "apiKey"

/// AI 提供商枚举
enum AIProvider: String, CaseIterable, Identifiable {
    case openai = "openai"
    case ollama = "ollama"
//    case gemini = "gemini"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai:
            return "OpenAI"
        case .ollama:
            return "Ollama"
//        case .gemini:
//            return "Google Gemini"
        }
    }

    var baseURL: String {
        switch self {
        case .openai:
            return "https://api.openai.com"
        case .ollama:
            return "http://localhost:11434"
//        case .gemini:
//            return "https://generativelanguage.googleapis.com"
        }
    }

    /// API 格式类型
    var apiFormat: APIFormat {
        switch self {
        case .openai:
            return .openAI
        case .ollama:
            return .ollama
//        case .gemini:
//            return .gemini
        }
    }

    /// API 路径
    var apiPath: String {
        switch self {
        case .openai:
            return "/v1/chat/completions"
        case .ollama:
            return "/api/chat"
//        case .gemini:
//            return "/v1/models/\(defaultModel):streamGenerateContent"
        }
    }
}

/// API 格式枚举
enum APIFormat {
    case openAI  // OpenAI 格式（兼容 DeepSeek 等）
    case ollama
//    case gemini
}

/// AI 设置管理器
class AISettingsManager: ObservableObject {
    static let shared = AISettingsManager()

    @AppStorage("aiProvider")
    private var _selectedProviderRawValue: String = "openai"

    var selectedProvider: AIProvider {
        get {
            return AIProvider(rawValue: _selectedProviderRawValue) ?? .openai
        }
        set {
            _selectedProviderRawValue = newValue.rawValue
            objectWillChange.send()
        }
    }

    private var _cachedApiKey: String?

    /// AI API Key（使用 Keychain 安全存储，带内存缓存）
    var apiKey: String {
        get {
            // 如果缓存已存在，直接返回
            if let cached = _cachedApiKey {
                return cached
            }

            // 从 Keychain 读取并缓存
            if let data = KeychainManager.load(account: aiSettingsAccount, key: aiApiKeyKeychainKey),
               let key = String(data: data, encoding: .utf8) {
                _cachedApiKey = key
                return key
            }

            // Keychain 中没有数据，缓存空字符串
            _cachedApiKey = ""
            return ""
        }
        set {
            // 更新缓存
            _cachedApiKey = newValue.isEmpty ? "" : newValue

            // 保存到 Keychain
            if newValue.isEmpty {
                // 如果为空，删除 Keychain 中的项
                _ = KeychainManager.delete(account: aiSettingsAccount, key: aiApiKeyKeychainKey)
            } else {
                // 保存到 Keychain
                if let data = newValue.data(using: .utf8) {
                    _ = KeychainManager.save(data: data, account: aiSettingsAccount, key: aiApiKeyKeychainKey)
                }
            }
            objectWillChange.send()
        }
    }

    @AppStorage("aiOllamaBaseURL")
    var ollamaBaseURL: String = "http://localhost:11434" {
        didSet {
            objectWillChange.send()
        }
    }

    @AppStorage("aiOpenAIBaseURL")
    var openAIBaseURL: String = "" {
        didSet {
            objectWillChange.send()
        }
    }

    @AppStorage("aiModelOverride")
    var modelOverride: String = "" {
        didSet {
            objectWillChange.send()
        }
    }

    @AppStorage("aiAvatarURL")
    var aiAvatarURL: String = "https://mcskins.top/assets/snippets/download/skin.php?n=7050" {
        didSet {
            objectWillChange.send()
        }
    }

    /// 获取当前提供商的 API URL（不包括 Gemini，因为 Gemini 需要特殊处理）
    func getAPIURL() -> String {
        if selectedProvider == .ollama {
            let url = ollamaBaseURL.isEmpty ? selectedProvider.baseURL : ollamaBaseURL
            return url + selectedProvider.apiPath
        } else if selectedProvider.apiFormat == .openAI {
            // OpenAI 格式支持自定义 URL（可用于 DeepSeek 等兼容服务）
            let url = openAIBaseURL.isEmpty ? selectedProvider.baseURL : openAIBaseURL
            return url + selectedProvider.apiPath
        } else {
            return selectedProvider.baseURL + selectedProvider.apiPath
        }
    }

    /// 获取当前提供商的模型名称（必填）
    func getModel() -> String {
        return modelOverride.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private init() {
        _ = apiKey
    }
}
