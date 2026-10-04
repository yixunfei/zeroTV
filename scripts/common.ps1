#Requires -Version 5.1
<#
.SYNOPSIS
  zeroTV 脚本共享函数库。

.DESCRIPTION
  被 scripts/ 下的脚本通过 dot-source 引用（. "$PSScriptRoot\common.ps1"），
  不要直接运行本文件。集中放置：依赖检查、代理绕过、依赖解析、代码生成、
  步骤执行与退出码处理，保证各脚本行为一致（DRY）。
#>

Set-StrictMode -Version Latest

# 仓库根目录（scripts/ 的上一级）与关键路径。
$Script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Script:AppDir = Join-Path $Script:RepoRoot 'apps\player'
# 四个纯 Dart 包（无 Flutter 依赖，用 dart test 跑）。
$Script:PurePackages = @('iptv_core', 'm3u_parser', 'xmltv_parser', 'stream_probe')

function Write-Step {
  <#.SYNOPSIS 打印分节标题，便于在长篇输出中定位。#>
  param([Parameter(Mandatory)][string]$Message)
  Write-Host "`n== $Message ==" -ForegroundColor Cyan
}

function Assert-Dependencies {
  <#
  .SYNOPSIS
    检查所需命令是否在 PATH 中；缺失即抛出带安装提示的错误。
  #>
  param([Parameter(Mandatory)][string[]]$Commands)
  foreach ($cmd in $Commands) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
      throw "未找到命令 '$cmd'。请先安装并加入 PATH（Flutter SDK 自带 dart；Android 构建需要 JDK17）。"
    }
  }
}

function Invoke-Step {
  <#
  .SYNOPSIS
    执行一个命名步骤；原生命令退出码非 0 时抛错（fail fast，与 CI 一致）。
  #>
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][scriptblock]$Action
  )
  Write-Step $Name
  $global:LASTEXITCODE = 0
  & $Action
  if ($LASTEXITCODE -ne 0) {
    throw "步骤失败：$Name（退出码 $LASTEXITCODE）"
  }
}

function Set-LocalhostProxyBypass {
  <#
  .SYNOPSIS
    绕过本机代理对 localhost 的劫持。
  .DESCRIPTION
    本机配了系统代理时，flutter_tester 与本地的 WebSocket 握手会被代理劫走，
    报 "Unable to connect to flutter_tester process"。对 localhost 强制直连。
  #>
  $entries = @($env:NO_PROXY -split ',') + @('localhost', '127.0.0.1', '::1')
  $env:NO_PROXY = ($entries | Where-Object { $_ } | Select-Object -Unique) -join ','
}

function Invoke-PubGetAll {
  <#
  .SYNOPSIS
    逐目录解析依赖。本仓库各包 standalone 解析（不用 Pub Workspaces），
    每个目录都必须单独 pub get。
  #>
  Invoke-Step 'pub get: 仓库根' {
    Push-Location $Script:RepoRoot
    try { dart pub get } finally { Pop-Location }
  }
  foreach ($pkg in $Script:PurePackages) {
    Invoke-Step "pub get: packages/$pkg" {
      Push-Location (Join-Path $Script:RepoRoot "packages\$pkg")
      try { dart pub get } finally { Pop-Location }
    }
  }
  Invoke-Step 'pub get: apps/player' {
    Initialize-WindowsPluginSymlinks
    Push-Location $Script:AppDir
    try { flutter pub get } finally { Pop-Location }
  }
}

function Invoke-Codegen {
  <#
  .SYNOPSIS
    drift 与 gen-l10n 代码生成（生成物不入库，构建/分析/测试前必须先跑）。
  #>
  Invoke-Step 'build_runner (drift)' {
    Push-Location $Script:AppDir
    try {
      dart run build_runner build
    } finally { Pop-Location }
  }
  Invoke-Step 'gen-l10n' {
    Push-Location $Script:AppDir
    try { flutter gen-l10n } finally { Pop-Location }
  }
}

function Initialize-WindowsPluginSymlinks {
  <#
  .SYNOPSIS
    预建 Windows 插件符号链接的父目录。
  .DESCRIPTION
    flutter 工具在本机创建 ephemeral\.plugin_symlinks 时可能因父目录缺失
    直接崩溃（errno=2）。预建该目录可让 pub get 通过；若 build 仍报
    "Cannot create link"，需开启 Windows 开发者模式或用管理员身份
    执行一次首次构建（符号链接特权问题，与项目代码无关）。
  #>
  $ep = Join-Path $Script:AppDir 'windows\flutter\ephemeral\.plugin_symlinks'
  New-Item -ItemType Directory -Force -Path $ep | Out-Null
}

function Get-AppVersion {
  $match = Select-String -LiteralPath (Join-Path $Script:AppDir 'pubspec.yaml') -Pattern '^version:\s*(\S+)'
  if (-not $match) { throw 'Missing app version in pubspec.yaml' }
  return ($match.Matches[0].Groups[1].Value -split '\+')[0]
}

function Write-ArtifactChecksums {
  param([string[]]$Files, [string]$Path)
  $lines = foreach ($file in $Files) {
    '{0}  {1}' -f (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant(), (Split-Path $file -Leaf)
  }
  [IO.File]::WriteAllText($Path, ($lines -join "`n") + "`n", (New-Object Text.UTF8Encoding($false)))
}

function Assert-WindowsBundle {
  param([string]$Path)
  foreach ($name in @('zerotv_player.exe', 'flutter_windows.dll', 'libmpv-2.dll', 'data\icudtl.dat', 'data\flutter_assets')) {
    if (-not (Test-Path -LiteralPath (Join-Path $Path $name))) {
      throw "Incomplete Windows bundle: missing $name"
    }
  }
}

function Copy-WindowsRuntime {
  param([string]$Destination)
  $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
  if (-not (Test-Path -LiteralPath $vswhere)) { throw 'vswhere.exe is required to locate the Visual C++ runtime' }
  $install = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
  if ($LASTEXITCODE -ne 0 -or -not $install) { throw 'Visual C++ toolchain not found' }
  $redist = Join-Path $install 'VC\Redist\MSVC'
  $crt = Get-ChildItem -Path "$redist\*\x64\Microsoft.VC*.CRT" -Directory | Sort-Object FullName -Descending | Select-Object -First 1
  if (-not $crt) { throw 'Visual C++ x64 redistributable DLLs not found' }
  Copy-Item -Path (Join-Path $crt.FullName '*.dll') -Destination $Destination -Force
}
