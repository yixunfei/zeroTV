param(
  [int]$TimeoutSec = 20
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $PSScriptRoot
$sourceFile = Join-Path $scriptRoot 'apps/player/lib/features/subscription/domain/default_subscription.dart'

if (-not (Test-Path -LiteralPath $sourceFile)) {
  throw "Built-in source file was not found: $sourceFile"
}

$urls = Select-String -Path $sourceFile -Pattern "'https://[^']+'" -AllMatches |
  ForEach-Object { $_.Matches.Value.Trim("'") } |
  Select-Object -Unique |
  Where-Object { $_ -notmatch 'Ftindy/IPTV-URL' }

if ($urls.Count -eq 0) {
  throw 'No built-in source URLs were found.'
}

$failed = [System.Collections.Generic.List[object]]::new()
$null = Add-Type -AssemblyName System.Net.Http
$client = New-Object System.Net.Http.HttpClient
$client.DefaultRequestHeaders.UserAgent.ParseAdd('zeroTV-source-precheck/1.0')
foreach ($url in $urls) {
  $cancel = [Threading.CancellationTokenSource]::new($TimeoutSec * 1000)
  try {
    $response = $client.GetAsync($url, $cancel.Token).GetAwaiter().GetResult()
    $bytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
    $header = [Text.Encoding]::ASCII.GetString($bytes, 0, [Math]::Min(4096, $bytes.Length))
    $valid = $response.IsSuccessStatusCode -and ($header -match '#EXTM3U|#EXTINF')
    $state = if ($valid) { 'OK' } else { 'INVALID_PLAYLIST' }
    Write-Host "$state`t$([int]$response.StatusCode)`t$($bytes.Length)`t$url"
    if (-not $valid) {
      $failed.Add([pscustomobject]@{ Url = $url; Reason = $state })
    }
  } catch {
    Write-Host "UNREACHABLE`t0`t0`t$url`t$($_.Exception.Message)"
    $failed.Add([pscustomobject]@{ Url = $url; Reason = 'UNREACHABLE' })
  } finally {
    $cancel.Dispose()
  }
}
$client.Dispose()

if ($failed.Count -gt 0) {
  throw "$($failed.Count) built-in source URL(s) failed the precheck."
}

Write-Host "Precheck passed for $($urls.Count) built-in source URL(s)."
