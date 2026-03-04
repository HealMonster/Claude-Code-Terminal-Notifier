# Claude-Code-Terminal-Notifier

跨平台 Claude Code 桌面通知 — 当 Claude 完成回复时自动弹出原生系统通知，让你在做别的事时不会错过。

## 原理

利用 Claude Code 的 [Stop Hook](https://docs.anthropic.com/en/docs/claude-code/hooks) 机制：每当 Claude 完成回复，自动执行 bash 脚本，脚本按操作系统分发到对应的原生通知 API。

**无需安装任何编辑器扩展**，适用于任意终端、任意 IDE。

## 平台支持

| 平台 | 通知方式 | 依赖 |
|------|---------|------|
| Windows 10+ | WinRT Toast（PowerShell 脚本） | PowerShell 5.1（系统内置） |
| macOS | `osascript display notification` | 系统内置，无需安装 |
| Linux | `notify-send`（libnotify） | 多数桌面发行版预装 |

## 通知效果

| 项目 | 内容 |
|------|------|
| 标题 | `Claude Code` |
| 正文 | Claude 最后一条回复的首行（最长 120 字符） |
| 声音 | 默认开启，可通过 `config.json` 关闭 |

## 安装

### 1. 克隆仓库

```bash
git clone https://github.com/HealMonster/Claude-Code-Terminal-Notifier.git ~/Claude-Code-Terminal-Notifier
```

### 2. 添加执行权限（macOS / Linux）

```bash
chmod +x ~/Claude-Code-Terminal-Notifier/scripts/claude-stop-notify.sh
```

### 3. 配置 Claude Code Stop Hook

编辑 `~/.claude/settings.json`，添加 `hooks` 配置（如已有其他配置项，合并即可）：

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash /path/to/Claude-Code-Terminal-Notifier/scripts/claude-stop-notify.sh",
            "async": true,
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

> **注意**：将 `/path/to/` 替换为实际克隆路径。Windows 上使用正斜杠（`D:/Practice/...`）或双反斜杠（`D:\\Practice\\...`）。

### 4. 重启 Claude Code 会话

Hook 配置在会话启动时加载，修改后需要**新开一个 Claude Code 会话**才能生效。

## 配置

编辑项目根目录下的 `config.json`：

```json
{
  "sound": true
}
```

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `sound` | boolean | `true` | 通知是否播放提示音（适用于 Windows 和 macOS） |

## 文件结构

```
Claude-Code-Terminal-Notifier/
├── scripts/
│   ├── claude-stop-notify.sh    # 跨平台入口脚本（核心）
│   └── claude-stop-notify.ps1   # Windows Toast 实现（由 .sh 自动调用）
├── config.json                  # 通知配置（声音开关等）
└── README.md
```

## Troubleshooting

### Windows

- **无通知弹出**：确认 Windows 设置 → 系统 → 通知 中 PowerShell 通知未被关闭
- **Git Bash 找不到 powershell.exe**：确认 `C:\Windows\System32\WindowsPowerShell\v1.0` 在 PATH 中
- **编码问题**：脚本已处理 UTF-8 编码，如仍有乱码请确认终端编码设置

### macOS

- **无通知弹出**：检查 系统设置 → 通知 中 Script Editor 通知是否开启
- **权限问题**：首次运行可能需要授权终端发送通知

### Linux

- **`notify-send` 未找到**：安装 libnotify
  - Debian/Ubuntu: `sudo apt install libnotify-bin`
  - Fedora: `sudo dnf install libnotify`
  - Arch: `sudo pacman -S libnotify`
- **SSH / 无头服务器**：无桌面环境时脚本会静默跳过，不影响 Claude Code 正常工作

### 通用

- **Hook 不触发**：确认 `settings.json` 语法正确（用 `cat ~/.claude/settings.json | node -e "JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'))"` 验证）
- **`stop_hook_active` 问题**：脚本会自动跳过 `stop_hook_active=true` 的情况，避免重复通知

## 卸载

1. 从 `~/.claude/settings.json` 中移除 `hooks.Stop` 配置
2. 删除仓库目录

## License

MIT
