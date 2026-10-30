USE RIS_HRO;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


/* ============================================================================
   RIS_HRO
   REQUERIMIENTO 6 - FASE 1
   SOLICITUDES DEL DÍA Y ESTUDIOS MÓVILES

   TipoRegistro:
       CITA
       SOLICITUD_DIA

   EsMovil:
       0 = No
       1 = Sí

   REGLAS:
   - Los registros existentes permanecen como CITA.
   - Una SOLICITUD_DIA no consume capacidad de agenda.
   - Una CITA normal sí continúa validando capacidad.
   - EsMovil solamente puede marcarse en SOLICITUD_DIA.
   ============================================================================ */


/* ============================================================================
   1. NUEVOS CAMPOS EN CITA
   ============================================================================ */

IF COL_LENGTH('dbo.CITA', 'TipoRegistro') IS NULL
BEGIN
    ALTER TABLE dbo.CITA
    ADD TipoRegistro VARCHAR(20) NOT NULL
        CONSTRAINT DF_CITA_TipoRegistro
        DEFAULT ('CITA')
        WITH VALUES;
END;
GO


IF COL_LENGTH('dbo.CITA', 'EsMovil') IS NULL
BEGIN
    ALTER TABLE dbo.CITA
    ADD EsMovil BIT NOT NULL
        CONSTRAINT DF_CITA_EsMovil
        DEFAULT (0)
        WITH VALUES;
END;
GO


/* ============================================================================
   2. RESTRICCIONES
   ============================================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE name = 'CK_CITA_TipoRegistro'
      AND parent_object_id = OBJECT_ID('dbo.CITA')
)
BEGIN
    ALTER TABLE dbo.CITA
    WITH CHECK ADD CONSTRAINT CK_CITA_TipoRegistro
    CHECK
    (
        TipoRegistro IN
        (
            'CITA',
            'SOLICITUD_DIA'
        )
    );
END;
GO


IF NOT EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE name = 'CK_CITA_MovilSoloSolicitud'
      AND parent_object_id = OBJECT_ID('dbo.CITA')
)
BEGIN
    ALTER TABLE dbo.CITA
    WITH CHECK ADD CONSTRAINT CK_CITA_MovilSoloSolicitud
    CHECK
    (
        TipoRegistro = 'SOLICITUD_DIA'
        OR EsMovil = 0
    );
END;
GO


/* ============================================================================
   3. ÍNDICE PARA FUTUROS FILTROS
   ============================================================================ */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.CITA')
      AND name = 'IX_CITA_TipoRegistro_Fecha'
)
BEGIN
    CREATE INDEX IX_CITA_TipoRegistro_Fecha
    ON dbo.CITA
    (
        TipoRegistro,
        FechaCita
    )
    INCLUDE
    (
        EsMovil,
        Estado,
        IdPaciente,
        IdServicio
    );
END;
GO


/* ============================================================================
   4. LISTADO DE CITAS / SOLICITUDES

   Los parámetros nuevos tienen valor por defecto para no romper las llamadas
   actuales de C#.
   ============================================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_Cita_Listar
    @FechaInicio DATE = NULL,
    @FechaFin DATE = NULL,
    @Paciente VARCHAR(100) = NULL,
    @Estado VARCHAR(20) = NULL,
    @TipoRegistro VARCHAR(20) = NULL,
    @EsMovil BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @Paciente =
        NULLIF(LTRIM(RTRIM(@Paciente)), '');

    SET @Estado =
        NULLIF(UPPER(LTRIM(RTRIM(@Estado))), '');

    SET @TipoRegistro =
        NULLIF(UPPER(LTRIM(RTRIM(@TipoRegistro))), '');


    IF @TipoRegistro IS NOT NULL
       AND @TipoRegistro NOT IN
       (
           'CITA',
           'SOLICITUD_DIA'
       )
    BEGIN
        THROW 50900,
              'Tipo de registro no válido.',
              1;
    END;


    SELECT
        C.IdCita,
        C.NumeroCita,
        C.FechaCita,
        C.HoraCita,

        C.IdPaciente,

        CONCAT
        (
            P.PrimerNombre,
            ' ',
            COALESCE(P.SegundoNombre + ' ', ''),
            P.PrimerApellido,
            COALESCE(' ' + P.SegundoApellido, '')
        ) AS Paciente,

        CONCAT
        (
            M.Nombres,
            ' ',
            M.Apellidos
        ) AS Medico,

        S.NombreServicio AS Servicio,

        ISNULL(E.Estudios, '') AS Estudios,

        C.Estado,

        C.TipoRegistro,
        C.EsMovil

    FROM dbo.CITA C

    INNER JOIN dbo.CAT_PACIENTES P
        ON P.IdPaciente = C.IdPaciente

    INNER JOIN dbo.CAT_MEDICOS M
        ON M.IdMedico = C.IdMedico

    INNER JOIN dbo.CAT_SERVICIOS_HOSPITALARIOS S
        ON S.IdServicio = C.IdServicio

    OUTER APPLY
    (
        SELECT
            STRING_AGG
            (
                PR.NombrePrueba,
                ', '
            ) AS Estudios

        FROM dbo.DETALLE_CITA DC

        INNER JOIN dbo.CAT_PRUEBAS PR
            ON PR.IdPrueba = DC.IdPrueba

        WHERE DC.IdCita = C.IdCita
    ) E

    WHERE
        C.Activo = 1

        AND
        (
            @FechaInicio IS NULL
            OR C.FechaCita >= @FechaInicio
        )

        AND
        (
            @FechaFin IS NULL
            OR C.FechaCita <= @FechaFin
        )

        AND
        (
            @Estado IS NULL
            OR C.Estado = @Estado
        )

        AND
        (
            @Paciente IS NULL

            OR C.IdPaciente LIKE
               '%' + @Paciente + '%'

            OR CONCAT
            (
                P.PrimerNombre,
                ' ',
                COALESCE(P.SegundoNombre + ' ', ''),
                P.PrimerApellido,
                ' ',
                COALESCE(P.SegundoApellido, '')
            )
            LIKE '%' + @Paciente + '%'
        )

        AND
        (
            @TipoRegistro IS NULL
            OR C.TipoRegistro = @TipoRegistro
        )

        AND
        (
            @EsMovil IS NULL
            OR C.EsMovil = @EsMovil
        )

    ORDER BY
        C.FechaCita DESC,
        C.HoraCita DESC;
END;
GO


/* ============================================================================
   5. OBTENER CITA / SOLICITUD

   Conserva los campos de INFORME_ESTUDIO agregados en el Req. 2.
   ============================================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_Cita_Obtener
    @IdCita INT
AS
BEGIN
    SET NOCOUNT ON;


    /* ------------------------------------------------------------------------
       Resultset 1: cabecera
       ------------------------------------------------------------------------ */

    SELECT
        C.IdCita,
        C.NumeroCita,
        C.IdPaciente,

        CONCAT
        (
            P.PrimerNombre,
            ' ',
            COALESCE(P.SegundoNombre + ' ', ''),
            P.PrimerApellido,
            COALESCE(' ' + P.SegundoApellido, '')
        ) AS Paciente,

        C.IdMedico,

        CONCAT
        (
            M.Nombres,
            ' ',
            M.Apellidos
        ) AS Medico,

        C.IdServicio,
        S.NombreServicio AS Servicio,

        C.FechaCita,
        C.HoraCita,

        C.Estado,

        C.TipoRegistro,
        C.EsMovil,

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

    WHERE
        C.IdCita = @IdCita
        AND C.Activo = 1;


    /* ------------------------------------------------------------------------
       Resultset 2: estudios + informe
       ------------------------------------------------------------------------ */

    SELECT
        DC.IdDetalleCita,
        DC.IdPrueba,

        P.NombrePrueba,
        CAT.NombreCategoria,

        DC.IdTecnico,

        CASE
            WHEN T.IdTecnico IS NULL
                THEN NULL
            ELSE CONCAT
            (
                T.Nombres,
                ' ',
                T.Apellidos
            )
        END AS Tecnico,

        DC.Estado,

        ISNULL
        (
            PC.PartesCuerpo,
            ''
        ) AS PartesCuerpo,

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
                CP.NombreParte

            FROM dbo.DETALLE_CITA_PARTE_CUERPO DCP

            INNER JOIN dbo.CAT_PARTES_CUERPO CP
                ON CP.IdParteCuerpo =
                   DCP.IdParteCuerpo

            WHERE
                DCP.IdDetalleCita =
                DC.IdDetalleCita
        ) X
    ) PC

    WHERE DC.IdCita = @IdCita

    ORDER BY P.NombrePrueba;


    /* ------------------------------------------------------------------------
       Resultset 3: partes del cuerpo
       ------------------------------------------------------------------------ */

    SELECT
        DCP.IdDetalleCita,
        DCP.IdParteCuerpo,
        PC.NombreParte

    FROM dbo.DETALLE_CITA_PARTE_CUERPO DCP

    INNER JOIN dbo.DETALLE_CITA DC
        ON DC.IdDetalleCita =
           DCP.IdDetalleCita

    INNER JOIN dbo.CAT_PARTES_CUERPO PC
        ON PC.IdParteCuerpo =
           DCP.IdParteCuerpo

    WHERE DC.IdCita = @IdCita

    ORDER BY
        DCP.IdDetalleCita,
        PC.NombreParte;
END;
GO


/* ============================================================================
   6. CREAR CITA / SOLICITUD DEL DÍA
   ============================================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_Cita_Crear
    @IdPaciente VARCHAR(30),
    @IdMedico VARCHAR(30),
    @IdServicio VARCHAR(30),

    @FechaCita DATE,
    @HoraCita TIME(0),

    @Observaciones VARCHAR(500) = NULL,

    @IdUsuario VARCHAR(30),

    @Estudios dbo.TVP_EstudioCita READONLY,
    @EstudioPartes dbo.TVP_EstudioParteCuerpo READONLY,

    @TipoRegistro VARCHAR(20) = 'CITA',
    @EsMovil BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET DATEFIRST 1;

    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;


    SET @TipoRegistro =
        UPPER
        (
            LTRIM
            (
                RTRIM
                (
                    ISNULL
                    (
                        @TipoRegistro,
                        'CITA'
                    )
                )
            )
        );


    /* ------------------------------------------------------------------------
       Validar tipo
       ------------------------------------------------------------------------ */

    IF @TipoRegistro NOT IN
    (
        'CITA',
        'SOLICITUD_DIA'
    )
    BEGIN
        THROW 50901,
              'Tipo de registro no válido.',
              1;
    END;


    IF @TipoRegistro = 'CITA'
       AND @EsMovil = 1
    BEGIN
        THROW 50902,
              'Solo las solicitudes del día pueden marcarse como móviles.',
              1;
    END;


    /* ------------------------------------------------------------------------
       Validaciones generales
       ------------------------------------------------------------------------ */

    IF NOT EXISTS
    (
        SELECT 1
        FROM @Estudios
    )
    BEGIN
        THROW 50001,
              'Debe agregar por lo menos un estudio.',
              1;
    END;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.CAT_PACIENTES
        WHERE IdPaciente = @IdPaciente
          AND Activo = 1
    )
    BEGIN
        THROW 50001,
              'Paciente inexistente o inactivo.',
              1;
    END;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.CAT_MEDICOS
        WHERE IdMedico = @IdMedico
          AND Activo = 1
    )
    BEGIN
        THROW 50001,
              'Médico inexistente o inactivo.',
              1;
    END;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.CAT_SERVICIOS_HOSPITALARIOS
        WHERE IdServicio = @IdServicio
          AND Activo = 1
    )
    BEGIN
        THROW 50001,
              'Servicio inexistente o inactivo.',
              1;
    END;


    /* Cada estudio requiere una parte del cuerpo */

    IF EXISTS
    (
        SELECT 1

        FROM @Estudios E

        WHERE NOT EXISTS
        (
            SELECT 1

            FROM @EstudioPartes EP

            WHERE
                EP.IdPrueba =
                E.IdPrueba
        )
    )
    BEGIN
        THROW 50001,
              'Debe seleccionar por lo menos una parte del cuerpo para cada estudio.',
              1;
    END;


    /* No aceptar partes para estudios ajenos */

    IF EXISTS
    (
        SELECT 1

        FROM @EstudioPartes EP

        WHERE NOT EXISTS
        (
            SELECT 1

            FROM @Estudios E

            WHERE
                E.IdPrueba =
                EP.IdPrueba
        )
    )
    BEGIN
        THROW 50001,
              'Se recibió una parte del cuerpo para un estudio que no pertenece a la cita.',
              1;
    END;


    /* Partes activas */

    IF EXISTS
    (
        SELECT 1

        FROM @EstudioPartes EP

        LEFT JOIN dbo.CAT_PARTES_CUERPO PC
            ON PC.IdParteCuerpo =
               EP.IdParteCuerpo

           AND PC.Activo = 1

        WHERE
            PC.IdParteCuerpo IS NULL
    )
    BEGIN
        THROW 50001,
              'Una o más partes del cuerpo no existen o están inactivas.',
              1;
    END;


    BEGIN TRY

        BEGIN TRANSACTION;


        /* ====================================================================
           SOLO LAS CITAS PROGRAMADAS VALIDAN CAPACIDAD
           ==================================================================== */

        IF @TipoRegistro = 'CITA'
        BEGIN

            DECLARE @Dia TINYINT =
                DATEPART
                (
                    WEEKDAY,
                    @FechaCita
                );


            IF EXISTS
            (
                SELECT 1

                FROM @Estudios E

                LEFT JOIN dbo.CAPACIDAD CAP
                    WITH
                    (
                        UPDLOCK,
                        HOLDLOCK
                    )

                    ON CAP.IdPrueba =
                       E.IdPrueba

                   AND CAP.DiaSemana =
                       @Dia

                   AND CAP.Activo = 1

                WHERE
                    CAP.IdCapacidad IS NULL
            )
            BEGIN
                THROW 50001,
                      'Uno o más estudios no tienen capacidad configurada para el día seleccionado.',
                      1;
            END;


            IF EXISTS
            (
                SELECT 1

                FROM @Estudios E

                INNER JOIN dbo.CAPACIDAD CAP
                    WITH
                    (
                        UPDLOCK,
                        HOLDLOCK
                    )

                    ON CAP.IdPrueba =
                       E.IdPrueba

                   AND CAP.DiaSemana =
                       @Dia

                   AND CAP.Activo = 1

                OUTER APPLY
                (
                    SELECT
                        COUNT(*) AS Utilizados

                    FROM dbo.DETALLE_CITA DC

                    INNER JOIN dbo.CITA C
                        ON C.IdCita =
                           DC.IdCita

                    WHERE
                        DC.IdPrueba =
                        E.IdPrueba

                        AND C.FechaCita =
                            @FechaCita

                        AND C.Activo = 1

                        /* Solicitudes del día NO consumen cupo */
                        AND C.TipoRegistro = 'CITA'

                        AND C.Estado <>
                            'CANCELADA'

                        AND DC.Estado <>
                            'CANCELADO'
                ) U

                WHERE
                    ISNULL
                    (
                        U.Utilizados,
                        0
                    )
                    >=
                    CAP.CantidadMaxima
            )
            BEGIN
                THROW 50001,
                      'No existe cupo disponible para uno o más estudios seleccionados.',
                      1;
            END;

        END;


        /* --------------------------------------------------------------------
           Insertar encabezado
           -------------------------------------------------------------------- */

        DECLARE @Tmp VARCHAR(30) =
            CONCAT
            (
                'TMP-',
                REPLACE
                (
                    CONVERT
                    (
                        VARCHAR(36),
                        NEWID()
                    ),
                    '-',
                    ''
                )
            );


        INSERT dbo.CITA
        (
            NumeroCita,
            IdPaciente,
            IdMedico,
            IdServicio,
            FechaCita,
            HoraCita,

            Estado,

            TipoRegistro,
            EsMovil,

            Observaciones,
            IdUsuarioCreacion
        )
        VALUES
        (
            @Tmp,
            @IdPaciente,
            @IdMedico,
            @IdServicio,
            @FechaCita,
            @HoraCita,

            'PROGRAMADA',

            @TipoRegistro,
            @EsMovil,

            @Observaciones,
            @IdUsuario
        );


        DECLARE @IdCita INT =
            SCOPE_IDENTITY();


        DECLARE @Numero VARCHAR(30) =
            CONCAT
            (
                'RAD-',
                YEAR(@FechaCita),
                '-',
                RIGHT
                (
                    '000000'
                    +
                    CAST
                    (
                        @IdCita
                        AS VARCHAR(6)
                    ),
                    6
                )
            );


        UPDATE dbo.CITA

        SET NumeroCita =
            @Numero

        WHERE IdCita =
            @IdCita;


        /* --------------------------------------------------------------------
           Estudios
           -------------------------------------------------------------------- */

        INSERT dbo.DETALLE_CITA
        (
            IdCita,
            IdPrueba,
            Estado
        )

        SELECT
            @IdCita,
            E.IdPrueba,
            'PENDIENTE'

        FROM @Estudios E;


        /* --------------------------------------------------------------------
           Partes del cuerpo
           -------------------------------------------------------------------- */

        INSERT dbo.DETALLE_CITA_PARTE_CUERPO
        (
            IdDetalleCita,
            IdParteCuerpo
        )

        SELECT
            DC.IdDetalleCita,
            EP.IdParteCuerpo

        FROM @EstudioPartes EP

        INNER JOIN dbo.DETALLE_CITA DC
            ON DC.IdCita =
               @IdCita

           AND DC.IdPrueba =
               EP.IdPrueba;


        COMMIT;


        SELECT
            @IdCita AS IdCita,
            @Numero AS NumeroCita;

    END TRY

    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK;

        THROW;

    END CATCH;

END;
GO


/* ============================================================================
   7. ACTUALIZAR CITA / SOLICITUD
   ============================================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_Cita_Actualizar
    @IdCita INT,

    @IdPaciente VARCHAR(30),
    @IdMedico VARCHAR(30),
    @IdServicio VARCHAR(30),

    @FechaCita DATE,
    @HoraCita TIME(0),

    @Observaciones VARCHAR(500) = NULL,

    @IdUsuario VARCHAR(30),

    @Estudios dbo.TVP_EstudioCita READONLY,
    @EstudioPartes dbo.TVP_EstudioParteCuerpo READONLY,

    @TipoRegistro VARCHAR(20) = 'CITA',
    @EsMovil BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET DATEFIRST 1;

    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;


    SET @TipoRegistro =
        UPPER
        (
            LTRIM
            (
                RTRIM
                (
                    ISNULL
                    (
                        @TipoRegistro,
                        'CITA'
                    )
                )
            )
        );


    IF @TipoRegistro NOT IN
    (
        'CITA',
        'SOLICITUD_DIA'
    )
    BEGIN
        THROW 50901,
              'Tipo de registro no válido.',
              1;
    END;


    IF @TipoRegistro = 'CITA'
       AND @EsMovil = 1
    BEGIN
        THROW 50902,
              'Solo las solicitudes del día pueden marcarse como móviles.',
              1;
    END;


    IF NOT EXISTS
    (
        SELECT 1

        FROM dbo.CITA

        WHERE
            IdCita = @IdCita
            AND Activo = 1
    )
    BEGIN
        THROW 50001,
              'La cita no existe.',
              1;
    END;


    IF NOT EXISTS
    (
        SELECT 1

        FROM dbo.CITA

        WHERE
            IdCita = @IdCita
            AND Activo = 1
            AND Estado = 'PROGRAMADA'
    )
    BEGIN
        THROW 50001,
              'Solo las citas o solicitudes pendientes pueden modificarse.',
              1;
    END;


    IF NOT EXISTS
    (
        SELECT 1
        FROM @Estudios
    )
    BEGIN
        THROW 50001,
              'Debe conservar por lo menos un estudio.',
              1;
    END;


    IF EXISTS
    (
        SELECT 1

        FROM @Estudios E

        WHERE NOT EXISTS
        (
            SELECT 1

            FROM @EstudioPartes EP

            WHERE
                EP.IdPrueba =
                E.IdPrueba
        )
    )
    BEGIN
        THROW 50001,
              'Debe seleccionar por lo menos una parte del cuerpo para cada estudio.',
              1;
    END;


    IF EXISTS
    (
        SELECT 1

        FROM @EstudioPartes EP

        WHERE NOT EXISTS
        (
            SELECT 1

            FROM @Estudios E

            WHERE
                E.IdPrueba =
                EP.IdPrueba
        )
    )
    BEGIN
        THROW 50001,
              'Se recibió una parte del cuerpo para un estudio que no pertenece a la cita.',
              1;
    END;


    IF EXISTS
    (
        SELECT 1

        FROM @EstudioPartes EP

        LEFT JOIN dbo.CAT_PARTES_CUERPO PC
            ON PC.IdParteCuerpo =
               EP.IdParteCuerpo

           AND PC.Activo = 1

        WHERE
            PC.IdParteCuerpo IS NULL
    )
    BEGIN
        THROW 50001,
              'Una o más partes del cuerpo no existen o están inactivas.',
              1;
    END;


    BEGIN TRY

        BEGIN TRANSACTION;


        /* ====================================================================
           SOLO CITA VALIDA CAPACIDAD
           ==================================================================== */

        IF @TipoRegistro = 'CITA'
        BEGIN

            DECLARE @Dia TINYINT =
                DATEPART
                (
                    WEEKDAY,
                    @FechaCita
                );


            IF EXISTS
            (
                SELECT 1

                FROM @Estudios E

                LEFT JOIN dbo.CAPACIDAD CAP
                    WITH
                    (
                        UPDLOCK,
                        HOLDLOCK
                    )

                    ON CAP.IdPrueba =
                       E.IdPrueba

                   AND CAP.DiaSemana =
                       @Dia

                   AND CAP.Activo = 1

                WHERE
                    CAP.IdCapacidad IS NULL
            )
            BEGIN
                THROW 50001,
                      'Uno o más estudios no tienen capacidad configurada para el día seleccionado.',
                      1;
            END;


            IF EXISTS
            (
                SELECT 1

                FROM @Estudios E

                INNER JOIN dbo.CAPACIDAD CAP
                    WITH
                    (
                        UPDLOCK,
                        HOLDLOCK
                    )

                    ON CAP.IdPrueba =
                       E.IdPrueba

                   AND CAP.DiaSemana =
                       @Dia

                   AND CAP.Activo = 1

                OUTER APPLY
                (
                    SELECT
                        COUNT(*) AS Utilizados

                    FROM dbo.DETALLE_CITA DC

                    INNER JOIN dbo.CITA C
                        ON C.IdCita =
                           DC.IdCita

                    WHERE
                        DC.IdPrueba =
                        E.IdPrueba

                        AND C.FechaCita =
                            @FechaCita

                        AND C.IdCita <>
                            @IdCita

                        AND C.Activo = 1

                        AND C.TipoRegistro = 'CITA'

                        AND C.Estado <>
                            'CANCELADA'

                        AND DC.Estado <>
                            'CANCELADO'
                ) U

                WHERE
                    ISNULL
                    (
                        U.Utilizados,
                        0
                    )
                    >=
                    CAP.CantidadMaxima
            )
            BEGIN
                THROW 50001,
                      'No existe cupo disponible para uno o más estudios seleccionados.',
                      1;
            END;

        END;


        /* --------------------------------------------------------------------
           Actualizar encabezado
           -------------------------------------------------------------------- */

        UPDATE dbo.CITA

        SET
            IdMedico =
                @IdMedico,

            IdServicio =
                @IdServicio,

            FechaCita =
                @FechaCita,

            HoraCita =
                @HoraCita,

            TipoRegistro =
                @TipoRegistro,

            EsMovil =
                @EsMovil,

            Observaciones =
                @Observaciones,

            IdUsuarioModificacion =
                @IdUsuario,

            FechaModificacion =
                SYSDATETIME()

        WHERE
            IdCita =
            @IdCita;


        /* --------------------------------------------------------------------
           Eliminar estudios retirados
           -------------------------------------------------------------------- */

        DELETE DC

        FROM dbo.DETALLE_CITA DC

        WHERE
            DC.IdCita =
            @IdCita

            AND NOT EXISTS
            (
                SELECT 1

                FROM @Estudios E

                WHERE
                    E.IdPrueba =
                    DC.IdPrueba
            );


        /* --------------------------------------------------------------------
           Insertar estudios nuevos
           -------------------------------------------------------------------- */

        INSERT dbo.DETALLE_CITA
        (
            IdCita,
            IdPrueba,
            Estado
        )

        SELECT
            @IdCita,
            E.IdPrueba,
            'PENDIENTE'

        FROM @Estudios E

        WHERE NOT EXISTS
        (
            SELECT 1

            FROM dbo.DETALLE_CITA DC

            WHERE
                DC.IdCita =
                @IdCita

                AND DC.IdPrueba =
                    E.IdPrueba
        );


        /* --------------------------------------------------------------------
           Sincronizar partes
           -------------------------------------------------------------------- */

        DELETE DCP

        FROM dbo.DETALLE_CITA_PARTE_CUERPO DCP

        INNER JOIN dbo.DETALLE_CITA DC
            ON DC.IdDetalleCita =
               DCP.IdDetalleCita

        WHERE
            DC.IdCita =
            @IdCita;


        INSERT dbo.DETALLE_CITA_PARTE_CUERPO
        (
            IdDetalleCita,
            IdParteCuerpo
        )

        SELECT
            DC.IdDetalleCita,
            EP.IdParteCuerpo

        FROM @EstudioPartes EP

        INNER JOIN dbo.DETALLE_CITA DC
            ON DC.IdCita =
               @IdCita

           AND DC.IdPrueba =
               EP.IdPrueba;


        DECLARE @Numero VARCHAR(30) =
        (
            SELECT NumeroCita

            FROM dbo.CITA

            WHERE IdCita =
                @IdCita
        );


        COMMIT;


        SELECT
            @IdCita AS IdCita,
            @Numero AS NumeroCita;

    END TRY

    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK;

        THROW;

    END CATCH;

END;
GO


/* ============================================================================
   8. DISPONIBILIDAD MENSUAL

   SOLICITUD_DIA se excluye de Utilizados.
   ============================================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_Capacidad_MesPorPruebas
    @Anio INT,
    @Mes INT,
    @IdsPruebas VARCHAR(MAX),
    @ExcluirIdCita INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET DATEFIRST 1;


    DECLARE @FechaInicio DATE =
        DATEFROMPARTS
        (
            @Anio,
            @Mes,
            1
        );


    DECLARE @FechaFin DATE =
        EOMONTH(@FechaInicio);


    CREATE TABLE #Selected
    (
        IdPrueba VARCHAR(30)
        NOT NULL
        PRIMARY KEY
    );


    INSERT #Selected

    SELECT DISTINCT
        LTRIM
        (
            RTRIM(value)
        )

    FROM STRING_SPLIT
    (
        @IdsPruebas,
        ','
    )

    WHERE
        LTRIM
        (
            RTRIM(value)
        ) <> '';


    CREATE TABLE #D
    (
        Fecha DATE NOT NULL,

        IdPrueba VARCHAR(30)
        NOT NULL,

        NombrePrueba VARCHAR(150)
        NOT NULL,

        Capacidad INT NULL,

        Utilizados INT NOT NULL,

        Disponibles INT NULL
    );


    ;WITH Dias AS
    (
        SELECT
            @FechaInicio AS Fecha

        UNION ALL

        SELECT
            DATEADD
            (
                DAY,
                1,
                Fecha
            )

        FROM Dias

        WHERE
            Fecha < @FechaFin
    )

    INSERT #D

    SELECT
        D.Fecha,

        P.IdPrueba,

        P.NombrePrueba,

        CAP.CantidadMaxima,

        ISNULL
        (
            U.Utilizados,
            0
        ),

        CASE

            WHEN CAP.CantidadMaxima IS NULL
                THEN NULL

            WHEN
                CAP.CantidadMaxima
                -
                ISNULL
                (
                    U.Utilizados,
                    0
                )
                < 0
                THEN 0

            ELSE
                CAP.CantidadMaxima
                -
                ISNULL
                (
                    U.Utilizados,
                    0
                )

        END

    FROM Dias D

    CROSS JOIN #Selected S

    INNER JOIN dbo.CAT_PRUEBAS P
        ON P.IdPrueba =
           S.IdPrueba

       AND P.Activo = 1

    OUTER APPLY
    (
        SELECT
            C.CantidadMaxima

        FROM dbo.CAPACIDAD C

        WHERE
            C.IdPrueba =
            P.IdPrueba

            AND C.DiaSemana =
                DATEPART
                (
                    WEEKDAY,
                    D.Fecha
                )

            AND C.Activo = 1
    ) CAP

    OUTER APPLY
    (
        SELECT
            COUNT(*) AS Utilizados

        FROM dbo.DETALLE_CITA DC

        INNER JOIN dbo.CITA CI
            ON CI.IdCita =
               DC.IdCita

        WHERE
            DC.IdPrueba =
            P.IdPrueba

            AND CI.FechaCita =
                D.Fecha

            AND CI.Activo = 1

            /* Solicitudes no consumen agenda */
            AND CI.TipoRegistro = 'CITA'

            AND CI.Estado <>
                'CANCELADA'

            AND DC.Estado <>
                'CANCELADO'

            AND
            (
                @ExcluirIdCita IS NULL
                OR CI.IdCita <>
                   @ExcluirIdCita
            )
    ) U

    OPTION
    (
        MAXRECURSION 100
    );


    SELECT
        Fecha,

        CASE

            WHEN SUM
            (
                CASE
                    WHEN Capacidad IS NULL
                        THEN 1
                    ELSE 0
                END
            ) > 0
                THEN 'NONE'

            WHEN MIN(Disponibles) <= 0
                THEN 'FULL'

            WHEN MIN
            (
                CAST
                (
                    Disponibles
                    AS DECIMAL(10,4)
                )
                /
                NULLIF
                (
                    Capacidad,
                    0
                )
            ) <= 0.25
                THEN 'LOW'

            ELSE 'HIGH'

        END AS Estado

    FROM #D

    GROUP BY Fecha

    ORDER BY Fecha;


    SELECT
        Fecha,
        IdPrueba,
        NombrePrueba,
        Capacidad,
        Utilizados,
        Disponibles

    FROM #D

    ORDER BY
        Fecha,
        NombrePrueba;

END;
GO


/* ============================================================================
   9. CAPACIDAD DEL DASHBOARD

   Solo las citas de agenda utilizan capacidad.
   ============================================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_Dashboard_CapacidadDia
    @Fecha DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET DATEFIRST 1;


    DECLARE @DiaSemana TINYINT =
        DATEPART
        (
            WEEKDAY,
            @Fecha
        );


    ;WITH Uso AS
    (
        SELECT
            DC.IdPrueba,

            COUNT(*) AS Utilizados

        FROM dbo.DETALLE_CITA DC

        INNER JOIN dbo.CITA C
            ON C.IdCita =
               DC.IdCita

        WHERE
            C.FechaCita =
            @Fecha

            AND C.Activo = 1

            /* Solicitudes no afectan cupos */
            AND C.TipoRegistro = 'CITA'

            AND C.Estado <>
                'CANCELADA'

            AND DC.Estado <>
                'CANCELADO'

        GROUP BY
            DC.IdPrueba
    )

    SELECT TOP (6)

        P.IdPrueba,

        P.NombrePrueba,

        CP.NombreCategoria,

        C.CantidadMaxima AS Capacidad,

        ISNULL
        (
            U.Utilizados,
            0
        ) AS Utilizados,

        CASE

            WHEN
                C.CantidadMaxima
                -
                ISNULL
                (
                    U.Utilizados,
                    0
                )
                < 0
                THEN 0

            ELSE
                C.CantidadMaxima
                -
                ISNULL
                (
                    U.Utilizados,
                    0
                )

        END AS Disponibles,

        CAST
        (
            CASE

                WHEN C.CantidadMaxima = 0
                    THEN 0

                ELSE
                    ISNULL
                    (
                        U.Utilizados,
                        0
                    )
                    * 100.0
                    /
                    C.CantidadMaxima

            END

            AS DECIMAL(6,2)

        ) AS PorcentajeUso

    FROM dbo.CAPACIDAD C

    INNER JOIN dbo.CAT_PRUEBAS P
        ON P.IdPrueba =
           C.IdPrueba

       AND P.Activo = 1

    INNER JOIN dbo.CAT_CATEGORIAS_PRUEBAS CP
        ON CP.IdCategoria =
           P.IdCategoria

    LEFT JOIN Uso U
        ON U.IdPrueba =
           P.IdPrueba

    WHERE
        C.DiaSemana =
        @DiaSemana

        AND C.Activo = 1

    ORDER BY
        PorcentajeUso DESC,
        P.NombrePrueba;

END;
GO


/* ============================================================================
   10. RESUMEN DEL DASHBOARD

   Los campos anteriores se conservan.
   Se agregan nuevos datos para la futura interfaz.
   ============================================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_Dashboard_ResumenDia
    @Fecha DATE
AS
BEGIN
    SET NOCOUNT ON;


    SELECT

        /* Se conserva por compatibilidad con la UI actual */
        COUNT(*) AS CitasHoy,


        ISNULL
        (
            SUM
            (
                CASE
                    WHEN Estado = 'PROGRAMADA'
                        THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS Pendientes,


        ISNULL
        (
            SUM
            (
                CASE
                    WHEN Estado = 'ATENDIDA'
                        THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS Atendidas,


        ISNULL
        (
            SUM
            (
                CASE
                    WHEN Estado = 'CANCELADA'
                        THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS Canceladas,


        /* Nuevos datos */

        ISNULL
        (
            SUM
            (
                CASE
                    WHEN TipoRegistro = 'CITA'
                        THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS CitasAgendaHoy,


        ISNULL
        (
            SUM
            (
                CASE
                    WHEN TipoRegistro = 'SOLICITUD_DIA'
                        THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS SolicitudesHoy,


        ISNULL
        (
            SUM
            (
                CASE
                    WHEN TipoRegistro = 'SOLICITUD_DIA'
                         AND EsMovil = 1
                        THEN 1
                    ELSE 0
                END
            ),
            0
        ) AS SolicitudesMovilesHoy


    FROM dbo.CITA

    WHERE
        FechaCita = @Fecha
        AND Activo = 1;

END;
GO


/* ============================================================================
   11. VERIFICACIÓN
   ============================================================================ */

SELECT

    TipoRegistro =
        CASE
            WHEN COL_LENGTH
            (
                'dbo.CITA',
                'TipoRegistro'
            ) IS NOT NULL
                THEN 'OK'
            ELSE 'FALTA'
        END,


    EsMovil =
        CASE
            WHEN COL_LENGTH
            (
                'dbo.CITA',
                'EsMovil'
            ) IS NOT NULL
                THEN 'OK'
            ELSE 'FALTA'
        END,


    Crear =
        CASE
            WHEN OBJECT_ID
            (
                'dbo.sp_Cita_Crear',
                'P'
            ) IS NOT NULL
                THEN 'OK'
            ELSE 'FALTA'
        END,


    Actualizar =
        CASE
            WHEN OBJECT_ID
            (
                'dbo.sp_Cita_Actualizar',
                'P'
            ) IS NOT NULL
                THEN 'OK'
            ELSE 'FALTA'
        END,


    Listar =
        CASE
            WHEN OBJECT_ID
            (
                'dbo.sp_Cita_Listar',
                'P'
            ) IS NOT NULL
                THEN 'OK'
            ELSE 'FALTA'
        END;


SELECT
    TipoRegistro,
    EsMovil,
    COUNT(*) AS Cantidad

FROM dbo.CITA

GROUP BY
    TipoRegistro,
    EsMovil

ORDER BY
    TipoRegistro,
    EsMovil;
GO


PRINT 'Requerimiento 6 - Fase 1 instalada correctamente.';
PRINT 'Las solicitudes del día no consumen capacidad de agenda.';
GO