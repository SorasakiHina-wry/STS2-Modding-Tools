# 多角色工作区的路径约定（PowerShell 脚本共用，dot-source 引入）
#
#   . (Join-Path $PSScriptRoot '_charpaths.ps1') -Character saria
#
# 之后可用：$Character / $Workspace / $ModRoot / $ProjectDir / $DistDir / $StageDir / $WorkshopDir

param(
    [string]$Character = $(if ($env:STS2_CHARACTER) { $env:STS2_CHARACTER } else { 'saria' })
)

$Workspace   = Split-Path -Parent $PSScriptRoot          # D:\STS2
$ModRoot     = Join-Path $Workspace $Character           # D:\STS2\saria
$ProjectDir  = Join-Path (Join-Path $ModRoot 'mods-src') $Character   # ...\mods-src\saria
$ResourcesDir = Join-Path $ModRoot 'resources'
$DistDir     = Join-Path $Workspace 'dist'
$StageDir    = Join-Path $DistDir $Character
$WorkshopDir = Join-Path (Join-Path $DistDir 'workshop') $Character
