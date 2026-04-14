import SwiftUI

/// 主窗口级展示层（导出、删除确认、启动公告）
struct MainViewPresentationModifier: ViewModifier {
    @ObservedObject private var gameDialogsPresenter = GameDialogsPresenter.shared
    @ObservedObject var detailState: ResourceDetailState

    @StateObject private var startupAnnouncementViewModel = StartupAnnouncementViewModel()
    @State private var showStartupInfo = false
    @State private var hasPresentedStartupInfo = false

    func body(content: Content) -> some View {
        content
            .sheet(item: $gameDialogsPresenter.gameForExport) { game in
                ModPackExportSheet(gameInfo: game)
            }
            .task {
                await startupAnnouncementViewModel.checkAnnouncementIfNeeded()
            }
            .onChange(of: startupAnnouncementViewModel.hasAnnouncement) { _, hasAnnouncement in
                guard
                    hasAnnouncement,
                    startupAnnouncementViewModel.announcementData != nil,
                    !hasPresentedStartupInfo
                else { return }
                hasPresentedStartupInfo = true
                showStartupInfo = true
            }
            .sheet(isPresented: $showStartupInfo) {
                StartupInfoSheetView(announcementData: startupAnnouncementViewModel.announcementData)
            }
            .deleteGameConfirmationDialog(
                gamePendingDeletion: $gameDialogsPresenter.gamePendingDeletion,
                detailState: detailState
            )
    }
}

extension View {
    func mainViewPresentations(detailState: ResourceDetailState) -> some View {
        modifier(MainViewPresentationModifier(detailState: detailState))
    }
}
