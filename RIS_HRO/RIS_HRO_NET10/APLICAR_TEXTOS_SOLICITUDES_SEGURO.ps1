param(
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path $PSScriptRoot).Path
$Parent = Split-Path $Root -Parent
$BackupBase = Join-Path $Parent 'RIS_HRO_BACKUPS'
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$BackupDir = Join-Path $BackupBase ("textos_solicitudes_" + $Timestamp)

Write-Host ''
Write-Host 'RIS_HRO - Cambio seguro de terminologia: Citas -> Solicitudes' -ForegroundColor Cyan
Write-Host ('Raiz del proyecto: ' + $Root)
Write-Host ''

$projectFile = Get-ChildItem -Path $Root -Filter *.csproj -File -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $projectFile) {
    throw 'No se encontro un archivo .csproj en esta carpeta. Coloque el script en la raiz del proyecto RIS_HRO y vuelva a ejecutarlo.'
}

# IMPORTANTE:
# No existe un reemplazo global de "cita" por "solicitud".
# Solo se sustituyen frases visibles exactas. Los identificadores tecnicos
# IdCita, NumeroCita, FechaCita, sp_Cita_*, Appointment*, etc. NO se cambian.
$replacements = @(
    [PSCustomObject]@{ Old = 'Sistema de Citas de Radiología'; New = 'Sistema de Solicitudes de Radiología' },
    [PSCustomObject]@{ Old = 'Estado de cupos y citas del día'; New = 'Estado de cupos y solicitudes del día' },
    [PSCustomObject]@{ Old = 'Citas de hoy'; New = 'Solicitudes de hoy' },
    [PSCustomObject]@{ Old = 'Próximas citas'; New = 'Próximas solicitudes' },
    [PSCustomObject]@{ Old = 'No hay citas para mostrar.'; New = 'No hay solicitudes para mostrar.' },
    [PSCustomObject]@{ Old = 'La consulta completa de citas se implementará en la siguiente iteración.'; New = 'La consulta completa de solicitudes se implementará en la siguiente iteración.' },

    [PSCustomObject]@{ Old = 'Nueva Cita'; New = 'Nueva Solicitud' },
    [PSCustomObject]@{ Old = 'Nueva cita'; New = 'Nueva solicitud' },
    [PSCustomObject]@{ Old = 'Consultar Citas'; New = 'Solicitudes' },
    [PSCustomObject]@{ Old = 'Consultar citas'; New = 'Solicitudes' },
    [PSCustomObject]@{ Old = 'Registro y programación de citas radiológicas'; New = 'Registro y control de solicitudes radiológicas' },
    [PSCustomObject]@{ Old = 'Guardar cita'; New = 'Guardar solicitud' },
    [PSCustomObject]@{ Old = 'Guardar Cita'; New = 'Guardar Solicitud' },
    [PSCustomObject]@{ Old = 'Datos generales de la cita'; New = 'Datos generales de la solicitud' },
    [PSCustomObject]@{ Old = 'Número de cita'; New = 'Número de solicitud' },
    [PSCustomObject]@{ Old = 'Fecha de cita'; New = 'Fecha de solicitud' },
    [PSCustomObject]@{ Old = 'Hora de cita'; New = 'Hora de solicitud' },
    [PSCustomObject]@{ Old = 'Disponibilidad de citas'; New = 'Disponibilidad de citas programadas' },

    [PSCustomObject]@{ Old = 'Modificar cita'; New = 'Modificar solicitud' },
    [PSCustomObject]@{ Old = 'seguimiento de la cita y sus estudios'; New = 'seguimiento de la solicitud y sus estudios' },
    [PSCustomObject]@{ Old = 'Cancelar cita'; New = 'Cancelar solicitud' },
    [PSCustomObject]@{ Old = 'El cálculo excluye la cita que se está editando'; New = 'El cálculo excluye el registro que se está editando' },
    [PSCustomObject]@{ Old = 'Cita no atendida'; New = 'Solicitud no atendida' },
    [PSCustomObject]@{ Old = 'No se encontraron citas.'; New = 'No se encontraron solicitudes.' },

    [PSCustomObject]@{ Old = 'Total citas'; New = 'Total solicitudes' },
    [PSCustomObject]@{ Old = 'Listado de citas'; New = 'Listado de solicitudes' },
    [PSCustomObject]@{ Old = '<th>Cita</th>'; New = '<th>Solicitud</th>' },
    [PSCustomObject]@{ Old = 'Reporte de citas'; New = 'Reporte de solicitudes' },
    [PSCustomObject]@{ Old = '$"Citas_{from:'; New = '$"Solicitudes_{from:' },

    [PSCustomObject]@{ Old = 'Constancia de cita - Departamento de Radiología'; New = 'Constancia de solicitud - Departamento de Radiología' },
    [PSCustomObject]@{ Old = '("Cita", 95)'; New = '("Solicitud", 95)' },
    [PSCustomObject]@{ Old = 'Se muestran las primeras 22 de {rows.Count} citas. Consulte el listado en pantalla para el detalle completo.'; New = 'Se muestran las primeras 22 de {rows.Count} solicitudes. Consulte el listado en pantalla para el detalle completo.' },

    [PSCustomObject]@{ Old = 'Cita {result.NumeroCita} registrada correctamente.'; New = 'Solicitud {result.NumeroCita} registrada correctamente.' },
    [PSCustomObject]@{ Old = 'Cita {result.NumeroCita} actualizada correctamente.'; New = 'Solicitud {result.NumeroCita} actualizada correctamente.' },
    [PSCustomObject]@{ Old = 'Estado de la cita actualizado a {status}.'; New = 'Estado de la solicitud actualizado a {status}.' },
    [PSCustomObject]@{ Old = 'La cita fue marcada como ATENDIDA y se registró el estado de cada estudio.'; New = 'La solicitud fue marcada como ATENDIDA y se registró el estado de cada estudio.' },
    [PSCustomObject]@{ Old = 'Para marcar la cita como atendida debe seleccionar los estudios realizados.'; New = 'Para marcar la solicitud como atendida debe seleccionar los estudios realizados.' },
    [PSCustomObject]@{ Old = 'Solo las citas PROGRAMADAS pueden modificarse.'; New = 'Solo las solicitudes PROGRAMADAS pueden modificarse.' },
    [PSCustomObject]@{ Old = 'No se obtuvo respuesta al guardar la cita.'; New = 'No se obtuvo respuesta al guardar la solicitud.' },

    [PSCustomObject]@{ Old = 'No puede registrarse la cita: uno o más estudios no tienen cupo.'; New = 'No puede registrarse la solicitud: uno o más estudios no tienen cupo.' },
    [PSCustomObject]@{ Old = 'La cita puede registrarse. Hay disponibilidad para todos los estudios seleccionados.'; New = 'La solicitud puede registrarse. Hay disponibilidad para todos los estudios seleccionados.' },

    [PSCustomObject]@{ Old = '¿Desea marcar esta cita como NO ASISTIÓ?'; New = '¿Desea marcar esta solicitud como NO ASISTIÓ?' },
    [PSCustomObject]@{ Old = '¿Desea cancelar esta cita?'; New = '¿Desea cancelar esta solicitud?' },
    [PSCustomObject]@{ Old = '¿Confirma la atención de la cita y los estudios seleccionados?'; New = '¿Confirma la atención de la solicitud y los estudios seleccionados?' }
)

$extensions = @('.cshtml', '.cs', '.js')
$files = Get-ChildItem -Path $Root -Recurse -File | Where-Object {
    $extensions -contains $_.Extension.ToLowerInvariant() -and
    $_.FullName -notmatch '[\\/](bin|obj|\.git|RIS_HRO_BACKUPS)[\\/]' -and
    $_.FullName -notmatch '[\\/]_backup_[^\\/]*[\\/]'
}

$planned = New-Object System.Collections.Generic.List[object]
$totalReplacements = 0

foreach ($file in $files) {
    $content = [System.IO.File]::ReadAllText($file.FullName)
    $newContent = $content
    $fileCount = 0
    $details = New-Object System.Collections.Generic.List[string]

    foreach ($item in $replacements) {
        if ($newContent.Contains($item.Old)) {
            $count = [regex]::Matches($newContent, [regex]::Escape($item.Old)).Count
            $newContent = $newContent.Replace($item.Old, $item.New)
            $fileCount += $count
            $details.Add(("{0} x  {1}" -f $count, $item.Old))
        }
    }

    if ($fileCount -gt 0) {
        $relative = $file.FullName.Substring($Root.Length).TrimStart([char]92, [char]47)
        $planned.Add([PSCustomObject]@{
            File = $file.FullName
            Relative = $relative
            Original = $content
            Updated = $newContent
            Count = $fileCount
            Details = $details
        })
        $totalReplacements += $fileCount
    }
}

if ($planned.Count -eq 0) {
    Write-Host 'No se encontraron textos pendientes para cambiar.' -ForegroundColor Yellow
    Write-Host 'No se modifico ningun archivo.'
    exit 0
}

Write-Host 'Cambios detectados:' -ForegroundColor Yellow
foreach ($item in $planned) {
    Write-Host ("  {0}  ({1} reemplazos)" -f $item.Relative, $item.Count)
}
Write-Host ''
Write-Host ("Archivos afectados: {0}" -f $planned.Count)
Write-Host ("Reemplazos exactos: {0}" -f $totalReplacements)
Write-Host ''
Write-Host 'No se cambiaran IdCita, NumeroCita, FechaCita, HoraCita, sp_Cita_*, Appointment*, nombres de tablas ni procedimientos.' -ForegroundColor Green
Write-Host 'La opcion "Cita programada" tambien se conserva como tipo de registro.' -ForegroundColor Green
Write-Host ''

if (-not $Apply) {
    Write-Host 'MODO PREVISUALIZACION: no se modifico ningun archivo.' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Si la lista anterior es correcta, ejecute:' -ForegroundColor Cyan
    Write-Host 'powershell -ExecutionPolicy Bypass -File .\APLICAR_TEXTOS_SOLICITUDES_SEGURO.ps1 -Apply' -ForegroundColor White
    exit 0
}

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
$manifest = New-Object System.Collections.Generic.List[string]
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

foreach ($item in $planned) {
    $backupFile = Join-Path $BackupDir $item.Relative
    $backupFolder = Split-Path $backupFile -Parent
    New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null

    Copy-Item -LiteralPath $item.File -Destination $backupFile -Force
    [System.IO.File]::WriteAllText($item.File, $item.Updated, $utf8NoBom)
    $manifest.Add($item.Relative)
}

[System.IO.File]::WriteAllLines((Join-Path $BackupDir 'manifest.txt'), $manifest, $utf8NoBom)

Write-Host ''
Write-Host 'Proceso completado correctamente.' -ForegroundColor Green
Write-Host ("Archivos modificados: {0}" -f $planned.Count)
Write-Host ("Reemplazos realizados: {0}" -f $totalReplacements)
Write-Host ('Respaldo FUERA del proyecto: ' + $BackupDir) -ForegroundColor Green
Write-Host ''
Write-Host 'Ahora ejecute Clean Solution y Rebuild Solution.' -ForegroundColor Cyan
