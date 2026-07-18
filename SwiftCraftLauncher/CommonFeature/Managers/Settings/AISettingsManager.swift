//
//  AISettingsManager.swift
//  CommonFeature
//
//  Manages AI service configuration including provider selection, API keys, and model settings.
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// Represents an available AI service provider.
enum AIProvider: String, CaseIterable, Identifiable {
    case openai
    case ollama
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
            return URLConfig.API.AIService.openAIBaseURL
        case .ollama:
            return URLConfig.API.AIService.ollamaDefaultBaseURL
//        case .gemini:
//            return "https://generativelanguage.googleapis.com"
        }
    }

    /// The API request format for this provider.
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

    /// The API endpoint path for chat completions.
    var apiPath: String {
        switch self {
        case .openai:
            return URLConfig.API.AIService.openAIChatPath
        case .ollama:
            return URLConfig.API.AIService.ollamaChatPath
//        case .gemini:
//            return "/v1/models/\(defaultModel):streamGenerateContent"
        }
    }
}

/// The request format used to communicate with an AI provider.
enum APIFormat {
    case openAI // Compatible with DeepSeek and similar services
    case ollama
//    case gemini
}

/// Manages persistent AI service settings including provider, API key, and model configuration.
class AISettingsManager: ObservableObject {
    @AppStorage(AppConstants.UserDefaultsKeys.aiProvider)
    private var _selectedProviderRawValue: String = "openai"

    var selectedProvider: AIProvider {
        get {
            AIProvider(rawValue: _selectedProviderRawValue) ?? .openai
        }
        set {
            _selectedProviderRawValue = newValue.rawValue
            objectWillChange.send()
        }
    }

    private var _cachedApiKey: String?

    /// The API key for the selected AI provider, stored securely in Keychain with in-memory caching.
    var apiKey: String {
        get {
            if let cached = _cachedApiKey {
                return cached
            }

            if let data = KeychainManager.load(account: AppConstants.KeychainAccounts.aiSettings, key: AppConstants.KeychainKeys.apiKey),
               let key = String(data: data, encoding: .utf8) {
                _cachedApiKey = key
                return key
            }

            _cachedApiKey = ""
            return ""
        }
        set {
            _cachedApiKey = newValue.isEmpty ? "" : newValue

            if newValue.isEmpty {
                _ = KeychainManager.delete(account: AppConstants.KeychainAccounts.aiSettings, key: AppConstants.KeychainKeys.apiKey)
            } else {
                if let data = newValue.data(using: .utf8) {
                    _ = KeychainManager.save(data: data, account: AppConstants.KeychainAccounts.aiSettings, key: AppConstants.KeychainKeys.apiKey)
                }
            }
            objectWillChange.send()
        }
    }

    @AppStorage(AppConstants.UserDefaultsKeys.aiOllamaBaseURL)
    var ollamaBaseURL: String = URLConfig.API.AIService.ollamaDefaultBaseURL {
        didSet {
            objectWillChange.send()
        }
    }

    @AppStorage(AppConstants.UserDefaultsKeys.aiOpenAIBaseURL)
    var openAIBaseURL: String = "" {
        didSet {
            objectWillChange.send()
        }
    }

    @AppStorage(AppConstants.UserDefaultsKeys.aiModelOverride)
    var modelOverride: String = "" {
        didSet {
            objectWillChange.send()
        }
    }

    @AppStorage(AppConstants.UserDefaultsKeys.aiAvatarURL)
    var aiAvatarURL: String = URLConfig.API.AIService.defaultAvatarURL {
        didSet {
            objectWillChange.send()
        }
    }

    /// Returns the full API endpoint URL for the current provider.
    func getAPIURL() -> String {
        if selectedProvider == .ollama {
            let url = ollamaBaseURL.isEmpty ? selectedProvider.baseURL : ollamaBaseURL
            return url + selectedProvider.apiPath
        } else if selectedProvider.apiFormat == .openAI {
            let url = openAIBaseURL.isEmpty ? selectedProvider.baseURL : openAIBaseURL
            return url + selectedProvider.apiPath
        } else {
            return selectedProvider.baseURL + selectedProvider.apiPath
        }
    }

    /// Returns the configured model name, trimmed of whitespace.
    func getModel() -> String {
        modelOverride.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init() { }
}
