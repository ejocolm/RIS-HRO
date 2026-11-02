USE RIS_HRO;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ============================================================================
   RIS_HRO - REQUERIMIENTO 5 / FASE 1
   PRÉSTAMOS DE MATERIALES FÍSICOS

   DISEÑO:
   - CAT_PRESTATARIOS almacena una sola vez los datos e imágenes del documento.
   - PRESTAMO_ESTUDIO guarda únicamente la FK del prestatario y los datos
     propios del evento de préstamo.
   - Un estudio puede prestarse indefinidamente a lo largo del tiempo.
   - Un estudio NO puede tener dos préstamos ACTIVO simultáneamente.
   - Los tres roles de la aplicación podrán prestar y devolver desde la UI.
   - Los datos de la persona que devuelve son opcionales de momento.
   ============================================================================ */


/* ============================================================================
   1. CATÁLOGO DE PRESTATARIOS
   ============================================================================ */
IF OBJECT_ID(N'dbo.CAT_PRESTATARIOS', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.CAT_PRESTATARIOS
    (
        IdPrestatario               VARCHAR(30) NOT NULL,
        NombreCompleto              VARCHAR(150) NOT NULL,
        Telefono                    VARCHAR(20) NULL,
        Correo                      VARCHAR(100) NULL,
        Direccion                   VARCHAR(250) NULL,

        Documento1NombreArchivo     VARCHAR(255) NOT NULL,
        Documento1TipoMime          VARCHAR(50) NOT NULL,
        Documento1Imagen            VARBINARY(MAX) NOT NULL,

        Documento2NombreArchivo     VARCHAR(255) NULL,
        Documento2TipoMime          VARCHAR(50) NULL,
        Documento2Imagen            VARBINARY(MAX) NULL,

        Activo                      BIT NOT NULL
                                    CONSTRAINT DF_CAT_PRESTATARIOS_Activo
                                    DEFAULT (1),

        FechaCreacion               DATETIME2(0) NOT NULL
                                    CONSTRAINT DF_CAT_PRESTATARIOS_FechaCreacion
                                    DEFAULT (SYSDATETIME()),

        FechaModificacion           DATETIME2(0) NULL,

        CONSTRAINT PK_CAT_PRESTATARIOS
            PRIMARY KEY (IdPrestatario),

        CONSTRAINT CK_CAT_PRESTATARIOS_Documento1Mime
            CHECK (Documento1TipoMime IN ('image/png', 'image/jpeg')),

        CONSTRAINT CK_CAT_PRESTATARIOS_Documento2
            CHECK
            (
                (Documento2NombreArchivo IS NULL
                 AND Documento2TipoMime IS NULL
                 AND Documento2Imagen IS NULL)
                OR
                (Documento2NombreArchivo IS NOT NULL
                 AND Documento2TipoMime IN ('image/png', 'image/jpeg')
                 AND Documento2Imagen IS NOT NULL)
            )
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.CAT_PRESTATARIOS')
      AND name = N'IX_CAT_PRESTATARIOS_Nombre'
)
BEGIN
    CREATE INDEX IX_CAT_PRESTATARIOS_Nombre
        ON dbo.CAT_PRESTATARIOS(NombreCompleto)
        INCLUDE(Activo, Telefono);
END;
GO


/* ============================================================================
   2. PRÉSTAMOS
   ============================================================================ */
IF OBJECT_ID(N'dbo.PRESTAMO_ESTUDIO', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PRESTAMO_ESTUDIO
    (
        IdPrestamo                      INT IDENTITY(1,1) NOT NULL,
        IdDetalleCita                   INT NOT NULL,
        IdPrestatario                   VARCHAR(30) NOT NULL,

        FechaHoraPrestamo               DATETIME2(0) NOT NULL
                                        CONSTRAINT DF_PRESTAMO_FechaHoraPrestamo
                                        DEFAULT (SYSDATETIME()),

        MotivoPrestamo                  VARCHAR(250) NOT NULL,
        Observaciones                   VARCHAR(500) NULL,
        Estado                          VARCHAR(20) NOT NULL
                                        CONSTRAINT DF_PRESTAMO_Estado
                                        DEFAULT ('ACTIVO'),

        UsuarioPrestamo                 VARCHAR(30) NOT NULL,

        DocumentoIdentificacionDevuelve VARCHAR(30) NULL,
        NombrePersonaDevuelve           VARCHAR(150) NULL,
        FechaHoraDevolucion             DATETIME2(0) NULL,
        UsuarioDevolucion               VARCHAR(30) NULL,
        ObservacionesDevolucion         VARCHAR(500) NULL,

        CONSTRAINT PK_PRESTAMO_ESTUDIO
            PRIMARY KEY (IdPrestamo),

        CONSTRAINT FK_PRESTAMO_DETALLE_CITA
            FOREIGN KEY (IdDetalleCita)
            REFERENCES dbo.DETALLE_CITA(IdDetalleCita),

        CONSTRAINT FK_PRESTAMO_PRESTATARIO
            FOREIGN KEY (IdPrestatario)
            REFERENCES dbo.CAT_PRESTATARIOS(IdPrestatario),

        CONSTRAINT FK_PRESTAMO_USUARIO_PRESTAMO
            FOREIGN KEY (UsuarioPrestamo)
            REFERENCES dbo.CAT_USUARIOS(IdUsuario),

        CONSTRAINT FK_PRESTAMO_USUARIO_DEVOLUCION
            FOREIGN KEY (UsuarioDevolucion)
            REFERENCES dbo.CAT_USUARIOS(IdUsuario),

        CONSTRAINT CK_PRESTAMO_Estado
            CHECK (Estado IN ('ACTIVO', 'DEVUELTO')),

        CONSTRAINT CK_PRESTAMO_Devolucion
            CHECK
            (
                (Estado = 'ACTIVO'
                 AND FechaHoraDevolucion IS NULL
                 AND UsuarioDevolucion IS NULL)
                OR
                (Estado = 'DEVUELTO'
                 AND FechaHoraDevolucion IS NOT NULL
                 AND UsuarioDevolucion IS NOT NULL)
            )
    );
END;
GO

/* Protección real contra dos préstamos activos simultáneos. */
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.PRESTAMO_ESTUDIO')
      AND name = N'UX_PRESTAMO_ESTUDIO_Activo'
)
BEGIN
    CREATE UNIQUE INDEX UX_PRESTAMO_ESTUDIO_Activo
        ON dbo.PRESTAMO_ESTUDIO(IdDetalleCita)
        WHERE Estado = 'ACTIVO';
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.PRESTAMO_ESTUDIO')
      AND name = N'IX_PRESTAMO_ESTUDIO_ActivosFecha'
)
BEGIN
    CREATE INDEX IX_PRESTAMO_ESTUDIO_ActivosFecha
        ON dbo.PRESTAMO_ESTUDIO(Estado, FechaHoraPrestamo DESC)
        INCLUDE(IdDetalleCita, IdPrestatario);
END;
GO


/* ============================================================================
   3. CAT_PRESTATARIOS - PROCEDIMIENTOS
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.sp_Prestatario_Listar
    @Texto VARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @Texto = NULLIF(LTRIM(RTRIM(@Texto)), '');

    SELECT
        IdPrestatario,
        NombreCompleto,
        Telefono,
        Correo,
        Direccion,
        Activo,
        FechaCreacion,
        FechaModificacion,
        CAST(1 AS BIT) AS TieneDocumento1,
        CAST(CASE WHEN Documento2Imagen IS NULL THEN 0 ELSE 1 END AS BIT)
            AS TieneDocumento2
    FROM dbo.CAT_PRESTATARIOS
    WHERE @Texto IS NULL
       OR IdPrestatario LIKE '%' + @Texto + '%'
       OR NombreCompleto LIKE '%' + @Texto + '%'
       OR Telefono LIKE '%' + @Texto + '%'
       OR Correo LIKE '%' + @Texto + '%'
    ORDER BY NombreCompleto, IdPrestatario;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Prestatario_Obtener
    @IdPrestatario VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdPrestatario,
        NombreCompleto,
        Telefono,
        Correo,
        Direccion,
        Activo,
        FechaCreacion,
        FechaModificacion,
        CAST(1 AS BIT) AS TieneDocumento1,
        CAST(CASE WHEN Documento2Imagen IS NULL THEN 0 ELSE 1 END AS BIT)
            AS TieneDocumento2
    FROM dbo.CAT_PRESTATARIOS
    WHERE IdPrestatario = @IdPrestatario;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Prestatario_Guardar
    @IdPrestatario VARCHAR(30),
    @NombreCompleto VARCHAR(150),
    @Telefono VARCHAR(20) = NULL,
    @Correo VARCHAR(100) = NULL,
    @Direccion VARCHAR(250) = NULL,
    @Documento1NombreArchivo VARCHAR(255) = NULL,
    @Documento1TipoMime VARCHAR(50) = NULL,
    @Documento1Imagen VARBINARY(MAX) = NULL,
    @Documento2NombreArchivo VARCHAR(255) = NULL,
    @Documento2TipoMime VARCHAR(50) = NULL,
    @Documento2Imagen VARBINARY(MAX) = NULL,
    @EliminarDocumento2 BIT = 0,
    @Activo BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @IdPrestatario = NULLIF(LTRIM(RTRIM(@IdPrestatario)), '');
    SET @NombreCompleto = NULLIF(LTRIM(RTRIM(@NombreCompleto)), '');
    SET @Telefono = NULLIF(LTRIM(RTRIM(@Telefono)), '');
    SET @Correo = NULLIF(LTRIM(RTRIM(@Correo)), '');
    SET @Direccion = NULLIF(LTRIM(RTRIM(@Direccion)), '');

    IF @IdPrestatario IS NULL
        THROW 50700, 'El ID del prestatario es obligatorio.', 1;

    IF @NombreCompleto IS NULL
        THROW 50701, 'El nombre completo del prestatario es obligatorio.', 1;

    IF @Documento1TipoMime IS NOT NULL
       AND @Documento1TipoMime NOT IN ('image/png', 'image/jpeg')
        THROW 50702, 'El documento 1 debe ser PNG, JPG o JPEG.', 1;

    IF @Documento2TipoMime IS NOT NULL
       AND @Documento2TipoMime NOT IN ('image/png', 'image/jpeg')
        THROW 50703, 'El documento 2 debe ser PNG, JPG o JPEG.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.CAT_PRESTATARIOS
        WHERE IdPrestatario = @IdPrestatario
    )
    BEGIN
        UPDATE dbo.CAT_PRESTATARIOS
        SET
            NombreCompleto = @NombreCompleto,
            Telefono = @Telefono,
            Correo = @Correo,
            Direccion = @Direccion,

            Documento1NombreArchivo =
                CASE WHEN @Documento1Imagen IS NULL
                     THEN Documento1NombreArchivo
                     ELSE @Documento1NombreArchivo END,
            Documento1TipoMime =
                CASE WHEN @Documento1Imagen IS NULL
                     THEN Documento1TipoMime
                     ELSE @Documento1TipoMime END,
            Documento1Imagen =
                COALESCE(@Documento1Imagen, Documento1Imagen),

            Documento2NombreArchivo =
                CASE
                    WHEN @EliminarDocumento2 = 1 THEN NULL
                    WHEN @Documento2Imagen IS NOT NULL THEN @Documento2NombreArchivo
                    ELSE Documento2NombreArchivo
                END,
            Documento2TipoMime =
                CASE
                    WHEN @EliminarDocumento2 = 1 THEN NULL
                    WHEN @Documento2Imagen IS NOT NULL THEN @Documento2TipoMime
                    ELSE Documento2TipoMime
                END,
            Documento2Imagen =
                CASE
                    WHEN @EliminarDocumento2 = 1 THEN NULL
                    WHEN @Documento2Imagen IS NOT NULL THEN @Documento2Imagen
                    ELSE Documento2Imagen
                END,

            Activo = @Activo,
            FechaModificacion = SYSDATETIME()
        WHERE IdPrestatario = @IdPrestatario;
    END
    ELSE
    BEGIN
        IF @Documento1Imagen IS NULL
           OR @Documento1NombreArchivo IS NULL
           OR @Documento1TipoMime IS NULL
        BEGIN
            THROW 50704,
                  'La primera imagen del documento de identificación es obligatoria.',
                  1;
        END;

        INSERT dbo.CAT_PRESTATARIOS
        (
            IdPrestatario,
            NombreCompleto,
            Telefono,
            Correo,
            Direccion,
            Documento1NombreArchivo,
            Documento1TipoMime,
            Documento1Imagen,
            Documento2NombreArchivo,
            Documento2TipoMime,
            Documento2Imagen,
            Activo
        )
        VALUES
        (
            @IdPrestatario,
            @NombreCompleto,
            @Telefono,
            @Correo,
            @Direccion,
            @Documento1NombreArchivo,
            @Documento1TipoMime,
            @Documento1Imagen,
            @Documento2NombreArchivo,
            @Documento2TipoMime,
            @Documento2Imagen,
            @Activo
        );
    END;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Prestatario_Documento
    @IdPrestatario VARCHAR(30),
    @Numero TINYINT
AS
BEGIN
    SET NOCOUNT ON;

    IF @Numero NOT IN (1, 2)
        THROW 50705, 'El número de documento debe ser 1 o 2.', 1;

    IF @Numero = 1
    BEGIN
        SELECT
            Documento1NombreArchivo AS NombreArchivo,
            Documento1TipoMime AS TipoMime,
            Documento1Imagen AS Imagen
        FROM dbo.CAT_PRESTATARIOS
        WHERE IdPrestatario = @IdPrestatario;
        RETURN;
    END;

    SELECT
        Documento2NombreArchivo AS NombreArchivo,
        Documento2TipoMime AS TipoMime,
        Documento2Imagen AS Imagen
    FROM dbo.CAT_PRESTATARIOS
    WHERE IdPrestatario = @IdPrestatario
      AND Documento2Imagen IS NOT NULL;
END;
GO


/* ============================================================================
   4. CONTEXTO Y OPERACIONES DE PRÉSTAMO
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.sp_Prestamo_ContextoEstudio
    @IdDetalleCita INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        DC.IdDetalleCita,
        C.IdCita,
        C.NumeroCita,
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
        IE.IdInternoRadiologia,

        PA.IdPrestamo AS IdPrestamoActivo,
        PA.FechaHoraPrestamo,
        PA.IdPrestatario AS IdPrestatarioActivo,
        CP.NombreCompleto AS PrestatarioActivo
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
    LEFT JOIN dbo.PRESTAMO_ESTUDIO PA
        ON PA.IdDetalleCita = DC.IdDetalleCita
       AND PA.Estado = 'ACTIVO'
    LEFT JOIN dbo.CAT_PRESTATARIOS CP
        ON CP.IdPrestatario = PA.IdPrestatario
    OUTER APPLY
    (
        SELECT
            STRING_AGG(X.NombreParte, ', ')
            WITHIN GROUP (ORDER BY X.NombreParte) AS PartesCuerpo
        FROM
        (
            SELECT PC2.NombreParte
            FROM dbo.DETALLE_CITA_PARTE_CUERPO DCP
            INNER JOIN dbo.CAT_PARTES_CUERPO PC2
                ON PC2.IdParteCuerpo = DCP.IdParteCuerpo
            WHERE DCP.IdDetalleCita = DC.IdDetalleCita
        ) X
    ) PC
    WHERE DC.IdDetalleCita = @IdDetalleCita
      AND DC.Estado = 'REALIZADO'
      AND C.Activo = 1;
END;
GO

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
        INNER JOIN dbo.CITA C ON C.IdCita = DC.IdCita
        WHERE DC.IdDetalleCita = @IdDetalleCita
          AND DC.Estado = 'REALIZADO'
          AND C.Activo = 1
    )
        THROW 50712, 'El estudio no existe o no se encuentra REALIZADO.', 1;

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

CREATE OR ALTER PROCEDURE dbo.sp_Prestamo_Devolver
    @IdPrestamo INT,
    @DocumentoIdentificacionDevuelve VARCHAR(30) = NULL,
    @NombrePersonaDevuelve VARCHAR(150) = NULL,
    @ObservacionesDevolucion VARCHAR(500) = NULL,
    @UsuarioDevolucion VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @DocumentoIdentificacionDevuelve =
        NULLIF(LTRIM(RTRIM(@DocumentoIdentificacionDevuelve)), '');
    SET @NombrePersonaDevuelve =
        NULLIF(LTRIM(RTRIM(@NombrePersonaDevuelve)), '');
    SET @ObservacionesDevolucion =
        NULLIF(LTRIM(RTRIM(@ObservacionesDevolucion)), '');

    UPDATE dbo.PRESTAMO_ESTUDIO
    SET
        Estado = 'DEVUELTO',
        DocumentoIdentificacionDevuelve = @DocumentoIdentificacionDevuelve,
        NombrePersonaDevuelve = @NombrePersonaDevuelve,
        FechaHoraDevolucion = SYSDATETIME(),
        UsuarioDevolucion = @UsuarioDevolucion,
        ObservacionesDevolucion = @ObservacionesDevolucion
    WHERE IdPrestamo = @IdPrestamo
      AND Estado = 'ACTIVO';

    IF @@ROWCOUNT = 0
        THROW 50715, 'El préstamo no existe o ya fue devuelto.', 1;
END;
GO


/* ============================================================================
   5. LISTADO DE PRÉSTAMOS ACTIVOS
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.sp_Prestamo_ListarActivos
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        P.IdPrestamo,
        P.IdDetalleCita,
        P.FechaHoraPrestamo,
        DATEDIFF(DAY, CAST(P.FechaHoraPrestamo AS DATE), CAST(SYSDATETIME() AS DATE))
            AS DiasPrestado,

        IE.IdInternoRadiologia,

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
        ISNULL(PC.PartesCuerpo, '') AS PartesCuerpo,

        P.IdPrestatario,
        CP.NombreCompleto AS Prestatario,
        CP.Telefono AS TelefonoPrestatario,
        P.MotivoPrestamo,
        P.Observaciones,
        P.UsuarioPrestamo
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
            STRING_AGG(X.NombreParte, ', ')
            WITHIN GROUP (ORDER BY X.NombreParte) AS PartesCuerpo
        FROM
        (
            SELECT PC2.NombreParte
            FROM dbo.DETALLE_CITA_PARTE_CUERPO DCP
            INNER JOIN dbo.CAT_PARTES_CUERPO PC2
                ON PC2.IdParteCuerpo = DCP.IdParteCuerpo
            WHERE DCP.IdDetalleCita = DC.IdDetalleCita
        ) X
    ) PC
    WHERE P.Estado = 'ACTIVO'
    ORDER BY P.FechaHoraPrestamo ASC, P.IdPrestamo;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Prestamo_Obtener
    @IdPrestamo INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        P.IdPrestamo,
        P.IdDetalleCita,
        P.FechaHoraPrestamo,
        P.MotivoPrestamo,
        P.Observaciones,
        P.Estado,
        P.UsuarioPrestamo,

        P.DocumentoIdentificacionDevuelve,
        P.NombrePersonaDevuelve,
        P.FechaHoraDevolucion,
        P.UsuarioDevolucion,
        P.ObservacionesDevolucion,

        IE.IdInternoRadiologia,

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

        P.IdPrestatario,
        CP.NombreCompleto AS Prestatario,
        CP.Telefono AS TelefonoPrestatario,
        CP.Correo AS CorreoPrestatario,
        CP.Direccion AS DireccionPrestatario,
        CAST(1 AS BIT) AS TieneDocumento1,
        CAST(CASE WHEN CP.Documento2Imagen IS NULL THEN 0 ELSE 1 END AS BIT)
            AS TieneDocumento2
    FROM dbo.PRESTAMO_ESTUDIO P
    INNER JOIN dbo.DETALLE_CITA DC
        ON DC.IdDetalleCita = P.IdDetalleCita
    INNER JOIN dbo.CITA C
        ON C.IdCita = DC.IdCita
    INNER JOIN dbo.CAT_PACIENTES PAC
        ON PAC.IdPaciente = C.IdPaciente
    INNER JOIN dbo.CAT_PRUEBAS PR
        ON PR.IdPrueba = DC.IdPrueba
    INNER JOIN dbo.CAT_CATEGORIAS_PRUEBAS CAT
        ON CAT.IdCategoria = PR.IdCategoria
    INNER JOIN dbo.CAT_PRESTATARIOS CP
        ON CP.IdPrestatario = P.IdPrestatario
    LEFT JOIN dbo.INFORME_ESTUDIO IE
        ON IE.IdDetalleCita = DC.IdDetalleCita
    OUTER APPLY
    (
        SELECT
            STRING_AGG(X.NombreParte, ', ')
            WITHIN GROUP (ORDER BY X.NombreParte) AS PartesCuerpo
        FROM
        (
            SELECT PC2.NombreParte
            FROM dbo.DETALLE_CITA_PARTE_CUERPO DCP
            INNER JOIN dbo.CAT_PARTES_CUERPO PC2
                ON PC2.IdParteCuerpo = DCP.IdParteCuerpo
            WHERE DCP.IdDetalleCita = DC.IdDetalleCita
        ) X
    ) PC
    WHERE P.IdPrestamo = @IdPrestamo;
END;
GO


/* ============================================================================
   6. INVENTARIO: AGREGAR ESTADO DE PRÉSTAMO SIN DUPLICAR BÚSQUEDAS
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
            ISNULL(IE.NumeroVersion, 0) AS NumeroVersion,

            PA.IdPrestamo AS IdPrestamoActivo,
            PA.FechaHoraPrestamo,
            PA.IdPrestatario AS IdPrestatarioActivo,
            CP.NombreCompleto AS PrestatarioActivo

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
        LEFT JOIN dbo.PRESTAMO_ESTUDIO PA
            ON PA.IdDetalleCita = DC.IdDetalleCita
           AND PA.Estado = 'ACTIVO'
        LEFT JOIN dbo.CAT_PRESTATARIOS CP
            ON CP.IdPrestatario = PA.IdPrestatario

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
                SELECT CP2.NombreParte
                FROM dbo.DETALLE_CITA_PARTE_CUERPO DCP
                INNER JOIN dbo.CAT_PARTES_CUERPO CP2
                    ON CP2.IdParteCuerpo = DCP.IdParteCuerpo
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
        NumeroVersion,
        IdPrestamoActivo,
        FechaHoraPrestamo,
        IdPrestatarioActivo,
        PrestatarioActivo
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
   7. VERIFICACIÓN
   ============================================================================ */
SELECT
    CatalogoPrestatarios =
        CASE WHEN OBJECT_ID(N'dbo.CAT_PRESTATARIOS', N'U') IS NOT NULL
             THEN 'OK' ELSE 'FALTA' END,

    Prestamos =
        CASE WHEN OBJECT_ID(N'dbo.PRESTAMO_ESTUDIO', N'U') IS NOT NULL
             THEN 'OK' ELSE 'FALTA' END,

    UnPrestamoActivo =
        CASE WHEN EXISTS
        (
            SELECT 1
            FROM sys.indexes
            WHERE object_id = OBJECT_ID(N'dbo.PRESTAMO_ESTUDIO')
              AND name = N'UX_PRESTAMO_ESTUDIO_Activo'
        )
        THEN 'OK' ELSE 'FALTA' END,

    ListadoActivos =
        CASE WHEN OBJECT_ID(N'dbo.sp_Prestamo_ListarActivos', N'P') IS NOT NULL
             THEN 'OK' ELSE 'FALTA' END;
GO

PRINT 'Requerimiento 5 - Fase 1 instalada correctamente.';
PRINT 'CAT_PRESTATARIOS almacena las imágenes una sola vez.';
PRINT 'PRESTAMO_ESTUDIO referencia al prestatario sin duplicar imágenes.';
PRINT 'Un estudio solo puede tener un préstamo ACTIVO al mismo tiempo.';
GO
