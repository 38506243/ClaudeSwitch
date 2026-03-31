# Claude Switch

macOS 菜单栏应用，一键切换 Claude Code 的 AI 模型配置，开箱即用。

## 功能

- 🤖 **菜单栏图标** — 顶部状态栏显示当前模型名称，点击弹出菜单
- 🔄 **一键切换** — 点击模型名即切换，写入 `~/.claude/settings.json`
- ➕ **添加/编辑模型** — 图形界面，8大厂商预设下拉联动，API Token 支持多行输入
- 🚀 **启动 Claude Code** — 弹窗选择项目目录，iTerm2 cd 进去后执行 claude
- 📁 **目录记忆** — 上次选择的目录自动保存，下次默认打开
- 🛡️ **容错完善** — 配置损坏时自动恢复默认；Token 为空时自动补全
- 🔒 **多实例保护** — 只允许一个实例运行

## 内置厂商

Anthropic · DashScope（阿里云）· Gemini · Kimi · MiniMax · OpenAI · OpenRouter · Zhipu AI

## 菜单结构

```
🤖 MiniMax
  ├─ ✔ MiniMax
  ├─    GLM-4
  ├─    GPT-4o
  ├─ ─────────────────
  ├─ 添加模型...
  ├─ 编辑 / 删除模型...
  ├─ ─────────────────
  │  当前: MiniMax / MiniMax-M2.7-highspeed
  ├─ ─────────────────
  ├─ 启动 Claude Code: myproject
  ├─ ─────────────────
  └─ 退出 Claude Switch
```

## 数据存储

| 文件 | 用途 |
|------|------|
| `~/.claude/model-switcher/models.json` | 模型配置列表 |
| `~/.claude/model-switcher/lastProjectPath.txt` | 上次启动目录 |
| `~/.claude/settings.json` | Claude Code 运行时配置（App 自动写入）|

## 编译

```bash
cd ~/Projects/ClaudeSwitch/macmenu
swiftc -o ClaudeSwitchMenu Sources/main.swift \
  -framework AppKit -framework Foundation
```

## 生成 App 图标（可选）

```bash
cd ~/Projects/ClaudeSwitch
swift gen_icon.swift
```

## 使用

1. 运行 `open ~/Projects/ClaudeSwitch/ClaudeSwitch.app`
2. 菜单栏出现 🤖 图标
3. 点击「添加模型...」添加第一个模型（首次运行会自动生成默认 MiniMax）
4. 点击任意模型开始使用

## 系统要求

- macOS 10.15 (Catalina) 及以上
- iTerm2 / iTerm / Terminal.app（至少一种）
- Claude Code 已安装（`npm install -g @anthropic-ai/claude-code`）
