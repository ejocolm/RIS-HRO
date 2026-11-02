USE RIS_HRO;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ============================================================================
   RIS_HRO - HOTFIX REQUERIMIENTO 5
   SOLO PRESTAR ESTUDIOS CON IdInternoRadiologia

   REGLA:
   - Un estudio REALIZADO sin IdInternoRadiologia NO puede prestarse.
   - La UI lo bloquea.
   - El servidor lo bloquea.
   - SQL Server también lo bloquea para evitar préstamos por URL o llamadas
     directas.
   ============================================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_Prestamo_Crear
    @IdDetalleCita INT,
    @IdPrestatario VARCHAR(30),
    @MotivoPrestamo VARCHAR(250),
    @Observaciones VARCHAR(500) = NULL,
    @UsuarioPrestamo VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @IdPrestatario = NULLIF(LTRIM(RTRIM(@IdPrestatario)), '');
    SET @MotivoPrestamo = NULLIF(LTRIM(RTRIM(@MotivoPrestamo)), '');
    SET @Observaciones = NULLIF(LTRIM(RTRIM(@Observaciones)), '');

    IF @IdPrestatario IS NULL
        THROW 50710, 'Debe seleccionar un prestatario.', 1;

    IF @MotivoPrestamo IS NULL
        THROW 50711, 'El motivo del préstamo es obligatorio.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.DETALLE_CITA DC
        INNER JOIN dbo.CITA C
            ON C.IdCita = DC.IdCita
        WHERE DC.IdDetalleCita = @IdDetalleCita
          AND DC.Estado = 'REALIZADO'
          AND C.Activo = 1
    )
        THROW 50712, 'El estudio no existe o no se encuentra REALIZADO.', 1;

    /* Un préstamo necesita una identificación interna inequívoca del estudio. */
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.INFORME_ESTUDIO IE
        WHERE IE.IdDetalleCita = @IdDetalleCita
          AND NULLIF(LTRIM(RTRIM(IE.IdInternoRadiologia)), '') IS NOT NULL
    )
    BEGIN
        THROW 50716,
              'El estudio no puede prestarse porque aún no tiene un ID interno de radiología.',
              1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.CAT_PRESTATARIOS
        WHERE IdPrestatario = @IdPrestatario
          AND Activo = 1
    )
        THROW 50713, 'El prestatario no existe o se encuentra inactivo.', 1;

    BEGIN TRY
        INSERT dbo.PRESTAMO_ESTUDIO
        (
            IdDetalleCita,
            IdPrestatario,
            MotivoPrestamo,
            Observaciones,
            UsuarioPrestamo
        )
        VALUES
        (
            @IdDetalleCita,
            @IdPrestatario,
            @MotivoPrestamo,
            @Observaciones,
            @UsuarioPrestamo
        );

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS IdPrestamo;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() IN (2601, 2627)
            THROW 50714,
                  'Este estudio ya posee un préstamo activo y no puede prestarse nuevamente hasta registrar la devolución.',
                  1;

        THROW;
    END CATCH;
END;
GO


/* ============================================================================
   VERIFICACIÓN
   ============================================================================ */
SELECT
    PrestamoCrear =
        CASE WHEN OBJECT_ID(N'dbo.sp_Prestamo_Crear', N'P') IS NOT NULL
             THEN 'OK' ELSE 'FALTA' END;
GO

PRINT 'Hotfix aplicado: solo pueden prestarse estudios con IdInternoRadiologia.';
GO
