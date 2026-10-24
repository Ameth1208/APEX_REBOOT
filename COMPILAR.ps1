param(
    [ValidateSet('all', 'windows', 'linux', 'web')]
    [string]$Target = 'all'
)

$ErrorActionPreference = 'Stop'
$BuildScript = Join-Path $PSScriptRoot 'tools\docker\build.ps1'

$Docker = Get-Command docker.exe -ErrorAction SilentlyContinue
$DockerReady = $false
if ($Docker) {
    $DockerOs = (& docker info --format '{{.OSType}}' 2>$null).Trim()
    $DockerReady = $LASTEXITCODE -eq 0 -and $DockerOs -eq 'linux'
}

if ($DockerReady) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $BuildScript -Target $Target
    exit $LASTEXITCODE
}

$Godot = Get-Command godot_console.exe, godot.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if (!$Godot) {
    throw 'No hay Docker Linux disponible ni Godot instalado. Instala uno de los dos.'
}

Write-Host 'Docker no disponible: compilando directamente con Godot local.'
& $Godot.Source --headless --editor --path $PSScriptRoot --import --quit
$ExitCode = $LASTEXITCODE
if ($ExitCode -is [int] -and $ExitCode -ne 0) { throw 'Error al importar el proyecto.' }

$Presets = switch ($Target) {
    'windows' { @('Windows Desktop') }
    'linux' { @('Linux') }
    'web' { @('Web') }
    default { @('Windows Desktop', 'Linux', 'Web') }
}

foreach ($Preset in $Presets) {
    & $Godot.Source --headless --path $PSScriptRoot --export-release $Preset
    $ExitCode = $LASTEXITCODE
    if ($ExitCode -is [int] -and $ExitCode -ne 0) { throw "Error al exportar $Preset." }
}

Write-Host 'Proyecto compilado localmente.'
exit 0
