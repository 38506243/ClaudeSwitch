# Claude Switch - macOS 菜单栏应用

> 一键切换 Claude Code 的 AI 模型配置，开箱即用。

**功能亮点：** 8大厂商预设 · 图形化添加模型 · 启动前选择项目目录 · 零依赖原生开发

---

## 1. 项目概述

| 项目 | 说明 |
|------|------|
| **核心功能** | macOS 状态栏菜单，一键切换 Claude Code 的 API 配置 |
| **技术栈** | Swift + AppKit（原生 macOS，零第三方依赖） |
| **兼容性** | macOS 10.15+ |
| **App 图标** | 蓝色渐变背景 + 白色粗体 C（程序化生成） |
| **许可** | MIT |

---

## 2. 功能列表

### 2.1 状态栏
- App 运行后在顶部菜单栏显示 🤖 图标 + 当前模型名称
- 点击弹出下拉菜单

### 2.2 模型切换
- 菜单列出所有已配置模型，当前激活者显示 ✔
- 点击任意模型 → 写入 `~/.claude/settings.json` → iTerm2 cd 到项目目录 → 执行 claude
- 配置不完整的模型显示 ⚠️，点击无效

### 2.3 添加模型
点击「添加模型...」弹出浮动面板（NSPanel），字段：
- **预设厂商**（下拉）— 选择后自动填充 Base URL 和模型下拉列表
- **名称**（必填）
- **Base URL**（必填，自动从预设填充）
- **API Token**（多行事度，约5行，选填，留空使用全局 Token）
- **模型 ID**（下拉联动自动填充，也支持手动输入）
- 验证：名称/URL/模型 ID 必填、URL 必须 `http(s)://` 开头、不允许重名

### 2.4 编辑 / 删除模型
- 点击「编辑 / 删除模型...」弹出浮动面板，预填充当前激活模型的配置
- 可修改任意字段后保存
- 提供红色「删除此模型」按钮，删除后自动保留至少一个模型

### 2.5 启动 Claude Code
- 点击「启动 Claude Code」→ NSOpenPanel 弹出目录选择框
- 目录路径持久化到 `~/.claude/model-switcher/lastProjectPath.txt`
- 下次打开面板时默认定位于上次选择的目录
- 菜单项标题动态显示当前目录名（如 `启动 Claude Code: myproject`）
- iTerm2/Terminal cd 进去后执行 claude

### 2.6 终端自动选择
| 优先级 | 应用 |
|--------|------|
| 1 | iTerm2 |
| 2 | iTerm |
| 3 | macOS Terminal.app |

### 2.7 容错处理
- 配置文件缺失 → 自动生成默认 MiniMax 配置
- JSON 格式损坏 → 重置为默认配置
- 模型列表为空 → 自动添加默认 MiniMax
- 多个模型同时激活 → 只保留第一个
- Token 为空 → 自动从 `~/.claude/settings.json` 读取并填充
- App 多开 → 只允许一个实例运行

---

## 3. 数据存储

### 3.1 模型配置
```
~/.claude/model-switcher/models.json
```
```json
[
  {
    "id": "uuid-string",
    "name": "MiniMax",
    "baseUrl": "https://api.minimaxi.com/anthropic",
    "apiToken": "sk-cp-...",
    "modelId": "MiniMax-M2.7-highspeed",
    "isActive": true
  }
]
```

### 3.2 Claude 配置（App 自动写入）
```
~/.claude/settings.json
```
```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.minimaxi.com/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "sk-cp-...",
    "ANTHROPIC_MODEL": "MiniMax-M2.7-highspeed",
    "API_TIMEOUT_MS": "300000",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": 1
  }
}
```

### 3.3 全局 Token 回退
- 模型 Token 为空时，自动从 `~/.claude/settings.json` 读取已有 Token

### 3.4 上次项目目录
```
~/.claude/model-switcher/lastProjectPath.txt
```

---

## 4. 菜单结构

```
🤖 MiniMax                    ← 状态栏（当前模型）
  ├─ ✔ MiniMax               ← 当前激活
  ├─    GLM-4
  ├─    GPT-4o
  ├─ ─────────────────
  ├─ 添加模型...
  ├─ 编辑 / 删除模型...
  ├─ ─────────────────
  │  当前: MiniMax / MiniMax-M2.7-highspeed
  ├─ ─────────────────
  ├─ 启动 Claude Code: myproject   ← 有目录时显示目录名
  │                                   无目录时显示「启动 Claude Code ->」
  ├─ ─────────────────
  └─ 退出 Claude Switch
```

---

## 5. 界面设计

### 5.1 状态栏
- 图标：🤖 emoji
- 文字：当前模型名称，12pt，medium weight

### 5.2 添加/编辑面板（NSPanel）
| 属性 | 值 |
|------|-----|
| 尺寸 | 480 × 510 pt |
| 样式 | NSPanel，floating，titled + closable |
| Token 输入框 | 110pt 高（约5行），自动换行，无滚动条 |
| 预设厂商下拉 | 第一个选项为"自定义"，选后自动填充 URL |
| 模型 ID 下拉 | 与预设厂商联动，实时切换列表 |

### 5.3 App 图标
- 蓝色渐变背景 + 白色粗体字母 C
- 程序化生成（Swift + Core Graphics → PNG → iconutil → .icns）
- 尺寸覆盖：16/32/64/128/256/512/1024 pt

### 5.4 颜色
- 背景：macOS 系统窗口背景色（跟随深色/浅色模式）
- 激活状态：系统蓝色高亮
- 删除按钮：系统红色

---

## 6. 内置预设厂商（按字母排序）

| 厂商 | Base URL | 模型示例 |
|------|---------|---------|
| Anthropic 官方 | `https://api.anthropic.com` | claude-sonnet-4-6, claude-opus-4-5, claude-haiku-3-5 |
| DashScope（阿里云） | `https://dashscope.aliyuncs.com/compatible-mode/v1` | qwen-plus, qwen-max, qwen-turbo |
| Gemini（Google AI） | `https://generativelanguage.googleapis.com/v1beta` | gemini-1.5-pro, gemini-1.5-flash, gemini-2.0-flash |
| Kimi（Moonshot AI） | `https://api.moonshot.cn/v1` | moonshot-v1-8k, moonshot-v1-32k, moonshot-v1-128k, kimi-plus |
| MiniMax | `https://api.minimaxi.com/anthropic` | MiniMax-M2.7-highspeed, MiniMax-M2.1-highspeed |
| OpenAI 官方 | `https://api.openai.com/v1` | gpt-4o, gpt-4o-mini, gpt-4-turbo |
| OpenRouter | `https://openrouter.ai/api/v1` | anthropic/claude-sonnet-4-6, openai/gpt-4o |
| Zhipu AI (GLM) | `https://open.bigmodel.cn/api/paas/v4` | glm-4, glm-4-flash, glm-4-plus |

> ⚠️ Kimi 的 Base URL 和模型名称建议前往 [platform.moonshot.cn](https://platform.moonshot.cn) 确认最新信息

---

## 7. 项目结构

```
ClaudeSwitch/
├── APP设计文稿.md
├── README.md
├── .gitignore
├── macmenu/
│   ├── ClaudeSwitchMenu     ← 编译输出（二进制）
│   └── Sources/
│       └── main.swift       ← 全部源码（约710行）
├── ClaudeSwitch.app/         ← 可直接运行的 App Bundle
│   └── Contents/
│       ├── Info.plist
│       ├── MacOS/ClaudeSwitch
│       └── Resources/ClaudeSwitch.icns
└── gen_icon.swift           ← 图标生成脚本（iconutil）
```

---

## 8. 编译与运行

### 编译 App
```bash
cd ~/Projects/ClaudeSwitch/macmenu
swiftc -o ClaudeSwitchMenu Sources/main.swift \
  -framework AppKit -framework Foundation
```

### 打包 App Bundle
```bash
# 创建目录结构
mkdir -p ClaudeSwitch.app/Contents/{MacOS,Resources}
cp macmenu/ClaudeSwitchMenu ClaudeSwitch.app/Contents/MacOS/ClaudeSwitch
chmod +x ClaudeSwitch.app/Contents/MacOS/ClaudeSwitch
```

### 生成 App 图标
```bash
swift gen_icon.swift
# 输出: ClaudeSwitch.app/Contents/Resources/ClaudeSwitch.icns
```

### 运行
```bash
open ClaudeSwitch.app
# 或双击 Finder 中的 ClaudeSwitch.app
```

> **注意**：App 设置了 `LSUIElement = true`，不显示 Dock 图标，仅在菜单栏运行。

---

## 9. 设计原则

1. **零配置即可用** — 首次运行自动生成默认 MiniMax 配置
2. **所见即所得** — 菜单直接展示所有模型
3. **安全第一** — 不覆盖用户已有的全局 Token
4. **容错优先** — 任何异常情况都有降级处理
5. **轻量原则** — 纯 Swift 原生实现，无第三方依赖

---

## 10. 待扩展功能

- [ ] 模型配置导入/导出（JSON 文件）
- [ ] 支持 Claude Code 以外的 CLI（Codex、Gemini CLI）
- [ ] 快捷键绑定（全局热键切换模型）
- [ ] 模型切换通知（macOS Notification）
- [ ] 模型可用性检测（切换前 ping API）
- [ ] 开机自启动
