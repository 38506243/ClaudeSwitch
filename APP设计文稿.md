# Claude Switch - macOS 菜单栏应用设计文稿

> 用于一键切换 Claude Code 的 AI 模型配置

---

## 1. 项目概述

**核心功能：** 通过 macOS 状态栏菜单，一键切换 Claude Code 的 API 配置（Base URL、Token、模型 ID），切换后自动打开终端运行 Claude Code。

**技术栈：** Swift + AppKit（原生 macOS 开发）

**兼容性：** macOS 10.15+

---

## 2. 功能列表

### 2.1 状态栏图标
- App 运行后在顶部菜单栏显示 🤖 图标
- 图标旁显示当前激活的模型名称（例：`🤖 MiniMax`）
- 点击图标弹出下拉菜单
- 右键/左键点击均可触发菜单

### 2.2 模型切换
- 菜单第一部分：已配置模型列表
  - 当前激活模型前显示 ✔
  - 点击任意模型 → 写入 `~/.claude/settings.json` → 打开终端运行 `claude`
  - 配置不完整的模型显示 ⚠️ 警告，点击无效

### 2.3 添加模型
- 点击「添加模型...」弹出浮动面板
- 输入项：
  - **名称**（必填）：显示在菜单中的名称，如 `GLM-4`
  - **Base URL**（必填）：API 端点，如 `https://api.zhipuai.cn/anthropic`
  - **API Token**（选填）：留空则使用全局 Token
  - **模型 ID**（必填）：实际调用的模型名，如 `glm-4`
- 验证规则：
  - 名称/URL/模型 ID 不能为空
  - URL 必须以 `http://` 或 `https://` 开头
  - 不允许重名模型

### 2.4 编辑 / 删除模型
- 点击「编辑 / 删除模型...」弹出浮动面板
- 预填充当前模型的配置信息
- 可修改任意字段后保存
- 提供「删除此模型」按钮（红色），删除后自动保留至少一个模型

### 2.5 启动 Claude Code
- 点击「启动 Claude Code →」直接打开终端运行 `claude`
- 无需切换模型，单独使用此功能

### 2.6 终端自动选择
- 优先使用 iTerm2（如果已安装）
- 其次使用 iTerm
- 最后降级到 macOS Terminal.app

### 2.7 Claude Code 安装检测
- 切换模型时检测 `which claude` 是否存在
- 如果未安装，弹出提示框询问是否安装
- 用户确认后执行 `npm install -g @anthropic-ai/claude-code`

### 2.8 容错处理
- 配置文件缺失 → 自动生成默认 MiniMax 配置
- JSON 格式损坏 → 重置为默认配置
- 模型列表为空 → 自动添加默认 MiniMax
- 多个模型同时激活 → 只保留第一个
- Token 为空 → 自动从现有 `settings.json` 读取并填充
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

### 3.2 Claude 配置（由 App 写入）
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
- 如果模型配置中 Token 为空，App 自动从 `~/.claude/settings.json` 读取已有 Token
- 确保 Token 不会因配置丢失

---

## 4. 菜单结构

```
🤖 MiniMax                    ← 状态栏（显示当前模型）
  ├─ ✔ MiniMax               ← 当前激活
  ├─    GLM-4
  ├─    GPT-4o
  ├─ ─────────────────
  ├─ 添加模型...
  ├─ 编辑 / 删除模型...
  ├─ ─────────────────
  │  当前: MiniMax / MiniMax-M2.7-highspeed   ← 只读信息
  ├─ ─────────────────
  ├─ 启动 Claude Code →
  ├─ ─────────────────
  └─ 退出 Claude Switch
```

---

## 5. 界面设计

### 5.1 状态栏
- 图标：🤖 emoji
- 文字：当前模型名称
- 字号：12pt，medium weight

### 5.2 添加/编辑面板
- 类型：浮动面板（NSPanel）
- 样式：macOS 原生简洁风格
- 大小：460 × 340 pt
- 居中显示，自动成为焦点窗口

### 5.3 颜色
- 背景：macOS 系统窗口背景色（跟随深色/浅色模式）
- 激活状态：系统蓝色高亮
- 删除按钮：系统红色
- 警告文字：系统警告色 + 图标 ⚠️

---

## 6. 工作流程

### 切换模型流程
```
用户点击模型
    ↓
App 写入 ~/.claude/settings.json
    ↓
更新 models.json 中的激活状态
    ↓
更新状态栏图标文字
    ↓
检测 Claude Code 是否安装
    ↓
打开终端（iTerm2/Terminal）
    ↓
执行 claude 命令
```

### 添加模型流程
```
用户点击「添加模型...」
    ↓
弹出浮动面板
    ↓
用户填写表单
    ↓
验证输入（名称不重复、URL 格式正确、必填项不为空）
    ↓
保存到 models.json
    ↓
自动激活新模型
    ↓
自动打开终端运行 claude
```

---

## 7. 安装与运行

### 编译
```bash
cd ~/Projects/ClaudeSwitch/macmenu
swiftc -o ClaudeSwitchMenu Sources/main.swift \
  -framework AppKit -framework Foundation
```

### 打包
```bash
# 复制到 App Bundle
cp ClaudeSwitchMenu /Applications/ClaudeSwitch.app/Contents/MacOS/ClaudeSwitch
```

### 运行
- 双击 `/Applications/ClaudeSwitch.app`
- 或命令行：`open -a ClaudeSwitch`

### 启动方式
- App 设置为 `LSUIElement = true`，不显示 Dock 图标
- 仅在菜单栏显示
- 退出方式：菜单 → 退出

---

## 8. 内置预设厂商（下拉选择）

> 添加模型时，用户可从预设列表选择厂商，自动填充 Base URL，减少手动输入

| 厂商 | Base URL | 支持模型示例 |
|------|---------|------------|
| **Anthropic 官方** | `https://api.anthropic.com` | claude-sonnet-4-6, claude-opus-4-5 |
| **DashScope（阿里云）** | `https://dashscope.aliyuncs.com/compatible-mode/v1` | qwen-plus, qwen-max |
| **Gemini（Google AI）** | `https://generativelanguage.googleapis.com/v1beta` | gemini-1.5-pro, gemini-1.5-flash |
| **Kimi（Moonshot AI）** | `https://api.moonshot.cn/v1` | moonshot-v1-8k, moonshot-v1-32k, kimi-plus |
| **MiniMax** | `https://api.minimaxi.com/anthropic` | MiniMax-M2.7-highspeed |
| **OpenAI 官方** | `https://api.openai.com/v1` | gpt-4o, gpt-4o-mini, gpt-4-turbo |
| **OpenRouter** | `https://openrouter.ai/api/v1` | 聚合多厂商模型 |
| **Zhipu AI (GLM)** | `https://open.bigmodel.cn/api/paas/v4` | glm-4, glm-4-flash |

> ⚠️ Kimi 的 Base URL 和模型名称基于训练数据，建议前往 [platform.moonshot.cn](https://platform.moonshot.cn) 确认最新信息

### 用户需提供
- API Token（从各厂商控制台获取）
- 模型 ID（可从下拉列表选择，或手动输入）

## 9. 默认配置

### 内置默认模型：MiniMax
```json
{
  "name": "MiniMax",
  "baseUrl": "https://api.minimaxi.com/anthropic",
  "modelId": "MiniMax-M2.7-highspeed"
}
```

---

## 10. 待扩展功能（后续版本）

- [ ] 模型配置导入/导出（JSON 文件）
- [ ] 支持 Claude Code 以外的 CLI（Codex、Gemini CLI）
- [ ] 快捷键绑定（全局热键切换模型）
- [ ] 模型切换通知（macOS Notification）
- [ ] 模型可用性检测（切换前 ping 一下 API 是否通）
- [ ] 开机自启动

---

## 11. 设计原则

1. **零配置即可用**：首次运行自动生成默认 MiniMax 配置
2. **所见即所得**：菜单直接展示所有模型，无需对话框
3. **安全第一**：不覆盖用户已有的全局 Token
4. **容错优先**：任何异常情况都有降级处理
5. **轻量原则**：纯 Swift 原生实现，无第三方依赖
