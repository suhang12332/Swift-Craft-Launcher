//
//  GameSaveInfoView.swift
//
//  Created by su on 2025/7/15.
//

import SwiftUI

struct GameSaveInfoView: View {
    let levelDatPath: String
    @StateObject private var levelDataModel = LevelDataModel()

    // 跟踪哪些部分已经加载
    @State private var worldSettingsLoaded = false
    @State private var playerDataLoaded = false
    @State private var weatherDataLoaded = false

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
                            .onAppear {
                                if !worldSettingsLoaded {
                                    levelDataModel.loadWorldSettingsData()
                                    worldSettingsLoaded = true
                                }
                            }
                    }
                    Section {
                        PlayerWidget(data: levelDataModel.levelData)
                            .onAppear {
                                if !playerDataLoaded {
                                    levelDataModel.loadPlayerData()
                                    playerDataLoaded = true
                                }
                            }
                    }
                    Section {
                        WeatherWidget(data: levelDataModel.levelData)
                            .onAppear {
                                if !weatherDataLoaded {
                                    levelDataModel.loadWeatherData()
                                    weatherDataLoaded = true
                                }
                            }
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
            // 重置加载状态
            worldSettingsLoaded = false
            playerDataLoaded = false
            weatherDataLoaded = false
        }
    }
}
