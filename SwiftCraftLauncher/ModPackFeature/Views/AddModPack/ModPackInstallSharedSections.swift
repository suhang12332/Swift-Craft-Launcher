import SwiftUI

struct ModPackInstallSharedSections: View {
    @Binding var gameName: String
    @Binding var isGameNameDuplicate: Bool

    let isGameNameInputDisabled: Bool
    let showGameNameInput: Bool

    @ObservedObject var gameSetupService: GameSetupUtil
    @ObservedObject var modPackInstallState: ModPackInstallState

    let lastParsedIndexInfo: ModrinthIndexInfo?

    /// 是否显示进度块
    let shouldShowProgress: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showGameNameInput {
                FormSection {
                    GameNameInputView(
                        gameName: $gameName,
                        isGameNameDuplicate: $isGameNameDuplicate,
                        isDisabled: isGameNameInputDisabled,
                        gameSetupService: gameSetupService
                    )
                }
            }

            if shouldShowProgress {
                DownloadProgressView(
                    gameSetupService: gameSetupService,
                    modPackInstallState: modPackInstallState,
                    lastParsedIndexInfo: lastParsedIndexInfo
                )
                .padding(.top, 10)
            }
        }
    }
}
