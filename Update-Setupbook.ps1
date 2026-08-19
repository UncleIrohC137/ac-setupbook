<#
.SYNOPSIS
  Reads every Assetto Corsa setup file and builds AC-Setupbook.html from them.

.DESCRIPTION
  Walks <setups>\<car>\<track>\*.ini, picks up car and track names from the
  Assetto Corsa install, and injects everything as JSON into
  setupbook.template.html.

  Runs on Windows PowerShell 5.1 and on PowerShell 7.

.EXAMPLE
  .\Update-Setupbook.ps1

.EXAMPLE
  .\Update-Setupbook.ps1 -SetupsRoot "D:\Games\Assetto Corsa\setups"
#>
[CmdletBinding()]
param(
  [string]$SetupsRoot = "$env:USERPROFILE\Documents\Assetto Corsa\setups",
  [string]$AcRoot     = '',
  [string]$Template   = '',
  [string]$OutFile    = ''
)

$ErrorActionPreference = 'Stop'

# Windows PowerShell 5.1 has not filled in $PSScriptRoot yet while binding params.
$here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $Template) { $Template = Join-Path $here 'setupbook.template.html' }
if (-not $OutFile)  { $OutFile  = Join-Path $here 'AC-Setupbook.html' }

# Locate the Assetto Corsa install. Only needed for readable car and track names;
# without it everything still works, just with tidied-up folder names.
function Find-AcRoot {
  $candidates = @()
  foreach ($reg in 'HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam') {
    try {
      $steam = (Get-ItemProperty -Path $reg -ErrorAction Stop).SteamPath
      if ($steam) { $candidates += (Join-Path $steam 'steamapps\common\assettocorsa') }
    } catch {}
  }
  foreach ($steam in "${env:ProgramFiles(x86)}\Steam", "$env:ProgramFiles\Steam") {
    $candidates += (Join-Path $steam 'steamapps\common\assettocorsa')
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path -LiteralPath $vdf) {
      foreach ($m in [regex]::Matches((Get-Content -LiteralPath $vdf -Raw), '"path"\s*"([^"]+)"')) {
        $candidates += (Join-Path ($m.Groups[1].Value -replace '\\\\', '\') 'steamapps\common\assettocorsa')
      }
    }
  }
  foreach ($d in (Get-PSDrive -PSProvider FileSystem).Root) {
    $candidates += (Join-Path $d 'SteamLibrary\steamapps\common\assettocorsa')
    $candidates += (Join-Path $d 'Steam\steamapps\common\assettocorsa')
  }
  foreach ($c in $candidates) {
    if ($c -and (Test-Path -LiteralPath (Join-Path $c 'content\cars'))) { return $c }
  }
  return ''
}

if (-not $AcRoot) { $AcRoot = Find-AcRoot }
if ($AcRoot) {
  Write-Host "Assetto Corsa install: $AcRoot" -ForegroundColor DarkGray
} else {
  Write-Host "No Assetto Corsa install found - cars and tracks will keep their folder names." -ForegroundColor DarkYellow
}

function Read-SetupIni {
  param([string]$Path)
  $values = [ordered]@{}
  $model = $null; $ext = $null; $section = $null
  foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
    if ($line -match '^\s*\[(.+?)\]\s*$') { $section = $Matches[1]; continue }
    if (-not $section) { continue }
    if ($line -match '^\s*VALUE\s*=\s*(.*?)\s*$')   { $values[$section] = $Matches[1]; continue }
    if ($section -eq 'CAR'         -and $line -match '^\s*MODEL\s*=\s*(.*?)\s*$')   { $model = $Matches[1]; continue }
    if ($section -eq '__EXT_PATCH' -and $line -match '^\s*VERSION\s*=\s*(.*?)\s*$') { $ext   = $Matches[1]; continue }
  }
  [pscustomobject]@{ Values = $values; Model = $model; Ext = $ext }
}

# AC's ui json is not always valid JSON, so fall back to a plain field reader.
function Get-JsonText {
  param([string]$Path, [string]$Field)
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
  if ($raw -match ('"' + [regex]::Escape($Field) + '"\s*:\s*"((?:[^"\\]|\\.)*)"')) {
    return $Matches[1] -replace '\\"', '"' -replace '\\\\', '\'
  }
  return $null
}

function Get-JsonTags {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return @() }
  $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
  if ($raw -match '"tags"\s*:\s*\[(.*?)\]') {
    return @([regex]::Matches($Matches[1], '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
  }
  return @()
}

# Stand-in for the ?? operator, which PowerShell 5.1 does not have.
function Coalesce {
  param($Value, $Fallback)
  if ([string]::IsNullOrEmpty($Value)) { return $Fallback }
  return $Value
}

function Get-CarMeta {
  param([string]$CarId)
  if (-not $AcRoot) {
    return [pscustomobject]@{ Name = $CarId; Brand = ''; Tags = @(); Bhp = ''; Kg = '' }
  }
  $ui = Join-Path $AcRoot "content\cars\$CarId\ui\ui_car.json"
  [pscustomobject]@{
    Name  = Coalesce (Get-JsonText $ui 'name')   $CarId
    Brand = Coalesce (Get-JsonText $ui 'brand')  ''
    Tags  = Get-JsonTags $ui
    Bhp   = Coalesce (Get-JsonText $ui 'bhp')    ''
    Kg    = Coalesce (Get-JsonText $ui 'weight') ''
  }
}

# Tracks with layouts have no ui_track.json at the root. Take the longest common
# prefix of all layout names instead: "Nordschleife - Endurance" and
# "Nordschleife Touristenfahrten" together give "Nordschleife".
function Get-TrackName {
  param([string]$TrackId)
  if ($TrackId -eq 'generic') { return '' }   # the page fills in its own translated text here
  if (-not $AcRoot) { return ($TrackId -replace '^ks_', '' -replace '[_-]', ' ') }
  $uiDir = Join-Path $AcRoot "content\tracks\$TrackId\ui"
  $root  = Join-Path $uiDir 'ui_track.json'
  if (Test-Path -LiteralPath $root) {
    $n = Get-JsonText $root 'name'
    if ($n) { return $n }
  }
  if (Test-Path -LiteralPath $uiDir) {
    $names = @(Get-ChildItem -LiteralPath $uiDir -Directory -ErrorAction SilentlyContinue |
      ForEach-Object { Get-JsonText (Join-Path $_.FullName 'ui_track.json') 'name' } |
      Where-Object { $_ })
    if ($names.Count -eq 1) { return $names[0] }
    if ($names.Count -gt 1) {
      $prefix = $names[0]
      foreach ($n in $names) {
        while ($prefix -and -not $n.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
          $prefix = $prefix.Substring(0, $prefix.Length - 1)
        }
      }
      $prefix = $prefix.TrimEnd(' ', '-', ':')
      if ($prefix.Length -ge 3) { return $prefix }
      if ($names[0]) { return $names[0] }
    }
  }
  return ($TrackId -replace '^ks_', '' -replace '[_-]', ' ')
}

# ---------------------------------------------------------------------------
# Reading data.acd
#
# Every car folder holds one data.acd: a container with the car's technical ini
# files inside, lightly obfuscated. The container itself is plain: a header, then
# per entry a name and a payload that stores one meaningful byte per four.
#
# The payload is unscrambled by subtracting a repeating key. That key is a string
# of eight numbers joined by dashes, derived from the car folder name. Rather than
# reproducing that derivation, we recover the key from the file itself: the result
# has to be readable text, and for a few thousand bytes that constraint leaves
# exactly one possible key. Wrong guesses are impossible to miss - they produce
# unreadable output and are rejected.
#
# Nothing is written to the car folder; the install is only read.
# ---------------------------------------------------------------------------

$script:AcdKeyCache = @{}
$script:AcdKeyFile  = Join-Path $here 'acd-keys.json'
if (Test-Path -LiteralPath $script:AcdKeyFile) {
  try {
    $j = Get-Content -LiteralPath $script:AcdKeyFile -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($p in $j.PSObject.Properties) { $script:AcdKeyCache[$p.Name] = $p.Value }
  } catch {}
}

function Read-AcdContainer {
  param([string]$Path)
  $b = [System.IO.File]::ReadAllBytes($Path)
  $pos = 0
  if ($b.Length -ge 8 -and [BitConverter]::ToInt32($b, 0) -eq -1111) { $pos = 8 }
  $out = New-Object System.Collections.Generic.List[object]
  while ($pos + 4 -le $b.Length) {
    $nameLen = [BitConverter]::ToInt32($b, $pos); $pos += 4
    if ($nameLen -le 0 -or $nameLen -gt 500 -or $pos + $nameLen + 4 -gt $b.Length) { break }
    $name = [Text.Encoding]::ASCII.GetString($b, $pos, $nameLen); $pos += $nameLen
    $len = [BitConverter]::ToInt32($b, $pos); $pos += 4
    if ($len -lt 0 -or $pos + $len * 4 -gt $b.Length) { break }
    $payload = New-Object byte[] $len
    for ($i = 0; $i -lt $len; $i++) { $payload[$i] = $b[$pos + $i * 4] }
    $pos += $len * 4
    $out.Add([pscustomobject]@{ Name = $name; Data = $payload })
  }
  return $out
}

$script:AcdOkChar = New-Object bool[] 256
foreach ($c in 9, 10, 13) { $script:AcdOkChar[$c] = $true }
for ($c = 32; $c -le 126; $c++) { $script:AcdOkChar[$c] = $true }

function Test-AcdKey {
  param([byte[]]$Data, [byte[]]$Key)
  $n = [Math]::Min($Data.Length, 4000)
  for ($i = 0; $i -lt $n; $i++) {
    if (-not $script:AcdOkChar[(($Data[$i] - $Key[$i % $Key.Length]) -band 0xFF)]) { return $false }
  }
  return $true
}

function Find-AcdKey {
  param([byte[]]$Sample)
  # The key only ever contains digits and dashes, and holds eight numbers, so its
  # length sits between 15 and 31 characters.
  $chars = @(45) + (48..57)
  $n = [Math]::Min($Sample.Length, 6000)
  for ($L = 10; $L -le 40; $L++) {
    $key = New-Object byte[] $L
    $good = $true
    for ($j = 0; $j -lt $L -and $good; $j++) {
      $seen = New-Object bool[] 256
      for ($i = $j; $i -lt $n; $i += $L) { $seen[$Sample[$i]] = $true }
      $hit = -1; $cnt = 0
      foreach ($k in $chars) {
        $fits = $true
        for ($v = 0; $v -lt 256; $v++) {
          if (-not $seen[$v]) { continue }
          if (-not $script:AcdOkChar[(($v - $k) -band 0xFF)]) { $fits = $false; break }
        }
        if ($fits) { $cnt++; if ($cnt -gt 1) { break }; $hit = $k }
      }
      if ($cnt -ne 1) { $good = $false } else { $key[$j] = $hit }
    }
    if ($good) { return $key }
  }
  return $null
}

function Get-AcdFiles {
  param([string]$CarId, [string[]]$Wanted)
  if (-not $AcRoot) { return $null }
  $acd = Join-Path $AcRoot "content\cars\$CarId\data.acd"
  if (-not (Test-Path -LiteralPath $acd)) { return $null }

  try { $entries = Read-AcdContainer $acd } catch { return $null }
  if ($entries.Count -eq 0) { return $null }

  # Derive the key from an .ini entry: those are always text, while some cars
  # carry binary entries that would defeat the readable-text test.
  # Solving the key needs a good many bytes. With too small a sample more than one
  # key satisfies the readable-text test and the search gives up, so work down from
  # the largest text entries. Any key that comes out is then checked against
  # setup.ini before it is trusted.
  $setupEntry = $entries | Where-Object { $_.Name -eq 'setup.ini' } | Select-Object -First 1
  $samples = @($entries |
    Where-Object { $_.Name -like '*.ini' -and $_.Data.Length -gt 1500 } |
    Sort-Object { $_.Data.Length } -Descending | Select-Object -First 5)
  if ($samples.Count -eq 0) {
    $samples = @($entries | Sort-Object { $_.Data.Length } -Descending | Select-Object -First 3)
  }
  if ($samples.Count -eq 0) { return $null }

  $checkSetup = {
    param([byte[]]$K)
    if (-not $setupEntry) { return $true }
    $d = $setupEntry.Data
    $n = [Math]::Min($d.Length, 3000)
    $sb = New-Object Text.StringBuilder
    for ($i = 0; $i -lt $n; $i++) { [void]$sb.Append([char]((($d[$i] - $K[$i % $K.Length]) -band 0xFF))) }
    $txt = $sb.ToString()
    return ($txt -match '\[[A-Z_0-9]+\]' -and $txt -match '(?m)^\s*(MIN|MAX|STEP|RATIOS)\s*=')
  }

  $key = $null
  if ($script:AcdKeyCache.ContainsKey($CarId)) {
    $cached = [byte[]][char[]]([string]$script:AcdKeyCache[$CarId])
    if ($cached.Length -gt 0 -and (& $checkSetup $cached)) { $key = $cached }
  }
  if (-not $key) {
    foreach ($s in $samples) {
      $try = Find-AcdKey $s.Data
      if ($try) {
        $tryBytes = [byte[]]$try
        if (& $checkSetup $tryBytes) { $key = $tryBytes; break }
      }
    }
    if (-not $key) { return $null }
    $script:AcdKeyCache[$CarId] = (-join ($key | ForEach-Object { [char]$_ }))
  }

  $res = @{}
  foreach ($e in $entries) {
    $keep = $false
    foreach ($w in $Wanted) { if ($e.Name -like $w) { $keep = $true; break } }
    if (-not $keep) { continue }
    $sb = New-Object Text.StringBuilder
    for ($i = 0; $i -lt $e.Data.Length; $i++) {
      [void]$sb.Append([char]((($e.Data[$i] - $key[$i % $key.Length]) -band 0xFF)))
    }
    $res[$e.Name] = $sb.ToString()
  }
  return $res
}

function ConvertFrom-IniText {
  param([string]$Text)
  $out = [ordered]@{}
  $sec = $null
  foreach ($raw in ($Text -split "`r?`n")) {
    $line = ($raw -split ';', 2)[0].Trim()
    if (-not $line) { continue }
    if ($line -match '^\[(.+?)\]') { $sec = $Matches[1]; if (-not $out.Contains($sec)) { $out[$sec] = [ordered]@{} }; continue }
    if ($sec -and $line -match '^([^=]+?)\s*=\s*(.*)$') { $out[$sec][$Matches[1].Trim()] = $Matches[2].Trim() }
  }
  return $out
}

# Turns one car's data.acd into the ranges, compound names and gear ratio tables
# the page needs to show real values instead of click positions.
function Get-CarSetupMeta {
  param([string]$CarId)
  $files = Get-AcdFiles $CarId @('setup.ini', 'tyres.ini', '*.rto')
  if (-not $files -or -not $files.ContainsKey('setup.ini')) { return $null }

  $setup = ConvertFrom-IniText $files['setup.ini']
  $ranges = [ordered]@{}
  $gearSections = New-Object System.Collections.Generic.List[string]
  foreach ($sec in $setup.Keys) {
    $s = $setup[$sec]
    if ($s.Contains('RATIOS')) { if ($sec -ne 'FINAL_GEAR_RATIO') { $gearSections.Add($sec) } }
    if (-not ($s.Contains('MIN') -and $s.Contains('MAX'))) { continue }
    $ranges[$sec] = [ordered]@{
      mn = [double]$s['MIN']
      mx = [double]$s['MAX']
      st = if ($s.Contains('STEP') -and [double]$s['STEP'] -ne 0) { [double]$s['STEP'] } else { 1 }
      nm = if ($s.Contains('NAME')) { $s['NAME'] } else { '' }
    }
  }

  # Gear ratio tables. Setup files number gears from INTERNAL_GEAR_2 upwards while
  # setup.ini calls them GEAR_1 and up, so pair them in order rather than by number.
  $gears = [ordered]@{}
  $sorted = @($gearSections | Sort-Object { [int]($_ -replace '\D', '') })
  for ($i = 0; $i -lt $sorted.Count; $i++) {
    $rto = $setup[$sorted[$i]]['RATIOS']
    if (-not $files.ContainsKey($rto)) { continue }
    $list = @(($files[$rto] -split "`r?`n") | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim() })
    if ($list.Count) { $gears["INTERNAL_GEAR_$($i + 2)"] = $list }
  }
  if ($setup.Contains('FINAL_GEAR_RATIO') -and $setup['FINAL_GEAR_RATIO'].Contains('RATIOS')) {
    $rto = $setup['FINAL_GEAR_RATIO']['RATIOS']
    if ($files.ContainsKey($rto)) {
      $list = @(($files[$rto] -split "`r?`n") | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim() })
      if ($list.Count) { $gears['FINAL_RATIO'] = $list }
    }
  }

  # Compounds: [FRONT] is index 0, [FRONT_1] is index 1, and so on.
  $compounds = New-Object System.Collections.Generic.List[object]
  if ($files.ContainsKey('tyres.ini')) {
    $ty = ConvertFrom-IniText $files['tyres.ini']
    $idx = 0
    while ($true) {
      $sec = if ($idx -eq 0) { 'FRONT' } else { "FRONT_$idx" }
      if (-not $ty.Contains($sec)) { break }
      $compounds.Add([ordered]@{
        n = if ($ty[$sec].Contains('NAME')) { $ty[$sec]['NAME'] } else { "Compound $idx" }
        s = if ($ty[$sec].Contains('SHORT_NAME')) { $ty[$sec]['SHORT_NAME'] } else { '' }
      })
      $idx++
    }
  }

  if ($ranges.Count -eq 0 -and $gears.Count -eq 0 -and $compounds.Count -eq 0) { return $null }
  # Plain hashtable on purpose: assigning an empty array into an ordered
  # dictionary trips PowerShell's indexer binding.
  $res = @{}
  $res['r'] = $ranges
  $res['g'] = $gears
  $res['c'] = [object[]]$compounds.ToArray()
  return $res
}

# Documents may have been moved by OneDrive, so look that way too.
if (-not (Test-Path -LiteralPath $SetupsRoot)) {
  foreach ($alt in @(
      "$env:OneDrive\Documents\Assetto Corsa\setups",
      "$env:USERPROFILE\OneDrive\Documents\Assetto Corsa\setups",
      "$env:USERPROFILE\Documents\Assetto Corsa\setups")) {
    if ($alt -and (Test-Path -LiteralPath $alt)) { $SetupsRoot = $alt; break }
  }
}

Write-Host "Reading setups from $SetupsRoot" -ForegroundColor Cyan
if (-not (Test-Path -LiteralPath $SetupsRoot)) {
  throw "Setups folder not found. Pass it in: .\Update-Setupbook.ps1 -SetupsRoot 'D:\path\to\Assetto Corsa\setups'"
}

$cars = [System.Collections.Generic.List[object]]::new()
$trackNames = [ordered]@{}
$nSetups = 0; $nSkipped = 0; $nMeta = 0; $nNoMeta = 0

foreach ($carDir in Get-ChildItem -LiteralPath $SetupsRoot -Directory | Sort-Object Name) {
  $setups = [System.Collections.Generic.List[object]]::new()

  foreach ($trackDir in Get-ChildItem -LiteralPath $carDir.FullName -Directory | Sort-Object Name) {
    $trackId = $trackDir.Name
    foreach ($file in Get-ChildItem -LiteralPath $trackDir.FullName -Filter *.ini -File | Sort-Object Name) {
      $ini = Read-SetupIni $file.FullName
      if ($ini.Values.Count -eq 0) { $nSkipped++; continue }
      if (-not $trackNames.Contains($trackId)) { $trackNames[$trackId] = Get-TrackName $trackId }
      $setups.Add([ordered]@{
        n = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        t = $trackId
        d = $file.LastWriteTime.ToString('yyyy-MM-dd')
        a = [bool]($file.BaseName -eq 'last')
        x = $ini.Ext
        v = $ini.Values
      })
      $nSetups++
    }
  }

  if ($setups.Count -eq 0) { continue }
  $meta = Get-CarMeta $carDir.Name
  $entry = [ordered]@{
    id = $carDir.Name; name = $meta.Name; brand = $meta.Brand
    tags = @($meta.Tags); bhp = $meta.Bhp; kg = $meta.Kg
    setups = $setups
  }
  $sm = $null
  try { $sm = Get-CarSetupMeta $carDir.Name } catch {
    $sm = $null
    if ($env:ACD_DEBUG) {
      Write-Host ("  ! {0}: {1}" -f $carDir.Name, $_.Exception.Message) -ForegroundColor Red
      Write-Host $_.InvocationInfo.PositionMessage -ForegroundColor DarkRed
    }
  }
  if ($sm) { $entry.m = $sm; $nMeta++ } else { $nNoMeta++ }
  $cars.Add($entry)
}

$data = [ordered]@{
  generated = (Get-Date).ToString('yyyy-MM-dd HH:mm')
  tracks    = $trackNames
  cars      = $cars
}

$json = $data | ConvertTo-Json -Depth 12 -Compress

Write-Host ("Read {0} setups, {1} cars, {2} tracks" -f $nSetups, $cars.Count, $trackNames.Count) -ForegroundColor Green
Write-Host ("Real values from car data: {0} cars ({1} without)" -f $nMeta, $nNoMeta) -ForegroundColor Green
if ($nSkipped) { Write-Host "$nSkipped file(s) skipped (no VALUE lines)" -ForegroundColor DarkYellow }

if ($script:AcdKeyCache.Count) {
  try { ($script:AcdKeyCache | ConvertTo-Json -Compress) | Set-Content -LiteralPath $script:AcdKeyFile -Encoding UTF8 } catch {}
}

if (-not (Test-Path -LiteralPath $Template)) { throw "Template not found: $Template" }
$html = Get-Content -LiteralPath $Template -Raw -Encoding UTF8
if ($html -notmatch '/\*ACDATA\*/') { throw "Template is missing the /*ACDATA*/ marker" }

# The whole package as one markdown file, embedded so the published page can hand
# it to a viewer. Tilde fences on the outside, because the files themselves use
# backtick fences.
$kitFiles = 'CLAUDE.md', 'README.txt', 'Run.cmd', 'Update-Setupbook.ps1', 'setupbook.template.html'
$kit = New-Object Text.StringBuilder
[void]$kit.AppendLine('# AC Setupbook - the full package')
[void]$kit.AppendLine('')
[void]$kit.AppendLine('Every file of the package is below, one fenced block each.')
[void]$kit.AppendLine('')
[void]$kit.AppendLine('**If you are Claude:** write each block to a file with the name in its heading,')
[void]$kit.AppendLine('all in one folder, then follow CLAUDE.md to build the page from this user''s own')
[void]$kit.AppendLine('Assetto Corsa setups. Do not alter the contents while writing them out.')
[void]$kit.AppendLine('')
[void]$kit.AppendLine('**If you are a person:** you only need AC-Setupbook.html to look around, and it')
[void]$kit.AppendLine('can read your own setups folder on its own. This package is for making a copy')
[void]$kit.AppendLine('that holds your setups permanently.')
[void]$kit.AppendLine('')
foreach ($f in $kitFiles) {
  $fp = Join-Path $here $f
  if (-not (Test-Path -LiteralPath $fp)) { continue }
  [void]$kit.AppendLine("## File: $f")
  [void]$kit.AppendLine('')
  [void]$kit.AppendLine('~~~~~')
  [void]$kit.AppendLine((Get-Content -LiteralPath $fp -Raw -Encoding UTF8).TrimEnd())
  [void]$kit.AppendLine('~~~~~')
  [void]$kit.AppendLine('')
}
$kitB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($kit.ToString()))

$html = $html.Replace('/*ACDATA*/', "const AC_DATA = $json;")
$html = $html.Replace('/*KITDATA*/', $kitB64)

$outDir = Split-Path -Parent $OutFile
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Force $outDir | Out-Null }
[System.IO.File]::WriteAllText($OutFile, $html, [System.Text.UTF8Encoding]::new($false))

$kb = [math]::Round((Get-Item -LiteralPath $OutFile).Length / 1KB)
Write-Host "Wrote $OutFile ($kb KB)" -ForegroundColor Green
