//
//  UIComponents.swift
//  MLauncherGame
//
//  Created by su on 2025/7/15.
//

import SwiftUI

// MARK: - macOS Style Widgets



struct WidgetHeader: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

struct WidgetRow: View {
    let title: String
    let value: String?
    
    var body: some View {
        if let value = value {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .frame(width: 80, alignment: .leading)
                
                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                
                Spacer()
            }
            .padding(.vertical, 1)
        }
    }
}

// MARK: - Specific Widgets

struct WorldSettingsWidget: View {
    let data: [String: String]
    
    var gameRules: [(String, String)] {
        data.filter { $0.key.hasPrefix("GameRules.") }
            .sorted { $0.key < $1.key }
            .map { (key: $0.key.replacingOccurrences(of: "GameRules.", with: ""), value: $0.value) }
    }
    
    // 检查是否有世界设置数据
    var hasWorldSettingsData: Bool {
        return data["Time"] != nil || data["DayTime"] != nil || data["LastPlayed"] != nil || 
               data["seed"] != nil || !gameRules.isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WidgetHeader(title: "world.data".localized(), icon: "globe", color: .blue)
            
            VStack(spacing: 4) {
                WidgetRow(title: "world.name".localized(), value: data["LevelName"])
                WidgetRow(title: "game.mode".localized(), value: data["GameType"])
                WidgetRow(title: "difficulty".localized(), value: data["Difficulty"])
                // 极限模式
                if let hardcore = data["hardcore"] {
                    if hardcore == "1" || hardcore == "true" {
                        HStack(spacing: 8) {
                            Text("hardcore.mode".localized())
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                                .frame(width: 80, alignment: .leading)
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Spacer()
                        }
                        .padding(.vertical, 1)
                    } else if hardcore == "0" || hardcore == "false" {
                        HStack(spacing: 8) {
                            Text("hardcore.mode".localized())
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                                .frame(width: 80, alignment: .leading)
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(.vertical, 1)
                    } else {
                        WidgetRow(title: "hardcore.mode".localized(), value: hardcore)
                    }
                } else {
                    WidgetRow(title: "hardcore.mode".localized(), value: data["hardcore"])
                }
                // 允许作弊
                if let allowCommands = data["allowCommands"] {
                    if allowCommands == "1" || allowCommands == "true" {
                        HStack(spacing: 8) {
                            Text("allow.commands".localized())
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                                .frame(width: 80, alignment: .leading)
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                            Spacer()
                        }
                        .padding(.vertical, 1)
                    } else if allowCommands == "0" || allowCommands == "false" {
                        HStack(spacing: 8) {
                            Text("allow.commands".localized())
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                                .frame(width: 80, alignment: .leading)
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(.vertical, 1)
                    } else {
                        WidgetRow(title: "allow.commands".localized(), value: allowCommands)
                    }
                } else {
                    WidgetRow(title: "allow.commands".localized(), value: data["allowCommands"])
                }
                WidgetRow(title: "world.seed".localized(), value: data["seed"])
            }
            
            // 时间相关
            if hasWorldSettingsData {
                VStack(spacing: 4) {
                    if let time = data["Time"] {
                        WidgetRow(title: "world.time".localized(), value: time)
                    }
                    if let dayTime = data["DayTime"] {
                        WidgetRow(title: "day.time".localized(), value: dayTime)
                    }
                    if let lastPlayed = data["LastPlayed"] {
                        WidgetRow(title: "last.played".localized(), value: lastPlayed)
                    }
                }
                
                // 游戏规则部分
                if !gameRules.isEmpty {
                    ForEach(gameRules, id: \.0) { key, value in
                        let displayKey = key == "keepInventory" ? "keep.inventory".localized() : key
                        if key == "keepInventory" {
                            if value == "true" || value == "1" {
                                HStack(spacing: 8) {
                                    Text(displayKey)
                                        .font(.system(size: 12))
                                        .foregroundColor(.primary)
                                        .frame(width: 80, alignment: .leading)
                                    Image(systemName: "checkmark.circle")
                                        .foregroundColor(.green)
                                    Spacer()
                                }
                                .padding(.vertical, 1)
                            } else if value == "false" || value == "0" {
                                HStack(spacing: 8) {
                                    Text(displayKey)
                                        .font(.system(size: 12))
                                        .foregroundColor(.primary)
                                        .frame(width: 80, alignment: .leading)
                                    Image(systemName: "xmark.circle")
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                                .padding(.vertical, 1)
                            } else {
                                WidgetRow(title: displayKey, value: value)
                            }
                        } else {
                            WidgetRow(title: displayKey, value: value)
                        }
                    }
                }
            } else {
                // 显示加载状态
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("loading.world.settings".localized())
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }.padding(.top,10)
    }
}

struct PlayerWidget: View {
    let data: [String: String]
    
    var playerData: [(String, String)] {
        data.filter { $0.key.hasPrefix("Player.") }
            .sorted { $0.key < $1.key }
            .map { (key: $0.key.replacingOccurrences(of: "Player.", with: ""), value: $0.value) }
    }
    
    // 检查是否有玩家数据
    var hasPlayerData: Bool {
        return !playerData.isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WidgetHeader(title: "player.data".localized(), icon: "person.fill", color: .purple)
            
            if hasPlayerData {
                VStack(spacing: 4) {
                    ForEach(playerData, id: \.0) { key, value in
                        WidgetRow(title: key, value: value)
                    }
                }
            } else {
                // 显示加载状态
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("loading.player.data".localized())
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }.padding(.top,10)
    }
}

struct WeatherWidget: View {
    let data: [String: String]
    
    // 检查是否有天气数据
    var hasWeatherData: Bool {
        return data["raining"] != nil || data["thundering"] != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WidgetHeader(title: "weather.status".localized(), icon: "cloud.rain", color: .cyan)
            
            if hasWeatherData {
                VStack(spacing: 4) {
                    WidgetRow(title: "raining.status".localized(), value: data["raining"])
                    WidgetRow(title: "thundering.status".localized(), value: data["thundering"])
                }
            } else {
                // 显示加载状态
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("loading.weather.data".localized())
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }.padding(.top,10)
    }
}

struct ErrorWidget: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundColor(.red)
            
            Text("error".localized())
                .font(.system(size: 14, weight: .semibold))
            
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
    }
}

struct LoadingWidget: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.0)
            
            Text("loading".localized())
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Legacy Components (for backward compatibility)

struct InfoCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

struct InfoRow: View {
    let title: String
    let value: String?
    
    var body: some View {
        if let value = value {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .frame(width: 100, alignment: .leading)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                Spacer()
            }
            .padding(.vertical, 2)
        }
    }
}

struct PlayerDataCard: View {
    let data: [String: String]
    
    var playerData: [(String, String)] {
        data.filter { $0.key.hasPrefix("Player.") }
            .sorted { $0.key < $1.key }
            .map { (key: $0.key.replacingOccurrences(of: "Player.", with: ""), value: $0.value) }
    }
    
    var body: some View {
        InfoCard(
            title: "player.data".localized(),
            icon: "person.fill",
            color: .purple
        ) {
            if playerData.isEmpty {
                Text("no.player.data".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(playerData, id: \.0) { key, value in
                    InfoRow(title: key, value: value)
                }
            }
        }
    }
}

struct GameRulesCard: View {
    let data: [String: String]
    
    var gameRules: [(String, String)] {
        data.filter { $0.key.hasPrefix("GameRules.") }
            .sorted { $0.key < $1.key }
            .map { (key: $0.key.replacingOccurrences(of: "GameRules.", with: ""), value: $0.value) }
    }
    
    var body: some View {
        InfoCard(
            title: "game.rules".localized(),
            icon: "gearshape.fill",
            color: .indigo
        ) {
            if gameRules.isEmpty {
                Text("no.game.rules".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(gameRules, id: \.0) { key, value in
                    InfoRow(title: key, value: value)
                }
            }
        }
    }
}

struct ErrorCard: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundColor(.red)
            
            Text("error".localized())
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
}

struct LoadingCard: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("loading".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .padding(.horizontal, 20)
    }
}
