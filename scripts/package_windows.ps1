#Requires -Version 5.1
<#
.SYNOPSIS
  zeroTV Windows 一键打包脚本：构建 release 并产出可分发 zip。

.DESCRIPTION
  在 build_windows.ps1 之上多做两步：
    1. 把 runner\Release 整个目录拷到 staging（重命名为 zerotv-<ver>-windows-x64）
    2. Compress-Archive 打成 zip + 生成 SHA256SUMS
  产物落在 build\dist\，命名与 GitHub Release 工作流保持一致。

  用法：
    powershell -File scripts\package_windows.ps1              # release 打包
    powershell -File scripts\package_windows.ps1 -SkipBuild   # 已构建过，只打包

.PARAMETER SkipBuild
  跳过 flutter build windows（沿用上一次 release 构建产物）。

.NOTES
  产物路径：build\dist\zerotv-<version>-windows-x64.zip
  版本号取自 apps\player\pubspec.yaml 的 version 字段（取 + 前的 semver）。
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
  Assert-Dependencies -Commands @('flutter', 'dart')
  Set-LocalhostProxyBypass

  if (-not $SkipBuild) {
    Invoke-PubGetAll
    Invoke-Codegen
    Invoke-Step '构建 Windows (release)' {
      Push-Location $Script:AppDir
      try { flutter build windows --release } finally { Pop-Location }
    }
  }

  $version = Get-AppVersion
  $src = Join-Path $Script:AppDir 'build\windows\x64\runner\Release'
  $exe = Join-Path $src 'zerotv_player.exe'
  if (-not (Test-Path $exe)) {
    throw "未找到构建产物：$exe。请先去掉 -SkipBuild 跑完整构建。"
  }

  $distRoot = Join-Path $Script:RepoRoot 'build\dist'
  $staging = Join-Path $distRoot "zerotv-${version}-windows-x64"
  $zipPath = Join-Path $distRoot "zerotv-${version}-windows-x64.zip"
  $sumsPath = Join-Path $distRoot 'SHA256SUMS-windows.txt'

  Write-Step "打包 $zipPath"
  New-Item -ItemType Directory -Force -Path $distRoot | Out-Null
  if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
  if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
  New-Item -ItemType Directory -Force -Path $staging | Out-Null
  Copy-Item (Join-Path $src '*') $staging -Recurse
  Compress-Archive -Path $staging -DestinationPath $zipPath -Force

  Write-Step "生成 SHA256 -> $sumsPath"
  $hash = (Get-FileHash $zipPath -Algorithm SHA256).Hash.ToLower()
  $line = "{0}  {1}" -f $hash, (Split-Path $zipPath -Leaf)
  [System.IO.File]::WriteAllText(
    $sumsPath,
    $line + "`n",
    (New-Object System.Text.UTF8Encoding($false))
  )

  Write-Host "`n打包完成：" -ForegroundColor Green
  Write-Host "  $zipPath"
  Write-Host "  $sumsPath"
  exit 0
} catch {
  Write-Host "`n打包失败：$($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
