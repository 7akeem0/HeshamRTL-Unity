<#
.SYNOPSIS
    Installs HeshamRTL into a Unity game WITHOUT BepInEx or any other mod loader (or removes it).
    Mono and IL2CPP, 64-bit and 32-bit. Install.bat, Install-Preview.bat and Uninstall.bat call this script.

.DESCRIPTION
    Mono games (Unity 2020.2 and later):
      <Game>_Data\Managed\HeshamRTL.dll, listed in <Game>_Data\ScriptingAssemblies.json (Unity loads it) and two
      entry points in <Game>_Data\RuntimeInitializeOnLoads.json (Unity calls them). The two JSON files are kept
      in HeshamRTL\_original before the first change; -Uninstall leaves them byte-identical.
    IL2CPP games (all versions with UnityPlayer.dll importing version.dll):
      <game>\version.dll, a proxy loader that starts HeshamRTL right after il2cpp_init, and
      <game>\HeshamRTL\HeshamRTL.dll, the runtime compiled to native code.
    Both: <game>\HeshamRTL\ holds Arabic.ttf, OFL.txt, HeshamRTL.cfg, the logs and install.json.

    If the BepInEx version of HeshamRTL is installed, it is moved aside (two right-to-left processors would shape
    the same text twice) and its config and fonts are carried over. With -RemoveBepInEx, BepInEx itself (BepInEx,
    dotnet, winhttp.dll, doorstop_config.ini, .doorstop_version) goes to the Recycle Bin, but only when no other
    BepInEx plugin is left (a game's translation plugin still needs it).

    Not supported: Mono games of Unity before 2020.2 (no ScriptingAssemblies.json).

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File Install-HeshamRTL.ps1 -GamePath "D:\Games\Blasphemous 2" -RemoveBepInEx
#>
param(
    [Parameter(Mandatory = $true)][string]$GamePath,
    [switch]$Uninstall,
    [switch]$Preview,
    [switch]$VerboseLog,
    [switch]$RemoveBepInEx,
    [string]$FontFrom
)

$ErrorActionPreference = 'Stop'
$payload = Join-Path $PSScriptRoot 'payload'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$assemblyFile = 'HeshamRTL.dll'
$entries = @(
    '{"assemblyName":"HeshamRTL","nameSpace":"HeshamRTL.Runtime","className":"Bootstrap","methodName":"Init","loadTypes":2,"isUnityClass":false}',
    '{"assemblyName":"HeshamRTL","nameSpace":"HeshamRTL.Runtime","className":"Bootstrap","methodName":"AfterFirstScene","loadTypes":0,"isUnityClass":false}'
)

function Read-Text([string]$path) { [System.IO.File]::ReadAllText($path, $utf8) }
function Write-Text([string]$path, [string]$text) { [System.IO.File]::WriteAllText($path, $text, $utf8) }

# ---------------------------------------------------------------- locate the game
if (Test-Path $GamePath -PathType Leaf) { $GamePath = Split-Path $GamePath -Parent }
$GamePath = (Resolve-Path $GamePath).Path
$data = Get-ChildItem $GamePath -Directory -Filter '*_Data' | Where-Object { (Test-Path (Join-Path $_.FullName 'globalgamemanagers')) -or (Test-Path (Join-Path $_.FullName 'data.unity3d')) } | Select-Object -First 1
if (-not $data) { throw "No Unity <Game>_Data folder in $GamePath" }
$data = $data.FullName
$managed = Join-Path $data 'Managed'
$scripting = Join-Path $data 'ScriptingAssemblies.json'
$runtimeInit = Join-Path $data 'RuntimeInitializeOnLoads.json'
$folder = Join-Path $GamePath 'HeshamRTL'
$manifestPath = Join-Path $folder 'install.json'
$il2cpp = Test-Path (Join-Path $GamePath 'GameAssembly.dll')

function Get-Arch([string]$path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $pe = [BitConverter]::ToInt32($bytes, 0x3c)
    $machine = [BitConverter]::ToUInt16($bytes, $pe + 4)
    if ($machine -eq 0x8664) { return 'x64' }
    if ($machine -eq 0x14c) { return 'x86' }
    throw "Unknown machine type 0x{0:X} in $path" -f $machine
}

# ---------------------------------------------------------------- Mono: JSON edits (text level, the rest stays byte-identical)
function Get-ArrayItems([string]$json, [string]$name) {
    $m = [regex]::Match($json, '"' + $name + '":\[([^\]]*)\]')
    if (-not $m.Success) { throw "ScriptingAssemblies.json has no `"$name`" array" }
    if ($m.Groups[1].Value.Length -eq 0) { return ,@() }
    return ,($m.Groups[1].Value -split ',')
}

function Set-ArrayItems([string]$json, [string]$name, $items) {
    $text = '"' + $name + '":[' + ($items -join ',') + ']'
    return [regex]::Replace($json, '"' + $name + '":\[[^\]]*\]', { param($m) $text }, 1)
}

function Test-Json([string]$path) {
    $parsed = (Read-Text $path) | ConvertFrom-Json
    if ($path -eq $scripting -and $parsed.names.Count -ne $parsed.types.Count) { throw "$path`: names and types differ in length" }
}

function Add-Assembly {
    $json = Read-Text $scripting
    $names = Get-ArrayItems $json 'names'
    if ($names -contains ('"' + $assemblyFile + '"')) { return $false }
    $types = Get-ArrayItems $json 'types'
    $json = Set-ArrayItems $json 'names' ($names + ('"' + $assemblyFile + '"'))
    $json = Set-ArrayItems $json 'types' ($types + '16')
    Write-Text $scripting $json
    Test-Json $scripting
    return $true
}

function Remove-Assembly {
    if (-not (Test-Path $scripting)) { return }
    $json = Read-Text $scripting
    $names = Get-ArrayItems $json 'names'
    $types = Get-ArrayItems $json 'types'
    $index = [array]::IndexOf($names, '"' + $assemblyFile + '"')
    if ($index -lt 0) { return }
    $keepNames = @(); $keepTypes = @()
    for ($i = 0; $i -lt $names.Count; $i++) { if ($i -ne $index) { $keepNames += $names[$i]; $keepTypes += $types[$i] } }
    $json = Set-ArrayItems $json 'names' $keepNames
    $json = Set-ArrayItems $json 'types' $keepTypes
    Write-Text $scripting $json
    Test-Json $scripting
}

function Add-EntryPoints {
    $text = Read-Text $runtimeInit
    $json = $text.TrimEnd()
    $tail = $text.Substring($json.Length)   # keep the file's own line ending
    $added = $false
    foreach ($entry in $entries) {
        if ($json.Contains($entry)) { continue }
        if (-not $json.EndsWith(']}')) { throw "Unexpected format of RuntimeInitializeOnLoads.json" }
        $body = $json.Substring(0, $json.Length - 2)
        $separator = if ($body.TrimEnd().EndsWith('[')) { '' } else { ',' }
        $json = $body + $separator + $entry + ']}'
        $added = $true
    }
    if ($added) {
        Write-Text $runtimeInit ($json + $tail)
        Test-Json $runtimeInit
    }
    return $added
}

function Remove-EntryPoints {
    if (-not (Test-Path $runtimeInit)) { return }
    $json = Read-Text $runtimeInit
    foreach ($entry in $entries) {
        $json = $json.Replace(',' + $entry, '').Replace($entry + ',', '').Replace($entry, '')
    }
    Write-Text $runtimeInit $json
    Test-Json $runtimeInit
}

function Get-Sha256([string]$path) {
    # .NET directly: Get-FileHash is missing when Windows PowerShell is started from PowerShell 7 (module path).
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash([System.IO.File]::ReadAllBytes($path))) } finally { $sha.Dispose() }
}

function Test-OurLoader([string]$path) {
    # Our version.dll: one of the payload builds, or any build that carries the HeshamRTL loader's text.
    if (-not (Test-Path $path)) { return $false }
    foreach ($a in 'x64', 'x86') {
        $p = Join-Path $payload "il2cpp\$a\version.dll"
        if ((Test-Path $p) -and (Get-Sha256 $path) -eq (Get-Sha256 $p)) { return $true }
    }
    $text = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($path))
    return $text.Contains('il2cpp_init redirected')
}

# ---------------------------------------------------------------- uninstall
if ($Uninstall) {
    if (-not (Test-Path $manifestPath)) { throw "HeshamRTL (standalone) is not installed in $GamePath" }
    $manifest = (Read-Text $manifestPath) | ConvertFrom-Json
    if ($il2cpp) {
        $loader = Join-Path $GamePath 'version.dll'
        if (Test-OurLoader $loader) { Remove-Item $loader -Force }
    } else {
        Remove-EntryPoints
        Remove-Assembly
        $dll = Join-Path $managed $assemblyFile
        if (Test-Path $dll) { Remove-Item $dll -Force }
    }
    foreach ($moved in @($manifest.moved)) {
        if ($moved -and (Test-Path $moved.to) -and -not (Test-Path $moved.from)) {
            Move-Item $moved.to $moved.from
            Write-Host "Restored $($moved.from)"
        }
    }
    Remove-Item $folder -Recurse -Force
    Write-Host "HeshamRTL (standalone) removed from $GamePath"
    if (@($manifest.recycled).Count -gt 0) {
        Write-Host "BepInEx was sent to the Recycle Bin at install time; restore it from there if the game needs it:"
        $manifest.recycled | ForEach-Object { Write-Host "  $_" }
    }
    return
}

# ---------------------------------------------------------------- install: checks
if ($il2cpp) {
    $arch = Get-Arch (Join-Path $GamePath 'GameAssembly.dll')
    $files = @("il2cpp\$arch\version.dll", "il2cpp\$arch\HeshamRTL.dll", 'Arabic.ttf', 'OFL.txt')
    $loader = Join-Path $GamePath 'version.dll'
    if ((Test-Path $loader) -and -not (Test-OurLoader $loader)) {
        throw "The game already has a version.dll that is not HeshamRTL's: $loader. Nothing was changed."
    }
} else {
    if (-not (Test-Path (Join-Path $managed 'Assembly-CSharp.dll'))) { throw "No Managed\Assembly-CSharp.dll: not a Unity Mono game." }
    if (-not (Test-Path $scripting) -or -not (Test-Path $runtimeInit)) {
        throw "This Mono game has no ScriptingAssemblies.json / RuntimeInitializeOnLoads.json (Unity before 2020.2): not supported. Nothing was changed."
    }
    $files = @('mono\HeshamRTL.dll', 'Arabic.ttf', 'OFL.txt')
}
foreach ($f in $files) {
    if (-not (Test-Path (Join-Path $payload $f))) { throw "Missing payload file $f (download the package again)" }
}

# ---------------------------------------------------------------- install
$first = -not (Test-Path $manifestPath)
New-Item -ItemType Directory -Force $folder | Out-Null
$manifest = if ($first) {
    [pscustomobject]@{ version = '1.0.0'; kind = $(if ($il2cpp) { "il2cpp-$arch" } else { 'mono' }); installedAt = ''; moved = @(); recycled = @() }
} else {
    (Read-Text $manifestPath) | ConvertFrom-Json
}
$manifest.installedAt = (Get-Date).ToString('s')
if (-not ($manifest.PSObject.Properties.Name -contains 'recycled')) { $manifest | Add-Member recycled @() }

# The BepInEx version on the same text would shape it twice: move it aside, keep its settings and fonts.
$bepPlugin = Join-Path $GamePath 'BepInEx\plugins\HeshamRTL'
$bepConfig = Join-Path $GamePath 'BepInEx\config\com.hesham.rtl.runtime.cfg'
$fontSource = $payload
if ((Test-Path (Join-Path $bepPlugin 'HeshamRTL.Runtime.dll')) -or (Test-Path (Join-Path $bepPlugin 'HeshamRTL.Runtime.IL2CPP.dll'))) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $aside = Join-Path $GamePath "BepInEx\_disabled_by_HeshamRTL\standalone-$stamp"
    New-Item -ItemType Directory -Force $aside | Out-Null
    $target = Join-Path $aside 'HeshamRTL'
    Move-Item $bepPlugin $target
    $manifest.moved = @(@($manifest.moved) + [pscustomobject]@{ from = $bepPlugin; to = $target } | Where-Object { $_ })
    $fontSource = $target
    Write-Host "Moved the BepInEx version aside: $target"
}
$config = Join-Path $folder 'HeshamRTL.cfg'
if (-not (Test-Path $config) -and (Test-Path $bepConfig)) {
    Copy-Item $bepConfig $config   # same format and keys
    Write-Host "Carried over the BepInEx settings ($bepConfig)"
}
if (-not (Test-Path (Join-Path $folder 'Arabic.ttf')) -or $fontSource -ne $payload) {
    foreach ($ttf in Get-ChildItem $fontSource -Filter '*.ttf') { Copy-Item $ttf.FullName $folder -Force }
}
if (-not (Test-Path (Join-Path $folder 'Arabic.ttf'))) { Copy-Item (Join-Path $payload 'Arabic.ttf') $folder -Force }
if ($FontFrom) { Copy-Item $FontFrom (Join-Path $folder 'Arabic.ttf') -Force }
Copy-Item (Join-Path $payload 'OFL.txt') $folder -Force

function Set-ConfigValue([string]$section, [string]$key, [string]$value) {
    $lines = New-Object System.Collections.Generic.List[string]
    if (Test-Path $config) { foreach ($l in [System.IO.File]::ReadAllLines($config, $utf8)) { $lines.Add($l) } }
    $current = ''; $done = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $t = $lines[$i].Trim()
        if ($t -match '^\[(.+)\]$') { $current = $Matches[1]; continue }
        if ($current -eq $section -and $t -match ('^' + [regex]::Escape($key) + '\s*=')) { $lines[$i] = "$key = $value"; $done = $true }
    }
    if (-not $done) { $lines.Add(''); $lines.Add("[$section]"); $lines.Add("$key = $value") }
    Write-Text $config (($lines -join "`n") + "`n")
}
if ($Preview) { Set-ConfigValue 'Preview' 'PseudoArabic' 'true' }
if ($VerboseLog) { Set-ConfigValue 'Diagnostics' 'Verbose' 'true' }

if ($il2cpp) {
    Copy-Item (Join-Path $payload "il2cpp\$arch\HeshamRTL.dll") (Join-Path $folder 'HeshamRTL.dll') -Force
    Copy-Item (Join-Path $payload "il2cpp\$arch\version.dll") $loader -Force
    Write-Host "HeshamRTL (standalone, IL2CPP $arch) installed in $GamePath"
    Write-Host "  $loader"
    Write-Host "  $folder\HeshamRTL.dll"
} else {
    $backup = Join-Path $folder '_original'
    if (-not (Test-Path $backup)) {
        New-Item -ItemType Directory -Force $backup | Out-Null
        Copy-Item $scripting, $runtimeInit $backup
    }
    Copy-Item (Join-Path $payload 'mono\HeshamRTL.dll') (Join-Path $managed $assemblyFile) -Force
    $a = Add-Assembly
    $e = Add-EntryPoints
    Write-Host "HeshamRTL (standalone, Mono) installed in $GamePath"
    Write-Host "  $managed\$assemblyFile"
    Write-Host "  ScriptingAssemblies.json: $(if ($a) { 'added' } else { 'already listed' }); RuntimeInitializeOnLoads.json: $(if ($e) { 'added' } else { 'already listed' })"
}

# ---------------------------------------------------------------- optional: BepInEx to the Recycle Bin
if ($RemoveBepInEx -and (Test-Path (Join-Path $GamePath 'BepInEx'))) {
    $others = @(Get-ChildItem (Join-Path $GamePath 'BepInEx\plugins') -Force -ErrorAction SilentlyContinue)
    if ($others.Count -gt 0) {
        Write-Host "BepInEx stays: other plugins still need it: $(($others | Select-Object -ExpandProperty Name) -join ', ')"
    } else {
        Add-Type -AssemblyName Microsoft.VisualBasic
        $fs = [Microsoft.VisualBasic.FileIO.FileSystem]
        $ui = [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs
        $bin = [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
        foreach ($name in 'BepInEx', 'dotnet', 'winhttp.dll', 'doorstop_config.ini', '.doorstop_version') {
            $p = Join-Path $GamePath $name
            if (-not (Test-Path $p)) { continue }
            if ((Get-Item $p -Force).PSIsContainer) { $fs::DeleteDirectory($p, $ui, $bin) } else { $fs::DeleteFile($p, $ui, $bin) }
            $manifest.recycled = @(@($manifest.recycled) + $p)
            Write-Host "Recycle Bin: $p"
        }
    }
}

Write-Text $manifestPath ($manifest | ConvertTo-Json -Depth 5)
Write-Host "  Log after launch: $folder\HeshamRTL.log"
