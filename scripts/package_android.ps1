#Requires -Version 5.1
<#
.SYNOPSIS
  zeroTV Android 一键打包脚本：构建 release APK（分 ABI + universal）并
  重命名成可分发文件名 + 生成 SHA256SUMS。

.DESCRIPTION
  在 build_android.ps1 之上多做：
    1. flutter build apk --release --split-per-abi
    2. flutter build apk --release（universal 兜底）
    3. 把 4 个 APK 重命名成 zerotv-<ver>-android-<abi>.apk /
       zerotv-<ver>-android-universal.apk 落到 build\dist\
    4. 生成 SHA256SUMS-android.txt
  命名与 .github/workflows/release.yaml 完全一致，本地包可直接 Release。

  用法：
    powershell -File scripts\package_android.ps1              # 完整流程
    powershell -File scripts\package_android.ps1 -SkipBuild   # 复用上次构建

.PARAMETER SkipBuild
  跳过 flutter build apk（沿用上一次 release 构建产物）。

.NOTES
  签名：复用 android/app/build.gradle.kts 的链路 —— 优先 android/key.properties，
  回退 ZEROTV_KEYSTORE_B64 等环境变量，都没有则 debug 签名（仅供开发自测）。
  正式发布请配好 key.properties 或走 GitHub Release 工作流。

  产物路径：build\dist\zerotv-<version>-android-*.apk
#>
param(
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"

function Get-AppVersion {
  <#
  .SYNOPSIS
    从 apps/player/pubspec.yaml 读取 version（去掉 +build 后缀）。
  #>
  $pubspec = Join-Path $Script:AppDir 'pubspec.yaml'
  $line = Select-String -Path $pubspec -Pattern '^version:\s*(\S+)' |
    Select-Object -First 1
  if (-not $line) { throw "未在 $pubspec 找到 version 字段" }
  $raw = $line.Matches[0].Groups[1].Value
  return ($raw -split '\+')[0]
}

try {
  Assert-Dependencies -Commands @('flutter', 'dart', 'java')
  Set-LocalhostProxyBypass

  if (-not $SkipBuild) {
    Invoke-PubGetAll
    Invoke-Codegen
    Invoke-Step '构建 Android release APK (split-per-abi)' {
      Push-Location $Script:AppDir
      try { flutter build apk --release --split-per-abi } finally { Pop-Location }
    }
    Invoke-Step '构建 Android release APK (universal)' {
      Push-Location $Script:AppDir
      try { flutter build apk --release } finally { Pop-Location }
    }
  }

  $version = Get-AppVersion
  $apkDir = Join-Path $Script:AppDir 'build\app\outputs\flutter-apk'
  $abis = @('armeabi-v7a', 'arm64-v8a', 'x86_64')
  foreach ($abi in $abis) {
    $expected = Join-Path $apkDir "app-$abi-release.apk"
    if (-not (Test-Path $expected)) {
      throw "未找到 $expected。请先去掉 -SkipBuild 跑完整构建。"
    }
  }
  $universal = Join-Path $apkDir 'app-release.apk'
  if (-not (Test-Path $universal)) {
    throw "未找到 $universal。请先去掉 -SkipBuild 跑完整构建。"
  }

  $distRoot = Join-Path $Script:RepoRoot 'build\dist'
  New-Item -ItemType Directory -Force -Path $distRoot | Out-Null
  $sumsPath = Join-Path $distRoot 'SHA256SUMS-android.txt'

  $renamed = @()
  foreach ($abi in $abis) {
    $renamed += Join-Path $distRoot "zerotv-${version}-android-${abi}.apk"
  }
  $renamed += Join-Path $distRoot "zerotv-${version}-android-universal.apk"

  $sources = @()
  foreach ($abi in $abis) {
    $sources += Join-Path $apkDir "app-$abi-release.apk"
  }
  $sources += $universal

  Write-Step "拷贝并按 ABI 重命名到 $distRoot"
  for ($i = 0; $i -lt $renamed.Count; $i++) {
    Copy-Item $sources[$i] $renamed[$i] -Force
  }

  Write-Step "生成 SHA256 -> $sumsPath"
  $lines = foreach ($f in $renamed) {
    $hash = (Get-FileHash $f -Algorithm SHA256).Hash.ToLower()
    "{0}  {1}" -f $hash, (Split-Path $f -Leaf)
  }
  [System.IO.File]::WriteAllText(
    $sumsPath,
    ($lines -join "`n") + "`n",
    (New-Object System.Text.UTF8Encoding($false))
  )

  Write-Host "`n打包完成：" -ForegroundColor Green
  foreach ($f in $renamed) { Write-Host "  $f" }
  Write-Host "  $sumsPath"
  exit 0
} catch {
  Write-Host "`n打包失败：$($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
