// UI/NotchPanel.swift
import AppKit

final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        // 决策 D2：高于菜单栏一层
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovable = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        animationBehavior = .none
    }

    // 无边框窗口默认不能成为 key；搜索框要打字，必须放开（坑 4）
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
