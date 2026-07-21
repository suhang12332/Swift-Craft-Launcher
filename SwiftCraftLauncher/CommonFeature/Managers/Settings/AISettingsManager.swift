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
@Observable
final class AISettingsManager {
    /// The currently selected AI provider, persisted in UserDefaults.
    var selectedProvider: AIProvider {
        didSet { UserDefaults.standard.set(selectedProvider.rawValue, forKey: AppConstants.UserDefaultsKeys.aiProvider) }
    }

    /// The API key for the selected AI provider, stored securely in Keychain.
    var apiKey: String {
        didSet {
            if apiKey.isEmpty {
                _ = KeychainManager.delete(account: AppConstants.KeychainAccounts.aiSettings, key: AppConstants.KeychainKeys.apiKey)
            } else {
                if let data = apiKey.data(using: .utf8) {
                    _ = KeychainManager.save(data: data, account: AppConstants.KeychainAccounts.aiSettings, key: AppConstants.KeychainKeys.apiKey)
                }
            }
        }
    }

    var ollamaBaseURL: String {
        didSet { UserDefaults.standard.set(ollamaBaseURL, forKey: AppConstants.UserDefaultsKeys.aiOllamaBaseURL) }
    }

    var openAIBaseURL: String {
        didSet { UserDefaults.standard.set(openAIBaseURL, forKey: AppConstants.UserDefaultsKeys.aiOpenAIBaseURL) }
    }

    var modelOverride: String {
        didSet { UserDefaults.standard.set(modelOverride, forKey: AppConstants.UserDefaultsKeys.aiModelOverride) }
    }

    var aiAvatarURL: String {
        didSet { UserDefaults.standard.set(aiAvatarURL, forKey: AppConstants.UserDefaultsKeys.aiAvatarURL) }
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

    init() {
        let d = UserDefaults.standard
        let providerRaw = d.string(forKey: AppConstants.UserDefaultsKeys.aiProvider) ?? "openai"
        selectedProvider = AIProvider(rawValue: providerRaw) ?? .openai
        ollamaBaseURL = d.string(forKey: AppConstants.UserDefaultsKeys.aiOllamaBaseURL) ?? URLConfig.API.AIService.ollamaDefaultBaseURL
        openAIBaseURL = d.string(forKey: AppConstants.UserDefaultsKeys.aiOpenAIBaseURL) ?? ""
        modelOverride = d.string(forKey: AppConstants.UserDefaultsKeys.aiModelOverride) ?? ""
        aiAvatarURL = d.string(forKey: AppConstants.UserDefaultsKeys.aiAvatarURL) ?? URLConfig.API.AIService.defaultAvatarURL

        if let data = KeychainManager.load(account: AppConstants.KeychainAccounts.aiSettings, key: AppConstants.KeychainKeys.apiKey),
           let key = String(data: data, encoding: .utf8) {
            apiKey = key
        } else {
            apiKey = ""
        }
    }
}
