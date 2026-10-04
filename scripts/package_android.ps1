#Requires -Version 5.1
<# .SYNOPSIS Builds universal/per-ABI APKs and SHA256 checksums. #>
param(
  [ValidateSet('debug', 'release')][string]$Mode = 'release',
  [switch]$TestPackage,
  [switch]$UniversalOnly,
  [switch]$SkipBuild,
  [switch]$SkipPreparation
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"
. "$PSScriptRoot\android_environment.ps1"
try {
  if (-not $SkipBuild) {
    Assert-Dependencies -Commands @('flutter', 'dart')
    Set-LocalhostProxyBypass
    Set-AndroidBuildProxy
    if (-not $SkipPreparation) { Invoke-PubGetAll; Invoke-Codegen }
    if (-not $UniversalOnly) {
      Invoke-Step "Build Android $Mode per-ABI" {
        Push-Location $Script:AppDir
        try {
          if ($Mode -eq 'release') {
            flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build\app\symbols
          } else {
            flutter build apk --debug --split-per-abi
          }
        } finally { Pop-Location }
      }
    }
    Invoke-Step "Build Android $Mode universal" {
      Push-Location $Script:AppDir
      try {
        if ($Mode -eq 'release') {
          flutter build apk --release --obfuscate --split-debug-info=build\app\symbols
        } else {
          flutter build apk --debug
        }
      } finally { Pop-Location }
    }
  }
  $version = Get-AppVersion
  $suffix = if ($TestPackage) { '-test' } elseif ($Mode -eq 'debug') { '-debug' } else { '' }
  $apkDir = Join-Path $Script:AppDir 'build\app\outputs\flutter-apk'
  $abis = @()
  if (-not $UniversalOnly) { $abis = @('armeabi-v7a', 'arm64-v8a', 'x86_64') }
  $sources = @($abis | ForEach-Object { "app-$_-$Mode.apk" }) + @("app-$Mode.apk")
  foreach ($source in $sources) {
    if (-not (Test-Path -LiteralPath (Join-Path $apkDir $source))) { throw "Missing APK: $source" }
  }
  $dist = Join-Path $Script:RepoRoot 'build\dist'
  New-Item -ItemType Directory -Force -Path $dist | Out-Null
  $names = @($abis) + @('universal')
  $artifacts = for ($i = 0; $i -lt $sources.Count; $i++) {
    $target = Join-Path $dist "zerotv-${version}${suffix}-android-$($names[$i]).apk"
    Copy-Item -LiteralPath (Join-Path $apkDir $sources[$i]) -Destination $target -Force
    $target
  }
  Write-ArtifactChecksums -Files @($artifacts) -Path (Join-Path $dist "SHA256SUMS-android${suffix}.txt")
  $artifacts | ForEach-Object { Write-Host "Package ready: $_" -ForegroundColor Green }
  exit 0
} catch {
  Write-Host "Packaging failed: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
