Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Root   = 'D:\dafeiyu'
$QRPath = "$Root\napcat\NapCat.52230.Shell\versions\9.9.33-52230\resources\app\napcat\cache\qrcode.png"
$Log    = "$Root\logs\qr-tool.log"
$Bat    = "$Root\napcat\NapCat.52230.Shell\napcat.bat"

function Write-Log([string]$Msg) {
    Add-Content -Path $Log -Value ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Msg) -Encoding UTF8
}

function Test-Port([int]$Port) {
    try { $c = New-Object Net.Sockets.TcpClient; $c.Connect('127.0.0.1', $Port); $c.Close(); return $true }
    catch { return $false }
}

function Test-Linked {
    return [bool](Get-NetTCPConnection -LocalPort 6199 -State Established -ErrorAction SilentlyContinue)
}

function Start-NapCatQR {
    Get-Process QQ, NapCatWinBootMain -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2
    Remove-Item $QRPath -Force -ErrorAction SilentlyContinue
    Start-Process -FilePath 'cmd.exe' `
        -ArgumentList '/c', "`"$Bat`"" `
        -WorkingDirectory (Split-Path $Bat) `
        -WindowStyle Hidden
    Write-Log '[start] napcat qr mode'
}

# ---------------- UI ----------------
$form = New-Object System.Windows.Forms.Form
$form.Text = '大肥鱼 · QQ 扫码登录'
$form.Size = New-Object System.Drawing.Size(520, 660)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false

$status = New-Object System.Windows.Forms.Label
$status.Text = '正在检查登录状态…'
$status.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 11, [System.Drawing.FontStyle]::Bold)
$status.AutoSize = $true
$status.Location = New-Object System.Drawing.Point(24, 18)

$picture = New-Object System.Windows.Forms.PictureBox
$picture.Size = New-Object System.Drawing.Size(460, 460)
$picture.Location = New-Object System.Drawing.Point(24, 56)
$picture.SizeMode = 'Zoom'
$picture.BackColor = [System.Drawing.Color]::White

$hint = New-Object System.Windows.Forms.Label
$hint.Text = '二维码每 2 分钟自动刷新；扫码后在手机上点「确认登录」。'
$hint.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
$hint.ForeColor = [System.Drawing.Color]::DimGray
$hint.AutoSize = $true
$hint.Location = New-Object System.Drawing.Point(24, 528)

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = '重新获取二维码'
$btnRefresh.Size = New-Object System.Drawing.Size(150, 38)
$btnRefresh.Location = New-Object System.Drawing.Point(24, 566)
$btnRefresh.Add_Click({
    if (Test-Linked) {
        $r = [System.Windows.Forms.MessageBox]::Show('当前已经登录，重新扫码会让 QQ 下线一次。继续？', '确认', 'YesNo', 'Question')
        if ($r -ne 'Yes') { return }
    }
    $script:lastMtime = [datetime]::MinValue
    $picture.Image = $null
    Start-NapCatQR
    $status.Text = '正在生成新二维码…'
    $status.ForeColor = [System.Drawing.Color]::DarkOrange
})

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = '关闭'
$btnClose.Size = New-Object System.Drawing.Size(90, 38)
$btnClose.Location = New-Object System.Drawing.Point(394, 566)
$btnClose.Add_Click({ $form.Close() })

$form.Controls.AddRange(@($status, $picture, $hint, $btnRefresh, $btnClose))

$script:lastMtime = [datetime]::MinValue

function Update-QR {
    $linked = Test-Linked
    if ($linked) {
        $status.Text = '✅ 已登录，不需要扫码'
        $status.ForeColor = [System.Drawing.Color]::SeaGreen
    } else {
        $status.Text = '⏳ 等待扫码…'
        $status.ForeColor = [System.Drawing.Color]::DarkOrange
    }

    if (-not (Test-Path $QRPath)) { return }
    $mtime = (Get-Item $QRPath).LastWriteTime
    if ($mtime -eq $script:lastMtime) { return }
    try {
        $fs = [System.IO.File]::Open($QRPath, 'Open', 'Read', 'ReadWrite')
        $img = [System.Drawing.Image]::FromStream($fs)
        $bmp = New-Object System.Drawing.Bitmap($img)
        $img.Dispose(); $fs.Close()
        $picture.Image = $bmp
        $script:lastMtime = $mtime
    } catch { }
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1500
$timer.Add_Tick({ Update-QR })
$timer.Start()

$form.Add_Shown({
    if (-not (Test-Linked) -and -not (Get-Process QQ -ErrorAction SilentlyContinue)) {
        Start-NapCatQR
    }
    Update-QR
})

$form.Add_FormClosed({ $timer.Stop() })

[void]$form.ShowDialog()
