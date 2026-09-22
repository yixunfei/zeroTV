#Requires -Version 5.1
<#
.SYNOPSIS
  zeroTV 本地一键质量门：依赖检查 → 依赖解析 → 代码生成 → 格式检查 →
  静态分析 → 全部测试（4 个纯 Dart 包 + Flutter 应用）。

.DESCRIPTION
  与 CI 流水线同构，本地提交前跑一遍即可预判 CI 结果。
  用法：
    powershell -File scripts\run_tests.ps1                  # 完整流程
    powershell -File scripts\run_tests.ps1 -SkipCodegen     # 已生成过代码
    powershell -File scripts\run_tests.ps1 -Fast            # 只跑测试（跳过格式/分析）

.PARAMETER SkipCodegen
  跳过 build_runner（drift 生成文件已是最新时使用）。

.PARAMETER Fast
  跳过 dart format 检查与 flutter analyze，只执行测试。
#>
param(
  [switch]$SkipCodegen,
  [switch]$Fast
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"

try {
  Assert-Dependencies -Commands @('flutter', 'dart')
  Set-LocalhostProxyBypass
  Invoke-PubGetAll
  if (-not $SkipCodegen) { Invoke-Codegen }

  if (-not $Fast) {
    Invoke-Step '格式检查 (dart format --set-exit-if-changed)' {
      Push-Location $Script:RepoRoot
      try { dart format --set-exit-if-changed . } finally { Pop-Location }
    }
    Invoke-Step '静态分析 (flutter analyze)' {
      Push-Location $Script:RepoRoot
      try { flutter analyze } finally { Pop-Location }
    }
  }

  foreach ($pkg in $Script:PurePackages) {
    Invoke-Step "测试: packages/$pkg (dart test)" {
      Push-Location (Join-Path $Script:RepoRoot "packages\$pkg")
      try { dart test } finally { Pop-Location }
    }
  }
  Invoke-Step '测试: apps/player (flutter test)' {
    Push-Location $Script:AppDir
    try { flutter test } finally { Pop-Location }
  }

  Write-Host "`n全部通过。" -ForegroundColor Green
  exit 0
} catch {
  Write-Host "`n失败：$($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
