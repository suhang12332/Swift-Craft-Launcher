//
//  AISettingsManager.swift
//  SwiftCraftLauncher
//
//  Created by AI Assistant
//

import Foundation
import SwiftUI

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

    @AppStorage("aiApiKey")
    var apiKey: String = "" {
        didSet {
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
    private init() {}
}
