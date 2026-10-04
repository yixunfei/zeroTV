#Requires -Version 5.1
<# .SYNOPSIS Runs quality checks, then creates Windows and Android test packages. #>
param(
  [ValidateSet('debug', 'release')][string]$Mode = 'release',
  [string]$AndroidDeviceId
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"
try {
  Invoke-Step 'Quality gate' {
    & powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\run_tests.ps1"
  }
  if ($AndroidDeviceId) {
    Invoke-Step 'Android live video regression' {
      Push-Location $Script:AppDir
      try {
        flutter test integration_test/live_video_test.dart -d $AndroidDeviceId
      } finally { Pop-Location }
    }
  }
  Invoke-Step 'Windows test package' {
    & powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\package_windows.ps1" -Mode $Mode -TestPackage -SkipPreparation
  }
  Invoke-Step 'Android test package' {
    & powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\package_android.ps1" -Mode $Mode -TestPackage -UniversalOnly -SkipPreparation
  }
  exit 0
} catch {
  Write-Host "Test packaging failed: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
