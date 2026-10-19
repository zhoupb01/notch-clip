// Core/HistoryStore.swift
import AppKit
import Combine
import CryptoKit

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var items: [ClipItem] = []

    private let baseDir: URL
    private let fileURL: URL
    let imagesDir: URL
    private let ioQueue = DispatchQueue(label: "NotchClip.history.io")
    private var saveWork: DispatchWorkItem?

    init(baseDir: URL = FileManager.default.urls(for: .applicationSupportDirectory,
                                                 in: .userDomainMask)[0]
        .appendingPathComponent("NotchClip", isDirectory: true)) {
        self.baseDir = baseDir
        fileURL = baseDir.appendingPathComponent("history.json")
        imagesDir = baseDir.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        load()
    }

    // MARK: 写入

    /// 按复制顺序入库，完成后回调实际条目，图片文件已落盘
    func add(_ item: ClipItem, image: ClipImage?,
             completion: @escaping @MainActor (ClipItem) -> Void) {
        let imagesDir = imagesDir
        ioQueue.async {
            guard let item = Self.prepare(item, image: image, imagesDir: imagesDir) else { return }
            DispatchQueue.main.async {
                var storedItem = item
                // 去重（非图片）：内容相同的旧条目上移刷新时间
                if item.type != .image,
                   let idx = self.items.firstIndex(where: { $0.type == item.type && $0.text == item.text }) {
                    storedItem = self.items.remove(at: idx)
                    storedItem.createdAt = Date()
                } else if item.type == .image, let hash = item.imageHash,
                          let first = self.items.first, first.type == .image,
                          first.imageHash == hash {
                    // 去重（图片）：只比较第一条的哈希，删除刚写入的副本
                    self.deleteImageFile(of: item)
                    storedItem = self.items.removeFirst()
                    storedItem.createdAt = Date()
                }
                self.items.insert(storedItem, at: 0)
                self.trim()
                self.scheduleSave()
                completion(storedItem)
            }
        }
    }

    func togglePin(_ item: ClipItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].isPinned.toggle()
        scheduleSave()
    }

    func delete(_ item: ClipItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        deleteImageFile(of: items[idx])
        items.remove(at: idx)
        scheduleSave()
    }

    /// 清空历史，固定项保留
    func clearHistory() {
        for it in items where !it.isPinned { deleteImageFile(of: it) }
        items.removeAll { !$0.isPinned }
        scheduleSave()
    }

    func imageURL(for item: ClipItem) -> URL? {
        guard let fn = item.imageFilename else { return nil }
        return imagesDir.appendingPathComponent(fn)
    }

    // MARK: 内部

    private nonisolated static func prepare(_ newItem: ClipItem, image: ClipImage?,
                                            imagesDir: URL) -> ClipItem? {
        var item = newItem
        if item.type == .image, let image {
            let data: Data
            switch image {
            case .png(let png):
                data = png
            case .tiff(let tiff):
                guard let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:]) else { return nil }
                data = png
            }
            let name = item.id.uuidString + ".png"
            item.imageHash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            do {
                try data.write(to: imagesDir.appendingPathComponent(name))
            } catch {
                return nil
            }
            item.imageFilename = name
        }
        return item
    }

    /// 只淘汰未固定的最老条目，直到未固定数量 <= 上限
    private func trim() {
        let cap = Settings.shared.maxItems
        var unpinned = items.filter { !$0.isPinned }.count
        guard unpinned > cap else { return }
        var idx = items.count - 1
        while idx >= 0, unpinned > cap {
            if !items[idx].isPinned {
                deleteImageFile(of: items[idx])
                items.remove(at: idx)
                unpinned -= 1
            }
            idx -= 1
        }
    }

    private func deleteImageFile(of item: ClipItem) {
        guard let fn = item.imageFilename else { return }
        try? FileManager.default.removeItem(at: imagesDir.appendingPathComponent(fn))
    }

    /// 防抖存盘：0.5 秒内的多次变更合并为一次写盘
    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let snapshot = self.items
            let fileURL = self.fileURL
            self.ioQueue.async { Self.write(snapshot, to: fileURL) }
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func saveNow() {
        saveWork?.cancel()
        let snapshot = items
        ioQueue.sync { Self.write(snapshot, to: fileURL) }
    }

    private nonisolated static func write(_ snapshot: [ClipItem], to fileURL: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        items = (try? decoder.decode([ClipItem].self, from: data)) ?? []
    }
}
