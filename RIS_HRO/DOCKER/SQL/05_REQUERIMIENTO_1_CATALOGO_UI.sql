USE RIS_HRO;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ============================================================================
   RIS_HRO - REQUERIMIENTO 1 - FASE 4
   Adaptadores para integrar CAT_PARTES_CUERPO al módulo genérico de catálogos.
   ============================================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_ParteCuerpo_ListarUI
    @Texto VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Filtro VARCHAR(100) = NULLIF(LTRIM(RTRIM(@Texto)), '');

    SELECT
        Id = IdParteCuerpo,
        Nombre = NombreParte,
        Descripcion,
        Extra1 = CAST(NULL AS VARCHAR(150)),
        Extra2 = CAST(NULL AS VARCHAR(100)),
        Extra3 = CAST(NULL AS VARCHAR(100)),
        Extra4 = CAST(NULL AS VARCHAR(100)),
        Activo
    FROM dbo.CAT_PARTES_CUERPO
    WHERE @Filtro IS NULL
       OR IdParteCuerpo LIKE '%' + @Filtro + '%'
       OR NombreParte LIKE '%' + @Filtro + '%'
       OR Descripcion LIKE '%' + @Filtro + '%'
    ORDER BY NombreParte;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ParteCuerpo_ObtenerUI
    @Id VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id = IdParteCuerpo,
        Nombre = NombreParte,
        Descripcion,
        Extra1 = CAST(NULL AS VARCHAR(150)),
        Extra2 = CAST(NULL AS VARCHAR(100)),
        Extra3 = CAST(NULL AS VARCHAR(100)),
        Extra4 = CAST(NULL AS VARCHAR(100)),
        Activo
    FROM dbo.CAT_PARTES_CUERPO
    WHERE IdParteCuerpo = @Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ParteCuerpo_GuardarUI
    @Id VARCHAR(30),
    @Nombre VARCHAR(150),
    @Descripcion VARCHAR(250) = NULL,
    @Extra1 VARCHAR(150) = NULL,
    @Extra2 VARCHAR(100) = NULL,
    @Extra3 VARCHAR(100) = NULL,
    @Extra4 VARCHAR(100) = NULL,
    @Activo BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdParte VARCHAR(20) = NULLIF(LTRIM(RTRIM(@Id)), '');
    DECLARE @NombreParte VARCHAR(120) = NULLIF(LTRIM(RTRIM(@Nombre)), '');
    DECLARE @Desc VARCHAR(250) = NULLIF(LTRIM(RTRIM(@Descripcion)), '');

    IF @IdParte IS NULL
        THROW 50001, 'El código de la parte del cuerpo es obligatorio.', 1;

    IF @NombreParte IS NULL
        THROW 50001, 'El nombre de la parte del cuerpo es obligatorio.', 1;

    IF EXISTS (SELECT 1 FROM dbo.CAT_PARTES_CUERPO WHERE IdParteCuerpo = @IdParte)
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM dbo.CAT_PARTES_CUERPO
            WHERE NombreParte = @NombreParte
              AND IdParteCuerpo <> @IdParte
        )
            THROW 50001, 'Ya existe otra parte del cuerpo con ese nombre.', 1;

        UPDATE dbo.CAT_PARTES_CUERPO
        SET NombreParte = @NombreParte,
            Descripcion = @Desc,
            Activo = @Activo
        WHERE IdParteCuerpo = @IdParte;
    END
    ELSE
    BEGIN
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
            @IdParte,
            @NombreParte,
            @Desc,
            @Activo
        );
    END
END;
GO

SELECT
    ListarUI = CASE WHEN OBJECT_ID('dbo.sp_ParteCuerpo_ListarUI', 'P') IS NOT NULL THEN 'OK' ELSE 'FALTA' END,
    ObtenerUI = CASE WHEN OBJECT_ID('dbo.sp_ParteCuerpo_ObtenerUI', 'P') IS NOT NULL THEN 'OK' ELSE 'FALTA' END,
    GuardarUI = CASE WHEN OBJECT_ID('dbo.sp_ParteCuerpo_GuardarUI', 'P') IS NOT NULL THEN 'OK' ELSE 'FALTA' END;
GO

PRINT 'Requerimiento 1 - Fase 4 - Catálogo UI preparado correctamente.';
GO
