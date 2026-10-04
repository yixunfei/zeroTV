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
    release APK 按 ABI 拆分（app-armeabi-v7a / app-arm64-v8a / app-x86_64），
      侧载 64 位手机选 app-arm64-v8a-release.apk；
    AAB → apps\player\build\app\outputs\bundle\release\app-release.aab；
    release 混淆符号（还原崩溃堆栈用）→ apps\player\build\app\symbols。

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
  [string]$Mode = 'release',
  [switch]$SkipPreparation
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"
. "$PSScriptRoot\android_environment.ps1"

try {
  Assert-Dependencies -Commands @('flutter', 'dart', 'java')
  Set-LocalhostProxyBypass
  Set-AndroidBuildProxy
  if (-not $SkipPreparation) {
    Invoke-PubGetAll
    Invoke-Codegen
  }

  Invoke-Step "构建 Android $Target ($Mode)" {
    Push-Location $Script:AppDir
    try {
      # 包体优化：
      #  - --split-per-abi：按 ABI 拆分 APK（arm64-v8a 单包约为通用包的
      #    1/3，native 库是 IPTV 播放器包体的主要来源）；
      #  - --obfuscate --split-debug-info：混淆并剥离 Dart 符号，产物
      #    崩溃堆栈需要用 build/app/symbols 下的符号文件还原。
      #  - --tree-shake-icons 由 Flutter 在非 debug 构建默认开启。
      if ($Mode -ne 'debug') {
        $symbols = "build\app\symbols"
        if ($Target -eq 'apk') {
          flutter build apk --release --split-per-abi --obfuscate --split-debug-info=$symbols
        } else {
          flutter build appbundle --release --obfuscate --split-debug-info=$symbols
        }
      } elseif ($Target -eq 'apk') {
        flutter build apk --debug
      } else {
        flutter build appbundle --debug
      }
    } finally { Pop-Location }
  }

  if ($Target -eq 'apk') {
    if ($Mode -ne 'debug') {
      # split-per-abi 产物：app-armeabi-v7a/arm64-v8a/x86_64-release.apk
      $outDir = Join-Path $Script:AppDir "build\app\outputs\flutter-apk"
      $apks = Get-ChildItem -LiteralPath $outDir -Filter "app-*-release.apk" -ErrorAction SilentlyContinue
      if ($apks) {
        $apks | ForEach-Object {
          Write-Host ("  {0}  {1:N1} MB" -f $_.Name, ($_.Length / 1MB)) -ForegroundColor Cyan
        }
      }
      $out = Join-Path $outDir "app-arm64-v8a-release.apk"
    } else {
      $out = Join-Path $Script:AppDir "build\app\outputs\flutter-apk\app-debug.apk"
    }
  } elseif ($Mode -ne 'debug') {
    $out = Join-Path $Script:AppDir "build\app\outputs\bundle\release\app-release.aab"
  } else {
    $out = Join-Path $Script:AppDir "build\app\outputs\bundle\debug\app-debug.aab"
  }
  if (-not (Test-Path -LiteralPath $out)) { throw "Missing artifact: $out" }
  Write-Host "`n构建完成：$out" -ForegroundColor Green
  exit 0
} catch {
  Write-Host "`n构建失败：$($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
