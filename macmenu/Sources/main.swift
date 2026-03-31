import AppKit
import Foundation
import ServiceManagement

// MARK: - 预设厂商数据（可序列化，支持持久化到 providers.json）
struct PresetProvider: Codable {
    var name: String       // 厂商显示名称
    var baseUrl: String    // API Base URL
    var models: [String]   // 支持的模型 ID 列表
}

// MARK: - 内置默认预设厂商列表（首次运行写入 providers.json，后续从文件读取）
private let DEFAULT_PRESET_PROVIDERS: [PresetProvider] = [
    PresetProvider(
        name: "Anthropic 官方",
        baseUrl: "https://api.anthropic.com",
        models: ["claude-sonnet-4-6", "claude-opus-4-5", "claude-haiku-3-5"]
    ),
    PresetProvider(
        name: "DashScope（阿里云）",
        baseUrl: "https://dashscope.aliyuncs.com/compatible-mode/v1",
        models: ["qwen-plus", "qwen-max", "qwen-turbo"]
    ),
    PresetProvider(
        name: "Gemini（Google AI）",
        baseUrl: "https://generativelanguage.googleapis.com/v1beta",
        models: ["gemini-3.1-pro", "gemini-3.1-flash", "gemini-2.5-flash"]
    ),
    PresetProvider(
        name: "Kimi（Moonshot AI）",
        baseUrl: "https://api.moonshot.cn/v1",
        models: ["moonshot-v1-8k", "moonshot-v1-32k", "moonshot-v1-128k", "kimi-k2", "kimi-k2.5"]
    ),
    PresetProvider(
        name: "MiniMax",
        baseUrl: "https://api.minimaxi.com/anthropic",
        models: ["MiniMax-M2.7-highspeed", "MiniMax-M2.7", "MiniMax-M2.5-highspeed", "MiniMax-M2.5"]
    ),
    PresetProvider(
        name: "OpenAI 官方",
        baseUrl: "https://api.openai.com/v1",
        models: ["gpt-4.5", "gpt-4.1-mini", "gpt-4.1-nano"]
    ),
    PresetProvider(
        name: "OpenRouter",
        baseUrl: "https://openrouter.ai/api/v1",
        models: ["anthropic/claude-sonnet-4-6", "anthropic/claude-opus-4-5", "openai/gpt-4.5"]
    ),
    PresetProvider(
        name: "Zhipu AI (GLM)",
        baseUrl: "https://open.bigmodel.cn/api/paas/v4",
        models: ["glm-4-plus", "glm-5", "glm-z1-flash"]
    )
]

// MARK: - 模型配置项
struct ModelItem: Codable, Identifiable {
    var id: String
    var name: String
    var baseUrl: String
    var apiToken: String
    var modelId: String
    var isActive: Bool

    var isValid: Bool { !name.isEmpty && !baseUrl.isEmpty && !modelId.isEmpty }

    static var defaultMiniMax: ModelItem {
        ModelItem(id: "default-minimax", name: "MiniMax",
                  baseUrl: "https://api.minimaxi.com/anthropic",
                  apiToken: "", modelId: "MiniMax-M2.7-highspeed", isActive: true)
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var models: [ModelItem] = []
    private let configDir: URL
    private let configPath: URL
    private let settingsPath: URL
    private var defaultToken: String = ""

    // 添加/编辑表单控件
    private var sheetNameField: NSTextField!
    private var sheetUrlField: NSTextField!
    private var sheetTokenField: NSTextField!
    private var sheetModelField: NSTextField!
    private var sheetProviderPopup: NSPopUpButton!
    private var sheetModelPopup: NSPopUpButton!
    private var sheetEditingId: String?
    private var sheetPanel: NSPanel!

    // 上次选择的 Claude Code 项目目录（存储在 settings.json）
    private var lastProjectPath: String = ""
    // 是否开机自启动（存储在 settings.json）
    private var launchAtLogin: Bool = false
    // 预设厂商列表（从 providers.json 加载）
    private var presetProviders: [PresetProvider] = []
    // 当前预设厂商下拉选中的索引（-1=自定义，0+=presetProviders索引）
    private var sheetSelectedProviderIdx: Int = -1

    override init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        configDir = home.appendingPathComponent(".claude/model-switcher")
        configPath = configDir.appendingPathComponent("models.json")
        settingsPath = home.appendingPathComponent(".claude/settings.json")
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 多实例保护
        let bid = Bundle.main.bundleIdentifier ?? ""
        if !bid.isEmpty && NSRunningApplication.runningApplications(withBundleIdentifier: bid).count > 1 {
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)

        // 设置 App 图标（🧠 图案）
        setupAppIcon()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let btn = statusItem.button {
            btn.title = "🤖 Claude"
            btn.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        ensureConfigDir()
        loadDefaultToken()
        loadPreferences()
        loadPresetProviders()
        loadModels()

        if let active = models.first(where: { $0.isActive }) {
            statusItem.button?.title = "🤖 \(active.name)"
        }
    }

    // MARK: - App 图标设置（蓝色白字 C）
    private func setupAppIcon() {
        let size = NSSize(width: 128, height: 128)
        let icon = NSImage(size: size, flipped: false) { rect in
            // 蓝色渐变背景
            let colors = [NSColor(red: 0.15, green: 0.45, blue: 0.98, alpha: 1.0),
                          NSColor(red: 0.25, green: 0.20, blue: 0.95, alpha: 1.0)]
            let gradient = NSGradient(colors: colors)
            let cpath = NSBezierPath(roundedRect: rect, xRadius: 28, yRadius: 28)
            gradient?.draw(in: cpath, angle: 135)

            // 白色字母 C
            let para = NSMutableParagraphStyle()
            para.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 80, weight: .bold),
                .foregroundColor: NSColor.white,
                .paragraphStyle: para
            ]
            let C = "C"
            C.draw(in: rect.insetBy(dx: 8, dy: rect.height * 0.12), withAttributes: attrs)
            return true
        }
        NSApp.applicationIconImage = icon
    }

    private func ensureConfigDir() {
        if !FileManager.default.fileExists(atPath: configDir.path) {
            try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        }
    }

    // App 配置存储路径（~/.claude/model-switcher/settings.json）
    private var appSettingsPath: URL {
        configDir.appendingPathComponent("settings.json")
    }

    // 预设厂商列表存储路径（~/.claude/model-switcher/providers.json）
    private var providersURL: URL {
        configDir.appendingPathComponent("providers.json")
    }

    // 从 providers.json 加载预设厂商列表；文件不存在时写入默认列表
    private func loadPresetProviders() {
        if FileManager.default.fileExists(atPath: providersURL.path) {
            do {
                let data = try Data(contentsOf: providersURL)
                presetProviders = try JSONDecoder().decode([PresetProvider].self, from: data)
            } catch {
                print("Load providers failed, using defaults: \(error)")
                presetProviders = DEFAULT_PRESET_PROVIDERS
                savePresetProviders()
            }
        } else {
            presetProviders = DEFAULT_PRESET_PROVIDERS
            savePresetProviders()
        }
    }

    private func savePresetProviders() {
        do {
            let data = try JSONEncoder().encode(presetProviders)
            try data.write(to: providersURL, options: .atomic)
        } catch {
            print("Save providers failed: \(error)")
        }
    }

    // 从 model-switcher/settings.json 加载 launchAtLogin 和 lastProjectPath
    private func loadPreferences() {
        guard FileManager.default.fileExists(atPath: appSettingsPath.path) else { return }
        do {
            let data = try Data(contentsOf: appSettingsPath)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                launchAtLogin = json["launchAtLogin"] as? Bool ?? false
                lastProjectPath = json["lastProjectPath"] as? String ?? ""
            }
        } catch { }
    }

    // 将 launchAtLogin 和 lastProjectPath 写入 model-switcher/settings.json
    private func savePreferences() {
        let json: [String: Any] = [
            "launchAtLogin": launchAtLogin,
            "lastProjectPath": lastProjectPath
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: appSettingsPath, options: .atomic)
        } catch {
            print("Save preferences failed: \(error)")
        }
    }

    private func loadLastProjectPath() {
        // lastProjectPath 已由 loadPreferences() 加载
    }

    private func saveLastProjectPath(_ path: String) {
        lastProjectPath = path
        savePreferences()
    }

    private func loadDefaultToken() {
        guard FileManager.default.fileExists(atPath: settingsPath.path) else { return }
        do {
            let data = try Data(contentsOf: settingsPath)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let env = json["env"] as? [String: Any],
               let token = env["ANTHROPIC_AUTH_TOKEN"] as? String, !token.isEmpty {
                defaultToken = token
            }
        } catch { }
    }

    private func loadModels() {
        if !FileManager.default.fileExists(atPath: configPath.path) {
            var dm = ModelItem.defaultMiniMax
            dm.apiToken = defaultToken
            models = [dm]
            saveModels()
            return
        }

        do {
            let data = try Data(contentsOf: configPath)
            models = try JSONDecoder().decode([ModelItem].self, from: data)
        } catch {
            var dm = ModelItem.defaultMiniMax
            dm.apiToken = defaultToken
            models = [dm]
            saveModels()
            return
        }

        if models.isEmpty {
            var dm = ModelItem.defaultMiniMax
            dm.apiToken = defaultToken
            models = [dm]
            saveModels()
        }

        for i in 0..<models.count where models[i].apiToken.isEmpty && !defaultToken.isEmpty {
            models[i].apiToken = defaultToken
        }

        let actives = models.filter { $0.isActive }
        if actives.isEmpty {
            models[0].isActive = true
            saveModels()
        } else if actives.count > 1 {
            for i in 0..<models.count { models[i].isActive = (i == 0) }
            saveModels()
        }
    }

    private func saveModels() {
        do {
            let data = try JSONEncoder().encode(models)
            try data.write(to: configPath, options: .atomic)
        } catch { print("Save failed: \(error)") }
    }

    // MARK: - 菜单构建
    func menuWillOpen(_ menu: NSMenu) {
        loadModels()
        buildMenu(menu)
    }

    private func buildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        for model in models {
            let title = model.isActive ? "✓ \(model.name)" : "   \(model.name)"
            let item = NSMenuItem(title: title, action: #selector(selectModel(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = model
            item.isEnabled = model.isValid
            if !model.isValid { item.title = "⚠️ \(model.name) (配置不完整)" }
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let addItem = NSMenuItem(title: "添加模型...", action: #selector(addModel), keyEquivalent: "")
        addItem.target = self
        menu.addItem(addItem)

        if !models.isEmpty {
            let editItem = NSMenuItem(title: "编辑 / 删除模型...", action: #selector(editModels), keyEquivalent: "")
            editItem.target = self
            menu.addItem(editItem)
        }

        menu.addItem(NSMenuItem.separator())

        if let active = models.first(where: { $0.isActive }) {
            let info = NSMenuItem(title: "当前: \(active.name) / \(active.modelId)", action: nil, keyEquivalent: "")
            info.isEnabled = false
            menu.addItem(info)
            menu.addItem(NSMenuItem.separator())
        }

        let launchItem = NSMenuItem(title: "启动 Claude Code ->", action: #selector(launchClaude), keyEquivalent: "")
        if !lastProjectPath.isEmpty {
            let displayPath = (lastProjectPath as NSString).lastPathComponent
            launchItem.title = "启动 Claude Code: \(displayPath)"
        }
        launchItem.target = self
        menu.addItem(launchItem)
        menu.addItem(NSMenuItem.separator())

        // 开机自启动开关
        let loginItem = NSMenuItem(title: launchAtLogin ? "✓ 开机自启动" : "   开机自启动",
                                   action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "退出 Claude Switch", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func selectModel(_ sender: NSMenuItem) {
        guard var model = sender.representedObject as? ModelItem else { return }
        if model.apiToken.isEmpty { model.apiToken = defaultToken }
        applyModel(model)
        statusItem.button?.title = "🤖 \(model.name)"
        launchTerminal()
    }

    private func applyModel(_ model: ModelItem) {
        let settings: [String: Any] = [
            "env": [
                "ANTHROPIC_BASE_URL": model.baseUrl,
                "ANTHROPIC_AUTH_TOKEN": model.apiToken,
                "ANTHROPIC_MODEL": model.modelId,
                "API_TIMEOUT_MS": "300000",
                "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": 1
            ]
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: settingsPath, options: .atomic)
        } catch {
            showError("写入配置失败: \(error.localizedDescription)")
            return
        }
        for i in 0..<models.count {
            models[i].isActive = (models[i].id == model.id)
            if models[i].id == model.id { models[i] = model }
        }
        saveModels()
    }

    // MARK: - 添加/编辑
    @objc private func addModel() { showSheet(mode: .add, existing: nil) }
    @objc private func editModels() { showSheet(mode: .edit, existing: models.first(where: { $0.isActive }) ?? models.first) }

    private enum SheetMode { case add, edit }

    private func showSheet(mode: SheetMode, existing: ModelItem?) {
        sheetEditingId = existing?.id
        sheetSelectedProviderIdx = -1

        // 面板高度：添加模式 510，编辑模式 510
        let panelH: CGFloat = 510
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: panelH),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        panel.title = mode == .add ? "添加模型" : "编辑模型"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.becomesKeyOnlyIfNeeded = true
        sheetPanel = panel

        let vw = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: panelH))
        panel.contentView = vw

        let pad: CGFloat = 20
        let lw: CGFloat = 100
        let fw: CGFloat = 340
        let fh: CGFloat = 24
        let gy: CGFloat = 38
        let startY: CGFloat = 470

        // 第1行：预设厂商下拉框
        let providerLbl = NSTextField(labelWithString: "预设厂商:")
        providerLbl.frame = NSRect(x: pad, y: startY + 2, width: lw, height: fh)
        providerLbl.alignment = .right
        vw.addSubview(providerLbl)

        sheetProviderPopup = NSPopUpButton(frame: NSRect(x: pad + lw + 8, y: startY, width: fw, height: fh))
        sheetProviderPopup.addItem(withTitle: "- 自定义（手动输入URL） -")
        for p in presetProviders {
            sheetProviderPopup.addItem(withTitle: p.name)
        }
        sheetProviderPopup.target = self
        sheetProviderPopup.action = #selector(providerPopupChanged(_:))
        vw.addSubview(sheetProviderPopup)

        // 第2行：名称
        let nameLbl = NSTextField(labelWithString: "名称:")
        nameLbl.frame = NSRect(x: pad, y: startY - gy + 2, width: lw, height: fh)
        nameLbl.alignment = .right
        vw.addSubview(nameLbl)

        sheetNameField = NSTextField()
        sheetNameField.frame = NSRect(x: pad + lw + 8, y: startY - gy, width: fw, height: fh)
        sheetNameField.placeholderString = "例如: MiniMax、GLM-4、Kimi"
        sheetNameField.stringValue = existing?.name ?? ""
        vw.addSubview(sheetNameField)

        // 第3行：Base URL
        let urlLbl = NSTextField(labelWithString: "Base URL:")
        urlLbl.frame = NSRect(x: pad, y: startY - gy * 2 + 2, width: lw, height: fh)
        urlLbl.alignment = .right
        vw.addSubview(urlLbl)

        sheetUrlField = NSTextField()
        sheetUrlField.frame = NSRect(x: pad + lw + 8, y: startY - gy * 2, width: fw, height: fh)
        sheetUrlField.placeholderString = "https://api.xxx.com/anthropic"
        sheetUrlField.stringValue = existing?.baseUrl ?? ""
        vw.addSubview(sheetUrlField)

        // 第4行：API Token（多行，5行高度）
        let tokenLbl = NSTextField(labelWithString: "API Token:")
        tokenLbl.frame = NSRect(x: pad, y: startY - gy * 3 + 2, width: lw, height: fh)
        tokenLbl.alignment = .right
        vw.addSubview(tokenLbl)

        let tokenFieldH: CGFloat = 110  // 5行高度
        // 添加模式：Token 默认为空；编辑模式：显示已有 Token（空时用全局 Token 填充）
        let existingToken = (mode == .add) ? "" : ((existing?.apiToken ?? "").isEmpty ? defaultToken : (existing?.apiToken ?? ""))
        sheetTokenField = NSTextField()
        sheetTokenField.frame = NSRect(x: pad + lw + 8, y: startY - gy * 3 - tokenFieldH + fh, width: fw, height: tokenFieldH)
        sheetTokenField.placeholderString = "sk-... (留空使用全局Token)"
        sheetTokenField.stringValue = existingToken
        sheetTokenField.cell?.wraps = true
        sheetTokenField.cell?.isScrollable = false
        sheetTokenField.isEditable = true
        sheetTokenField.isBordered = true
        sheetTokenField.font = NSFont.systemFont(ofSize: 12)
        vw.addSubview(sheetTokenField)

        // 第5行：模型 ID
        let modelLbl = NSTextField(labelWithString: "模型 ID:")
        modelLbl.frame = NSRect(x: pad, y: startY - gy * 4 - tokenFieldH + fh + 4, width: lw, height: fh)
        modelLbl.alignment = .right
        vw.addSubview(modelLbl)

        sheetModelField = NSTextField()
        sheetModelField.frame = NSRect(x: pad + lw + 8, y: startY - gy * 4 - tokenFieldH + fh + 4, width: fw - 100, height: fh)
        sheetModelField.placeholderString = "例如: MiniMax-M2.7-highspeed"
        sheetModelField.stringValue = existing?.modelId ?? ""
        vw.addSubview(sheetModelField)

        // 模型 ID 快捷下拉（先以自定义模式初始化，后续会根据匹配结果重建）
        let modelPopupX = pad + lw + 8 + fw - 96
        let modelPopupY = startY - gy * 4 - tokenFieldH + fh + 4
        sheetModelPopup = NSPopUpButton(frame: NSRect(x: modelPopupX, y: modelPopupY, width: 96, height: fh))
        sheetModelPopup.target = self
        sheetModelPopup.action = #selector(modelPopupChanged(_:))
        vw.addSubview(sheetModelPopup)

        // 如果现有配置匹配某个预设厂商，自动选中它并重建模型下拉
        var matchedProviderIdx = -1
        if let existingUrl = existing?.baseUrl, !existingUrl.isEmpty {
            for (idx, p) in presetProviders.enumerated() {
                if p.baseUrl == existingUrl {
                    sheetProviderPopup.selectItem(at: idx + 1)
                    sheetSelectedProviderIdx = idx
                    matchedProviderIdx = idx
                    break
                }
            }
        }
        rebuildModelPopup(idx: matchedProviderIdx, selectedModelId: existing?.modelId)

        // 提示文字
        let hintLbl = NSTextField(labelWithString: "")
        hintLbl.frame = NSRect(x: pad, y: 58, width: 440, height: 30)
        hintLbl.font = NSFont.systemFont(ofSize: 11)
        hintLbl.textColor = .secondaryLabelColor
        hintLbl.stringValue = "提示: 选择预设厂商可自动填充 Base URL 和模型下拉列表。Token 留空使用全局 Token。"
        hintLbl.lineBreakMode = .byWordWrapping
        vw.addSubview(hintLbl)

        // 按钮
        let by: CGFloat = 14

        let saveBtn = NSButton(title: mode == .add ? "添加" : "保存", target: self, action: #selector(sheetSave(_:)))
        saveBtn.bezelStyle = .rounded
        saveBtn.frame = NSRect(x: 480 - pad - 160, y: by, width: 70, height: 28)
        saveBtn.keyEquivalent = "\r"
        saveBtn.tag = mode == .add ? 100 : 200
        vw.addSubview(saveBtn)

        let cancelBtn = NSButton(title: "取消", target: self, action: #selector(sheetCancel(_:)))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.frame = NSRect(x: 480 - pad - 80, y: by, width: 60, height: 28)
        cancelBtn.keyEquivalent = "\u{1b}"
        vw.addSubview(cancelBtn)

        if mode == .edit {
            let delBtn = NSButton(title: "删除此模型", target: self, action: #selector(sheetDelete(_:)))
            delBtn.bezelStyle = .rounded
            delBtn.frame = NSRect(x: pad, y: by, width: 120, height: 28)
            delBtn.contentTintColor = .systemRed
            vw.addSubview(delBtn)
        }

        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // 根据预设厂商索引重建模型 ID 下拉列表
    private func rebuildModelPopup(idx: Int, selectedModelId: String? = nil) {
        sheetModelPopup.removeAllItems()
        sheetModelPopup.addItem(withTitle: "从预设选")

        if idx >= 0 && idx < presetProviders.count {
            let provider = presetProviders[idx]
            for modelId in provider.models {
                sheetModelPopup.addItem(withTitle: modelId)
                if modelId == selectedModelId {
                    sheetModelPopup.selectItem(withTitle: modelId)
                }
            }
        } else {
            // 自定义模式：显示所有预设模型（按厂商分组标题）
            for p in presetProviders {
                // 用分隔符形式的分组标题
                sheetModelPopup.addItem(withTitle: "--- \(p.name) ---")
                sheetModelPopup.item(at: sheetModelPopup.numberOfItems - 1)?.isEnabled = false
                for m in p.models {
                    sheetModelPopup.addItem(withTitle: m)
                    if m == selectedModelId {
                        sheetModelPopup.selectItem(withTitle: m)
                    }
                }
            }
        }
    }

    // 预设厂商下拉选择变化 → 自动填充 Base URL + 重建模型下拉
    @objc private func providerPopupChanged(_ sender: NSPopUpButton) {
        let idx = sender.indexOfSelectedItem - 1
        sheetSelectedProviderIdx = idx

        if idx >= 0 && idx < presetProviders.count {
            let provider = presetProviders[idx]
            sheetUrlField.stringValue = provider.baseUrl
            if sheetNameField.stringValue.isEmpty {
                sheetNameField.stringValue = provider.name
            }
        }

        // 重建模型 ID 下拉（联动）
        rebuildModelPopup(idx: idx, selectedModelId: nil)
        // 清空模型 ID 输入框，等待用户选择
        sheetModelField.stringValue = ""
    }

    // 模型 ID 下拉选择变化 → 自动填充模型 ID
    @objc private func modelPopupChanged(_ sender: NSPopUpButton) {
        let title = sender.titleOfSelectedItem ?? ""
        if !title.isEmpty && title != "从预设选" && !title.hasPrefix("--- ") {
            sheetModelField.stringValue = title
        }
    }

    @objc private func sheetSave(_ sender: NSButton) {
        // 强制提交正在编辑的文本框内容
        sheetPanel?.makeFirstResponder(nil)

        // 文本框优先；下拉只在下拉有选中（非"从预设选"）且文本框为空时才补充
        let name = sheetNameField.stringValue.trimmingCharacters(in: CharacterSet.whitespaces)
        let url = sheetUrlField.stringValue.trimmingCharacters(in: CharacterSet.whitespaces)
        let token = sheetTokenField.stringValue.trimmingCharacters(in: CharacterSet.whitespaces)
        let typedModelId = sheetModelField.stringValue.trimmingCharacters(in: CharacterSet.whitespaces)
        let popupModelId = sheetModelPopup.titleOfSelectedItem ?? ""
        let modelId = !typedModelId.isEmpty ? typedModelId : popupModelId

        if name.isEmpty || url.isEmpty || modelId.isEmpty {
            showError("名称、Base URL 和模型 ID 不能为空"); return
        }
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            showError("Base URL 必须以 http:// 或 https:// 开头"); return
        }

        let finalToken = token.isEmpty ? defaultToken : token

        if sender.tag == 200, let eid = sheetEditingId {
            if let idx = models.firstIndex(where: { $0.id == eid }) {
                models[idx] = ModelItem(id: eid, name: name, baseUrl: url, apiToken: finalToken, modelId: modelId, isActive: true)
                for i in 0..<models.count where i != idx { models[i].isActive = false }
            }
        } else {
            if models.contains(where: { $0.name.lowercased() == name.lowercased() }) {
                showError("已存在同名模型: \(name)"); return
            }
            for i in 0..<models.count { models[i].isActive = false }
            models.append(ModelItem(id: UUID().uuidString, name: name, baseUrl: url, apiToken: finalToken, modelId: modelId, isActive: true))
        }

        saveModels()
        sheetPanel.close()
    }

    @objc private func sheetCancel(_ sender: Any) { sheetPanel.close() }

    @objc private func sheetDelete(_ sender: Any) {
        guard let eid = sheetEditingId else { return }
        models.removeAll { $0.id == eid }
        if models.isEmpty {
            var dm = ModelItem.defaultMiniMax
            dm.apiToken = defaultToken
            models = [dm]
        }
        if !models.contains(where: { $0.isActive }) { models[0].isActive = true }
        saveModels()
        sheetPanel.close()
    }

    // MARK: - 终端启动
    @objc private func launchClaude() { launchTerminal() }

    private func launchTerminal() {
        // 弹出目录选择面板
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "启动 Claude Code"
        panel.message = "选择 Claude Code 的项目目录"

        // 默认路径：上次选择的目录，或用户 home
        if !lastProjectPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: lastProjectPath)
        } else {
            panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        }

        // 尝试以 sheet 方式显示（附属于 key window）
        if let keyWin = NSApp.keyWindow {
            panel.beginSheetModal(for: keyWin) { [weak self] response in
                guard response == .OK, let url = panel.url else { return }
                self?.doLaunchTerminal(projectDir: url.path)
            }
        } else {
            // 无 key window 时用普通方式
            let response = panel.runModal()
            guard response == .OK, let url = panel.url else { return }
            doLaunchTerminal(projectDir: url.path)
        }
    }

    private func doLaunchTerminal(projectDir: String) {
        // 保存本次选择的目录
        saveLastProjectPath(projectDir)

        let hasITerm2 = FileManager.default.fileExists(atPath: "/Applications/iTerm2.app")
        let hasITerm = FileManager.default.fileExists(atPath: "/Applications/iTerm.app")

        // 构造 cd && claude 命令
        let escapedDir = projectDir.replacingOccurrences(of: "\"", with: "\\\"")
        let shellCmd = "cd \"\(escapedDir)\" && claude"

        let script: String
        if hasITerm2 || hasITerm {
            let appName = hasITerm2 ? "iTerm2" : "iTerm"
            script = """
                tell application "\(appName)"
                    activate
                    try
                        tell current window
                            create tab with default profile
                        end tell
                    on error
                        delay 0.5
                        create window with default profile
                    end try
                    delay 2.0
                    tell current session of current window
                        write text "\(shellCmd.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))"
                    end tell
                end tell
                """
        } else {
            script = """
                tell application "Terminal"
                    activate
                    do script "\(shellCmd)"
                end tell
                """
        }

        // 写入临时脚本文件，用 osascript 执行
        let scriptPath = NSTemporaryDirectory() + "claudeswitch_\(UUID().uuidString).scpt"
        do {
            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write script: \(error)")
            return
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = [scriptPath]
        task.standardOutput = nil
        task.standardError = nil

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            print("osascript error: \(error)")
        }

        try? FileManager.default.removeItem(atPath: scriptPath)
    }

    @objc private func quitApp() { NSApp.terminate(nil) }

    @objc private func toggleLaunchAtLogin() {
        launchAtLogin.toggle()
        savePreferences()

        // 调用 SMAppService 实际注册/取消登录项（macOS 13+）
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if launchAtLogin {
                    try service.register()
                } else {
                    try service.unregister()
                }
            } catch {
                print("SMAppService error: \(error)")
                // SMAppService 失败时回写状态
                launchAtLogin.toggle()
                savePreferences()
                showError("开机自启动设置失败：\(error.localizedDescription)")
            }
        }
    }

    private func showError(_ msg: String) {
        DispatchQueue.main.async {
            let a = NSAlert()
            a.messageText = "错误"
            a.informativeText = msg
            a.alertStyle = .warning
            a.addButton(withTitle: "确定")
            a.runModal()
        }
    }
}

// MARK: - 入口
let delegate = AppDelegate()
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
