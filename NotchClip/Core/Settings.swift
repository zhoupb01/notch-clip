// Core/Settings.swift
import Foundation

// UserDefaults 本身线程安全，唯一的可变内存态 didShowAccessibilityAlertThisLaunch 仅在主线程读写，
// 因此标记 @unchecked Sendable 以满足 Swift 6 并发检查
final class Settings: @unchecked Sendable {
    static let shared = Settings()
    private let d = UserDefaults.standard

    /// 灵动岛唤醒方式，二选一
    enum WakeMode: String, CaseIterable {
        case hover    // 鼠标移到刘海
        case hotKey   // 快捷键 ⌘⇧V
    }

    /// 唤醒方式变更后广播，AppDelegate 据此实时切换快捷键/悬停
    static let wakeModeDidChange = Notification.Name("NotchClip.wakeModeDidChange")

    /// 唤醒方式，默认悬停（灵动岛原生交互）
    var wakeMode: WakeMode {
        get { WakeMode(rawValue: d.string(forKey: "wakeMode") ?? "") ?? .hover }
        set { d.set(newValue.rawValue, forKey: "wakeMode") }
    }

    /// 历史条数上限，允许值 100/500/1000，默认 500
    var maxItems: Int {
        get { let v = d.integer(forKey: "maxItems"); return v == 0 ? 500 : v }
        set { d.set(newValue, forKey: "maxItems") }
    }

    /// 排除应用的 Bundle ID 集合
    var excludedBundleIDs: Set<String> {
        get { Set(d.stringArray(forKey: "excludedBundleIDs") ?? []) }
        set { d.set(Array(newValue).sorted(), forKey: "excludedBundleIDs") }
    }

    /// 「本次启动是否已弹过辅助功能引导」——不落盘，进程级标志
    var didShowAccessibilityAlertThisLaunch = false
}
