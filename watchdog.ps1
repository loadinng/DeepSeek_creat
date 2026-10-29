param([switch]$TestOnce)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Root = 'D:\dafeiyu'
$Log  = "$Root\logs\watchdog.log"
$QRTool = "$Root\tools\qr-tool.vbs"

function Write-Log([string]$Msg) {
    $line = "{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Msg
    Add-Content -Path $Log -Value $line -Encoding UTF8
}

function Test-Port([int]$Port) {
    try {
        $c = New-Object Net.Sockets.TcpClient
        $c.Connect('127.0.0.1', $Port)
        $c.Close()
        return $true
    } catch { return $false }
}

function Test-Linked {
    $conns = Get-NetTCPConnection -LocalPort 6199 -State Established -ErrorAction SilentlyContinue
    return [bool]$conns
}

function Get-Status {
    if (-not (Test-Port 6185)) { return @{ ok = $false; reason = 'AstrBot 后台没在运行' } }
    if (-not (Test-Port 6099)) { return @{ ok = $false; reason = 'NapCat 没在运行' } }
    if (-not (Get-Process QQ -ErrorAction SilentlyContinue)) { return @{ ok = $false; reason = 'QQ 没在运行' } }
    if (-not (Test-Linked)) { return @{ ok = $false; reason = 'NapCat 没连上 AstrBot（QQ 可能掉线了）' } }
    return @{ ok = $true; reason = '' }
}

function Show-OfflinePopup([string]$Reason, [switch]$AutoClose) {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = '大肥鱼掉线了'
    $form.Size = New-Object System.Drawing.Size(460, 240)
    $form.StartPosition = 'CenterScreen'
    $form.TopMost = $true
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $icon = New-Object System.Windows.Forms.Label
    $icon.Text = '!'
    $icon.Font = New-Object System.Drawing.Font('Segoe UI', 28, [System.Drawing.FontStyle]::Bold)
    $icon.ForeColor = [System.Drawing.Color]::OrangeRed
    $icon.AutoSize = $true
    $icon.Location = New-Object System.Drawing.Point(24, 28)

    $title = New-Object System.Windows.Forms.Label
    $title.Text = '大肥鱼不在线'
    $title.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 15, [System.Drawing.FontStyle]::Bold)
    $title.AutoSize = $true
    $title.Location = New-Object System.Drawing.Point(70, 28)

    $body = New-Object System.Windows.Forms.Label
    $body.Text = "原因：$Reason`r`n`r`n点「打开二维码」扫码重新登录，通常 10 秒内恢复。"
    $body.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10)
    $body.AutoSize = $false
    $body.Size = New-Object System.Drawing.Size(400, 70)
    $body.Location = New-Object System.Drawing.Point(70, 70)

    $btnQR = New-Object System.Windows.Forms.Button
    $btnQR.Text = '打开二维码'
    $btnQR.Size = New-Object System.Drawing.Size(140, 36)
    $btnQR.Location = New-Object System.Drawing.Point(190, 150)
    $btnQR.Add_Click({
        Start-Process -FilePath 'wscript.exe' -ArgumentList "`"$QRTool`"" -WindowStyle Hidden
        $form.Close()
    })

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = '知道了'
    $btnClose.Size = New-Object System.Drawing.Size(100, 36)
    $btnClose.Location = New-Object System.Drawing.Point(340, 150)
    $btnClose.Add_Click({ $form.Close() })

    $form.Controls.AddRange(@($icon, $title, $body, $btnQR, $btnClose))

    if ($AutoClose) {
        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 8000
        $timer.Add_Tick({ $timer.Stop(); $form.Close() })
        $timer.Start()
    }

    [void]$form.ShowDialog()
}

if ($TestOnce) {
    Write-Log '[test] popup shown'
    Show-OfflinePopup -Reason '这是一次测试弹窗（8 秒后自动关闭）' -AutoClose
    Write-Log '[test] popup closed'
    exit 0
}

Write-Log '[start] watchdog started'
$graceUntil = (Get-Date).AddSeconds(180)
$lastPopup  = [datetime]::MinValue
$wasOk      = $true

while ($true) {
    $status = Get-Status
    if ($status.ok) {
        if (-not $wasOk) { Write-Log '[online] recovered' }
        $wasOk = $true
    } else {
        $now = Get-Date
        $cooldownOk = (($now - $lastPopup).TotalMinutes -ge 10)
        if ($now -gt $graceUntil -and $cooldownOk) {
            Write-Log "[offline] $($status.reason)"
            Show-OfflinePopup -Reason $status.reason
            $lastPopup = Get-Date
        }
        $wasOk = $false
    }
    Start-Sleep -Seconds 20
}
