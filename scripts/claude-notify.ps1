# claude-notify.ps1
# Windows Toast 通知实现 — 由 claude-notify.sh 自动调用
# 通过环境变量接收参数：
#   CLAUDE_NOTIFY_TITLE — 通知标题
#   CLAUDE_NOTIFY_MSG   — 通知正文
#   CLAUDE_NOTIFY_SOUND — "true"/"false" 声音开关

try {
    $title = $env:CLAUDE_NOTIFY_TITLE
    $msg = $env:CLAUDE_NOTIFY_MSG
    if (-not $title) { $title = "Claude Code" }
    if (-not $msg) { $msg = "(no message)" }

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

    # 使用 PowerShell 的 AppId 发送 Toast
    $appId = "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe"
    $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
}
catch {
    # 静默捕获所有异常，绝不影响 Claude Code 流程
}

exit 0
