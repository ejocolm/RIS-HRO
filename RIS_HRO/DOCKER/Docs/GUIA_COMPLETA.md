# GUÍA COMPLETA DE INSTALACIÓN, CONFIGURACIÓN Y PRUEBAS — RIS_HRO

## 1. Qué incluye esta entrega

Esta versión integra los módulos definidos para la primera versión del proyecto:

- Inicio de sesión.
- Autenticación por cookies.
- Roles `ADMINISTRADOR` y `USUARIO_CITAS`.
- Dashboard.
- Búsqueda de pacientes.
- Contingencia: servicio institucional → base local → captura manual.
- Parser base para mensajes HL7 v2 con segmento PID.
- Nueva cita.
- Varios estudios por cita.
- Control de cupos por examen.
- Calendario de disponibilidad.
- Consulta e historial de citas.
- Modificación de citas.
- Cambio de estado de cita.
- Constancia de cita en PDF.
- Catálogo local de pacientes.
- Catálogo de usuarios.
- Catálogo de roles.
- Catálogo de médicos.
- Catálogo de técnicos radiólogos.
- Catálogo de servicios hospitalarios.
- Catálogo de categorías de pruebas.
- Catálogo de estudios.
- Configuración de capacidad por estudio y día de la semana.
- Reporte de estudios realizados por rango de fechas.
- Reporte de citas por rango de fechas.
- Exportación de ambos reportes a PDF.
- Calendario mensual grande de disponibilidad.
- Datos de demostración.

La aplicación NO utiliza ORM. Todo el acceso a SQL Server se realiza mediante ADO.NET y procedimientos almacenados.

---

# 2. Requisitos

## 2.1 Software

Instalar:

1. Visual Studio Community 2026.
2. Carga de trabajo **Desarrollo de ASP.NET y web**.
3. .NET SDK 10.
4. SQL Server.
5. SQL Server Management Studio (SSMS).

Para confirmar el SDK:

```cmd
dotnet --list-sdks
```

Debe aparecer una línea semejante a:

```text
10.0.401 [C:\Program Files\dotnet\sdk]
```

---

# 3. Estructura del proyecto

Las carpetas principales son:

```text
RIS_HRO_COMPLETO
│
├── Data
│   └── SqlConnectionFactory.cs
│
├── Models
│   ├── AppointmentModels.cs
│   ├── AuthModels.cs
│   ├── CapacityModels.cs
│   ├── CatalogModels.cs
│   ├── DashboardModels.cs
│   ├── Patient.cs
│   └── ReportModels.cs
│
├── Repositories
│   ├── AppointmentRepository.cs
│   ├── AuthRepository.cs
│   ├── CapacityRepository.cs
│   ├── CatalogRepository.cs
│   ├── DashboardRepository.cs
│   ├── PatientRepository.cs
│   ├── ReportRepository.cs
│   └── UserRepository.cs
│
├── Services
│   ├── Hl7ParserService.cs
│   ├── HospitalPatientService.cs
│   ├── PasswordService.cs
│   ├── PatientLookupService.cs
│   └── PdfService.cs
│
├── Pages
│   ├── Account
│   ├── Admin
│   ├── Appointments
│   ├── Capacity
│   ├── Catalogs
│   ├── Dashboard
│   ├── Patients
│   └── Reports
│
├── SQL
│   ├── 00_FULL_SETUP_DEV.sql
│   └── 01_CHECK_INSTALLATION.sql
│
└── wwwroot
    ├── css
    ├── images
    └── js
```

---

# 4. Crear la base de datos

## IMPORTANTE

`SQL/00_FULL_SETUP_DEV.sql` elimina `RIS_HRO` si ya existe y vuelve a crearla.

Úselo solamente en el ambiente de desarrollo.

## Pasos

1. Abrir SQL Server Management Studio.
2. Conectarse al servidor.
3. Abrir `SQL/00_FULL_SETUP_DEV.sql`.
4. Ejecutar el script completo.
5. Confirmar que finalice sin errores.

Luego ejecutar:

`SQL/01_CHECK_INSTALLATION.sql`

Debe devolver conteos de tablas y resultados del Dashboard.

---

# 5. Información de prueba

## Usuarios

Administrador:

```text
Usuario: ADMIN01
Contraseña: Admin123*
```

Usuario operativo:

```text
Usuario: CITAS01
Contraseña: Citas123*
```

## Pacientes

```text
152487
100002
100003
100004
100005
```

## Médicos

```text
MED001
MED002
MED003
```

## Servicios

```text
SER001
SER002
SER003
SER004
```

## Estudios

```text
RX001
RX002
RX003
US001
US002
MAM001
```

---

# 6. Configurar la cadena de conexión

Abrir:

`appsettings.Development.json`

Por defecto:

```json
"DefaultConnection": "Server=localhost;Database=RIS_HRO;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True"
```

## Ejemplos

SQL Server local:

```json
Server=localhost;Database=RIS_HRO;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True
```

SQL Express:

```json
Server=localhost\\SQLEXPRESS;Database=RIS_HRO;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True
```

Servidor con nombre:

```json
Server=MI-PC\\SQLSERVER;Database=RIS_HRO;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True
```

Si se utiliza autenticación SQL:

```json
Server=SERVIDOR;Database=RIS_HRO;User Id=usuario;Password=clave;TrustServerCertificate=True;MultipleActiveResultSets=True
```

No guardar una contraseña real de producción en Git.

---

# 7. Abrir en Visual Studio

Se puede abrir:

`RIS_HRO.sln`

o directamente:

`RIS_HRO.csproj`

Después:

1. Esperar a que Visual Studio restaure NuGet.
2. Compilar `Build > Build Solution`.
3. Corregir primero cualquier problema de conexión.
4. Ejecutar con F5.

Los paquetes utilizados son:

- `Microsoft.Data.SqlClient`
- `PDFsharp`

---

# 8. Primer inicio de sesión

Abrir la aplicación.

Ingresar:

```text
ADMIN01
Admin123*
```

Después del acceso debe mostrarse el Dashboard.

El usuario `CITAS01` tendrá ocultas las funciones administrativas.

---

# 9. Dashboard

El Dashboard obtiene la información directamente de SQL Server.

Procedimientos:

- `sp_Dashboard_ResumenDia`
- `sp_Dashboard_CapacidadDia`
- `sp_Dashboard_ProximasCitas`

Muestra:

- Citas de hoy.
- Pendientes.
- Atendidas.
- Canceladas.
- Capacidad y ocupación por EXAMEN.
- Próximas citas.

La capacidad nunca se calcula por categoría.

---

# 10. Regla central de capacidad

La regla implementada es:

```text
1 fila en DETALLE_CITA = 1 cupo consumido de IdPrueba.
```

Ejemplo:

```text
Paciente A:
RX001
RX002
US001
```

consume:

```text
RX001 = 1
RX002 = 1
US001 = 1
```

No se utiliza la categoría para calcular cupos.

---

# 11. Crear una cita

Ir a:

`Citas > Nueva cita`

## Paso 1 — paciente

Ingresar `152487`.

Presionar Buscar.

El flujo del sistema es:

```text
Servicio institucional
        ↓
Si no existe o falla
        ↓
CAT_PACIENTES
        ↓
Si tampoco existe
        ↓
Ingreso manual
```

Con el proyecto recién instalado, el servicio institucional está deshabilitado, por lo que se utiliza la base local.

## Paso 2 — médico y servicio

Seleccionar los valores de los catálogos.

## Paso 3 — estudios

Se puede escribir directamente:

```text
RX001
```

y presionar Enter.

También se puede utilizar:

`Buscar estudio`

Se pueden agregar varios estudios.

## Paso 4 — calendario

El calendario consulta la capacidad de todos los estudios seleccionados.

Estados:

- Verde: disponibilidad suficiente.
- Amarillo: disponibilidad igual o menor al 25 %.
- Rojo: por lo menos uno de los estudios está completo.
- Gris: uno o más estudios no tienen capacidad configurada.

## Paso 5 — fecha y hora

Seleccionar el día y la hora exacta indicada al paciente.

## Paso 6 — guardar

La aplicación vuelve a validar la capacidad en SQL Server.

Después se ejecuta una transacción:

```text
BEGIN TRANSACTION
  Validar capacidad
  INSERT CITA
  INSERT DETALLE_CITA
COMMIT
```

Ante un error:

```text
ROLLBACK
```

---

# 12. Consultar y modificar citas

Ir a:

`Citas > Consultar citas`

Filtros:

- Fecha inicial.
- Fecha final.
- Paciente.
- Estado.

Desde el listado puede abrirse la edición.

La pantalla de edición conserva la misma línea visual de Nueva cita.

Al cambiar fecha o estudios se valida nuevamente la capacidad.

La edición excluye del cálculo los cupos que ya pertenecen a la misma cita.

---

# 13. Estados de cita

Estados disponibles:

```text
PROGRAMADA
ATENDIDA
CANCELADA
NO_ASISTIO
```

La versión funcional actual implementa esta regla:

- `ATENDIDA`: los detalles pendientes pasan a `REALIZADO`.
- `CANCELADA`: los detalles pendientes pasan a `CANCELADO`.
- `NO_ASISTIO`: los detalles pendientes pasan a `CANCELADO`.

Por lo tanto, cancelaciones y no asistencia liberan el cupo.

IMPORTANTE:
esta regla fue necesaria para cerrar el flujo funcional, pero debe confirmarse con el departamento antes de una puesta en producción real. Si el hospital indica otra conducta, debe modificarse `sp_Cita_CambiarEstado` y los SP de disponibilidad.

---

# 14. Constancia de cita

Desde Consultar citas o Modificar cita se puede generar la constancia.

Incluye:

- Número de cita.
- Paciente.
- Médico.
- Servicio.
- Fecha.
- Hora.
- Estudios.
- Estado.
- Observaciones.

Se genera mediante PDFsharp.

La configuración actual utiliza las fuentes de Windows. Por esa razón, para el despliegue de esta versión se recomienda Azure App Service en Windows.

---

# 15. Pacientes

El módulo `Pacientes` administra la copia local utilizada por RIS_HRO.

No reemplaza el sistema maestro institucional.

Se utiliza como contingencia y para cumplir las relaciones de la base local.

---

# 16. Catálogos

El administrador puede mantener:

- Médicos.
- Técnicos radiólogos.
- Servicios hospitalarios.
- Categorías de pruebas.
- Estudios.
- Roles.

Los registros se desactivan mediante el campo `Activo`; no se eliminan físicamente como operación normal.

---

# 17. Usuarios

Ruta:

`Administración > Usuarios`

Al crear un usuario se solicita contraseña.

Al editar:

- dejar la contraseña vacía conserva la actual;
- ingresar una contraseña genera un nuevo hash.

Las contraseñas no se almacenan en texto plano.

---

# 18. Capacidad

Ruta:

`Catálogos > Capacidad`

Cada fila corresponde a un estudio.

Se configuran valores para:

- Lunes.
- Martes.
- Miércoles.
- Jueves.
- Viernes.
- Sábado.
- Domingo.

Un valor vacío desactiva la capacidad de ese día para la prueba.

---

# 19. Reportes

Ruta:

`Reportes > Reportes`

Se selecciona:

- Fecha inicial.
- Fecha final.

La pantalla presenta:

- Resumen de citas.
- Conteo de estudios realizados.
- Listado de citas.

Cada reporte dispone de exportación a PDF.

---

# 20. Calendario general

Ruta:

`Reportes > Disponibilidad`

Seleccionar:

1. Estudio.
2. Mes.
3. Consultar.

Se obtiene un calendario mensual grande con:

- disponibilidad;
- cupos utilizados;
- cupos disponibles;
- detalle del día.

---

# 21. Integración con WebService / HL7

## Estado actual

La arquitectura está implementada, pero no es posible conectar definitivamente el servicio del hospital sin su contrato técnico.

Configuración:

```json
"HospitalPatientService": {
  "Enabled": false,
  "Mode": "Disabled",
  "BaseUrl": "",
  "PatientPath": "",
  "PatientIdQueryName": "idPaciente",
  "BearerToken": ""
}
```

## Si el servicio real es HTTP GET que devuelve HL7 v2 crudo

Cambiar:

```json
"Enabled": true,
"Mode": "HttpGetRawHl7"
```

e ingresar `BaseUrl` y `PatientPath`.

El parser base interpreta convencionalmente:

- PID-3: identificador.
- PID-5: nombre.
- PID-7: fecha de nacimiento.
- PID-8: sexo.
- PID-13: teléfono.

ANTES DE PRODUCCIÓN hay que comparar estos campos con el mensaje real del HRO.

## Si el servicio es SOAP, POST JSON, autenticación diferente u otra variante

Modificar únicamente:

`Services/HospitalPatientService.cs`

El resto del flujo no necesita cambiar.

---

# 22. Procedimientos almacenados incluidos

## Login / usuarios

- `sp_Usuario_ObtenerLogin`
- `sp_Usuario_ActualizarUltimoAcceso`
- `sp_Usuario_Listar`
- `sp_Usuario_Obtener`
- `sp_Usuario_Guardar`

## Pacientes

- `sp_Paciente_Obtener`
- `sp_Paciente_Listar`
- `sp_Paciente_Guardar`

## Médicos

- `sp_Medico_Listar`
- `sp_Medico_Obtener`
- `sp_Medico_Guardar`
- `sp_Medico_ListarActivos`

## Técnicos

- `sp_Tecnico_Listar`
- `sp_Tecnico_Obtener`
- `sp_Tecnico_Guardar`

## Servicios

- `sp_Servicio_Listar`
- `sp_Servicio_Obtener`
- `sp_Servicio_Guardar`
- `sp_Servicio_ListarActivos`

## Categorías

- `sp_Categoria_Listar`
- `sp_Categoria_Obtener`
- `sp_Categoria_Guardar`
- `sp_Categoria_ListarActivas`

## Estudios

- `sp_Prueba_Listar`
- `sp_Prueba_Obtener`
- `sp_Prueba_Guardar`
- `sp_Prueba_ObtenerActiva`
- `sp_Prueba_BuscarActivas`

## Roles

- `sp_Rol_Listar`
- `sp_Rol_Obtener`
- `sp_Rol_Guardar`
- `sp_Rol_ListarActivos`

## Capacidad

- `sp_Capacidad_Listar`
- `sp_Capacidad_Guardar`
- `sp_Capacidad_MesPorPruebas`

## Dashboard

- `sp_Dashboard_ResumenDia`
- `sp_Dashboard_CapacidadDia`
- `sp_Dashboard_ProximasCitas`

## Citas

- `sp_Cita_Listar`
- `sp_Cita_Obtener`
- `sp_Cita_Crear`
- `sp_Cita_Actualizar`
- `sp_Cita_CambiarEstado`

## Reportes

- `sp_Reporte_Resumen`
- `sp_Reporte_EstudiosRealizados`
- `sp_Reporte_Citas`

---

# 23. Flujo de prueba recomendado

## Prueba A — Login

1. Entrar con ADMIN01.
2. Cerrar sesión.
3. Entrar con CITAS01.
4. Confirmar que los catálogos administrativos no estén disponibles.

## Prueba B — Nueva cita

1. Buscar paciente 152487.
2. Seleccionar MED001.
3. Seleccionar SER001.
4. Agregar RX001.
5. Agregar US001.
6. Seleccionar fecha disponible.
7. Ingresar hora.
8. Guardar.

## Prueba C — Validación de capacidad

1. Cambiar una capacidad a `1`.
2. Crear una cita que consuma ese estudio.
3. Intentar crear una segunda cita en la misma fecha.
4. SQL Server debe impedirla.

## Prueba D — Edición

1. Abrir una cita PROGRAMADA.
2. Agregar un estudio.
3. Cambiar fecha.
4. Guardar.
5. Confirmar que se vuelva a validar la capacidad.

## Prueba E — Reportes

1. Marcar una cita como ATENDIDA.
2. Ir a Reportes.
3. Incluir la fecha correspondiente.
4. El estudio debe aparecer en el conteo de realizados.
5. Exportar PDF.

---

# 24. Publicación futura en Azure

La arquitectura prevista es:

```text
Navegador
   ↓ HTTPS
Azure App Service (Windows)
   ↓
Azure SQL Database
```

Para esta versión se recomienda App Service Windows por la configuración de PDFsharp con fuentes de Windows.

Antes de publicar:

1. Cambiar contraseñas demo.
2. Crear base Azure SQL.
3. Ejecutar scripts de estructura/datos apropiados.
4. Configurar Connection String desde Azure, no en el código.
5. Activar HTTPS.
6. Configurar el WebService institucional.
7. Validar reglas de firewall.
8. Realizar pruebas de aceptación.

---

# 25. Aspectos que deben confirmarse antes de producción

Hay dos puntos funcionales que todavía dependen del hospital:

1. Contrato técnico real del WebService y mensaje HL7.
2. Si una cita cancelada o no asistida debe liberar inmediatamente el cupo.

El proyecto está preparado para ambos, pero no se deben inventar estas reglas institucionales.

---

# 26. Solución de problemas

## Error: no se puede conectar a SQL Server

Revisar el nombre del servidor en SSMS y usar exactamente el mismo en `DefaultConnection`.

## Error de certificado SQL

Para desarrollo se incluye:

```text
TrustServerCertificate=True
```

## Login no funciona después de cambiar usuarios

Verificar que el script completo haya terminado sin errores y que se utilice la base `RIS_HRO`.

## El calendario aparece gris

Significa que no existe capacidad activa para uno o más estudios en ese día.

Revisar:

`Catálogos > Capacidad`

## El PDF produce error de fuente

Esta entrega está preparada para Windows.

Confirmar que la aplicación se ejecuta en Windows y que `Program.cs` conserva:

```csharp
GlobalFontSettings.UseWindowsFontsUnderWindows = true;
```

---

# 27. Orden recomendado para la demostración universitaria

1. Login.
2. Dashboard.
3. Mostrar catálogos.
4. Mostrar capacidad por examen.
5. Crear cita.
6. Explicar búsqueda de paciente.
7. Agregar varios estudios.
8. Mostrar calendario.
9. Guardar.
10. Consultar historial.
11. Editar la cita.
12. Generar constancia PDF.
13. Marcar atendida.
14. Mostrar reportes.
15. Mostrar calendario mensual de disponibilidad.
16. Explicar WebService/HL7 y contingencia local.

Este recorrido muestra la relación completa entre problema, solución, base de datos y aplicación.
