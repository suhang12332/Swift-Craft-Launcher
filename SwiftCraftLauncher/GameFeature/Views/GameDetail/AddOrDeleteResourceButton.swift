//
//  AddOrDeleteResourceButton.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/28.
//

import Foundation
import SwiftUI

struct AddOrDeleteResourceButton: View {
    var project: ModrinthProject
    let selectedVersions: [String]
    let selectedLoaders: [String]
    let gameInfo: GameVersionInfo?
    let query: String
    let type: Bool  // false = local, true = server
    @Binding var scannedDetailIds: Set<String> // 已扫描资源的 detailId Set，用于快速查找（O(1)）
    @EnvironmentObject private var gameRepository: GameRepository
    @EnvironmentObject private var playerListViewModel: PlayerListViewModel
    @Binding var isResourceDisabled: Bool  // 暴露给父视图的禁用状态（用于置灰效果）
    @Binding var selectedItem: SidebarItem
    var onResourceChanged: (() -> Void)?
    /// 启用/禁用状态切换后的回调（仅本地资源列表使用）
    var onToggleDisableState: ((Bool) -> Void)?
    /// 更新成功回调：仅更新当前条目的 hash 与列表项，不全局扫描。参数 (projectId, oldFileName, newFileName, newHash)
    var onResourceUpdated: ((String, String, String, String?) -> Void)?

    @StateObject private var viewModel: AddOrDeleteResourceButtonViewModel
    // 保证所有 init 都有 onResourceChanged 参数（带默认值）
    init(
        project: ModrinthProject,
        selectedVersions: [String],
        selectedLoaders: [String],
        gameInfo: GameVersionInfo?,
        query: String,
        type: Bool,
        selectedItem: Binding<SidebarItem>,
        onResourceChanged: (() -> Void)? = nil,
        scannedDetailIds: Binding<Set<String>> = .constant([]),
        isResourceDisabled: Binding<Bool> = .constant(false),
        onResourceUpdated: ((String, String, String, String?) -> Void)? = nil,
        onToggleDisableState: ((Bool) -> Void)? = nil
    ) {
        self.project = project
        self.selectedVersions = selectedVersions
        self.selectedLoaders = selectedLoaders
        self.gameInfo = gameInfo
        self.query = query
        self.type = type
        self._selectedItem = selectedItem
        self.onResourceChanged = onResourceChanged
        self._scannedDetailIds = scannedDetailIds
        self._isResourceDisabled = isResourceDisabled
        self.onResourceUpdated = onResourceUpdated
        self.onToggleDisableState = onToggleDisableState

        _viewModel = StateObject(
            wrappedValue: AddOrDeleteResourceButtonViewModel(
                project: project,
                selectedVersions: selectedVersions,
                selectedLoaders: selectedLoaders,
                gameInfo: gameInfo,
                query: query,
                type: type,
                onResourceChanged: onResourceChanged,
                onResourceUpdated: onResourceUpdated,
                onToggleDisableState: onToggleDisableState,
                setIsResourceDisabled: { isResourceDisabled.wrappedValue = $0 },
                addScannedHash: { hash in scannedDetailIds.wrappedValue.insert(hash) }
            )
        )
    }

    var body: some View {

        HStack(spacing: 8) {
            LocalResourceUpdateButton(
                isVisible: type == false && viewModel.addButtonState == .update && !isResourceDisabled,
                isUpdateButtonLoading: $viewModel.isUpdateButtonLoading,
                addButtonState: viewModel.addButtonState,
                onTap: viewModel.handleUpdateTap
            )

            LocalResourceToggle(
                isVisible: type == false,
                isDisabled: $viewModel.isDisabled,
                onToggle: viewModel.toggleDisableState
            )

            // 安装/删除按钮
            ResourcePrimaryActionButton(
                addButtonState: viewModel.addButtonState,
                type: type,
                isDisabled: viewModel.addButtonState == .loading
                    || (viewModel.addButtonState == .installed && type),
                onTap: { viewModel.handlePrimaryTap(selectedItem: selectedItem) },
                query: query
            )
            .onAppear {
                viewModel.setDependencies(
                    gameRepository: gameRepository,
                    playerListViewModel: playerListViewModel
                )
                viewModel.onAppear(selectedItem: selectedItem, scannedDetailIds: scannedDetailIds)
            }
            // 根据最新扫描结果刷新按钮的安装状态
            .onChange(of: scannedDetailIds) { _, _ in
                viewModel.onScannedDetailIdsChanged(
                    selectedItem: selectedItem,
                    scannedDetailIds: scannedDetailIds
                )
            }
        }
        .modifier(
            AddOrDeleteResourceButtonOverlays(
                viewModel: viewModel,
                project: project,
                gameInfo: gameInfo,
                query: query,
                gameRepository: gameRepository
            )
        )
    }
}
