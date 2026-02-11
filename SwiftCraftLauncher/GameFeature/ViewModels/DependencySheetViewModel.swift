//
//  DependencySheetViewModel.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/28.
//

import Foundation
import SwiftUI

// MARK: - 下载状态定义
enum ResourceDownloadState {
    case idle, downloading, success, failed
}

// MARK: - 依赖管理ViewModel
/// 持久化依赖相关状态，用于管理资源依赖项的下载和安装
final class DependencySheetViewModel: ObservableObject {
    @Published var missingDependencies: [ModrinthProjectDetail] = []
    @Published var isLoadingDependencies = true
    @Published var showDependenciesSheet = false
    @Published var dependencyDownloadStates: [String: ResourceDownloadState] = [:]
    @Published var dependencyVersions: [String: [ModrinthProjectDetailVersion]] = [:]
    @Published var selectedDependencyVersion: [String: String] = [:]
    @Published var overallDownloadState: OverallDownloadState = .idle

    enum OverallDownloadState {
        case idle  // 初始状态，或全部下载成功后
        case failed  // 首次"全部下载"操作中，有任何文件失败
        case retrying  // 用户正在重试失败项
    }

    var allDependenciesDownloaded: Bool {
        // 当没有依赖时，也认为"所有依赖都已下载"
        if missingDependencies.isEmpty { return true }

        // 检查所有列出的依赖项是否都标记为成功
        return missingDependencies.allSatisfy {
            dependencyDownloadStates[$0.id] == .success
        }
    }

    func resetDownloadStates() {
        for dep in missingDependencies {
            dependencyDownloadStates[dep.id] = .idle
        }
        overallDownloadState = .idle
    }

    /// 清理所有数据，在 sheet 关闭时调用以释放内存
    func cleanup() {
        missingDependencies = []
        isLoadingDependencies = true
        dependencyDownloadStates = [:]
        dependencyVersions = [:]
        selectedDependencyVersion = [:]
        overallDownloadState = .idle
    }
}
