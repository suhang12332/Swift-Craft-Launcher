//
//  MainModVersionSheetViewModel.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/1.
//

import Foundation
import SwiftUI

// MARK: - 主Mod版本管理ViewModel
/// 用于管理主mod版本信息的显示和选择
final class MainModVersionSheetViewModel: ObservableObject {
    @Published var isLoadingVersions = true
    @Published var availableVersions: [ModrinthProjectDetailVersion] = []
    @Published var selectedVersionId: String?
    @Published var showMainModVersionSheet = false

    /// 清理所有数据，在 sheet 关闭时调用以释放内存
    func cleanup() {
        isLoadingVersions = true
        availableVersions = []
        selectedVersionId = nil
    }
}
