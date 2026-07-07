// NotchClipApp.swift
import SwiftUI

@main
struct NotchClipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 不需要主窗口；留一个空的 Settings scene 满足 App 协议。
        // 注意：Core/Settings 类与 SwiftUI.Settings 场景同名，这里显式限定为 SwiftUI.Settings。
        SwiftUI.Settings { EmptyView() }
    }
}
