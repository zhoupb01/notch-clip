// App/AppDelegate.swift
import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = ClipboardMonitor()
    private let hotKey = HotKeyManager()
    private var store: HistoryStore!
    private var viewModel: NotchViewModel!
    private var pasteService: PasteService!
    private var windowController: NotchWindowController!
    private var statusItemManager: StatusItemManager!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = HistoryStore()
        viewModel = NotchViewModel()
        pasteService = PasteService()
        windowController = NotchWindowController(viewModel: viewModel, store: store,
                                                 pasteService: pasteService, monitor: monitor)
        pasteService.onAccessibilityMissing = { [weak self] in
            self?.showAccessibilityAlert()
        }

        monitor.onNewItem = { [weak self] item, data in
            Task { @MainActor in
                guard let self else { return }
                let stored = self.store.add(item, imageData: data)
                self.viewModel.showHUD(stored)
            }
        }
        monitor.start()

        hotKey.onHotKey = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.viewModel.state == .panel {
                    self.windowController.closePanel()
                } else {
                    self.windowController.openPanel(byHover: false)
                }
            }
        }
        hotKey.register()

        statusItemManager = StatusItemManager(
            onOpenPanel: { [weak self] in self?.windowController.openPanel(byHover: false) },
            onClearHistory: { [weak self] in self?.confirmClearHistory() },
            onOpenSettings: { [weak self] in self?.openSettings() }
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        store?.saveNow()
    }

    private func confirmClearHistory() {
        let alert = NSAlert()
        alert.messageText = "清空剪贴板历史？"
        alert.informativeText = "固定的条目会保留，此操作不可撤销。"
        alert.addButton(withTitle: "清空")
        alert.addButton(withTitle: "取消")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            store.clearHistory()
        }
    }

    @MainActor
    private func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentRect: .zero,
                             styleMask: [.titled, .closable],
                             backing: .buffered, defer: false)
            w.title = "NotchClip 设置"
            w.contentView = NSHostingView(rootView: SettingsView())
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @MainActor
    private func showAccessibilityAlert() {
        guard !Settings.shared.didShowAccessibilityAlertThisLaunch else { return }
        Settings.shared.didShowAccessibilityAlertThisLaunch = true
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = "NotchClip 需要辅助功能权限才能把内容粘贴到其他应用。请在 系统设置 → 隐私与安全性 → 辅助功能 中勾选 NotchClip。"
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
        PasteService.promptAccessibilityIfNeeded()   // 顺带触发系统弹窗，方便用户直达
    }
}
