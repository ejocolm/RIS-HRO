# CHECKLIST DE PRUEBAS — RIS_HRO

## Base de datos
- [ ] RIS_HRO creada.
- [ ] 11 tablas principales creadas.
- [ ] TVP_EstudioCita creado.
- [ ] Procedimientos almacenados creados.
- [ ] Datos demo cargados.
- [ ] 01_CHECK_INSTALLATION.sql sin errores.

## Login
- [ ] ADMIN01 entra.
- [ ] CITAS01 entra.
- [ ] contraseña incorrecta rechazada.
- [ ] cerrar sesión funciona.
- [ ] usuario de citas no puede acceder a administración.

## Dashboard
- [ ] resumen del día.
- [ ] capacidad por examen.
- [ ] próximas citas.
- [ ] datos cambian después de crear una cita.

## Pacientes
- [ ] paciente local encontrado.
- [ ] paciente inexistente habilita captura manual.
- [ ] paciente manual se guarda.
- [ ] búsqueda local funciona.

## Nueva cita
- [ ] médico.
- [ ] servicio.
- [ ] estudio por código.
- [ ] buscar estudio.
- [ ] varios estudios.
- [ ] calendario.
- [ ] validación de cupo.
- [ ] fecha.
- [ ] hora.
- [ ] observaciones.
- [ ] transacción completa.

## Consulta / edición
- [ ] filtros.
- [ ] abrir cita.
- [ ] editar fecha.
- [ ] agregar/quitar estudio.
- [ ] revalidar cupo.
- [ ] constancia PDF.
- [ ] marcar atendida.
- [ ] cancelar.
- [ ] no asistió.

## Catálogos
- [ ] usuarios.
- [ ] roles.
- [ ] médicos.
- [ ] técnicos.
- [ ] servicios.
- [ ] categorías.
- [ ] estudios.
- [ ] capacidad.

## Reportes
- [ ] fecha inicial/final.
- [ ] estudios realizados.
- [ ] listado de citas.
- [ ] PDF estudios.
- [ ] PDF citas.
- [ ] calendario mensual.

## Pendientes externos
- [ ] documentación WebService.
- [ ] URL.
- [ ] autenticación.
- [ ] versión HL7.
- [ ] campos PID reales.
- [ ] regla institucional de cancelación/cupos.
