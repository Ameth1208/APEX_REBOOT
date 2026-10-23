param([switch]$Web)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$ApexVersion = '4.6.3'
$ApexCache = Join-Path $env:LOCALAPPDATA 'APEX-REBOOT-Build'
$ApexTemplates = Join-Path $env:APPDATA "Godot\export_templates\$ApexVersion.stable"
$ApexRemote = "https://github.com/godotengine/godot/releases/download/$ApexVersion-stable"
New-Item -ItemType Directory -Force $ApexCache,$ApexTemplates,'build\Windows','build\Linux','build\Web' | Out-Null
New-Item -ItemType File -Force 'build\.gdignore' | Out-Null
function Get-ApexFile([string]$Name) {
  $Target = Join-Path $ApexCache $Name
  if (!(Test-Path $Target)) {
    Write-Host "Descargando $Name"
    Invoke-WebRequest -UseBasicParsing "$ApexRemote/$Name" -OutFile "$Target.part"
    Move-Item "$Target.part" $Target
  }
  return $Target
}
$Sums = Get-ApexFile 'SHA512-SUMS.txt'
function Test-ApexHash([string]$Path) {
  $FileName = Split-Path $Path -Leaf
  $Entry = Get-Content $Sums | Where-Object { ($_ -split '\s+')[1] -eq $FileName }
  if (!$Entry) { throw "No se encontro checksum oficial para $FileName" }
  $Expected = ($Entry -split '\s+')[0]
  if ((Get-FileHash $Path -Algorithm SHA512).Hash.ToLower() -ne $Expected.ToLower()) {
    throw "La descarga no supera la verificacion SHA-512: $FileName"
  }
}
$ApexEngineName = "Godot_v$ApexVersion-stable_win64.exe"
$ApexEngine = Join-Path $ApexCache $ApexEngineName
if (!(Test-Path $ApexEngine)) {
  $Archive = Get-ApexFile "$ApexEngineName.zip"
  Test-ApexHash $Archive
  Expand-Archive -Force $Archive $ApexCache
}
if (!(Test-Path (Join-Path $ApexTemplates 'windows_release_x86_64.exe')) -or !(Test-Path (Join-Path $ApexTemplates 'linux_release.x86_64')) -or ($Web -and !(Test-Path (Join-Path $ApexTemplates 'web_nothreads_release.zip')))) {
  Write-Host 'Primera descarga de plantillas oficiales: aproximadamente 1.2 GB.'
  $Archive = Get-ApexFile "Godot_v$ApexVersion-stable_export_templates.tpz"
  Test-ApexHash $Archive
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $Zip = [IO.Compression.ZipFile]::OpenRead($Archive)
  try {
    foreach ($Entry in $Zip.Entries) {
      if ($Entry.Name -match '^(windows_(debug|release)_x86_64\.exe|linux_(debug|release)\.x86_64|web_nothreads_(debug|release)\.zip|version\.txt)$') {
        [IO.Compression.ZipFileExtensions]::ExtractToFile($Entry, (Join-Path $ApexTemplates $Entry.Name), $true)
      }
    }
  } finally { $Zip.Dispose() }
}
& $ApexEngine --headless --editor --path . --import
if ($LASTEXITCODE -ne 0) { throw 'Error al importar el proyecto.' }
& $ApexEngine --headless --path . --export-release 'Windows Desktop'
if ($LASTEXITCODE -ne 0) { throw 'Error al exportar Windows.' }
& $ApexEngine --headless --path . --export-release 'Linux'
if ($LASTEXITCODE -ne 0) { throw 'Error al exportar Linux.' }
if ($Web) {
  & $ApexEngine --headless --path . --export-release 'Web'
  if ($LASTEXITCODE -ne 0) { throw 'Error al exportar Web.' }
}
foreach ($ApexPlatform in @('Windows', 'Linux', 'Web')) {
  if ($ApexPlatform -eq 'Web' -and !$Web) { continue }
  $ApexOutput = Join-Path 'build' $ApexPlatform
  New-Item -ItemType Directory -Force (Join-Path $ApexOutput 'assets\vehicles') | Out-Null
  Copy-Item 'README_ES.md' $ApexOutput -Force
  Copy-Item 'docs', 'licenses' $ApexOutput -Recurse -Force
  Copy-Item 'assets\vehicles\THIRD_PARTY_NOTICES.md' (Join-Path $ApexOutput 'assets\vehicles') -Force
}
Write-Host 'Proyecto compilado. Abre build\Windows\APEX_REBOOT.exe.'
