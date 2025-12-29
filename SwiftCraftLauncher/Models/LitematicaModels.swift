//
//  LitematicaModels.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/20.
//

import Foundation

/// Litematica 投影文件信息模型
struct LitematicaInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let path: URL
    let createdDate: Date?
    let fileSize: Int64
    let author: String?
    let description: String?
    let version: String?
    let regionCount: Int?
    let totalBlocks: Int?
    
    init(
        name: String,
        path: URL,
        createdDate: Date? = nil,
        fileSize: Int64 = 0,
        author: String? = nil,
        description: String? = nil,
        version: String? = nil,
        regionCount: Int? = nil,
        totalBlocks: Int? = nil
    ) {
        self.id = path.lastPathComponent
        self.name = name
        self.path = path
        self.createdDate = createdDate
        self.fileSize = fileSize
        self.author = author
        self.description = description
        self.version = version
        self.regionCount = regionCount
        self.totalBlocks = totalBlocks
    }
}

/// Litematica 投影元数据结构（用于列表显示）
struct LitematicaMetadata {
    let author: String?
    let description: String?
    let version: String?
    let regionCount: Int?
    let totalBlocks: Int?
}

/// Litematica 投影完整元数据结构（用于详情显示）
struct LitematicMetadata {
    let name: String
    let author: String
    let description: String
    let timeCreated: Int64
    let timeModified: Int64
    let totalVolume: Int32
    let totalBlocks: Int32
    let enclosingSize: Size
    let regionCount: Int32
}

/// 尺寸结构
struct Size {
    let x: Int32
    let y: Int32
    let z: Int32
}

