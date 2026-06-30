//
//  AnnouncementModels.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A response containing announcement data from the server.
public struct AnnouncementResponse: Codable {
    public let success: Bool
    public let data: AnnouncementData?

    public init(success: Bool, data: AnnouncementData?) {
        self.success = success
        self.data = data
    }
}

/// A single announcement with title, content, and author.
public struct AnnouncementData: Codable {
    public let title: String
    public let content: String
    public let author: String

    public init(title: String, content: String, author: String) {
        self.title = title
        self.content = content
        self.author = author
    }
}
