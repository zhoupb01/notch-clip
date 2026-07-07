// UI/SettingsView.swift
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var wakeMode = Settings.shared.wakeMode
    @State private var maxItems = Settings.shared.maxItems
    @State private var excluded = Settings.shared.excludedBundleIDs.sorted().joined(separator: "\n")
    @State private var launchAtLogin = (SMAppService.mainApp.status == .enabled)

    /// 版本号来自 Info.plist（由 project.yml 的 MARKETING_VERSION / CURRENT_PROJECT_VERSION 生成）
    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    var body: some View {
        Form {
            Picker("唤醒方式", selection: $wakeMode) {
                Text("鼠标移到刘海").tag(Settings.WakeMode.hover)
                Text("快捷键 ⌘⇧V").tag(Settings.WakeMode.hotKey)
            }
            .onChange(of: wakeMode) {
                Settings.shared.wakeMode = wakeMode
                NotificationCenter.default.post(name: Settings.wakeModeDidChange, object: nil)
            }

            Picker("历史条数上限", selection: $maxItems) {
                Text("100").tag(100)
                Text("500").tag(500)
                Text("1000").tag(1000)
            }
            .onChange(of: maxItems) { Settings.shared.maxItems = maxItems }

            Toggle("开机自动启动", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) {
                    if launchAtLogin { try? SMAppService.mainApp.register() }
                    else { try? SMAppService.mainApp.unregister() }
                }

            Section("排除的应用（每行一个 Bundle ID，例如 com.apple.Terminal）") {
                TextEditor(text: $excluded)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(height: 120)
                    .onChange(of: excluded) {
                        let ids = excluded.split(separator: "\n")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        Settings.shared.excludedBundleIDs = Set(ids)
                    }
            }

            LabeledContent("版本", value: versionText)
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 380)
    }
}
