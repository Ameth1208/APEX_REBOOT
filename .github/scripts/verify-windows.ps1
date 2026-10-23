param([Parameter(Mandatory=$true)][string]$PackageDir)
$ErrorActionPreference = 'Stop'
$ApexRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$ApexIncoming = (Resolve-Path $PackageDir).Path
$ApexName = 'APEX_REBOOT_v0.3.1_Windows_x64'
$ApexArchive = Join-Path $ApexIncoming "$ApexName.zip"
$ApexHashLine = Get-Content (Join-Path $ApexIncoming 'SHA256SUMS.txt') |
    Where-Object { ($_ -split '\s+')[1] -eq "$ApexName.zip" }
if (@($ApexHashLine).Count -ne 1) { throw 'Falta un checksum único del paquete Windows.' }
$ApexExpected = ($ApexHashLine -split '\s+')[0]
if ((Get-FileHash $ApexArchive -Algorithm SHA256).Hash -ne $ApexExpected) {
    throw 'El ZIP Windows no coincide con el generado por el job Ubuntu.'
}
$ApexExtract = Join-Path $ApexRoot 'build/windows-check'
$ApexLogs = Join-Path $ApexRoot 'build/logs'
New-Item -ItemType Directory -Force $ApexExtract,$ApexLogs | Out-Null
Expand-Archive -LiteralPath $ApexArchive -DestinationPath $ApexExtract -Force
$ApexGameDir = Join-Path $ApexExtract $ApexName
$ApexExecutable = Join-Path $ApexGameDir 'APEX_REBOOT.exe'
if (!(Test-Path (Join-Path $ApexGameDir 'APEX_REBOOT.pck'))) { throw 'Falta el PCK junto al ejecutable.' }
$ApexStdout = Join-Path $ApexLogs 'windows_stdout.log'
$ApexStderr = Join-Path $ApexLogs 'windows_stderr.log'
$ApexEngineLog = Join-Path $ApexGameDir 'windows_start.log'
$ApexArguments = '--headless --quit-after 120 --log-file "' + $ApexEngineLog + '"'
$ApexProcess = Start-Process -FilePath $ApexExecutable -WorkingDirectory $ApexGameDir `
    -ArgumentList $ApexArguments `
    -RedirectStandardOutput $ApexStdout -RedirectStandardError $ApexStderr -PassThru
try {
    if (!$ApexProcess.WaitForExit(120000)) {
        Stop-Process -Id $ApexProcess.Id -Force
        throw 'El ejecutable Windows no terminó dentro de 120 segundos.'
    }
    if ($ApexProcess.ExitCode -ne 0) { throw "El ejecutable Windows devolvió $($ApexProcess.ExitCode)." }
} finally {
    if (Test-Path $ApexEngineLog) { Copy-Item $ApexEngineLog $ApexLogs -Force }
    Get-ChildItem $ApexLogs -Filter 'windows_*.log' | ForEach-Object { Get-Content $_.FullName }
}
$ApexLogFiles = Get-ChildItem $ApexLogs -Filter 'windows_*.log'
$ApexErrors = $ApexLogFiles | Select-String -Pattern 'SCRIPT ERROR:|ERROR:'
if ($ApexErrors) { throw 'Godot registró errores durante el arranque de Windows.' }
if (!($ApexLogFiles | Select-String -SimpleMatch 'Godot Engine')) { throw 'No se encontró el arranque de Godot en los registros.' }
Write-Host 'Windows nativo inició el EXE/PCK y terminó correctamente. No es una prueba gráfica ni de mando.'
