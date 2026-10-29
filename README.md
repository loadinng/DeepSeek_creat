# 大肥鱼 QQ 机器人 · 掉线弹窗 + 扫码助手

两个独立的小工具，配合 AstrBot + NapCat 使用，解决「QQ 掉线后没人知道」和「重新登录要翻黑窗口找二维码」两个问题。

## 文件

| 文件 | 作用 |
|---|---|
| `watchdog.ps1` | 每 20 秒检查一次 AstrBot / NapCat / QQ / 6199 连接；从在线变为掉线时弹窗，点「打开二维码」直接拉起扫码助手 |
| `watchdog.vbs` | 隐藏窗口启动 watchdog |
| `qr-tool.ps1` | 一个窗口显示当前登录二维码，每 1.5 秒自动跟随 NapCat 刷新；已登录时显示「✅ 已登录」；可一键重新获取 |
| `qr-tool.vbs` | 隐藏 PowerShell 控制台，只显示图形窗口 |

## 依赖

- Windows 10/11，PowerShell 5.1（系统自带）
- 已经按 `D:\dafeiyu` 部署好的 AstrBot + NapCat
- 无第三方模块，不需要联网

## 直接用

```text
双击 D:\dafeiyu\tools\qr-tool.vbs        打开二维码窗口
双击 D:\dafeiyu\tools\watchdog.vbs       启动后台监控（无窗口）
```

开机自启已经由 `D:\dafeiyu\start-all.ps1` 在最后一步拉起 watchdog；扫码助手的桌面快捷方式是「扫二维码.lnk」。

## 判定逻辑

在线 = 同时满足：

1. `127.0.0.1:6185` 在监听（AstrBot 后台）
2. `127.0.0.1:6099` 在监听（NapCat）
3. `QQ.exe` 进程存在
4. `127.0.0.1:6199` 有 Established 连接（NapCat → AstrBot）

任一不满足即视为掉线；弹窗里会写明是哪一条不满足。启动后有 180 秒宽限期，避免开机时服务还没起来就误报；同一轮掉线最多每 10 分钟提醒一次。

## 路径适配

脚本默认根目录是 `D:\dafeiyu`，二维码路径按当前 NapCat 版本写死：

```text
D:\dafeiyu\napcat\NapCat.52230.Shell\versions\9.9.33-52230\resources\app\napcat\cache\qrcode.png
```

换机器或升级 NapCat 后，改 `qr-tool.ps1` 顶部的 `$QRPath` 和 `$Bat` 两个变量即可（`$Root` 也在一起）。

## 已知限制

- 只能发现「已掉线」，不能自动重新登录：QQ 要求扫码/验证时必须人工确认。
- 弹窗是本地 WinForms 窗口，只在当前登录的 Windows 桌面显示；远程桌面断开时看不到。
- 杀毒软件可能拦截 `wscript.exe` 启动 PowerShell，遇到就把 `D:\dafeiyu\tools` 加白名单。

## 许可

MIT
