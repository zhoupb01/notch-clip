// Core/HistoryStore.swift
import AppKit
import Combine

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var items: [ClipItem] = []

    private let baseDir: URL
    private let fileURL: URL
    let imagesDir: URL
    private var saveWork: DispatchWorkItem?

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask)[0]
        baseDir = appSupport.appendingPathComponent("NotchClip", isDirectory: true)
        fileURL = baseDir.appendingPathComponent("history.json")
        imagesDir = baseDir.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        load()
    }

    // MARK: 写入

    /// 返回实际入库的条目（可能是被上移刷新的旧条目）。M4 的 HUD 必须用这个返回值，
    /// 因为图片条目的 imageFilename 是在这里才写入的
    @discardableResult
    func add(_ newItem: ClipItem, imageData: Data?) -> ClipItem {
        var item = newItem

        // 去重（非图片）：内容相同的旧条目上移刷新时间
        if item.type != .image,
           let idx = items.firstIndex(where: { $0.type == item.type && $0.text == item.text }) {
            var existing = items.remove(at: idx)
            existing.createdAt = Date()
            items.insert(existing, at: 0)
            scheduleSave()
            return existing
        }
        // 去重（图片）：仅与最新一条图片比对字节，相同则上移
        if item.type == .image, let data = imageData,
           let first = items.first, first.type == .image,
           let fn = first.imageFilename,
           let old = try? Data(contentsOf: imagesDir.appendingPathComponent(fn)),
           old == data {
            var f = items.removeFirst()
            f.createdAt = Date()
            items.insert(f, at: 0)
            scheduleSave()
            return f
        }
        // 图片落盘
        if item.type == .image, let data = imageData {
            let name = item.id.uuidString + ".png"
            try? data.write(to: imagesDir.appendingPathComponent(name))
            item.imageFilename = name
        }
        items.insert(item, at: 0)
        trim()
        scheduleSave()
        return item
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
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func saveNow() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        items = (try? decoder.decode([ClipItem].self, from: data)) ?? []
    }
}
