#requires -Version 5.1
<#
Build one character mod (see -Character). Keeps dotnet's first-run/tool state inside the workspace so it
works under the DSH file sandbox (which forbids writes to %USERPROFILE%\.dotnet).

  pwsh -File tools\build.ps1 -Character saria
#>
param(
    [string]$Character = $(if ($env:STS2_CHARACTER) { $env:STS2_CHARACTER } else { 'saria' })
)

$ErrorActionPreference = 'Stop'


. (Join-Path $PSScriptRoot '_charpaths.ps1') -Character $Character

$env:DOTNET_CLI_HOME = Join-Path $Workspace '.dotnet-home'
$env:NUGET_PACKAGES = Join-Path $Workspace '.nuget\packages'
$env:DOTNET_NOLOGO = '1'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'

Push-Location $ProjectDir
try {
    dotnet build -c Release
    if ($LASTEXITCODE -ne 0) { throw "build failed ($LASTEXITCODE)" }
}
finally {
    Pop-Location
}
