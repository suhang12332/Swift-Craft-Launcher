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
    case deepseek = "deepseek"  // 使用 OpenAI 格式
    case gemini = "gemini"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .openai:
            return "OpenAI"
        case .ollama:
            return "Ollama"
        case .deepseek:
            return "DeepSeek"
        case .gemini:
            return "Google Gemini"
        }
    }
    
    var baseURL: String {
        switch self {
        case .openai:
            return "https://api.openai.com"
        case .ollama:
            return "http://localhost:11434"
        case .deepseek:
            return "https://api.deepseek.com"
        case .gemini:
            return "https://generativelanguage.googleapis.com"
        }
    }
    
    /// API 格式类型
    var apiFormat: APIFormat {
        switch self {
        case .openai, .deepseek:
            return .openAI
        case .ollama:
            return .ollama
        case .gemini:
            return .gemini
        }
    }
    
    /// 默认模型名称
    var defaultModel: String {
        switch self {
        case .openai:
            return "gpt-4o"
        case .ollama:
            return "llama3"
        case .deepseek:
            return "deepseek-chat"
        case .gemini:
            return "gemini-1.5-flash"
        }
    }
    
    /// API 路径
    var apiPath: String {
        switch self {
        case .openai, .deepseek:
            return "/v1/chat/completions"
        case .ollama:
            return "/api/chat"
        case .gemini:
            return "/v1beta/models/\(defaultModel):streamGenerateContent"
        }
    }
}

/// API 格式枚举
enum APIFormat {
    case openAI  // OpenAI 和 DeepSeek
    case ollama
    case gemini
}

/// AI 设置管理器
class AISettingsManager: ObservableObject {
    static let shared = AISettingsManager()
    
    @AppStorage("aiProvider")
    var selectedProvider: AIProvider = .openai {
        didSet {
            objectWillChange.send()
            // 当提供商更改时，更新服务
            Task { @MainActor in
                AIChatManager.shared.updateService()
            }
        }
    }
    
    @AppStorage("aiApiKey")
    var apiKey: String = "" {
        didSet {
            objectWillChange.send()
            // 当 API Key 更改时，更新服务
            Task { @MainActor in
                AIChatManager.shared.updateService()
            }
        }
    }
    
    @AppStorage("aiOllamaBaseURL")
    var ollamaBaseURL: String = "http://localhost:11434" {
        didSet {
            objectWillChange.send()
            // 当 Ollama 地址更改时，如果当前提供商是 Ollama，更新服务
            if selectedProvider == .ollama {
                Task { @MainActor in
                    AIChatManager.shared.updateService()
                }
            }
        }
    }
    
    /// 获取当前提供商的 API URL（不包括 Gemini，因为 Gemini 需要特殊处理）
    func getAPIURL() -> String {
        if selectedProvider == .ollama {
            let url = ollamaBaseURL.isEmpty ? selectedProvider.baseURL : ollamaBaseURL
            return url + selectedProvider.apiPath
        } else {
            return selectedProvider.baseURL + selectedProvider.apiPath
        }
    }
    
    private init() {}
}

