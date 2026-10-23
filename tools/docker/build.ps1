param([ValidateSet('all', 'windows', 'linux', 'web')][string]$Target = 'all')
$ErrorActionPreference = 'Stop'
$ApexProject = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (!(Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Instala e inicia Docker Desktop con contenedores Linux.'
}
Push-Location $ApexProject
try {
    & docker compose version
    if ($LASTEXITCODE -ne 0) { throw 'Docker Compose no esta disponible.' }
    $ApexDockerOs = & docker info --format '{{.OSType}}'
    if ($LASTEXITCODE -ne 0) { throw 'Inicia Docker Desktop antes de compilar.' }
    if ($ApexDockerOs.Trim() -ne 'linux') { throw 'Selecciona contenedores Linux en Docker Desktop.' }
    & docker compose run --rm build $Target
    if ($LASTEXITCODE -ne 0) { throw 'La compilacion fallo. Revisa build/logs.' }
} finally { Pop-Location }
