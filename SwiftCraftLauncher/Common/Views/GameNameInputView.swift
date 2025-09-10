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
    let isDisabled: Bool
    let gameSetupService: GameSetupUtil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("game.form.name".localized())
                    .font(.subheadline)
                    .foregroundColor(.primary)
                if isGameNameDuplicate {
                    Spacer()
                    Text("game.form.name.duplicate".localized())
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.trailing, 4)
                }
            }
            TextField(
                "game.form.name.placeholder".localized(),
                text: $gameName
            )
            .textFieldStyle(.roundedBorder)
            .foregroundColor(.primary)
            .focused($isGameNameFocused)
            .disabled(isDisabled)
            .onChange(of: gameName) { _, newName in
                Task {
                    let isDuplicate = await gameSetupService.checkGameNameDuplicate(newName)
                    if isDuplicate != isGameNameDuplicate {
                        isGameNameDuplicate = isDuplicate
                    }
                }
            }
        }
    }
}
