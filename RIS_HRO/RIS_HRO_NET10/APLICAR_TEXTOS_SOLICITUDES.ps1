param(
    [string]$Root = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'

Write-Host "RIS_HRO - Hotfix de terminología: Citas -> Solicitudes" -ForegroundColor Cyan
Write-Host "Raíz: $Root" -ForegroundColor DarkGray

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupRoot = Join-Path $Root "_backup_textos_solicitudes_$timestamp"

# IMPORTANTE:
# Este parche cambia únicamente textos visibles/mensajes.
# NO renombra clases, propiedades, tablas, SPs, rutas ni identificadores como:
# CITA, IdCita, NumeroCita, FechaCita, HoraCita, sp_Cita_*, Appointment*, etc.
# También conserva intencionalmente el nombre del tipo "Cita programada".

$replacements = @(
    # Nombre general del sistema
    @('Sistema de Citas de Radiología', 'Sistema de Solicitudes de Radiología'),

    # Navegación / títulos principales
    @('Nueva cita', 'Nueva solicitud'),
    @('Nueva Cita', 'Nueva Solicitud'),
    @('Consultar citas', 'Solicitudes'),
    @('Consultar Citas', 'Solicitudes'),
    @('Consultar cita', 'Solicitudes'),
    @('Consultar Cita', 'Solicitudes'),
    @('Modificar cita', 'Modificar solicitud'),
    @('Modificar Cita', 'Modificar Solicitud'),

    # Creación / edición
    @('Registro y programación de citas radiológicas', 'Registro y gestión de solicitudes radiológicas'),
    @('Guardar cita', 'Guardar solicitud'),
    @('Guardar Cita', 'Guardar Solicitud'),
    @('Datos generales de la cita', 'Datos generales de la solicitud'),
    @('Número de cita', 'Número de solicitud'),
    @('Fecha de cita', 'Fecha de solicitud'),
    @('Hora de cita', 'Hora de solicitud'),
    @('seguimiento de la cita y sus estudios', 'seguimiento de la solicitud y sus estudios'),
    @('El cálculo excluye la cita que se está editando', 'El cálculo excluye la solicitud que se está editando'),
    @('Cancelar cita', 'Cancelar solicitud'),
    @('Cancelar Cita', 'Cancelar Solicitud'),
    @('¿Desea cancelar esta cita?', '¿Desea cancelar esta solicitud?'),
    @('¿Desea marcar esta cita como NO ASISTIÓ?', '¿Desea marcar esta solicitud como NO ASISTIÓ?'),
    @('Cita no atendida', 'Solicitud no atendida'),
    @('cita no atendida', 'solicitud no atendida'),
    @('la atención de la cita y los estudios seleccionados', 'la atención de la solicitud y los estudios seleccionados'),

    # Disponibilidad: se mantiene el término "cita programada" porque es un tipo real del sistema
    @('Disponibilidad de citas', 'Disponibilidad de citas programadas'),
    @('No puede registrarse la cita: uno o más estudios no tienen cupo.', 'No puede registrarse la cita programada: uno o más estudios no tienen cupo.'),
    @('La cita puede registrarse. Hay disponibilidad para todos los estudios seleccionados.', 'La cita programada puede registrarse. Hay disponibilidad para todos los estudios seleccionados.'),

    # Mensajes de aplicación
    @('Solo las citas PROGRAMADAS pueden modificarse.', 'Solo las solicitudes en estado PROGRAMADA pueden modificarse.'),
    @('Para marcar una cita como atendida debe seleccionar los estudios realizados.', 'Para marcar una solicitud como atendida debe seleccionar los estudios realizados.'),
    @('Para marcar la cita como atendida debe seleccionar los estudios realizados.', 'Para marcar la solicitud como atendida debe seleccionar los estudios realizados.'),
    @('La cita fue marcada como ATENDIDA y se registró el estado de cada estudio.', 'La solicitud fue marcada como ATENDIDA y se registró el estado de cada estudio.'),
    @('Estado de la cita actualizado a', 'Estado de la solicitud actualizado a'),
    @('No se obtuvo respuesta al guardar la cita.', 'No se obtuvo respuesta al guardar la solicitud.'),
    @('$"Cita {result.NumeroCita} actualizada correctamente."', '$"Solicitud {result.NumeroCita} actualizada correctamente."'),
    @('$"Cita {result.NumeroCita} registrada correctamente."', '$"Solicitud {result.NumeroCita} registrada correctamente."'),

    # Dashboard
    @('Estado de cupos y citas del día', 'Estado de cupos y solicitudes del día'),
    @('Citas de hoy', 'Solicitudes de hoy'),
    @('Próximas citas', 'Próximas solicitudes'),
    @('No hay citas para mostrar.', 'No hay solicitudes para mostrar.'),
    @('La consulta completa de citas se implementará en la siguiente iteración.', 'La consulta completa de solicitudes se implementará en la siguiente iteración.'),

    # Listado principal
    @('No se encontraron citas.', 'No se encontraron solicitudes.'),

    # Reportes
    @('Total citas', 'Total solicitudes'),
    @('Listado de citas', 'Listado de solicitudes'),
    @('<th>Cita</th>', '<th>Solicitud</th>'),
    @('Reporte de citas', 'Reporte de solicitudes'),
    @('$"Citas_{from:yyyyMMdd}_{to:yyyyMMdd}.pdf"', '$"Solicitudes_{from:yyyyMMdd}_{to:yyyyMMdd}.pdf"'),
    @('("Cita", 95)', '("Solicitud", 95)'),
    @('Se muestran las primeras 22 de {rows.Count} citas.', 'Se muestran las primeras 22 de {rows.Count} solicitudes.'),

    # PDF / constancias
    @('Constancia de cita - Departamento de Radiología', 'Constancia de solicitud - Departamento de Radiología')
)

$extensions = @('*.cshtml', '*.cs', '*.js')
$files = foreach ($ext in $extensions) {
    Get-ChildItem -Path $Root -Recurse -File -Filter $ext |
        Where-Object {
            $_.FullName -notmatch '[\\/](bin|obj|node_modules|wwwroot[\\/]lib|_backup_textos_solicitudes_)' -and
            $_.FullName -notlike "$backupRoot*"
        }
}

$files = $files | Sort-Object FullName -Unique
$changedFiles = New-Object System.Collections.Generic.List[string]
$totalReplacements = 0

foreach ($file in $files) {
    $content = [System.IO.File]::ReadAllText($file.FullName)
    $original = $content
    $fileReplacementCount = 0

    foreach ($pair in $replacements) {
        $old = [string]$pair[0]
        $new = [string]$pair[1]
        if ($content.Contains($old)) {
            $count = ([regex]::Matches($content, [regex]::Escape($old))).Count
            $content = $content.Replace($old, $new)
            $fileReplacementCount += $count
        }
    }

    if ($content -ne $original) {
        $relative = $file.FullName.Substring($Root.Length).TrimStart([char]92, [char]47)
        $backupPath = Join-Path $backupRoot $relative
        $backupDir = Split-Path $backupPath -Parent
        if (-not (Test-Path $backupDir)) {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        }

        [System.IO.File]::WriteAllText($backupPath, $original, [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.UTF8Encoding]::new($false))

        $changedFiles.Add($relative)
        $totalReplacements += $fileReplacementCount
        Write-Host "MODIFICADO: $relative ($fileReplacementCount cambio(s))" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Proceso terminado." -ForegroundColor Cyan
Write-Host "Archivos modificados: $($changedFiles.Count)"
Write-Host "Reemplazos realizados: $totalReplacements"
Write-Host "Respaldo: $backupRoot" -ForegroundColor Yellow

if ($changedFiles.Count -eq 0) {
    Write-Host "No se encontraron textos pendientes con esta lista de reemplazos." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "IMPORTANTE:" -ForegroundColor Cyan
Write-Host "- Se conservaron CITA, IdCita, NumeroCita, FechaCita, HoraCita, sp_Cita_* y Appointment* como nombres internos."
Write-Host "- Se conserva 'Cita programada' porque es una de las dos opciones reales del sistema."
Write-Host "- Compile con Clean Solution + Rebuild Solution después de aplicar el parche."
