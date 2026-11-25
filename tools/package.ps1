#requires -Version 5.1
<#
把某个角色 mod 打包成「可直接放进游戏 mods 目录」的分发文件。

用法：
  powershell -ExecutionPolicy Bypass -File tools\package.ps1 -Character saria

产物：
  dist\<角色>\...                解压/拷贝到 <游戏>\mods\ 下的文件夹
  dist\<角色>-<version>.zip      给别人测试用（解压后把 <角色> 文件夹放进 mods）

前置：
  - 已安装 .NET 9 SDK
  - PCK 已构建到 build\<角色>.pck（改动 assets\ 后需要重新打包，见项目 README）
#>
param(
    [string]$Character = $(if ($env:STS2_CHARACTER) { $env:STS2_CHARACTER } else { 'saria' })
)

$ErrorActionPreference = 'Stop'


. (Join-Path $PSScriptRoot '_charpaths.ps1') -Character $Character
$Manifest   = Get-Content (Join-Path $ProjectDir 'mod_manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$Version    = $Manifest.version
$HasPck     = -not ($Manifest.PSObject.Properties.Name -contains 'has_pck') -or [bool]$Manifest.has_pck

Write-Host "[1/5] 编译 Release ..."
Push-Location $ProjectDir
try {
    & dotnet build -c Release --nologo *> $null
    if ($LASTEXITCODE -ne 0) { throw 'dotnet build 失败' }
} finally { Pop-Location }

$dll = Join-Path $ProjectDir "bin\Release\$Character.dll"
$pck = Join-Path $ProjectDir "build\$Character.pck"
$required = @($dll)
if ($HasPck) { $required += $pck }
foreach ($f in $required) {
    if (-not (Test-Path $f)) { throw "缺少文件：$f" }
}
if (-not $HasPck) { Write-Host "manifest 标记 has_pck=false：跳过 PCK" }

# PCK 比 assets 旧时提醒（PCK 只装 spine 与本地化 JSON，改卡不改它）
$assetsDir = Join-Path $ProjectDir 'assets'
if (Test-Path $assetsDir) {
    $newest = Get-ChildItem $assetsDir -Recurse -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($HasPck -and $newest -and $newest.LastWriteTime -gt (Get-Item $pck).LastWriteTime) {
        Write-Warning "assets\ 比 build\$Character.pck 新（$($newest.Name)），PCK 可能需要重新打包。"
    }
}

Write-Host "[2/5] 准备 dist\$Character ..."
if (Test-Path $StageDir) { Remove-Item $StageDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $StageDir | Out-Null

Write-Host "[3/5] 复制 DLL / manifest / PCK ..."
Copy-Item $dll (Join-Path $StageDir "$Character.dll") -Force
if ($HasPck) { Copy-Item $pck (Join-Path $StageDir "$Character.pck") -Force }
Copy-Item (Join-Path $ProjectDir 'mod_manifest.json') (Join-Path $StageDir 'mod_manifest.json') -Force

Write-Host "[4/5] 复制图片与 Spine（运行时按散文件读取）..."
$pngDir   = Join-Path $ModRoot 'resources\png'
$spineDir = Join-Path $ModRoot 'resources\spine\fight\4.2'
# 顺序有意义：先拷原图兜底，再拷 derived（居中裁剪 + 缩放的派生图），后者覆盖前者。
# 源文件与部署文件同名（2026-11-25 起，角色图直接用成品名）；
# derived 里的同名文件后拷，覆盖之（存在时以派生图为准）。
$imageMap = @(
    @("sundry\char_select_bg_$Character.png",   "char_select_bg_$Character.png"),
    @("sundry\char_select_$Character.png",       "char_select_$Character.png"),
    @("sundry\character_icon_$Character.png",    "character_icon_$Character.png"),
    @("sundry\map_marker_$Character.png",        "map_marker_$Character.png"),
    @("derived\char_select_bg_$Character.png",   "char_select_bg_$Character.png"),
    @("derived\char_select_$Character.png",      "char_select_$Character.png"),
    @("derived\character_icon_$Character.png",   "character_icon_$Character.png"),
    @("derived\map_marker_$Character.png",       "map_marker_$Character.png")
)

# 派生图缺失时自动生成（需要 Pillow；可用环境变量 STS2_PYTHON 指定解释器）
$derivedDir = Join-Path $pngDir 'derived'
if (-not (Test-Path (Join-Path $derivedDir "map_marker_$Character.png"))) {
    $py = if ($env:STS2_PYTHON) { $env:STS2_PYTHON } else { $env:SARIA_PYTHON }
    if (-not $py) { $py = 'python' }
    Write-Host "派生图标缺失，先运行 tools\prepare_icons.py ..."
    & $py (Join-Path $PSScriptRoot 'prepare_icons.py')
    if ($LASTEXITCODE -ne 0) { throw "prepare_icons.py 失败（请设置 STS2_PYTHON 指向带 Pillow 的 python）" }
}

if (Test-Path $pngDir) {
    New-Item -ItemType Directory -Force -Path (Join-Path $StageDir 'images') | Out-Null
    foreach ($pair in $imageMap) {
        $from = Join-Path $pngDir $pair[0]
        if (-not (Test-Path $from)) { Write-Warning "缺少图片（跳过）：$from"; continue }
        Copy-Item $from (Join-Path $StageDir ('images\' + $pair[1])) -Force
    }
    # 状态图标：resources\png\powers\*.png -> images\powers\
    $powerArtDir = Join-Path $ModRoot 'resources\png\powers'
    if (Test-Path $powerArtDir) {
        New-Item -ItemType Directory -Force -Path (Join-Path $StageDir 'images\powers') | Out-Null
        Copy-Item (Join-Path $powerArtDir '*.png') (Join-Path $StageDir 'images\powers') -Force
    }
    else {
        Write-Warning "resources\png\powers 不存在，本次不含状态图标。"
    }

    # 能量球图层：resources\png\orb\*.png -> images\orb\
    $orbArtDir = Join-Path $ModRoot 'resources\png\orb'
    if (Test-Path $orbArtDir) {
        New-Item -ItemType Directory -Force -Path (Join-Path $StageDir 'images\orb') | Out-Null
        Copy-Item (Join-Path $orbArtDir '*.png') (Join-Path $StageDir 'images\orb') -Force
    }
    else {
        Write-Warning "resources\png\orb 不存在，本次不含能量球图层。"
    }

    # 获得能量特效贴图：resources\png\derived\vfx\*.png -> images\vfx\
    $vfxArtDir = Join-Path $ModRoot 'resources\png\derived\vfx'
    if ((Test-Path $vfxArtDir) -and (Get-ChildItem $vfxArtDir -Filter '*.png' | Select-Object -First 1)) {
        New-Item -ItemType Directory -Force -Path (Join-Path $StageDir 'images\vfx') | Out-Null
        Copy-Item (Join-Path $vfxArtDir '*.png') (Join-Path $StageDir 'images\vfx') -Force
    }

    # 猜拳手部贴图：resources\png\hand\*.png -> images\hand\
    $handArtDir = Join-Path $ModRoot 'resources\png\hand'
    if (Test-Path $handArtDir) {
        New-Item -ItemType Directory -Force -Path (Join-Path $StageDir 'images\hand') | Out-Null
        Copy-Item (Join-Path $handArtDir '*.png') (Join-Path $StageDir 'images\hand') -Force
    }

    # 转场遮罩：resources\png\sundry\<角色>_transition.png -> images\transition\
    $transitionSrc = Join-Path $ModRoot "resources\png\sundry\${Character}_transition.png"
    if (Test-Path $transitionSrc) {
        New-Item -ItemType Directory -Force -Path (Join-Path $StageDir 'images\transition') | Out-Null
        Copy-Item $transitionSrc (Join-Path $StageDir "images\transition\${Character}_transition.png") -Force
    }

    # 遗物图标：resources\png\relics\derived\*.png -> images\relics\（大图 256）
#            resources\png\relics\derived\cropped\*.png -> images\relics\cropped\（小图 80）
    $relicArtDir = Join-Path $ModRoot 'resources\png\relics\derived'
    if (Test-Path $relicArtDir) {
        New-Item -ItemType Directory -Force -Path (Join-Path $StageDir 'images\relics\cropped') | Out-Null
        Copy-Item (Join-Path $relicArtDir '*.png') (Join-Path $StageDir 'images\relics') -Force
        $relicSmallDir = Join-Path $relicArtDir 'cropped'
        if (Test-Path $relicSmallDir) {
            Copy-Item (Join-Path $relicSmallDir '*.png') (Join-Path $StageDir 'images\relics\cropped') -Force
        }
        $relicOutlineDir = Join-Path $relicArtDir 'outline'
        if (Test-Path $relicOutlineDir) {
            New-Item -ItemType Directory -Force -Path (Join-Path $StageDir 'images\relics\outline') | Out-Null
            Copy-Item (Join-Path $relicOutlineDir '*.png') (Join-Path $StageDir 'images\relics\outline') -Force
        }
    }

    # 卡图：优先用压缩版 resources\png\cards-little\*.png -> images\portraits\（没有则退回原图）
    $cardArtDir = Join-Path $ModRoot 'resources\png\cards-little'

    if (-not (Test-Path $cardArtDir)) { $cardArtDir = Join-Path $ModRoot 'resources\png\cards' }
    if (Test-Path $cardArtDir) {
        New-Item -ItemType Directory -Force -Path (Join-Path $StageDir 'images\portraits') | Out-Null
        $cardRenames = @{ 'ProbeArmpng.png' = 'ProbeArm.png'; 'ProbeInsightpng.png' = 'ProbeInsight.png' }
        foreach ($png in Get-ChildItem $cardArtDir -Filter '*.png') {
            $target = if ($cardRenames.ContainsKey($png.Name)) { $cardRenames[$png.Name] } else { $png.Name }
            Copy-Item $png.FullName (Join-Path $StageDir ('images\portraits\' + $target)) -Force
        }
    }
    else {
        Write-Warning "resources\png\cards 不存在，本次不含卡图。"
    }
    # 音效：可选
    $oggDir = Join-Path $ModRoot 'resources\ogg'
    if (Test-Path $oggDir) {
        New-Item -ItemType Directory -Force -Path (Join-Path $StageDir 'audio') | Out-Null
        foreach ($ogg in Get-ChildItem $oggDir -Filter '*.ogg') {
            Copy-Item $ogg.FullName (Join-Path $StageDir ('audio\' + $ogg.Name)) -Force
        }
    }

    # Spine：按磁盘上的 .skel 自动探测（战斗骨骼在 fight\4.2，非战斗在 4.2），不写死 rig 名
    New-Item -ItemType Directory -Force -Path (Join-Path $StageDir 'spine') | Out-Null
    $spineDirs = @($spineDir, (Join-Path $ModRoot 'resources\spine\4.2'))
    $spineCount = 0
    foreach ($dir in $spineDirs) {
        if (-not (Test-Path $dir)) { continue }
        foreach ($skel in Get-ChildItem $dir -Filter '*.skel') {
            foreach ($ext in @('.atlas', '.png', '.skel')) {
                $from = Join-Path $dir ($skel.BaseName + $ext)
                if (-not (Test-Path $from)) { Write-Warning "Spine 缺配套文件：$from"; continue }
                Copy-Item $from (Join-Path $StageDir ('spine\' + (Split-Path -Leaf $from))) -Force
            }
            $spineCount++
        }
    }
    if ($spineCount -eq 0) { Write-Warning 'resources\spine 里没有 .skel，本次不含 Spine 立绘。' }
}
else {
    Write-Warning "resources\png 不存在（公开仓库里被排除），本次只打包代码与 PCK，不含立绘/头像。"
}

Write-Host "[5/5] 打包 zip ..."
$zipPath = Join-Path $DistDir ("$Character-$Version.zip")
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path $StageDir -DestinationPath $zipPath -CompressionLevel Optimal

$sizeMb = [Math]::Round((Get-ChildItem $StageDir -Recurse -File | Measure-Object Length -Sum).Sum / 1MB, 2)
Write-Host ""
Write-Host "完成："
Write-Host "  文件夹  $StageDir  ($sizeMb MB)"
Write-Host "  zip     $zipPath"
Write-Host ""
Write-Host "安装方法（测试者）："
Write-Host "  1. 先订阅 Steam 工坊的 BaseLib（必需依赖）"
Write-Host "  2. 解压 zip，把里面的 $Character 文件夹整体放进 <游戏目录>\mods\"
Write-Host "  3. 启动游戏，角色选择界面最右侧多出的「$($Manifest.name)」即为本 mod"
exit 0
