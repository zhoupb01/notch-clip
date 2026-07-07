// App/StatusItemManager.swift
import AppKit

@MainActor
final class StatusItemManager: NSObject {
    private var statusItem: NSStatusItem!
    private let onOpenPanel: () -> Void
    private let onClearHistory: () -> Void
    private let onOpenSettings: () -> Void

    init(onOpenPanel: @escaping () -> Void,
         onClearHistory: @escaping () -> Void,
         onOpenSettings: @escaping () -> Void) {
        self.onOpenPanel = onOpenPanel
        self.onClearHistory = onClearHistory
        self.onOpenSettings = onOpenSettings
        super.init()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "doc.on.clipboard",
                                           accessibilityDescription: "NotchClip")

        let menu = NSMenu()
        menu.addItem(withTitle: "打开面板", action: #selector(openPanel), keyEquivalent: "")
        menu.addItem(withTitle: "清空历史…", action: #selector(clearHistory), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "设置…", action: #selector(openSettings), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 NotchClip", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        statusItem.menu = menu
    }

    @objc private func openPanel() { onOpenPanel() }
    @objc private func clearHistory() { onClearHistory() }
    @objc private func openSettings() { onOpenSettings() }
    @objc private func quit() { NSApp.terminate(nil) }
}
