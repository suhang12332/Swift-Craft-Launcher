//
//  GameNameInputView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/27.
//

import SwiftUI

// MARK: - GameNameInputView
struct GameNameInputView: View {
    @Binding var gameName: String
    @Binding var isGameNameDuplicate: Bool
    @FocusState private var isGameNameFocused: Bool
    @State private var showErrorPopover: Bool = false
    let isDisabled: Bool
    let gameSetupService: GameSetupUtil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("game.form.name".localized())
                .font(.subheadline)
                .foregroundColor(.primary)
            TextField(
                "game.form.name.placeholder".localized(),
                text: $gameName
            )
            .textFieldStyle(.roundedBorder)
            .foregroundColor(.primary)
            .focused($isGameNameFocused)
            .focusEffectDisabled()
            .disabled(isDisabled)
            .popover(isPresented: $showErrorPopover, arrowEdge: .trailing) {
                if isGameNameDuplicate {
                    Text("game.form.name.duplicate".localized())
                        .padding()
                        .presentationCompactAdaptation(.popover)
                }
            }
            .onChange(of: gameName) { _, newName in
                Task {
                    let isDuplicate = await gameSetupService.checkGameNameDuplicate(newName)
                    await MainActor.run {
                        if isDuplicate != isGameNameDuplicate {
                            isGameNameDuplicate = isDuplicate
                        }
                        showErrorPopover = isDuplicate
                    }
                }
            }
        }
    }
}
