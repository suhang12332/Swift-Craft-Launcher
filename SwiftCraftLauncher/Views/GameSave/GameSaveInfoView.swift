//
//  GameSaveInfoView.swift
//
//  Created by su on 2025/7/15.
//

import SwiftUI

struct GameSaveInfoView: View {
    let levelDatPath: String
        @StateObject private var levelDataModel = LevelDataModel()

        var body: some View {
            VStack(spacing: 0) {
                
                
                if let error = levelDataModel.errorMessage {
                    ErrorWidget(message: error)
                } else if levelDataModel.levelData.isEmpty {
                    LoadingWidget()
                } else {
                    // Widget Group Layout
                    VStack(spacing: 0) {
                        Section {
                            WorldSettingsWidget(data: levelDataModel.levelData)
                        }
                        Section {
                            PlayerWidget(data: levelDataModel.levelData)
                        }
                        Section {
                            WeatherWidget(data: levelDataModel.levelData)
                        }
                    }
                }
            }
            .onAppear {
                levelDataModel.loadLevelDat(from: levelDatPath)
            }
            .onDisappear {
                levelDataModel.levelData.removeAll(keepingCapacity: false)
                levelDataModel.errorMessage = nil
            }
        }
}


