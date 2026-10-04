#Requires -Version 5.1
<# .SYNOPSIS Builds a complete portable Windows bundle and SHA256 checksums. #>
param(
  [ValidateSet('debug', 'release')][string]$Mode = 'release',
  [switch]$TestPackage,
  [switch]$SkipBuild,
  [switch]$SkipPreparation
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"
try {
  if (-not $SkipBuild) {
    Invoke-Step 'Build Windows' {
      $buildArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "$PSScriptRoot\build_windows.ps1", '-Mode', $Mode)
      if ($SkipPreparation) { $buildArgs += '-SkipPreparation' }
      & powershell @buildArgs
    }
  }
  $src = Join-Path $Script:AppDir "build\windows\x64\runner\$Mode"
  Assert-WindowsBundle -Path $src
  if ($Mode -eq 'release' -and (Test-Path -LiteralPath (Join-Path $src 'data\flutter_assets\kernel_blob.bin'))) {
    throw 'Release contains stale debug snapshots. Rebuild without -SkipBuild.'
  }
  $version = Get-AppVersion
  $suffix = if ($TestPackage) { '-test' } elseif ($Mode -eq 'debug') { '-debug' } else { '' }
  $name = "zerotv-${version}${suffix}-windows-x64"
  $dist = Join-Path $Script:RepoRoot 'build\dist'
  New-Item -ItemType Directory -Force -Path $dist | Out-Null
  $stageRoot = Join-Path $Script:RepoRoot ('build\package-staging\' + [Guid]::NewGuid().ToString())
  $staging = Join-Path $stageRoot $name
  New-Item -ItemType Directory -Force -Path $staging | Out-Null
  Copy-Item -Path (Join-Path $src '*') -Destination $staging -Recurse
  Copy-WindowsRuntime -Destination $staging
  Copy-Item -LiteralPath (Join-Path $Script:RepoRoot 'LICENSE') -Destination $staging
  $zip = Join-Path $dist "$name.zip"
  Compress-Archive -LiteralPath $staging -DestinationPath $zip -Force
  Write-ArtifactChecksums -Files @($zip) -Path (Join-Path $dist "SHA256SUMS-windows${suffix}.txt")
  Write-Host "Package ready: $zip" -ForegroundColor Green
  exit 0
} catch {
  Write-Host "Packaging failed: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
