# Claude Switch

macOS 菜单栏应用，一键切换 Claude Code 的 AI 模型配置。

## 功能

- 🔘 **菜单栏图标** - 顶部状态栏显示，点击弹出菜单
- ✅ **一键切换** - 点击模型名即切换，写入 `~/.claude/settings.json`
- ➕ **添加模型** - 图形界面添加新的模型配置（URL、Token、模型ID）
- ✏️ **编辑/删除** - 随时修改或删除已有模型
- 🚀 **自动启动** - 切换后自动打开 iTerm2/Terminal 并运行 `claude`
- 🤖 **自动安装** - 检测到 Claude Code 未安装时提示安装
- 🛡️ **容错完善** - 配置为空/无效时自动恢复默认；自动补全 Token

## 界面预览

```
🤖 MiniMax  ← 状态栏显示当前模型
  ├─ ✔ MiniMax        ← 当前激活
  ├─    GLM-4          ← 其他模型
  ├─    GPT-4o
  ├─ ─────────────────
  ├─ 添加模型...
  ├─ 编辑/删除模型...
  ├─ ─────────────────
  │  当前: MiniMax / MiniMax-M2.7-highspeed
  ├─ ─────────────────
  ├─ 启动 Claude Code →
  ├─ ─────────────────
  └─ 退出 Claude Switch
```

## 配置文件

- 模型列表: `~/.claude/model-switcher/models.json`
- Claude 配置: `~/.claude/settings.json` (由 App 自动写入)

## 编译

```bash
cd macmenu
swiftc -o ClaudeSwitchMenu Sources/main.swift -framework AppKit -framework Foundation
```

## 使用

1. 运行 `/Applications/ClaudeSwitch.app`
2. 菜单栏出现 🤖 图标
3. 点击选择模型
4. 自动打开终端并运行 `claude`

## 添加新模型

点击「添加模型」，填入：
- **名称**: 如 `GLM-4`
- **Base URL**: 如 `https://api.zhipuai.cn/anthropic`
- **API Token**: 如 `sk-xxx...`
- **模型 ID**: 如 `glm-4`

Token 留空则使用全局配置的 Token。
