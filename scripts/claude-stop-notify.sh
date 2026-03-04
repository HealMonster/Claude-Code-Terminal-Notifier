#!/usr/bin/env bash
# claude-stop-notify.sh
# 跨平台 Claude Code Stop Hook — 回复完成时弹出桌面通知
# 由 ~/.claude/settings.json hooks.Stop 配置调用
#
# 支持平台：
#   - Windows 10+（委托 claude-stop-notify.ps1，WinRT Toast）
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

# 用 node 解析 JSON，提取 stop_hook_active 和 last_assistant_message 首行
# 输出两行：第一行 active 标志，第二行消息文本（已截取首行，不含换行）
PARSED=$(node -e "
  let buf = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', c => buf += c);
  process.stdin.on('end', () => {
    const d = JSON.parse(buf);
    const active = d.stop_hook_active === true ? 'true' : 'false';
    let msg = (d.last_assistant_message || '(no message)').split(/\r?\n/)[0].trim();
    if (msg.length > 120) msg = msg.substring(0, 120) + '...';
    console.log(active);
    console.log(msg);
  });
" <<< "$INPUT" 2>/dev/null) || exit 0

# 按行分割
STOP_ACTIVE=$(echo "$PARSED" | head -n 1)
MSG=$(echo "$PARSED" | tail -n +2)

# stop_hook_active=true 表示 hook 继续的中间状态，跳过通知
if [ "$STOP_ACTIVE" = "true" ]; then
  exit 0
fi

# 检测 OS 并分发通知
OS=$(uname -s 2>/dev/null || echo "Unknown")

case "$OS" in
  Darwin)
    # macOS — osascript display notification
    ESCAPED_MSG=$(echo "$MSG" | sed 's/\\/\\\\/g; s/"/\\"/g')
    if [ "$SOUND" = "true" ]; then
      osascript -e "display notification \"${ESCAPED_MSG}\" with title \"Claude Code\" sound name \"default\"" 2>/dev/null || true
    else
      osascript -e "display notification \"${ESCAPED_MSG}\" with title \"Claude Code\"" 2>/dev/null || true
    fi
    ;;
  Linux)
    # Linux — notify-send (libnotify)
    if command -v notify-send >/dev/null 2>&1; then
      notify-send "Claude Code" "$MSG" 2>/dev/null || true
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*)
    # Windows (Git Bash / MSYS2 / Cygwin) — 委托 PowerShell 脚本
    export CLAUDE_NOTIFY_SOUND="$SOUND"
    powershell.exe -ExecutionPolicy Bypass -NoProfile -File \
      "${SCRIPT_DIR}/claude-stop-notify.ps1" <<< "$INPUT" 2>/dev/null || true
    ;;
  *)
    # 未知平台，静默跳过
    ;;
esac

exit 0
