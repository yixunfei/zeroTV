#Requires -Version 5.1
<#
.SYNOPSIS
  zeroTV Windows 桌面端构建打包脚本。

.DESCRIPTION
  前置要求：Visual Studio 2022（含 "使用 C++ 的桌面开发" 工作负荷）、
  Flutter 已启用 windows-desktop。
  用法：
    powershell -File scripts\build_windows.ps1              # release（默认）
    powershell -File scripts\build_windows.ps1 -Mode debug  # debug

  产物：
    apps\player\build\windows\x64\runner\<Mode>\zerotv_player.exe
    （release 模式直接分发 runner\Release 整个目录即可，含全部 DLL）

.PARAMETER Mode
  debug 或 release，默认 release。

.NOTES
  已知环境问题：本机未开开发者模式时，flutter 创建插件符号链接可能崩溃
  （"Cannot create link ... .plugin_symlinks"）。本脚本会预建目录缓解；
  仍失败请开启开发者模式（设置 → 系统 → 开发者选项）或以管理员身份
  运行一次首次构建。
#>
param(
  [ValidateSet('debug', 'release')]
  [string]$Mode = 'release',
  [switch]$SkipPreparation
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"

try {
  Assert-Dependencies -Commands @('flutter', 'dart')
  Set-LocalhostProxyBypass
  Initialize-WindowsPluginSymlinks
  if (-not $SkipPreparation) {
    Invoke-PubGetAll
    Invoke-Codegen
  }

  Invoke-Step "构建 Windows ($Mode)" {
    Push-Location $Script:AppDir
    try {
      # release 混淆并剥离 Dart 符号（还原崩溃堆栈用 build\windows\symbols）。
      if ($Mode -eq 'release') {
        flutter build windows --release --obfuscate --split-debug-info=build/windows/symbols
      } else {
        flutter build windows --debug
      }
    } finally { Pop-Location }
  }

  $out = Join-Path $Script:AppDir "build\windows\x64\runner\$Mode"
  Assert-WindowsBundle -Path $out
  Write-Host "`n构建完成：$out\zerotv_player.exe" -ForegroundColor Green
  exit 0
} catch {
  Write-Host "`n构建失败：$($_.Exception.Message)" -ForegroundColor Red
  Write-Host '提示：若错误含 "Cannot create link ... plugin_symlinks"，' `
    '请开启 Windows 开发者模式或以管理员身份重试（符号链接特权问题）。' `
    -ForegroundColor Yellow
  exit 1
}
