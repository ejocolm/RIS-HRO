USE RIS_HRO;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ============================================================================
   RIS_HRO - REQUERIMIENTO 4 / FASE 1
   MÓDULO DE INVENTARIO DE ESTUDIOS REALIZADOS

   IMPORTANTE:
   - NO crea una tabla de inventario.
   - NO duplica registros.
   - El inventario se obtiene de:
       CITA + DETALLE_CITA + INFORME_ESTUDIO
   - Solo muestra estudios con DETALLE_CITA.Estado = 'REALIZADO'.
   - El estado del informe se presenta como:
       SIN_INFORME / BORRADOR / FINALIZADO.
   ============================================================================ */


/* ============================================================================
   1. ÍNDICES DE APOYO
   ============================================================================ */
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.DETALLE_CITA')
      AND name = N'IX_DETALLE_CITA_InventarioRealizados'
)
BEGIN
    CREATE INDEX IX_DETALLE_CITA_InventarioRealizados
    ON dbo.DETALLE_CITA(IdCita, IdDetalleCita)
    INCLUDE(IdPrueba, Observaciones)
    WHERE Estado = 'REALIZADO';
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.HISTORIAL_ESTADO_DETALLE_CITA')
      AND name = N'IX_HIST_ESTADO_DETALLE_Realizado'
)
BEGIN
    CREATE INDEX IX_HIST_ESTADO_DETALLE_Realizado
    ON dbo.HISTORIAL_ESTADO_DETALLE_CITA(IdDetalleCita, FechaHoraCambio DESC)
    WHERE EstadoNuevo = 'REALIZADO';
END;
GO


/* ============================================================================
   2. LISTADO / BÚSQUEDA DE INVENTARIO
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.sp_Inventario_Estudios_Listar
    @IdInternoRadiologia VARCHAR(50) = NULL,
    @IdPaciente VARCHAR(30) = NULL,
    @Paciente VARCHAR(150) = NULL,
    @IdPrueba VARCHAR(30) = NULL,
    @NombrePrueba VARCHAR(150) = NULL,
    @FechaInicio DATE = NULL,
    @FechaFin DATE = NULL,
    @EstadoInforme VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @IdInternoRadiologia = NULLIF(LTRIM(RTRIM(@IdInternoRadiologia)), '');
    SET @IdPaciente = NULLIF(LTRIM(RTRIM(@IdPaciente)), '');
    SET @Paciente = NULLIF(LTRIM(RTRIM(@Paciente)), '');
    SET @IdPrueba = NULLIF(LTRIM(RTRIM(@IdPrueba)), '');
    SET @NombrePrueba = NULLIF(LTRIM(RTRIM(@NombrePrueba)), '');
    SET @EstadoInforme = NULLIF(UPPER(LTRIM(RTRIM(@EstadoInforme))), '');

    IF @EstadoInforme IS NOT NULL
       AND @EstadoInforme NOT IN ('SIN_INFORME', 'BORRADOR', 'FINALIZADO')
    BEGIN
        THROW 50500, 'Estado de informe no válido.', 1;
    END;

    ;WITH InventarioBase AS
    (
        SELECT
            DC.IdDetalleCita,
            C.IdCita,
            C.NumeroCita,
            COALESCE
            (
                HR.FechaRealizacion,
                DATEADD
                (
                    SECOND,
                    DATEDIFF(SECOND, CAST('00:00:00' AS TIME), C.HoraCita),
                    CAST(C.FechaCita AS DATETIME2(0))
                )
            ) AS FechaRealizacion,

            C.IdPaciente,
            LTRIM(RTRIM(CONCAT
            (
                PAC.PrimerNombre, ' ',
                COALESCE(PAC.SegundoNombre + ' ', ''),
                PAC.PrimerApellido,
                COALESCE(' ' + PAC.SegundoApellido, '')
            ))) AS Paciente,

            DC.IdPrueba,
            PR.NombrePrueba,
            CAT.NombreCategoria,
            ISNULL(PC.PartesCuerpo, '') AS PartesCuerpo,

            IE.IdInforme,
            IE.IdInternoRadiologia,
            CASE
                WHEN IE.IdInforme IS NULL THEN 'SIN_INFORME'
                ELSE IE.Estado
            END AS EstadoInforme,
            ISNULL(IE.NumeroVersion, 0) AS NumeroVersion
        FROM dbo.DETALLE_CITA DC
        INNER JOIN dbo.CITA C
            ON C.IdCita = DC.IdCita
        INNER JOIN dbo.CAT_PACIENTES PAC
            ON PAC.IdPaciente = C.IdPaciente
        INNER JOIN dbo.CAT_PRUEBAS PR
            ON PR.IdPrueba = DC.IdPrueba
        INNER JOIN dbo.CAT_CATEGORIAS_PRUEBAS CAT
            ON CAT.IdCategoria = PR.IdCategoria
        LEFT JOIN dbo.INFORME_ESTUDIO IE
            ON IE.IdDetalleCita = DC.IdDetalleCita

        OUTER APPLY
        (
            SELECT TOP (1)
                H.FechaHoraCambio AS FechaRealizacion
            FROM dbo.HISTORIAL_ESTADO_DETALLE_CITA H
            WHERE H.IdDetalleCita = DC.IdDetalleCita
              AND H.EstadoNuevo = 'REALIZADO'
            ORDER BY H.FechaHoraCambio DESC
        ) HR

        OUTER APPLY
        (
            SELECT
                STRING_AGG(X.NombreParte, ', ')
                WITHIN GROUP (ORDER BY X.NombreParte) AS PartesCuerpo
            FROM
            (
                SELECT CP.NombreParte
                FROM dbo.DETALLE_CITA_PARTE_CUERPO DCP
                INNER JOIN dbo.CAT_PARTES_CUERPO CP
                    ON CP.IdParteCuerpo = DCP.IdParteCuerpo
                WHERE DCP.IdDetalleCita = DC.IdDetalleCita
            ) X
        ) PC

        WHERE DC.Estado = 'REALIZADO'
          AND C.Activo = 1
    )
    SELECT
        IdDetalleCita,
        IdCita,
        NumeroCita,
        FechaRealizacion,
        IdPaciente,
        Paciente,
        IdPrueba,
        NombrePrueba,
        NombreCategoria,
        PartesCuerpo,
        IdInforme,
        IdInternoRadiologia,
        EstadoInforme,
        NumeroVersion
    FROM InventarioBase
    WHERE
        (@IdInternoRadiologia IS NULL
            OR IdInternoRadiologia LIKE '%' + @IdInternoRadiologia + '%')
        AND
        (@IdPaciente IS NULL
            OR IdPaciente LIKE '%' + @IdPaciente + '%')
        AND
        (@Paciente IS NULL
            OR Paciente LIKE '%' + @Paciente + '%')
        AND
        (@IdPrueba IS NULL
            OR IdPrueba LIKE '%' + @IdPrueba + '%')
        AND
        (@NombrePrueba IS NULL
            OR NombrePrueba LIKE '%' + @NombrePrueba + '%')
        AND
        (@FechaInicio IS NULL
            OR CAST(FechaRealizacion AS DATE) >= @FechaInicio)
        AND
        (@FechaFin IS NULL
            OR CAST(FechaRealizacion AS DATE) <= @FechaFin)
        AND
        (@EstadoInforme IS NULL
            OR EstadoInforme = @EstadoInforme)
    ORDER BY FechaRealizacion DESC, IdDetalleCita DESC;
END;
GO


/* ============================================================================
   3. DETALLE DE UN ESTUDIO DEL INVENTARIO
   Solo ADMINISTRADOR / USUARIO_INFORMES lo expondrán desde la aplicación.
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.sp_Inventario_Estudio_Obtener
    @IdDetalleCita INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        DC.IdDetalleCita,
        C.IdCita,
        C.NumeroCita,

        COALESCE
        (
            HR.FechaRealizacion,
            DATEADD
            (
                SECOND,
                DATEDIFF(SECOND, CAST('00:00:00' AS TIME), C.HoraCita),
                CAST(C.FechaCita AS DATETIME2(0))
            )
        ) AS FechaRealizacion,

        C.IdPaciente,
        LTRIM(RTRIM(CONCAT
        (
            PAC.PrimerNombre, ' ',
            COALESCE(PAC.SegundoNombre + ' ', ''),
            PAC.PrimerApellido,
            COALESCE(' ' + PAC.SegundoApellido, '')
        ))) AS Paciente,

        C.IdServicio,
        SER.NombreServicio AS Servicio,
        C.IdMedico AS IdMedicoSolicitante,
        CONCAT(MED.Nombres, ' ', MED.Apellidos) AS MedicoSolicitante,
        C.Observaciones AS ObservacionesCita,

        DC.IdPrueba,
        PR.NombrePrueba,
        CAT.NombreCategoria,
        DC.Observaciones AS ObservacionesEstudio,
        ISNULL(PC.PartesCuerpo, '') AS PartesCuerpo,

        IE.IdInforme,
        IE.IdInternoRadiologia,
        CASE
            WHEN IE.IdInforme IS NULL THEN 'SIN_INFORME'
            ELSE IE.Estado
        END AS EstadoInforme,
        ISNULL(IE.NumeroVersion, 0) AS NumeroVersion,
        IE.FechaHoraInforme,
        IE.FechaFinalizacion,

        IE.IdTecnicoRealiza,
        CASE
            WHEN TR.IdTecnico IS NULL THEN NULL
            ELSE CONCAT(TR.Nombres, ' ', TR.Apellidos)
        END AS TecnicoRealiza,

        IE.IdTecnicoPosiciona,
        CASE
            WHEN TP.IdTecnico IS NULL THEN NULL
            ELSE CONCAT(TP.Nombres, ' ', TP.Apellidos)
        END AS TecnicoPosiciona,

        IE.IdMedicoInformante,
        CASE
            WHEN MI.IdMedicoInformante IS NULL THEN NULL
            ELSE CONCAT(MI.Nombres, ' ', MI.Apellidos)
        END AS MedicoInformante,
        MI.Puesto AS PuestoMedicoInformante

    FROM dbo.DETALLE_CITA DC
    INNER JOIN dbo.CITA C
        ON C.IdCita = DC.IdCita
    INNER JOIN dbo.CAT_PACIENTES PAC
        ON PAC.IdPaciente = C.IdPaciente
    INNER JOIN dbo.CAT_SERVICIOS_HOSPITALARIOS SER
        ON SER.IdServicio = C.IdServicio
    INNER JOIN dbo.CAT_MEDICOS MED
        ON MED.IdMedico = C.IdMedico
    INNER JOIN dbo.CAT_PRUEBAS PR
        ON PR.IdPrueba = DC.IdPrueba
    INNER JOIN dbo.CAT_CATEGORIAS_PRUEBAS CAT
        ON CAT.IdCategoria = PR.IdCategoria

    LEFT JOIN dbo.INFORME_ESTUDIO IE
        ON IE.IdDetalleCita = DC.IdDetalleCita
    LEFT JOIN dbo.CAT_TECNICOS_RADIOLOGOS TR
        ON TR.IdTecnico = IE.IdTecnicoRealiza
    LEFT JOIN dbo.CAT_TECNICOS_RADIOLOGOS TP
        ON TP.IdTecnico = IE.IdTecnicoPosiciona
    LEFT JOIN dbo.CAT_MEDICOS_INFORMANTES MI
        ON MI.IdMedicoInformante = IE.IdMedicoInformante

    OUTER APPLY
    (
        SELECT TOP (1)
            H.FechaHoraCambio AS FechaRealizacion
        FROM dbo.HISTORIAL_ESTADO_DETALLE_CITA H
        WHERE H.IdDetalleCita = DC.IdDetalleCita
          AND H.EstadoNuevo = 'REALIZADO'
        ORDER BY H.FechaHoraCambio DESC
    ) HR

    OUTER APPLY
    (
        SELECT
            STRING_AGG(X.NombreParte, ', ')
            WITHIN GROUP (ORDER BY X.NombreParte) AS PartesCuerpo
        FROM
        (
            SELECT CP.NombreParte
            FROM dbo.DETALLE_CITA_PARTE_CUERPO DCP
            INNER JOIN dbo.CAT_PARTES_CUERPO CP
                ON CP.IdParteCuerpo = DCP.IdParteCuerpo
            WHERE DCP.IdDetalleCita = DC.IdDetalleCita
        ) X
    ) PC

    WHERE DC.IdDetalleCita = @IdDetalleCita
      AND DC.Estado = 'REALIZADO'
      AND C.Activo = 1;
END;
GO


/* ============================================================================
   4. VERIFICACIÓN
   ============================================================================ */
SELECT
    Listado =
        CASE WHEN OBJECT_ID(N'dbo.sp_Inventario_Estudios_Listar', N'P') IS NOT NULL
             THEN 'OK' ELSE 'FALTA' END,
    Detalle =
        CASE WHEN OBJECT_ID(N'dbo.sp_Inventario_Estudio_Obtener', N'P') IS NOT NULL
             THEN 'OK' ELSE 'FALTA' END,
    SinTablaDuplicada =
        CASE WHEN OBJECT_ID(N'dbo.INVENTARIO', N'U') IS NULL
             THEN 'OK' ELSE 'REVISAR' END;
GO

PRINT 'Requerimiento 4 - Fase 1 instalada correctamente.';
PRINT 'El inventario se consulta directamente desde los estudios REALIZADOS existentes.';
GO
