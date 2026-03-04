# Claude-Code-Terminal-Notifier

跨平台 Claude Code 桌面通知 — 当 Claude 完成回复或需要权限确认时，自动弹出原生系统通知。

## 通知触发时机

| 场景 | Hook 类型 | 说明 |
|------|----------|------|
| Claude 完成回复 | Stop | 回复结束后通知你查看结果 |
| 等待权限确认 | Notification (`permission_prompt`) | Bash 命令、文件写入等需要你确认时通知 |

## 原理

利用 Claude Code 的 [Hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) 机制，通过一个统一的 bash 脚本按操作系统分发到对应的原生通知 API。

**无需安装任何编辑器扩展**，适用于任意终端、任意 IDE。

## 平台支持

| 平台 | 通知方式 | 依赖 |
|------|---------|------|
| Windows 10+ | WinRT Toast（PowerShell 脚本） | PowerShell 5.1（系统内置） |
| macOS | `osascript display notification` | 系统内置，无需安装 |
| Linux | `notify-send`（libnotify） | 多数桌面发行版预装 |

## 安装

### 1. 克隆仓库

```bash
git clone https://github.com/HealMonster/Claude-Code-Terminal-Notifier.git ~/Claude-Code-Terminal-Notifier
```

### 2. 添加执行权限（macOS / Linux）

```bash
chmod +x ~/Claude-Code-Terminal-Notifier/scripts/claude-notify.sh
```

### 3. 配置 Claude Code Hooks

编辑 `~/.claude/settings.json`，添加 `hooks` 配置（如已有其他配置项，合并即可）：

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash /path/to/Claude-Code-Terminal-Notifier/scripts/claude-notify.sh",
            "async": true,
            "timeout": 10
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "permission_prompt",
        "hooks": [
          {
            "type": "command",
            "command": "bash /path/to/Claude-Code-Terminal-Notifier/scripts/claude-notify.sh",
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
│   ├── claude-notify.sh     # 跨平台入口脚本（核心）
│   └── claude-notify.ps1    # Windows Toast 实现（由 .sh 自动调用）
├── config.json              # 通知配置（声音开关等）
└── README.md
```

## Troubleshooting

### Windows

- **无通知弹出**：确认 Windows 设置 → 系统 → 通知 中 PowerShell 通知未被关闭
- **Git Bash 找不到 powershell.exe**：确认 `C:\Windows\System32\WindowsPowerShell\v1.0` 在 PATH 中

### macOS

- **无通知弹出**：检查 系统设置 → 通知 中 Script Editor 通知是否开启
- **权限问题**：首次运行可能需要授权终端发送通知

### Linux

- **`notify-send` 未找到**：安装 libnotify
  - Debian/Ubuntu: `sudo apt install libnotify-bin`
  - Fedora: `sudo dnf install libnotify`
  - Arch: `sudo pacman -S libnotify`
- **SSH / 无头服务器**：无桌面环境时脚本会静默跳过，不影响 Claude Code 正常工作

## 卸载

1. 从 `~/.claude/settings.json` 中移除 `hooks.Stop` 和 `hooks.Notification` 配置
2. 删除仓库目录

## License

MIT
