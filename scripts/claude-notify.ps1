# claude-notify.ps1
# Windows Toast 通知实现 — 由 claude-notify.sh 自动调用
# 通过环境变量接收参数：
#   CLAUDE_NOTIFY_TITLE   — 通知标题
#   CLAUDE_NOTIFY_MSG     — 通知正文
#   CLAUDE_NOTIFY_SOUND   — "true"/"false" 声音开关
#   CLAUDE_NOTIFY_ONLY_BG — "true"/"false" 仅后台通知
#   CLAUDE_NOTIFY_TYPE    — "stop"/"permission" 通知类型

try {
    $title = $env:CLAUDE_NOTIFY_TITLE
    $msg = $env:CLAUDE_NOTIFY_MSG
    $notifyType = $env:CLAUDE_NOTIFY_TYPE
    if (-not $title) { $title = "Claude Code" }
    if (-not $msg) { $msg = "(no message)" }

    # 前台检查：仅对 stop 类型生效，permission 始终通知
    if ($env:CLAUDE_NOTIFY_ONLY_BG -eq "true" -and $notifyType -eq "stop") {
        Add-Type -MemberDefinition '
            [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
            [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
        ' -Name 'User32' -Namespace 'Win32' -ErrorAction SilentlyContinue

        $hwnd = [Win32.User32]::GetForegroundWindow()
        $pid = [uint32]0
        [void][Win32.User32]::GetWindowThreadProcessId($hwnd, [ref]$pid)
        $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue

        # 常见终端 / IDE 进程名
        $terminals = @(
            'WindowsTerminal', 'powershell', 'pwsh', 'cmd',
            'Code', 'Code - Insiders', 'Cursor', 'Windsurf',
            'mintty', 'ConEmu', 'ConEmu64', 'Hyper',
            'Alacritty', 'WezTerm', 'wt'
        )
        if ($proc -and $terminals -contains $proc.ProcessName) {
            exit 0
        }
    }

    # 加载 WinRT Toast API
    [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime]

    # 声音配置
    $silent = "false"
    if ($env:CLAUDE_NOTIFY_SOUND -eq "false") { $silent = "true" }

    # 构建 Toast XML
    $toastXml = @"
<toast>
  <visual>
    <binding template="ToastGeneric">
      <text>$([System.Security.SecurityElement]::Escape($title))</text>
      <text>$([System.Security.SecurityElement]::Escape($msg))</text>
    </binding>
  </visual>
  <audio silent="$silent"/>
</toast>
"@

    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml($toastXml)

    $appId = "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe"
    $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
}
catch {
    # 静默捕获所有异常，绝不影响 Claude Code 流程
}

exit 0
