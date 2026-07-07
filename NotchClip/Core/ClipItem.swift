// Core/ClipItem.swift
import Foundation

enum ClipItemType: String, Codable {
    case text, link, color, image, file
}

struct ClipItem: Identifiable, Codable, Equatable {
    let id: UUID
    let type: ClipItemType
    var text: String?           // text/link/color 存内容；file 存完整路径
    var imageFilename: String?  // image 类型：images/ 目录下的文件名（M2 写入）
    var sourceAppBundleID: String?
    var sourceAppName: String?
    var createdAt: Date         // var：去重上移时会刷新
    var isPinned: Bool = false
}
