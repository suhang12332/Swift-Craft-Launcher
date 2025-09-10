import SwiftUI

// MARK: - GameFormView
struct GameFormView: View {
    @EnvironmentObject var gameRepository: GameRepository
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @Environment(\.dismiss)
    private var dismiss

    // MARK: - State
    @State private var isImportMode = false
    @State private var isDownloading = false
    @State private var isFormValid = false
    @State private var triggerConfirm = false

    // MARK: - Body
    var body: some View {
        CommonSheetView(
            header: { headerView },
            body: {
                if isImportMode {
                    ModPackImportView(
                        isDownloading: $isDownloading,
                        isFormValid: $isFormValid,
                        triggerConfirm: $triggerConfirm,
                        onCancel: { dismiss() },
                        onConfirm: {
                            triggerConfirm = true
                        }
                    )
                } else {
                    GameCreationView(
                        isDownloading: $isDownloading,
                        isFormValid: $isFormValid,
                        triggerConfirm: $triggerConfirm,
                        onCancel: { dismiss() },
                        onConfirm: {
                            triggerConfirm = true
                        }
                    )
                }
            },
            footer: { footerView }
        )
    }

    // MARK: - View Components
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Text(isImportMode ? "modpack.import.local.title".localized() : "game.form.title".localized())
                    .font(.headline)
                Spacer()
                Button(
                    action: {
                        isImportMode.toggle()
                    },
                    label: {
                        Label(
                            (!isImportMode ? "game.form.mode.import" : "game.form.mode.create").localized(),
                            systemImage: !isImportMode ? "square.and.arrow.down" : "plus.square"
                        ).labelStyle(.iconOnly)
                    }
                )
                .buttonStyle(.plain)
                .help(
                    (!isImportMode ? "game.form.mode.import" : "game.form.mode.create").localized()
                )
                .applyReplaceTransition()
            }
        }
    }

    private var footerView: some View {
        HStack {
            cancelButton
            Spacer()
            confirmButton
        }
    }

    private var cancelButton: some View {
        Button("common.cancel".localized()) {
                dismiss()
        }
        .keyboardShortcut(.cancelAction)
    }

    private var confirmButton: some View {
        Button {
            triggerConfirm = true
        } label: {
            HStack {
                if isDownloading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(isImportMode ? "modpack.import.button".localized() : "common.confirm".localized())
                }
            }
        }
        .keyboardShortcut(.defaultAction)
        .disabled(!isFormValid || isDownloading)
    }
}
