# claude-stop-notify.ps1
# Windows Toast 通知实现 — 由 claude-stop-notify.sh 在 Windows 上自动调用
# 也可直接通过 ~/.claude/settings.json hooks.Stop 配置调用

try {
    # 强制 UTF-8 读取 stdin（Claude Code 输出 UTF-8，PS5.1 默认用系统编码）
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    $inputJson = [Console]::In.ReadToEnd()
    $data = $inputJson | ConvertFrom-Json

    # stop_hook_active == true 表示被 hook 继续的中间状态，跳过
    if ($data.stop_hook_active -eq $true) { exit 0 }

    # --- Windows Toast 通知 ---
    # 提取预览文本：取 last_assistant_message 首行，最长 120 字符
    $msg = $data.last_assistant_message
    if ($msg) {
        $firstLine = ($msg -split "`n")[0].Trim()
        if ($firstLine.Length -gt 120) {
            $firstLine = $firstLine.Substring(0, 120) + "..."
        }
    } else {
        $firstLine = "(no message)"
    }

    # 加载 WinRT Toast API
    [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime]

    # 读取声音配置：环境变量 CLAUDE_NOTIFY_SOUND（由 .sh 传入），默认 true
    $silent = "false"
    $soundEnv = $env:CLAUDE_NOTIFY_SOUND
    if ($soundEnv -eq "false") { $silent = "true" }

    # 构建 Toast XML
    $toastXml = @"
<toast>
  <visual>
    <binding template="ToastGeneric">
      <text>Claude Code</text>
      <text>$([System.Security.SecurityElement]::Escape($firstLine))</text>
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
    # 静默捕获所有异常，绝不影响 Claude Code 停止流程
}

# 始终 exit 0，避免阻止 Claude 停止
exit 0
