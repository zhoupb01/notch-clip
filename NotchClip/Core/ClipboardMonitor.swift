// Core/ClipboardMonitor.swift
import AppKit

enum ClipImage: Sendable {
    case png(Data), tiff(Data)
}

@MainActor
final class ClipboardMonitor {
    /// 新内容回调。第二个参数仅当 type == .image 时非空，是原始图片数据，交给存储层处理
    var onNewItem: ((ClipItem, ClipImage?) -> Void)?

    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount

    func start() {
        stop()
        // Timer 挂在主 RunLoop，回调必然在主线程；跳回主 actor 调 tick
        let t = Timer(timeInterval: 0.3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        t.tolerance = 0.1
        // 必须加到 .common 模式，否则菜单打开/滚动时定时器会停摆（坑 5）
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// 决策 D5：PasteService 写回后立即调用，将这次写入视为已读
    func skipOwnWrite() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    private func tick() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        if PrivacyFilter.shouldIgnore(pb, excludedBundleIDs: Settings.shared.excludedBundleIDs) {
            return
        }
        guard let (item, image) = Self.parse(pb) else { return }
        onNewItem?(item, image)
    }

    /// 类型判定顺序（决策见 02 第 3 节）：文件 → 图片 → 字符串（颜色 → 链接 → 文本）
    static func parse(_ pb: NSPasteboard) -> (ClipItem, ClipImage?)? {
        let front = NSWorkspace.shared.frontmostApplication

        func makeItem(_ type: ClipItemType, text: String?) -> ClipItem {
            ClipItem(id: UUID(), type: type, text: text, imageFilename: nil,
                     sourceAppBundleID: front?.bundleIdentifier,
                     sourceAppName: front?.localizedName,
                     createdAt: Date())
        }

        // 1) 文件引用
        if let urls = pb.readObjects(forClasses: [NSURL.self],
                                     options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let first = urls.first {
            return (makeItem(.file, text: first.path), nil)
        }

        // 2) 图片：优先 PNG，其次 TIFF，保留原始数据
        if let png = pb.data(forType: .png) {
            return (makeItem(.image, text: nil), .png(png))
        }
        if let tiff = pb.data(forType: .tiff) {
            return (makeItem(.image, text: nil), .tiff(tiff))
        }

        // 3) 字符串
        if let raw = pb.string(forType: .string) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            // 3a) 颜色：#RGB / #RRGGBB / #RRGGBBAA
            if trimmed.range(of: "^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$",
                             options: .regularExpression) != nil {
                return (makeItem(.color, text: trimmed), nil)
            }
            // 3b) 链接：能解析且 scheme 为 http/https，且不含空白
            if !trimmed.contains(where: { $0.isWhitespace }),
               let url = URL(string: trimmed),
               let scheme = url.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                return (makeItem(.link, text: raw), nil)
            }
            // 3c) 普通文本（存原文 raw，不存 trimmed）
            return (makeItem(.text, text: raw), nil)
        }
        return nil
    }
}
