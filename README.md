<div align="center">

# NotchClip

**常驻 MacBook 刘海的剪贴板历史工具**

平时完全隐形 · 复制时刘海给出反馈 · 呼出面板搜索并一键粘贴 · 数据全本地

![platform](https://img.shields.io/badge/platform-macOS-black)
![swift](https://img.shields.io/badge/Swift-6.0-orange)
![deps](https://img.shields.io/badge/dependencies-0-brightgreen)
![license](https://img.shields.io/badge/license-MIT-blue)

</div>

---

## 这是什么

macOS 自带剪贴板只保留最后一条,复制新内容就覆盖旧的。NotchClip 把剪贴板历史的入口搬进 MacBook 的刘海——那块平时用不上的黑色区域:

- **平时隐形**:不占任何屏幕空间,静默在后台记录你复制过的内容;
- **复制有反馈**:每次复制,刘海短暂展开约 1.2 秒,显示内容类型与摘要(类比 iPhone 灵动岛);
- **呼出即粘贴**:唤醒历史面板,即输即搜,点一下就把内容粘回你原来的应用;
- **数据全本地**:所有历史存在本机,不联网、无账号、无云同步。

无刘海的机器(外接屏、旧机型)会自动降级为「顶部居中悬浮条」,交互一致。

## 功能

| | 功能 | 说明 |
|---|---|---|
| 📋 | 剪贴板监听 | 后台轮询系统剪贴板,自动捕获新内容 |
| 🗂 | 历史存储 | 默认保留最近 500 条,本地持久化,重启不丢(可设 100 / 500 / 1000) |
| 🏷 | 类型识别 | 区分纯文本 / 链接 / 颜色值 / 图片 / 文件,图标区分显示 |
| ✨ | 三态交互 | 常态(隐形)· HUD 反馈态 · 面板态 |
| 🔑 | 两种唤醒方式 | **鼠标移到刘海** 或 **快捷键 ⌘⇧V**,设置里二选一 |
| 🔍 | 即输即搜 | 面板内输入关键字实时过滤 |
| 🖱 | 点击粘贴 | 点选历史条目即粘贴,全程不抢占目标应用焦点 |
| 📌 | 固定(Pin) | 常用片段固定在列表顶部,不被条数上限淘汰 |
| 🔒 | 隐私过滤 | 自动跳过密码管理器等标记为机密 / 临时的剪贴内容 |
| 🚫 | 应用排除 | 按 Bundle ID 排除指定应用(如终端、密码管理器) |
| ⚙️ | 状态栏菜单 | 打开面板 / 清空历史 / 设置 / 退出 |
| 🚀 | 开机自启 | 可选,基于 `SMAppService` |

## 唤醒方式

灵动岛的唤醒支持两种模式,在 **设置 → 唤醒方式** 中切换,任一时刻只有一种生效:

- **鼠标移到刘海**(默认):鼠标甩到刘海上停留一瞬,面板自动展开;移出片刻自动收起。零快捷键、零记忆负担,是灵动岛的原生交互。
- **快捷键 ⌘⇧V**:按下呼出面板,再按或 `Esc` 收起。适合不喜欢误触、偏好显式操作的人;此模式下不占用系统的悬停行为。

> 快捷键只负责唤醒面板,粘贴一律通过鼠标点击完成。

## 安装

### 方式一:下载 DMG(推荐给普通用户)

到 [Releases](https://github.com/zhoupb01/notch-clip/releases) 下载 `NotchClip-*.dmg`,双击后把 NotchClip 拖进 Applications 即可。

> ⚠️ 本项目使用 ad-hoc 签名(无 Apple 开发者账号),首次打开需 **右键 → 打开**,或到 系统设置 → 隐私与安全性 里点「仍要打开」。

### 方式二:从源码一键构建安装

```bash
git clone https://github.com/zhoupb01/notch-clip.git
cd notch-clip
brew install xcodegen        # 唯一的构建期依赖
bun run install:app          # 生成工程 → Release 构建 → 安装到 /Applications 并启动
```

首次运行需在 **系统设置 → 隐私与安全性 → 辅助功能** 中勾选 NotchClip(用于模拟 ⌘V 把内容粘贴到其他应用)。

## 从源码开发

本项目**零第三方运行时依赖**,仅使用系统框架;Xcode 工程由 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 从 `project.yml` 生成,不入库。

**环境要求**

- macOS 26 (Tahoe) 或更新 —— 部署目标定在 macOS 26;若要支持更旧系统,改 `project.yml` 里的 `deploymentTarget` 即可(源码只用标准框架,无版本壁垒)
- Xcode 26+(需 macOS 26 SDK 与 Swift 6)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen):`brew install xcodegen`
- [Bun](https://bun.sh)(可选,仅用于跑 `package.json` 里的脚本;也可换成 `npm run` 或直接执行对应命令)

**常用命令**

```bash
bun run project:generate   # 由 project.yml 生成 NotchClip.xcodeproj
bun run build              # 生成工程并做 Debug 构建
bun run typecheck          # 仅类型检查(swiftc -typecheck)
bun run install:app        # Release 构建并安装到 /Applications
bun run dmg                # 打包可分发 DMG(含 Applications 拖拽软链接)
bun run icons              # 从源图生成全套 App 图标
```

生成的工程用 Xcode 打开也行,但**不要手动编辑或提交 `.xcodeproj`**——`project.yml` 是唯一真相源。

**签名**:默认 ad-hoc(`Config/Signing.xcconfig`,`CODE_SIGN_IDENTITY = -`)。要用自己的开发者证书,复制 `Config/LocalSigning.xcconfig.example` 为 `Config/LocalSigning.xcconfig` 并填入(该文件已被忽略,不入库)。

## 技术栈

纯系统框架,无任何第三方运行时依赖:

- **AppKit + SwiftUI** —— 刘海窗口(`NSPanel`)与三态视图
- **Foundation** —— 历史持久化(JSON + images/)
- **Carbon.HIToolbox** —— 全局快捷键 ⌘⇧V
- **ServiceManagement** —— 开机自启

数据目录:`~/Library/Application Support/NotchClip/`(`history.json` + `images/`),不产生任何网络请求。

## 项目结构

```
NotchClip/
├── App/          # 应用生命周期:AppDelegate、全局快捷键、状态栏菜单
├── Core/         # 无 UI 内核:剪贴板监听、历史存储、粘贴、隐私过滤、设置
├── UI/           # 刘海窗口与三态视图、面板、设置页
└── Resources/    # Assets(App 图标等)
Config/           # 签名配置
scripts/          # 构建 / 安装 / 打包 DMG / 生成图标
docs/             # 设计文档(PRD、架构、交互规范、实现指南)
project.yml       # XcodeGen 工程定义(唯一真相源)
```

设计与决策细节见 [`docs/`](docs/):产品需求、架构设计、交互与视觉规范、逐里程碑实现指南。

## 致谢

设计思路借鉴了几个优秀的开源 / 商业项目,各取其成熟部分:

- [**Maccy**](https://github.com/p0deje/Maccy) —— 剪贴板内核思路:`changeCount` 轮询、隐私标记过滤、模拟 ⌘V 粘贴
- [**boring.notch**](https://github.com/TheBoredTeam/boring.notch) —— 刘海窗口壳:面板层级、刘海几何、展开 / 收起形态
- **Vibe Island / NotchDrop** —— 灵动岛式三态交互与无刘海降级方案

## 许可证

[MIT](LICENSE)
