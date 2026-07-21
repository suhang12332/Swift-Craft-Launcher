//
//  GeneralSettingsManager.swift
//  CommonFeature
//
//  Manages general application settings including proxy, downloads, and layout preferences.
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Combine
import Foundation
import SwiftUI

/// The interface layout style for the main window.
public enum InterfaceLayoutStyle: String, CaseIterable {
    case classic
    case focused

    public var localizedName: String {
        "settings.interface_style.\(rawValue)".localized()
    }
}

/// Manages general application settings including proxy, downloads, and layout preferences.
@Observable
final class GeneralSettingsManager: WorkingPathProviding {
    /// A Combine subject that fires when the working directory path changes.
    private let workingPathDidChangeSubject = PassthroughSubject<Void, Never>()

    /// Whether GitHub proxy is enabled.
    var enableGitHubProxy: Bool {
        didSet { UserDefaults.standard.set(enableGitHubProxy, forKey: AppConstants.UserDefaultsKeys.enableGitHubProxy) }
    }

    var gitProxyURL: String {
        didSet { UserDefaults.standard.set(gitProxyURL, forKey: AppConstants.UserDefaultsKeys.gitProxyURL) }
    }

    /// Whether to limit the height of common sheets.
    var limitCommonSheetHeight: Bool {
        didSet { UserDefaults.standard.set(limitCommonSheetHeight, forKey: AppConstants.UserDefaultsKeys.limitCommonSheetHeight) }
    }

    var concurrentDownloads: Int {
        didSet {
            if concurrentDownloads < 1 { concurrentDownloads = 1 }
            UserDefaults.standard.set(concurrentDownloads, forKey: AppConstants.UserDefaultsKeys.concurrentDownloads)
        }
    }

    /// The launcher working directory path.
    var launcherWorkingDirectory: String {
        didSet {
            UserDefaults.standard.set(launcherWorkingDirectory, forKey: AppConstants.UserDefaultsKeys.launcherWorkingDirectory)
            workingPathDidChangeSubject.send()
        }
    }

    /// The interface layout style for the main window.
    var interfaceLayoutStyle: InterfaceLayoutStyle {
        didSet { UserDefaults.standard.set(interfaceLayoutStyle.rawValue, forKey: AppConstants.UserDefaultsKeys.interfaceLayoutStyle) }
    }

    /// The current working path, falling back to the default support directory when empty.
    var currentWorkingPath: String {
        launcherWorkingDirectory.isEmpty ? AppPaths.launcherSupportDirectory.path : launcherWorkingDirectory
    }

    var workingPathWillChange: AnyPublisher<Void, Never> {
        workingPathDidChangeSubject.eraseToAnyPublisher()
    }

    init() {
        let d = UserDefaults.standard
        enableGitHubProxy = d.object(forKey: AppConstants.UserDefaultsKeys.enableGitHubProxy) as? Bool ?? true
        gitProxyURL = d.string(forKey: AppConstants.UserDefaultsKeys.gitProxyURL) ?? URLConfig.Defaults.gitProxyURL
        limitCommonSheetHeight = d.bool(forKey: AppConstants.UserDefaultsKeys.limitCommonSheetHeight)
        concurrentDownloads = d.object(forKey: AppConstants.UserDefaultsKeys.concurrentDownloads) as? Int ?? 64
        launcherWorkingDirectory = d.string(forKey: AppConstants.UserDefaultsKeys.launcherWorkingDirectory) ?? AppPaths.launcherSupportDirectory.path
        let layoutRaw = d.string(forKey: AppConstants.UserDefaultsKeys.interfaceLayoutStyle) ?? InterfaceLayoutStyle.classic.rawValue
        interfaceLayoutStyle = InterfaceLayoutStyle(rawValue: layoutRaw) ?? .classic
    }
}
