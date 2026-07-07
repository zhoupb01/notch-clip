// UI/NotchGeometry.swift
import AppKit

struct NotchGeometry {
    let screen: NSScreen
    let hasNotch: Bool
    /// 刘海矩形，全局屏幕坐标（原点在主屏左下角）
    let notchRect: NSRect

    static func detect() -> NotchGeometry {
        // 多显示器：优先选带刘海的内建屏，否则主屏（见 03 第 6 节）
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main ?? NSScreen.screens[0]
        let f = screen.frame

        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            // 刘海宽 = 屏宽 - 左右两块可用区域宽；高 = 顶部安全区
            let h = screen.safeAreaInsets.top
            let w = f.width - left.width - right.width
            let rect = NSRect(x: f.minX + left.width, y: f.maxY - h, width: w, height: h)
            #if DEBUG
            // 临时：真机上分别在「非全屏」「全屏」触发一次，核对两组是否不同（验证后删除）
            print("[NotchGeometry] frame=\(f) safeTop=\(screen.safeAreaInsets.top) left=\(left) right=\(right) notchRect=\(rect)")
            #endif
            return NotchGeometry(screen: screen, hasNotch: true, notchRect: rect)
        }
        // 无刘海降级：200×32 假刘海，贴顶居中（F10）
        let rect = NSRect(x: f.midX - 100, y: f.maxY - 32, width: 200, height: 32)
        return NotchGeometry(screen: screen, hasNotch: false, notchRect: rect)
    }
}
