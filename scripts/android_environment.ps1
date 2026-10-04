#Requires -Version 5.1
<# .SYNOPSIS Propagates an existing Windows web proxy to Java for this build. #>
function Set-AndroidBuildProxy {
  # Gradle's plugin downloads use java.net.URL and ignore the Windows proxy.
  # Honor explicit Java proxy configuration instead of overriding it.
  if ("$env:JAVA_TOOL_OPTIONS $env:GRADLE_OPTS" -match '-Dhttps?\.proxyHost=') { return }
  $target = [Uri]'https://github.com'
  $proxy = [Net.WebRequest]::DefaultWebProxy.GetProxy($target)
  if ($proxy -eq $target -or $proxy.Scheme -ne 'http' -or $proxy.UserInfo) { return }
  $options = "-Dhttps.proxyHost=$($proxy.Host) -Dhttps.proxyPort=$($proxy.Port) -Dhttp.proxyHost=$($proxy.Host) -Dhttp.proxyPort=$($proxy.Port)"
  $env:JAVA_TOOL_OPTIONS = "$env:JAVA_TOOL_OPTIONS $options".Trim()
  Write-Host 'Using the configured Windows web proxy for Java downloads.'
}
