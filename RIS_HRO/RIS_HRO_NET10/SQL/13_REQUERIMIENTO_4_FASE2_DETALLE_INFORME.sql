USE RIS_HRO;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ============================================================================
   RIS_HRO - REQUERIMIENTO 4 / FASE 2
   DETALLE INTEGRAL DEL ESTUDIO E INTEGRACIÓN CON INFORMES

   - NO crea una tabla de inventario.
   - NO duplica información.
   - Amplía el detalle del inventario para mostrar:
       * Hallazgos
       * Conclusiones
       * Recursos utilizados (películas / imágenes)
       * Datos del personal del informe
   - Los recursos se muestran en inventario, pero NO forman parte del PDF clínico.
   ============================================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_Inventario_Estudio_Obtener
    @IdDetalleCita INT
AS
BEGIN
    SET NOCOUNT ON;

    /* ------------------------------------------------------------------------
       RESULTSET 1: DATOS GENERALES + INFORME ACTUAL
       ------------------------------------------------------------------------ */
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

        IE.Hallazgos,
        IE.Conclusiones,
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


    /* ------------------------------------------------------------------------
       RESULTSET 2: RECURSOS UTILIZADOS
       Se conservan para consulta/estadísticas; no se imprimen en el informe.
       ------------------------------------------------------------------------ */
    SELECT
        R.TamanoPelicula,
        R.PeliculasEntregadas,
        R.ImagenesDigitales,
        R.SistemaAdquisicionCDDR
    FROM dbo.INFORME_ESTUDIO_RECURSOS R
    INNER JOIN dbo.INFORME_ESTUDIO IE
        ON IE.IdInforme = R.IdInforme
    WHERE IE.IdDetalleCita = @IdDetalleCita
    ORDER BY CASE R.TamanoPelicula
        WHEN '8x10' THEN 1
        WHEN '10x14' THEN 2
        WHEN '14x17' THEN 3
        ELSE 4
    END;
END;
GO


/* ============================================================================
   VERIFICACIÓN
   ============================================================================ */
SELECT
    DetalleInventario =
        CASE WHEN OBJECT_ID(N'dbo.sp_Inventario_Estudio_Obtener', N'P') IS NOT NULL
             THEN 'OK' ELSE 'FALTA' END,
    TablaInventarioDuplicada =
        CASE WHEN OBJECT_ID(N'dbo.INVENTARIO', N'U') IS NULL
             THEN 'NO CREADA - OK' ELSE 'REVISAR' END;
GO

PRINT 'Requerimiento 4 - Fase 2 instalada correctamente.';
PRINT 'El detalle de inventario incluye informe actual y recursos utilizados.';
GO
