USE RIS_HRO;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ============================================================================
   RIS_HRO - REQUERIMIENTO 2 - FASE 2
   Flujo de atención por estudio y trazabilidad

   PRERREQUISITO
   Haber ejecutado correctamente:
       07_REQUERIMIENTO_2_FASE1_BASE_DATOS.sql

   REGLAS IMPLEMENTADAS
   1. Una cita PROGRAMADA pasa a ATENDIDA mediante selección explícita de estudios.
   2. Los estudios seleccionados pasan a REALIZADO.
   3. Los estudios no seleccionados pasan a NO_REALIZADO.
   4. Cada cambio queda registrado en HISTORIAL_ESTADO_DETALLE_CITA.
   5. Luego de atender la cita se puede corregir REALIZADO <-> NO_REALIZADO.
   6. No se permite pasar un estudio a NO_REALIZADO si ya posee un informe.
   7. CANCELADA y NO_ASISTIO continúan cancelando los estudios pendientes.
   8. sp_Cita_Obtener expone datos básicos del informe para las siguientes fases.
   ============================================================================ */


/* ============================================================================
   1. TVP PARA INDICAR ESTUDIOS REALIZADOS
   ============================================================================ */
IF TYPE_ID(N'dbo.TVP_DetalleCitaRealizado') IS NULL
BEGIN
    EXEC(N'
        CREATE TYPE dbo.TVP_DetalleCitaRealizado AS TABLE
        (
            IdDetalleCita INT NOT NULL PRIMARY KEY
        );
    ');
END;
GO


/* ============================================================================
   2. MARCAR CITA COMO ATENDIDA
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.sp_Cita_MarcarAtendida
    @IdCita INT,
    @IdUsuario VARCHAR(30),
    @EstudiosRealizados dbo.TVP_DetalleCitaRealizado READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.CAT_USUARIOS
        WHERE IdUsuario = @IdUsuario
          AND Activo = 1
    )
        THROW 50300, 'El usuario no existe o se encuentra inactivo.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.CITA
        WHERE IdCita = @IdCita
          AND Activo = 1
    )
        THROW 50301, 'La cita no existe.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.CITA
        WHERE IdCita = @IdCita
          AND Activo = 1
          AND Estado = 'PROGRAMADA'
    )
        THROW 50302, 'Solo una cita PROGRAMADA puede marcarse como ATENDIDA.', 1;

    /* Todos los IDs seleccionados deben pertenecer a la cita y estar pendientes. */
    IF EXISTS
    (
        SELECT 1
        FROM @EstudiosRealizados ER
        LEFT JOIN dbo.DETALLE_CITA DC
          ON DC.IdDetalleCita = ER.IdDetalleCita
         AND DC.IdCita = @IdCita
         AND DC.Estado = 'PENDIENTE'
        WHERE DC.IdDetalleCita IS NULL
    )
        THROW 50303, 'Uno o más estudios seleccionados no pertenecen a la cita o ya no están pendientes.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        /* Registrar el estado que recibirá cada estudio pendiente. */
        INSERT dbo.HISTORIAL_ESTADO_DETALLE_CITA
        (
            IdDetalleCita,
            EstadoAnterior,
            EstadoNuevo,
            IdUsuario,
            Observacion
        )
        SELECT
            DC.IdDetalleCita,
            DC.Estado,
            CASE
                WHEN ER.IdDetalleCita IS NOT NULL THEN 'REALIZADO'
                ELSE 'NO_REALIZADO'
            END,
            @IdUsuario,
            'Registro de estudios realizados al marcar la cita como ATENDIDA.'
        FROM dbo.DETALLE_CITA DC
        LEFT JOIN @EstudiosRealizados ER
          ON ER.IdDetalleCita = DC.IdDetalleCita
        WHERE DC.IdCita = @IdCita
          AND DC.Estado = 'PENDIENTE';

        /* Aplicar estados por estudio. */
        UPDATE DC
        SET Estado =
            CASE
                WHEN ER.IdDetalleCita IS NOT NULL THEN 'REALIZADO'
                ELSE 'NO_REALIZADO'
            END
        FROM dbo.DETALLE_CITA DC
        LEFT JOIN @EstudiosRealizados ER
          ON ER.IdDetalleCita = DC.IdDetalleCita
        WHERE DC.IdCita = @IdCita
          AND DC.Estado = 'PENDIENTE';

        /* Finalmente marcar la cita como atendida. */
        UPDATE dbo.CITA
        SET Estado = 'ATENDIDA',
            IdUsuarioModificacion = @IdUsuario,
            FechaModificacion = SYSDATETIME()
        WHERE IdCita = @IdCita
          AND Activo = 1
          AND Estado = 'PROGRAMADA';

        COMMIT;

        SELECT
            C.IdCita,
            C.NumeroCita,
            C.Estado
        FROM dbo.CITA C
        WHERE C.IdCita = @IdCita;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO


/* ============================================================================
   3. CORREGIR ESTADO DE REALIZACIÓN DE UN ESTUDIO
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.sp_DetalleCita_CambiarRealizacion
    @IdDetalleCita INT,
    @NuevoEstado VARCHAR(20),
    @IdUsuario VARCHAR(30),
    @Observacion VARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @NuevoEstado NOT IN ('REALIZADO','NO_REALIZADO')
        THROW 50310, 'El nuevo estado debe ser REALIZADO o NO_REALIZADO.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.CAT_USUARIOS
        WHERE IdUsuario = @IdUsuario
          AND Activo = 1
    )
        THROW 50311, 'El usuario no existe o se encuentra inactivo.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.DETALLE_CITA DC
        INNER JOIN dbo.CITA C
          ON C.IdCita = DC.IdCita
        WHERE DC.IdDetalleCita = @IdDetalleCita
          AND C.Activo = 1
          AND C.Estado = 'ATENDIDA'
    )
        THROW 50312, 'El estudio no pertenece a una cita ATENDIDA.', 1;

    DECLARE @EstadoAnterior VARCHAR(20);

    SELECT @EstadoAnterior = DC.Estado
    FROM dbo.DETALLE_CITA DC
    WHERE DC.IdDetalleCita = @IdDetalleCita;

    IF @EstadoAnterior NOT IN ('REALIZADO','NO_REALIZADO')
        THROW 50313, 'Solo se puede corregir un estudio REALIZADO o NO_REALIZADO.', 1;

    IF @EstadoAnterior = @NuevoEstado
        RETURN;

    /* Protección clínica:
       un estudio con informe no puede pasar a NO_REALIZADO. */
    IF @NuevoEstado = 'NO_REALIZADO'
       AND EXISTS
       (
           SELECT 1
           FROM dbo.INFORME_ESTUDIO
           WHERE IdDetalleCita = @IdDetalleCita
       )
        THROW 50314, 'No puede marcarse como NO_REALIZADO porque el estudio ya posee un informe.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT dbo.HISTORIAL_ESTADO_DETALLE_CITA
        (
            IdDetalleCita,
            EstadoAnterior,
            EstadoNuevo,
            IdUsuario,
            Observacion
        )
        VALUES
        (
            @IdDetalleCita,
            @EstadoAnterior,
            @NuevoEstado,
            @IdUsuario,
            NULLIF(LTRIM(RTRIM(@Observacion)), '')
        );

        UPDATE dbo.DETALLE_CITA
        SET Estado = @NuevoEstado
        WHERE IdDetalleCita = @IdDetalleCita;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO


/* ============================================================================
   4. HISTORIAL DE ESTADOS DE UN ESTUDIO
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.sp_DetalleCita_HistorialEstado
    @IdDetalleCita INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        H.IdHistorialEstado,
        H.IdDetalleCita,
        H.EstadoAnterior,
        H.EstadoNuevo,
        H.IdUsuario,
        U.NombreCompleto AS Usuario,
        H.FechaHoraCambio,
        H.Observacion
    FROM dbo.HISTORIAL_ESTADO_DETALLE_CITA H
    INNER JOIN dbo.CAT_USUARIOS U
      ON U.IdUsuario = H.IdUsuario
    WHERE H.IdDetalleCita = @IdDetalleCita
    ORDER BY H.FechaHoraCambio DESC, H.IdHistorialEstado DESC;
END;
GO


/* ============================================================================
   5. CAMBIAR ESTADO GENERAL DE LA CITA
   ATENDIDA ahora usa sp_Cita_MarcarAtendida.
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.sp_Cita_CambiarEstado
    @IdCita INT,
    @Estado VARCHAR(20),
    @IdUsuario VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Estado NOT IN ('PROGRAMADA','ATENDIDA','CANCELADA','NO_ASISTIO')
        THROW 50040, 'Estado inválido.', 1;

    IF @Estado = 'ATENDIDA'
        THROW 50320, 'Para marcar una cita como ATENDIDA debe seleccionar los estudios realizados.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.CITA
        WHERE IdCita = @IdCita
          AND Activo = 1
    )
        THROW 50041, 'La cita no existe.', 1;

    IF @Estado <> 'PROGRAMADA'
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.CITA
           WHERE IdCita = @IdCita
             AND Activo = 1
             AND Estado = 'PROGRAMADA'
       )
        THROW 50042, 'La cita ya no se encuentra en estado PROGRAMADA.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.CITA
        SET Estado = @Estado,
            IdUsuarioModificacion = @IdUsuario,
            FechaModificacion = SYSDATETIME()
        WHERE IdCita = @IdCita
          AND Activo = 1;

        IF @Estado IN ('CANCELADA','NO_ASISTIO')
        BEGIN
            INSERT dbo.HISTORIAL_ESTADO_DETALLE_CITA
            (
                IdDetalleCita,
                EstadoAnterior,
                EstadoNuevo,
                IdUsuario,
                Observacion
            )
            SELECT
                DC.IdDetalleCita,
                DC.Estado,
                'CANCELADO',
                @IdUsuario,
                CASE
                    WHEN @Estado = 'CANCELADA'
                        THEN 'Estudio cancelado por cancelación de la cita.'
                    ELSE 'Estudio cancelado porque el paciente no asistió.'
                END
            FROM dbo.DETALLE_CITA DC
            WHERE DC.IdCita = @IdCita
              AND DC.Estado = 'PENDIENTE';

            UPDATE dbo.DETALLE_CITA
            SET Estado = 'CANCELADO'
            WHERE IdCita = @IdCita
              AND Estado = 'PENDIENTE';
        END;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO


/* ============================================================================
   6. OBTENER CITA
   Se agregan al resultset de estudios:
   - IdInforme
   - EstadoInforme
   - NumeroVersionInforme
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.sp_Cita_Obtener
    @IdCita INT
AS
BEGIN
    SET NOCOUNT ON;

    /* Resultset 1: cabecera */
    SELECT
        C.IdCita,
        C.NumeroCita,
        C.IdPaciente,
        CONCAT(
            P.PrimerNombre,' ',
            COALESCE(P.SegundoNombre+' ',''),
            P.PrimerApellido,
            COALESCE(' '+P.SegundoApellido,'')
        ) AS Paciente,
        C.IdMedico,
        CONCAT(M.Nombres,' ',M.Apellidos) AS Medico,
        C.IdServicio,
        S.NombreServicio AS Servicio,
        C.FechaCita,
        C.HoraCita,
        C.Estado,
        C.Observaciones,
        U.NombreCompleto AS UsuarioCreacion,
        C.FechaCreacion
    FROM dbo.CITA C
    INNER JOIN dbo.CAT_PACIENTES P
      ON P.IdPaciente = C.IdPaciente
    INNER JOIN dbo.CAT_MEDICOS M
      ON M.IdMedico = C.IdMedico
    INNER JOIN dbo.CAT_SERVICIOS_HOSPITALARIOS S
      ON S.IdServicio = C.IdServicio
    INNER JOIN dbo.CAT_USUARIOS U
      ON U.IdUsuario = C.IdUsuarioCreacion
    WHERE C.IdCita = @IdCita
      AND C.Activo = 1;

    /* Resultset 2: estudios */
    SELECT
        DC.IdDetalleCita,
        DC.IdPrueba,
        P.NombrePrueba,
        CAT.NombreCategoria,
        DC.IdTecnico,
        CASE
            WHEN T.IdTecnico IS NULL THEN NULL
            ELSE CONCAT(T.Nombres,' ',T.Apellidos)
        END AS Tecnico,
        DC.Estado,
        ISNULL(PC.PartesCuerpo,'') AS PartesCuerpo,

        IE.IdInforme,
        IE.Estado AS EstadoInforme,
        IE.NumeroVersion AS NumeroVersionInforme
    FROM dbo.DETALLE_CITA DC
    INNER JOIN dbo.CAT_PRUEBAS P
      ON P.IdPrueba = DC.IdPrueba
    INNER JOIN dbo.CAT_CATEGORIAS_PRUEBAS CAT
      ON CAT.IdCategoria = P.IdCategoria
    LEFT JOIN dbo.CAT_TECNICOS_RADIOLOGOS T
      ON T.IdTecnico = DC.IdTecnico
    LEFT JOIN dbo.INFORME_ESTUDIO IE
      ON IE.IdDetalleCita = DC.IdDetalleCita
    OUTER APPLY
    (
        SELECT STRING_AGG(X.NombreParte, ', ')
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
    WHERE DC.IdCita = @IdCita
    ORDER BY P.NombrePrueba;

    /* Resultset 3: partes del cuerpo */
    SELECT
        DCP.IdDetalleCita,
        DCP.IdParteCuerpo,
        PC.NombreParte
    FROM dbo.DETALLE_CITA_PARTE_CUERPO DCP
    INNER JOIN dbo.DETALLE_CITA DC
      ON DC.IdDetalleCita = DCP.IdDetalleCita
    INNER JOIN dbo.CAT_PARTES_CUERPO PC
      ON PC.IdParteCuerpo = DCP.IdParteCuerpo
    WHERE DC.IdCita = @IdCita
    ORDER BY DCP.IdDetalleCita, PC.NombreParte;
END;
GO


/* ============================================================================
   7. VERIFICACIÓN
   ============================================================================ */
SELECT
    TipoSeleccionRealizados =
        CASE WHEN TYPE_ID(N'dbo.TVP_DetalleCitaRealizado') IS NOT NULL
             THEN 'OK' ELSE 'FALTA' END,

    MarcarAtendida =
        CASE WHEN OBJECT_ID(N'dbo.sp_Cita_MarcarAtendida', N'P') IS NOT NULL
             THEN 'OK' ELSE 'FALTA' END,

    CambiarRealizacion =
        CASE WHEN OBJECT_ID(N'dbo.sp_DetalleCita_CambiarRealizacion', N'P') IS NOT NULL
             THEN 'OK' ELSE 'FALTA' END,

    HistorialEstado =
        CASE WHEN OBJECT_ID(N'dbo.sp_DetalleCita_HistorialEstado', N'P') IS NOT NULL
             THEN 'OK' ELSE 'FALTA' END,

    CambiarEstadoCita =
        CASE WHEN OBJECT_ID(N'dbo.sp_Cita_CambiarEstado', N'P') IS NOT NULL
             THEN 'OK' ELSE 'FALTA' END,

    ObtenerCita =
        CASE WHEN OBJECT_ID(N'dbo.sp_Cita_Obtener', N'P') IS NOT NULL
             THEN 'OK' ELSE 'FALTA' END;
GO

PRINT 'Requerimiento 2 - Fase 2 SQL instalada correctamente.';
GO
