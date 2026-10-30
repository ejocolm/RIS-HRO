param(
    [string]$Root = (Get-Location).Path,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

Write-Host "RIS_HRO - Restaurar estado anterior al hotfix de textos" -ForegroundColor Cyan
Write-Host "Raiz del proyecto: $Root" -ForegroundColor DarkGray

$backups = Get-ChildItem -Path $Root -Directory -Filter '_backup_textos_solicitudes_*' |
    Sort-Object LastWriteTime -Descending

if (-not $backups -or $backups.Count -eq 0) {
    Write-Host "" 
    Write-Host "No se encontro ninguna carpeta _backup_textos_solicitudes_* en la raiz del proyecto." -ForegroundColor Red
    Write-Host "No se modifico ningun archivo." -ForegroundColor Yellow
    exit 1
}

$backup = $backups[0]
$backupFiles = Get-ChildItem -Path $backup.FullName -Recurse -File

if (-not $backupFiles -or $backupFiles.Count -eq 0) {
    Write-Host "La carpeta de respaldo mas reciente esta vacia: $($backup.FullName)" -ForegroundColor Red
    Write-Host "No se modifico ningun archivo." -ForegroundColor Yellow
    exit 1
}

Write-Host "" 
Write-Host "Respaldo que se restaurara:" -ForegroundColor Yellow
Write-Host "  $($backup.FullName)"
Write-Host "Archivos encontrados: $($backupFiles.Count)"

if (-not $Force) {
    Write-Host "" 
    $answer = Read-Host "Escriba SI para restaurar estos archivos"
    if ($answer -ne 'SI') {
        Write-Host "Operacion cancelada. No se modifico ningun archivo." -ForegroundColor Yellow
        exit 0
    }
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$currentStateBackup = Join-Path $Root "_backup_estado_actual_antes_restauracion_$timestamp"
New-Item -ItemType Directory -Path $currentStateBackup -Force | Out-Null

$restored = 0

foreach ($file in $backupFiles) {
    $relative = $file.FullName.Substring($backup.FullName.Length).TrimStart([char]92, [char]47)
    $target = Join-Path $Root $relative
    $targetDir = Split-Path $target -Parent

    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    # Guardar el estado actual por seguridad antes de sobrescribirlo.
    if (Test-Path $target) {
        $safetyPath = Join-Path $currentStateBackup $relative
        $safetyDir = Split-Path $safetyPath -Parent
        if (-not (Test-Path $safetyDir)) {
            New-Item -ItemType Directory -Path $safetyDir -Force | Out-Null
        }
        Copy-Item -LiteralPath $target -Destination $safetyPath -Force
    }

    Copy-Item -LiteralPath $file.FullName -Destination $target -Force
    $restored++
    Write-Host "RESTAURADO: $relative" -ForegroundColor Green
}

Write-Host ""
Write-Host "Restauracion terminada correctamente." -ForegroundColor Cyan
Write-Host "Archivos restaurados: $restored"
Write-Host "Origen: $($backup.FullName)" -ForegroundColor Yellow
Write-Host "Copia de seguridad del estado que acabamos de reemplazar:" -ForegroundColor DarkGray
Write-Host "  $currentStateBackup" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Ahora ejecute Clean Solution y Rebuild Solution en Visual Studio." -ForegroundColor Cyan
