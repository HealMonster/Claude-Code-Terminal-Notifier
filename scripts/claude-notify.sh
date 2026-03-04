#!/usr/bin/env bash
# claude-notify.sh
# 跨平台 Claude Code Hook 通知脚本
# 同时支持 Stop hook 和 Notification hook（如 permission_prompt）
#
# 支持平台：
#   - Windows 10+（委托 claude-notify.ps1，WinRT Toast）
#   - macOS（osascript display notification）
#   - Linux（notify-send / libnotify）

set -euo pipefail

# 脚本所在目录 & 项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 读取 stdin 全部内容（Claude Code 传入 JSON）
INPUT=$(cat)

# 读取 config.json 中的 sound 配置（默认 true）
SOUND="true"
CONFIG_FILE="${PROJECT_DIR}/config.json"
if [ -f "$CONFIG_FILE" ]; then
  SOUND=$(node -e "
    const c = JSON.parse(require('fs').readFileSync('${CONFIG_FILE}','utf8'));
    console.log(c.sound === false ? 'false' : 'true');
  " 2>/dev/null) || SOUND="true"
fi

# 用 node 解析 JSON，自动检测 hook 类型并提取标题和消息
# 输出三行：skip（是否跳过）、title、message
PARSED=$(node -e "
  let buf = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', c => buf += c);
  process.stdin.on('end', () => {
    const d = JSON.parse(buf);

    // Stop hook: 有 stop_hook_active 字段
    if ('stop_hook_active' in d) {
      if (d.stop_hook_active === true) {
        console.log('skip');
        console.log('');
        console.log('');
        return;
      }
      let msg = (d.last_assistant_message || '(no message)').split(/\r?\n/)[0].trim();
      if (msg.length > 120) msg = msg.substring(0, 120) + '...';
      console.log('show');
      console.log('Claude Code');
      console.log(msg);
      return;
    }

    // Notification hook: 有 notification_type 字段
    if ('notification_type' in d) {
      const title = d.title || 'Claude Code';
      let msg = (d.message || '').split(/\r?\n/)[0].trim();
      if (msg.length > 120) msg = msg.substring(0, 120) + '...';
      console.log('show');
      console.log(title);
      console.log(msg || '需要你的确认');
      return;
    }

    // 未知格式，跳过
    console.log('skip');
    console.log('');
    console.log('');
  });
" <<< "$INPUT" 2>/dev/null) || exit 0

# 按行分割
ACTION=$(echo "$PARSED" | head -n 1)
TITLE=$(echo "$PARSED" | sed -n '2p')
MSG=$(echo "$PARSED" | tail -n +3)

# 需要跳过时直接退出
if [ "$ACTION" = "skip" ]; then
  exit 0
fi

# 检测 OS 并分发通知
OS=$(uname -s 2>/dev/null || echo "Unknown")

case "$OS" in
  Darwin)
    # macOS — osascript display notification
    ESCAPED_TITLE=$(echo "$TITLE" | sed 's/\\/\\\\/g; s/"/\\"/g')
    ESCAPED_MSG=$(echo "$MSG" | sed 's/\\/\\\\/g; s/"/\\"/g')
    if [ "$SOUND" = "true" ]; then
      osascript -e "display notification \"${ESCAPED_MSG}\" with title \"${ESCAPED_TITLE}\" sound name \"default\"" 2>/dev/null || true
    else
      osascript -e "display notification \"${ESCAPED_MSG}\" with title \"${ESCAPED_TITLE}\"" 2>/dev/null || true
    fi
    ;;
  Linux)
    # Linux — notify-send (libnotify)
    if command -v notify-send >/dev/null 2>&1; then
      notify-send "$TITLE" "$MSG" 2>/dev/null || true
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*)
    # Windows (Git Bash / MSYS2 / Cygwin) — 委托 PowerShell 脚本
    export CLAUDE_NOTIFY_SOUND="$SOUND"
    export CLAUDE_NOTIFY_TITLE="$TITLE"
    export CLAUDE_NOTIFY_MSG="$MSG"
    powershell.exe -ExecutionPolicy Bypass -NoProfile -File \
      "${SCRIPT_DIR}/claude-notify.ps1" 2>/dev/null || true
    ;;
  *)
    # 未知平台，静默跳过
    ;;
esac

exit 0
