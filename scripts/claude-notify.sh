#!/usr/bin/env bash
# claude-notify.sh
# 跨平台 Claude Code Hook 通知脚本
# 同时支持 Stop hook 和 Notification hook（如 permission_prompt）
#
# 优化特性：
#   - 区分通知类型：回复完成 vs 需要确认，标题不同
#   - 冷却防刷屏：Stop 通知有冷却期，权限确认始终通知
#   - 仅后台通知：终端在前台时抑制 Stop 通知，权限确认始终通知
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

# 读取 config.json（sound / cooldownSeconds / onlyBackground）
SOUND="true"
COOLDOWN=5
ONLY_BG="true"
CONFIG_FILE="${PROJECT_DIR}/config.json"
if [ -f "$CONFIG_FILE" ]; then
  CONFIG_PARSED=$(node -e "
    const c = JSON.parse(require('fs').readFileSync('${CONFIG_FILE}','utf8'));
    console.log(c.sound === false ? 'false' : 'true');
    console.log(typeof c.cooldownSeconds === 'number' ? c.cooldownSeconds : 5);
    console.log(c.onlyBackground === false ? 'false' : 'true');
  " 2>/dev/null) || CONFIG_PARSED=""
  if [ -n "$CONFIG_PARSED" ]; then
    SOUND=$(echo "$CONFIG_PARSED" | sed -n '1p')
    COOLDOWN=$(echo "$CONFIG_PARSED" | sed -n '2p')
    ONLY_BG=$(echo "$CONFIG_PARSED" | sed -n '3p')
  fi
fi

# 用 node 解析 JSON，自动检测 hook 类型
# 输出四行：action、type、title、message
PARSED=$(node -e "
  let buf = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', c => buf += c);
  process.stdin.on('end', () => {
    const d = JSON.parse(buf);

    // Stop hook
    if ('stop_hook_active' in d) {
      if (d.stop_hook_active === true) {
        console.log('skip'); console.log(''); console.log(''); console.log('');
        return;
      }
      let msg = (d.last_assistant_message || '(no message)').split(/\r?\n/)[0].trim();
      if (msg.length > 120) msg = msg.substring(0, 120) + '...';
      console.log('show');
      console.log('stop');
      console.log('Claude Code');
      console.log(msg);
      return;
    }

    // Notification hook
    if ('notification_type' in d) {
      let msg = (d.message || '').split(/\r?\n/)[0].trim();
      if (msg.length > 120) msg = msg.substring(0, 120) + '...';
      console.log('show');
      console.log('permission');
      console.log('Claude Code - \u9700\u8981\u786e\u8ba4');
      console.log(msg || '\u9700\u8981\u4f60\u7684\u786e\u8ba4');
      return;
    }

    console.log('skip'); console.log(''); console.log(''); console.log('');
  });
" <<< "$INPUT" 2>/dev/null) || exit 0

# 按行分割
ACTION=$(echo "$PARSED" | sed -n '1p')
TYPE=$(echo "$PARSED" | sed -n '2p')
TITLE=$(echo "$PARSED" | sed -n '3p')
MSG=$(echo "$PARSED" | sed -n '4p')

if [ "$ACTION" = "skip" ]; then
  exit 0
fi

# --- 以下检查仅对 stop 类型生效，permission 始终通知 ---

COOLDOWN_FILE="/tmp/claude-notify-last"

if [ "$TYPE" = "stop" ]; then
  # 冷却检查：N 秒内不重复通知
  if [ "$COOLDOWN" -gt 0 ] && [ -f "$COOLDOWN_FILE" ]; then
    LAST=$(cat "$COOLDOWN_FILE" 2>/dev/null || echo "0")
    NOW=$(date +%s)
    DIFF=$((NOW - LAST))
    if [ "$DIFF" -lt "$COOLDOWN" ]; then
      exit 0
    fi
  fi

  # 前台检查：终端在前台时不通知
  if [ "$ONLY_BG" = "true" ]; then
    OS_CHECK=$(uname -s 2>/dev/null || echo "Unknown")
    case "$OS_CHECK" in
      Darwin)
        FRONT_APP=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null || echo "")
        case "$FRONT_APP" in
          Terminal|iTerm2|Alacritty|kitty|WezTerm|Hyper|Warp|Rio)
            exit 0 ;;
          "Visual Studio Code"|"Visual Studio Code - Insiders"|Cursor|Windsurf)
            exit 0 ;;
        esac
        ;;
      Linux)
        if command -v xdotool >/dev/null 2>&1; then
          ACTIVE_ID=$(xdotool getactivewindow 2>/dev/null || echo "")
          if [ -n "$ACTIVE_ID" ]; then
            ACTIVE_CLASS=$(xprop -id "$ACTIVE_ID" WM_CLASS 2>/dev/null || echo "")
            if echo "$ACTIVE_CLASS" | grep -qiE 'terminal|konsole|alacritty|kitty|wezterm|tilix|terminator|xterm|urxvt|st-256color|code|cursor'; then
              exit 0
            fi
          fi
        fi
        ;;
      # Windows 前台检查在 PS1 中处理
    esac
  fi
fi

# 检测 OS 并分发通知
OS=$(uname -s 2>/dev/null || echo "Unknown")

case "$OS" in
  Darwin)
    ESCAPED_TITLE=$(echo "$TITLE" | sed 's/\\/\\\\/g; s/"/\\"/g')
    ESCAPED_MSG=$(echo "$MSG" | sed 's/\\/\\\\/g; s/"/\\"/g')
    if [ "$SOUND" = "true" ]; then
      osascript -e "display notification \"${ESCAPED_MSG}\" with title \"${ESCAPED_TITLE}\" sound name \"default\"" 2>/dev/null || true
    else
      osascript -e "display notification \"${ESCAPED_MSG}\" with title \"${ESCAPED_TITLE}\"" 2>/dev/null || true
    fi
    ;;
  Linux)
    if command -v notify-send >/dev/null 2>&1; then
      notify-send "$TITLE" "$MSG" 2>/dev/null || true
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*)
    export CLAUDE_NOTIFY_SOUND="$SOUND"
    export CLAUDE_NOTIFY_TITLE="$TITLE"
    export CLAUDE_NOTIFY_MSG="$MSG"
    export CLAUDE_NOTIFY_ONLY_BG="$ONLY_BG"
    export CLAUDE_NOTIFY_TYPE="$TYPE"
    powershell.exe -ExecutionPolicy Bypass -NoProfile -File \
      "${SCRIPT_DIR}/claude-notify.ps1" 2>/dev/null || true
    ;;
  *)
    ;;
esac

# 更新冷却时间戳（仅 stop 类型且实际发送了通知）
if [ "$TYPE" = "stop" ]; then
  date +%s > "$COOLDOWN_FILE" 2>/dev/null || true
fi

exit 0
