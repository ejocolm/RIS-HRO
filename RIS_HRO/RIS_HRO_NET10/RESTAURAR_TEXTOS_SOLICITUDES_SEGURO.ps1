param(
    [string]$BackupPath
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path $PSScriptRoot).Path
$Parent = Split-Path $Root -Parent
$BackupBase = Join-Path $Parent 'RIS_HRO_BACKUPS'

if ([string]::IsNullOrWhiteSpace($BackupPath)) {
    if (-not (Test-Path $BackupBase)) {
        throw 'No existe la carpeta RIS_HRO_BACKUPS junto al proyecto.'
    }

    $latest = Get-ChildItem -Path $BackupBase -Directory -Filter 'textos_solicitudes_*' |
        Sort-Object Name -Descending |
        Select-Object -First 1

    if (-not $latest) {
        throw 'No se encontro un respaldo de textos_solicitudes.'
    }

    $BackupPath = $latest.FullName
}

$BackupPath = (Resolve-Path $BackupPath).Path
$manifestPath = Join-Path $BackupPath 'manifest.txt'

if (-not (Test-Path $manifestPath)) {
    throw 'El respaldo no contiene manifest.txt y no se restaurara automaticamente.'
}

$files = Get-Content -LiteralPath $manifestPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

Write-Host ''
Write-Host 'RIS_HRO - Restauracion segura de textos' -ForegroundColor Cyan
Write-Host ('Proyecto: ' + $Root)
Write-Host ('Respaldo: ' + $BackupPath)
Write-Host ('Archivos a restaurar: ' + $files.Count)
Write-Host ''

$answer = Read-Host 'Escriba SI para continuar'
if ($answer -ne 'SI') {
    Write-Host 'Restauracion cancelada.' -ForegroundColor Yellow
    exit 0
}

foreach ($relative in $files) {
    $source = Join-Path $BackupPath $relative
    $destination = Join-Path $Root $relative

    if (-not (Test-Path $source)) {
        throw ("Falta el archivo respaldado: " + $source)
    }

    $destinationFolder = Split-Path $destination -Parent
    New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Force
    Write-Host ('Restaurado: ' + $relative)
}

Write-Host ''
Write-Host 'Restauracion completada.' -ForegroundColor Green
Write-Host 'Ejecute Clean Solution y Rebuild Solution.' -ForegroundColor Cyan
