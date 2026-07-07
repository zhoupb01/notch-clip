// Core/PasteService.swift
import AppKit

@MainActor
final class PasteService {
    private(set) var previousApp: NSRunningApplication?
    /// 辅助功能权限缺失时回调（AppDelegate 用它弹引导，每次启动最多一次）
    var onAccessibilityMissing: (() -> Void)?

    /// 打开面板前必须调用：记录当前前台应用（决策 D4）
    func rememberFrontmostApp() {
        previousApp = NSWorkspace.shared.frontmostApplication
    }

    /// 把焦点还给原应用。activateIgnoringOtherApps 在 macOS 14 标记废弃，
    /// 但仍然可用且行为正确——编译警告可接受，不要为消除警告改用其他 API
    func restoreFocus() {
        previousApp?.activate(options: [.activateIgnoringOtherApps])
    }

    /// 完整粘贴流程。调用方必须【先】把面板状态切回 idle 再调它（决策 D4，坑 1）
    func paste(_ item: ClipItem, imagesDir: URL, monitor: ClipboardMonitor) {
        writeToPasteboard(item, imagesDir: imagesDir, monitor: monitor)
        restoreFocus()
        guard AXIsProcessTrusted() else {
            // 退化：内容已写入剪贴板，用户可手动 ⌘V
            onAccessibilityMissing?()
            return
        }
        // 给系统 150ms 完成焦点切换后再发按键
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            Self.sendCmdV()
        }
    }

    private func writeToPasteboard(_ item: ClipItem, imagesDir: URL, monitor: ClipboardMonitor) {
        let pb = NSPasteboard.general
        monitor.ignoreNextChange = true   // 决策 D5（坑 2）
        pb.clearContents()
        switch item.type {
        case .text, .link, .color:
            pb.setString(item.text ?? "", forType: .string)
        case .file:
            if let path = item.text {
                // 注：文档原文的 NSURL.fileURL(withPath:) 返回 Swift URL，不符合 NSPasteboardWriting；
                // 改用 NSURL(fileURLWithPath:) 得到符合协议的 NSURL，行为一致（往剪贴板写文件 URL）
                pb.writeObjects([NSURL(fileURLWithPath: path)])
            }
        case .image:
            if let fn = item.imageFilename,
               let data = try? Data(contentsOf: imagesDir.appendingPathComponent(fn)) {
                pb.setData(data, forType: .png)
            }
        }
    }

    /// 模拟 ⌘V。虚拟键码 kVK_ANSI_V = 9，不要改
    private static func sendCmdV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }

    /// 触发系统级授权弹窗（应用首次启动时调用一次即可）
    static func promptAccessibilityIfNeeded() {
        // kAXTrustedCheckOptionPrompt 作为导入的全局 var 在 Swift 6 下不满足并发安全；
        // 其值为文档固定的键字符串，直接用字面量等价且无副作用
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }
}
