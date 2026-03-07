//
//  ResourceDetailState.swift
//  SwiftCraftLauncher
//
//  收拢当前选中的侧边栏项、游戏/资源类型、项目详情等状态，通过 @EnvironmentObject 向下提供，减少 @Binding 透传。
//

import SwiftUI

/// 资源/游戏详情与导航相关状态（可观测）
public final class ResourceDetailState: ObservableObject {

    @Published public var selectedItem: SidebarItem
    @Published public var gameType: Bool  // false = local, true = server
    @Published public var gameId: String?
    @Published public var gameResourcesType: String
    @Published public var selectedProjectId: String? {
        didSet {
            if selectedProjectId != oldValue {
                loadedProjectDetail = nil
            }
        }
    }
    @Published public var loadedProjectDetail: ModrinthProjectDetail?
    @Published public var showInstallSheet: Bool = false
    @Published public var currentProject: ModrinthProject?
    @Published var compatibleGames: [GameVersionInfo] = []

    public init(
        selectedItem: SidebarItem = .resource(.mod),
        gameType: Bool = true,
        gameId: String? = nil,
        gameResourcesType: String = "mod",
        selectedProjectId: String? = nil,
        loadedProjectDetail: ModrinthProjectDetail? = nil
    ) {
        self.selectedItem = selectedItem
        self.gameType = gameType
        self.gameId = gameId
        self.gameResourcesType = gameResourcesType
        self.selectedProjectId = selectedProjectId
        self.loadedProjectDetail = loadedProjectDetail
    }

    // MARK: - 便捷方法

    public func selectGame(id: String?) {
        gameId = id
    }

    public func selectResource(type: String) {
        gameResourcesType = type
    }

    /// 清空项目/游戏选中状态（用于切换回列表等）
    public func clearSelection() {
        selectedProjectId = nil
        loadedProjectDetail = nil
    }

    // MARK: - Bindings（供子视图与 GameActionManager 等使用）

    public var selectedItemBinding: Binding<SidebarItem> {
        Binding(get: { [weak self] in self?.selectedItem ?? .resource(.mod) }, set: { [weak self] value in
            guard let self else { return }
            if Thread.isMainThread {
                self.selectedItem = value
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.selectedItem = value
                }
            }
        })
    }

    /// 用于 List(selection:) 等需要 Optional 的 API
    public var selectedItemOptionalBinding: Binding<SidebarItem?> {
        Binding(get: { [weak self] in self?.selectedItem }, set: { [weak self] value in
            guard let self else { return }
            if let v = value {
                if Thread.isMainThread {
                    self.selectedItem = v
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.selectedItem = v
                    }
                }
            }
        })
    }
    public var gameTypeBinding: Binding<Bool> {
        Binding(get: { [weak self] in self?.gameType ?? true }, set: { [weak self] value in
            guard let self else { return }
            if Thread.isMainThread {
                self.gameType = value
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.gameType = value
                }
            }
        })
    }
    public var gameIdBinding: Binding<String?> {
        Binding(get: { [weak self] in self?.gameId }, set: { [weak self] value in
            guard let self else { return }
            if Thread.isMainThread {
                self.gameId = value
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.gameId = value
                }
            }
        })
    }
    public var gameResourcesTypeBinding: Binding<String> {
        Binding(get: { [weak self] in self?.gameResourcesType ?? "mod" }, set: { [weak self] value in
            guard let self else { return }
            if Thread.isMainThread {
                self.gameResourcesType = value
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.gameResourcesType = value
                }
            }
        })
    }
    public var selectedProjectIdBinding: Binding<String?> {
        Binding(get: { [weak self] in self?.selectedProjectId }, set: { [weak self] value in
            guard let self else { return }
            guard self.selectedProjectId != value else { return }
            if Thread.isMainThread {
                self.selectedProjectId = value
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    guard self.selectedProjectId != value else { return }
                    self.selectedProjectId = value
                }
            }
        })
    }
    public var loadedProjectDetailBinding: Binding<ModrinthProjectDetail?> {
        Binding(get: { [weak self] in self?.loadedProjectDetail }, set: { [weak self] value in
            guard let self else { return }
            guard self.loadedProjectDetail?.id != value?.id else { return }
            if Thread.isMainThread {
                self.loadedProjectDetail = value
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    guard self.loadedProjectDetail?.id != value?.id else { return }
                    self.loadedProjectDetail = value
                }
            }
        })
    }
    public var showInstallSheetBinding: Binding<Bool> {
        Binding(get: { [weak self] in self?.showInstallSheet ?? false }, set: { [weak self] value in
            guard let self else { return }
            if Thread.isMainThread {
                self.showInstallSheet = value
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.showInstallSheet = value
                }
            }
        })
    }
}
