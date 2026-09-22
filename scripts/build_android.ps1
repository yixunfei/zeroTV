#Requires -Version 5.1
<#
.SYNOPSIS
  zeroTV Android 端构建打包脚本。

.DESCRIPTION
  前置要求：JDK17（Flutter 3.44 推荐）、Android SDK（含 cmdline-tools）。
  复用工程现有 Gradle 配置与 AndroidManifest（已含 INTERNET 权限与
  usesCleartextTraffic，IPTV 明文源必需，勿删）。
  用法：
    powershell -File scripts\build_android.ps1                    # release APK
    powershell -File scripts\build_android.ps1 -Target aab        # release AAB
    powershell -File scripts\build_android.ps1 -Mode debug        # debug APK

  产物：
    APK → apps\player\build\app\outputs\flutter-apk\app-<mode>.apk
    AAB → apps\player\build\app\outputs\bundle\release\app-release.aab

.PARAMETER Target
  apk（侧载分发）或 aab（上架商店），默认 apk。

.PARAMETER Mode
  debug 或 release，默认 release。

.NOTES
  release 签名：当前使用 flutter 默认 debug 签名（开发期）。上架前需在
  android/app 下配置 signingConfigs 与 key.properties（M5 Release 工作流
  一并处理）。
#>
param(
  [ValidateSet('apk', 'aab')]
  [string]$Target = 'apk',
  [ValidateSet('debug', 'release')]
  [string]$Mode = 'release'
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"

try {
  Assert-Dependencies -Commands @('flutter', 'dart', 'java')
  Set-LocalhostProxyBypass
  Invoke-PubGetAll
  Invoke-Codegen

  Invoke-Step "构建 Android $Target ($Mode)" {
    Push-Location $Script:AppDir
    try {
      if ($Target -eq 'apk') {
        flutter build apk --$Mode
      } else {
        # AAB 只有 release 形态有意义
        flutter build appbundle --release
      }
    } finally { Pop-Location }
  }

  if ($Target -eq 'apk') {
    $out = Join-Path $Script:AppDir "build\app\outputs\flutter-apk\app-$Mode.apk"
  } else {
    $out = Join-Path $Script:AppDir 'build\app\outputs\bundle\release\app-release.aab'
  }
  Write-Host "`n构建完成：$out" -ForegroundColor Green
  exit 0
} catch {
  Write-Host "`n构建失败：$($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
