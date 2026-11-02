/* ============================================================================
   RIS_HRO - REQUERIMIENTO 1
   Catálogo de partes del cuerpo y relación con estudios solicitados

   OBJETIVO
   - Crear CAT_PARTES_CUERPO.
   - Crear DETALLE_CITA_PARTE_CUERPO como tabla intermedia.
   - Preparar un TVP para enviar las partes seleccionadas por estudio.
   - Crear procedimientos almacenados básicos del catálogo y consulta de relación.

   REGLAS FUNCIONALES CONFIRMADAS
   1. Cada estudio debe tener por lo menos una parte del cuerpo.
   2. Un estudio puede tener varias partes del cuerpo.
   3. Las partes del cuerpo NO crean estudios adicionales.
   4. Un DETALLE_CITA continúa consumiendo solamente 1 cupo de IdPrueba.
   5. Se mantiene UNIQUE (IdCita, IdPrueba) en DETALLE_CITA.

   IMPORTANTE
   Este script es INCREMENTAL. No elimina ni recrea la base de datos.
   Los registros históricos de DETALLE_CITA existentes quedan sin parte anatómica;
   se completarán cuando se editen. La obligatoriedad se aplicará en los SP de
   creación/edición y en la interfaz en la siguiente fase.
   ============================================================================ */

USE RIS_HRO;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ============================================================================
   1. CATÁLOGO DE PARTES DEL CUERPO
   ============================================================================ */
IF OBJECT_ID(N'dbo.CAT_PARTES_CUERPO', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.CAT_PARTES_CUERPO
    (
        IdParteCuerpo VARCHAR(20) NOT NULL,
        NombreParte VARCHAR(120) NOT NULL,
        Descripcion VARCHAR(250) NULL,
        Activo BIT NOT NULL
            CONSTRAINT DF_CAT_PARTES_CUERPO_Activo DEFAULT (1),
        FechaCreacion DATETIME2(0) NOT NULL
            CONSTRAINT DF_CAT_PARTES_CUERPO_Fecha DEFAULT (SYSDATETIME()),

        CONSTRAINT PK_CAT_PARTES_CUERPO
            PRIMARY KEY (IdParteCuerpo),

        CONSTRAINT UQ_CAT_PARTES_CUERPO_Nombre
            UNIQUE (NombreParte)
    );
END;
GO

/* ============================================================================
   2. TABLA INTERMEDIA DETALLE_CITA <-> PARTE DEL CUERPO
   ============================================================================ */
IF OBJECT_ID(N'dbo.DETALLE_CITA_PARTE_CUERPO', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DETALLE_CITA_PARTE_CUERPO
    (
        IdDetalleCita INT NOT NULL,
        IdParteCuerpo VARCHAR(20) NOT NULL,
        FechaCreacion DATETIME2(0) NOT NULL
            CONSTRAINT DF_DETALLE_CITA_PARTE_Fecha DEFAULT (SYSDATETIME()),

        CONSTRAINT PK_DETALLE_CITA_PARTE_CUERPO
            PRIMARY KEY (IdDetalleCita, IdParteCuerpo),

        CONSTRAINT FK_DETALLE_CITA_PARTE_DETALLE
            FOREIGN KEY (IdDetalleCita)
            REFERENCES dbo.DETALLE_CITA(IdDetalleCita)
            ON DELETE CASCADE,

        CONSTRAINT FK_DETALLE_CITA_PARTE_PARTE
            FOREIGN KEY (IdParteCuerpo)
            REFERENCES dbo.CAT_PARTES_CUERPO(IdParteCuerpo)
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.DETALLE_CITA_PARTE_CUERPO')
      AND name = N'IX_DETALLE_CITA_PARTE_IdParteCuerpo'
)
BEGIN
    CREATE INDEX IX_DETALLE_CITA_PARTE_IdParteCuerpo
        ON dbo.DETALLE_CITA_PARTE_CUERPO(IdParteCuerpo);
END;
GO

/* ============================================================================
   3. TIPO TABLA PARA ENVIAR LAS PARTES SELECCIONADAS POR ESTUDIO

   Ejemplo lógico:
       RX001 | PC001
       RX001 | PC002
       RX003 | PC005

   RX001 puede repetirse porque cada fila representa una parte anatómica distinta.
   ============================================================================ */
IF TYPE_ID(N'dbo.TVP_EstudioParteCuerpo') IS NULL
BEGIN
    EXEC(N'
        CREATE TYPE dbo.TVP_EstudioParteCuerpo AS TABLE
        (
            IdPrueba VARCHAR(30) NOT NULL,
            IdParteCuerpo VARCHAR(20) NOT NULL,
            PRIMARY KEY (IdPrueba, IdParteCuerpo)
        );
    ');
END;
GO

/* ============================================================================
   4. PROCEDIMIENTOS DEL CATÁLOGO
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.sp_ParteCuerpo_Listar
    @SoloActivos BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdParteCuerpo,
        NombreParte,
        Descripcion,
        Activo,
        FechaCreacion
    FROM dbo.CAT_PARTES_CUERPO
    WHERE @SoloActivos = 0 OR Activo = 1
    ORDER BY NombreParte;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ParteCuerpo_Buscar
    @Texto VARCHAR(120) = NULL,
    @SoloActivos BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Filtro VARCHAR(120) = NULLIF(LTRIM(RTRIM(@Texto)), '');

    SELECT TOP (100)
        IdParteCuerpo,
        NombreParte,
        Descripcion,
        Activo,
        FechaCreacion
    FROM dbo.CAT_PARTES_CUERPO
    WHERE (@SoloActivos = 0 OR Activo = 1)
      AND
      (
          @Filtro IS NULL
          OR IdParteCuerpo LIKE '%' + @Filtro + '%'
          OR NombreParte LIKE '%' + @Filtro + '%'
          OR Descripcion LIKE '%' + @Filtro + '%'
      )
    ORDER BY NombreParte;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ParteCuerpo_Obtener
    @IdParteCuerpo VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdParteCuerpo,
        NombreParte,
        Descripcion,
        Activo,
        FechaCreacion
    FROM dbo.CAT_PARTES_CUERPO
    WHERE IdParteCuerpo = @IdParteCuerpo;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ParteCuerpo_Crear
    @IdParteCuerpo VARCHAR(20),
    @NombreParte VARCHAR(120),
    @Descripcion VARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @IdParteCuerpo = NULLIF(LTRIM(RTRIM(@IdParteCuerpo)), '');
    SET @NombreParte = NULLIF(LTRIM(RTRIM(@NombreParte)), '');
    SET @Descripcion = NULLIF(LTRIM(RTRIM(@Descripcion)), '');

    IF @IdParteCuerpo IS NULL
        THROW 50001, 'El código de la parte del cuerpo es obligatorio.', 1;

    IF @NombreParte IS NULL
        THROW 50001, 'El nombre de la parte del cuerpo es obligatorio.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.CAT_PARTES_CUERPO
        WHERE IdParteCuerpo = @IdParteCuerpo
    )
        THROW 50001, 'Ya existe una parte del cuerpo con ese código.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.CAT_PARTES_CUERPO
        WHERE NombreParte = @NombreParte
    )
        THROW 50001, 'Ya existe una parte del cuerpo con ese nombre.', 1;

    INSERT dbo.CAT_PARTES_CUERPO
    (
        IdParteCuerpo,
        NombreParte,
        Descripcion,
        Activo
    )
    VALUES
    (
        @IdParteCuerpo,
        @NombreParte,
        @Descripcion,
        1
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ParteCuerpo_Actualizar
    @IdParteCuerpo VARCHAR(20),
    @NombreParte VARCHAR(120),
    @Descripcion VARCHAR(250) = NULL,
    @Activo BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    SET @NombreParte = NULLIF(LTRIM(RTRIM(@NombreParte)), '');
    SET @Descripcion = NULLIF(LTRIM(RTRIM(@Descripcion)), '');

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.CAT_PARTES_CUERPO
        WHERE IdParteCuerpo = @IdParteCuerpo
    )
        THROW 50001, 'La parte del cuerpo indicada no existe.', 1;

    IF @NombreParte IS NULL
        THROW 50001, 'El nombre de la parte del cuerpo es obligatorio.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.CAT_PARTES_CUERPO
        WHERE NombreParte = @NombreParte
          AND IdParteCuerpo <> @IdParteCuerpo
    )
        THROW 50001, 'Ya existe otra parte del cuerpo con ese nombre.', 1;

    UPDATE dbo.CAT_PARTES_CUERPO
    SET NombreParte = @NombreParte,
        Descripcion = @Descripcion,
        Activo = @Activo
    WHERE IdParteCuerpo = @IdParteCuerpo;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ParteCuerpo_CambiarEstado
    @IdParteCuerpo VARCHAR(20),
    @Activo BIT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.CAT_PARTES_CUERPO
        WHERE IdParteCuerpo = @IdParteCuerpo
    )
        THROW 50001, 'La parte del cuerpo indicada no existe.', 1;

    UPDATE dbo.CAT_PARTES_CUERPO
    SET Activo = @Activo
    WHERE IdParteCuerpo = @IdParteCuerpo;
END;
GO

/* ============================================================================
   5. PROCEDIMIENTO PARA LEER LAS PARTES DE UN DETALLE DE CITA
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.sp_DetalleCita_PartesCuerpo_Listar
    @IdDetalleCita INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        PC.IdParteCuerpo,
        PC.NombreParte,
        PC.Descripcion,
        PC.Activo
    FROM dbo.DETALLE_CITA_PARTE_CUERPO DCP
    INNER JOIN dbo.CAT_PARTES_CUERPO PC
        ON PC.IdParteCuerpo = DCP.IdParteCuerpo
    WHERE DCP.IdDetalleCita = @IdDetalleCita
    ORDER BY PC.NombreParte;
END;
GO

/* ============================================================================
   6. VERIFICACIÓN
   ============================================================================ */
SELECT
    TablaPartesCuerpo = CASE
        WHEN OBJECT_ID(N'dbo.CAT_PARTES_CUERPO', N'U') IS NOT NULL THEN 'OK'
        ELSE 'FALTA'
    END,
    TablaRelacion = CASE
        WHEN OBJECT_ID(N'dbo.DETALLE_CITA_PARTE_CUERPO', N'U') IS NOT NULL THEN 'OK'
        ELSE 'FALTA'
    END,
    TipoTVP = CASE
        WHEN TYPE_ID(N'dbo.TVP_EstudioParteCuerpo') IS NOT NULL THEN 'OK'
        ELSE 'FALTA'
    END;
GO

SELECT
    FK.name AS ForeignKey,
    OBJECT_NAME(FK.parent_object_id) AS TablaOrigen,
    OBJECT_NAME(FK.referenced_object_id) AS TablaDestino
FROM sys.foreign_keys FK
WHERE FK.parent_object_id = OBJECT_ID(N'dbo.DETALLE_CITA_PARTE_CUERPO');
GO

PRINT 'Requerimiento 1 - Fase de base de datos instalada correctamente.';
GO

/* ============================================================================
   DATOS DE PRUEBA OPCIONALES - NO SE EJECUTAN AUTOMÁTICAMENTE

   Cuando quieras probar manualmente el catálogo puedes ejecutar, por ejemplo:

   EXEC dbo.sp_ParteCuerpo_Crear 'PC001', 'Pie derecho', NULL;
   EXEC dbo.sp_ParteCuerpo_Crear 'PC002', 'Pie izquierdo', NULL;
   EXEC dbo.sp_ParteCuerpo_Crear 'PC003', 'Mano derecha', NULL;
   EXEC dbo.sp_ParteCuerpo_Crear 'PC004', 'Mano izquierda', NULL;
   EXEC dbo.sp_ParteCuerpo_Crear 'PC005', 'Cabeza', NULL;

   EXEC dbo.sp_ParteCuerpo_Listar @SoloActivos = 1;
   ============================================================================ */
