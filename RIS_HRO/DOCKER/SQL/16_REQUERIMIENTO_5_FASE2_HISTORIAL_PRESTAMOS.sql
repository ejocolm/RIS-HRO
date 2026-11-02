USE RIS_HRO;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


/* ============================================================================
   RIS_HRO
   REQUERIMIENTO 5 - FASE 2
   HISTORIAL DE PRÉSTAMOS

   OBJETIVO:
   - Consultar préstamos activos y devueltos.
   - Filtrar por rango de fechas.
   - Filtrar por ID de paciente.
   - Filtrar por ID interno de radiología.
   - Filtrar por estado.
   - Conservar todo el historial de PRESTAMO_ESTUDIO.

   IMPORTANTE:
   En base de datos:
       ACTIVO    = PRESTADO
       DEVUELTO  = DEVUELTO

   El filtro de fechas se aplica sobre FechaHoraPrestamo.
   ============================================================================ */


/* ============================================================================
   1. LISTADO GENERAL / HISTORIAL DE PRÉSTAMOS
   ============================================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_Prestamo_Listar
    @FechaInicio DATE = NULL,
    @FechaFin DATE = NULL,
    @IdPaciente VARCHAR(30) = NULL,
    @IdInternoRadiologia VARCHAR(50) = NULL,
    @Estado VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @IdPaciente =
        NULLIF(LTRIM(RTRIM(@IdPaciente)), '');

    SET @IdInternoRadiologia =
        NULLIF(LTRIM(RTRIM(@IdInternoRadiologia)), '');

    SET @Estado =
        NULLIF(UPPER(LTRIM(RTRIM(@Estado))), '');


    /* ------------------------------------------------------------------------
       Validación de rango de fechas
       ------------------------------------------------------------------------ */

    IF @FechaInicio IS NOT NULL
       AND @FechaFin IS NOT NULL
       AND @FechaInicio > @FechaFin
    BEGIN
        THROW 50800,
              'La fecha inicial no puede ser posterior a la fecha final.',
              1;
    END;


    /* ------------------------------------------------------------------------
       Validación de estado
       ------------------------------------------------------------------------ */

    IF @Estado IS NOT NULL
       AND @Estado NOT IN ('PRESTADO', 'DEVUELTO')
    BEGIN
        THROW 50801,
              'Estado de préstamo no válido.',
              1;
    END;


    /* ------------------------------------------------------------------------
       Consulta
       ------------------------------------------------------------------------ */

    SELECT
        P.IdPrestamo,
        P.IdDetalleCita,

        P.FechaHoraPrestamo,
        P.FechaHoraDevolucion,

        CASE
            WHEN P.Estado = 'ACTIVO'
                THEN 'PRESTADO'
            ELSE 'DEVUELTO'
        END AS EstadoPrestamo,

        DATEDIFF
        (
            DAY,
            CAST(P.FechaHoraPrestamo AS DATE),
            CAST
            (
                COALESCE
                (
                    P.FechaHoraDevolucion,
                    SYSDATETIME()
                )
                AS DATE
            )
        ) AS DiasPrestamo,


        /* ID interno del estudio */

        IE.IdInternoRadiologia,


        /* Paciente */

        C.IdPaciente,

        LTRIM
        (
            RTRIM
            (
                CONCAT
                (
                    PAC.PrimerNombre,
                    ' ',

                    COALESCE
                    (
                        PAC.SegundoNombre + ' ',
                        ''
                    ),

                    PAC.PrimerApellido,

                    COALESCE
                    (
                        ' ' + PAC.SegundoApellido,
                        ''
                    )
                )
            )
        ) AS Paciente,


        /* Estudio */

        DC.IdPrueba,
        PR.NombrePrueba,

        ISNULL
        (
            PC.PartesCuerpo,
            ''
        ) AS PartesCuerpo,


        /* Prestatario */

        P.IdPrestatario,
        CP.NombreCompleto AS Prestatario,
        CP.Telefono AS TelefonoPrestatario,


        /* Datos del préstamo */

        P.MotivoPrestamo,
        P.Observaciones,

        P.UsuarioPrestamo,
        P.UsuarioDevolucion


    FROM dbo.PRESTAMO_ESTUDIO P


    INNER JOIN dbo.DETALLE_CITA DC
        ON DC.IdDetalleCita = P.IdDetalleCita


    INNER JOIN dbo.CITA C
        ON C.IdCita = DC.IdCita


    INNER JOIN dbo.CAT_PACIENTES PAC
        ON PAC.IdPaciente = C.IdPaciente


    INNER JOIN dbo.CAT_PRUEBAS PR
        ON PR.IdPrueba = DC.IdPrueba


    INNER JOIN dbo.CAT_PRESTATARIOS CP
        ON CP.IdPrestatario = P.IdPrestatario


    LEFT JOIN dbo.INFORME_ESTUDIO IE
        ON IE.IdDetalleCita = DC.IdDetalleCita


    OUTER APPLY
    (
        SELECT
            STRING_AGG
            (
                X.NombreParte,
                ', '
            )
            WITHIN GROUP
            (
                ORDER BY X.NombreParte
            ) AS PartesCuerpo

        FROM
        (
            SELECT
                PC2.NombreParte

            FROM dbo.DETALLE_CITA_PARTE_CUERPO DCP

            INNER JOIN dbo.CAT_PARTES_CUERPO PC2
                ON PC2.IdParteCuerpo =
                   DCP.IdParteCuerpo

            WHERE
                DCP.IdDetalleCita =
                DC.IdDetalleCita
        ) X

    ) PC


    WHERE

        /* Fecha inicial */

        (
            @FechaInicio IS NULL
            OR
            CAST(P.FechaHoraPrestamo AS DATE)
                >= @FechaInicio
        )


        /* Fecha final */

        AND
        (
            @FechaFin IS NULL
            OR
            CAST(P.FechaHoraPrestamo AS DATE)
                <= @FechaFin
        )


        /* ID paciente */

        AND
        (
            @IdPaciente IS NULL
            OR
            C.IdPaciente LIKE
                '%' + @IdPaciente + '%'
        )


        /* ID interno de radiología */

        AND
        (
            @IdInternoRadiologia IS NULL
            OR
            IE.IdInternoRadiologia LIKE
                '%' + @IdInternoRadiologia + '%'
        )


        /* Estado */

        AND
        (
            @Estado IS NULL

            OR
            (
                @Estado = 'PRESTADO'
                AND
                P.Estado = 'ACTIVO'
            )

            OR
            (
                @Estado = 'DEVUELTO'
                AND
                P.Estado = 'DEVUELTO'
            )
        )


    ORDER BY
        P.FechaHoraPrestamo DESC,
        P.IdPrestamo DESC;

END;
GO



/* ============================================================================
   2. ÍNDICE PARA EL HISTORIAL
   ============================================================================ */

IF NOT EXISTS
(
    SELECT 1

    FROM sys.indexes

    WHERE
        object_id =
            OBJECT_ID(N'dbo.PRESTAMO_ESTUDIO')

        AND name =
            N'IX_PRESTAMO_ESTUDIO_HistorialFecha'
)
BEGIN

    CREATE INDEX IX_PRESTAMO_ESTUDIO_HistorialFecha

        ON dbo.PRESTAMO_ESTUDIO
        (
            FechaHoraPrestamo DESC,
            Estado
        )

        INCLUDE
        (
            IdDetalleCita,
            IdPrestatario,
            FechaHoraDevolucion,
            UsuarioPrestamo,
            UsuarioDevolucion
        );

END;
GO



/* ============================================================================
   3. VERIFICACIÓN
   ============================================================================ */

SELECT

    ListadoHistorial =
        CASE

            WHEN OBJECT_ID
            (
                N'dbo.sp_Prestamo_Listar',
                N'P'
            ) IS NOT NULL

            THEN 'OK'

            ELSE 'FALTA'

        END,


    IndiceHistorial =
        CASE

            WHEN EXISTS
            (
                SELECT 1

                FROM sys.indexes

                WHERE
                    object_id =
                        OBJECT_ID
                        (
                            N'dbo.PRESTAMO_ESTUDIO'
                        )

                    AND name =
                        N'IX_PRESTAMO_ESTUDIO_HistorialFecha'
            )

            THEN 'OK'

            ELSE 'FALTA'

        END;

GO


PRINT 'Requerimiento 5 - Fase 2 instalada correctamente.';
PRINT 'El módulo Préstamos ahora incluye activos y devueltos.';
GO