USE RIS_HRO;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* =============================================================
   REQUERIMIENTO 7 - FASE 1
   ROL DE BODEGA

   Rol nuevo:
       USUARIO_BODEGA

   Permisos funcionales:
       - Inventario
       - Préstamos
       - Prestatarios

   Los permisos de páginas se aplican en C#.
   ============================================================= */

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.CAT_ROLES
    WHERE NombreRol = 'USUARIO_BODEGA'
)
BEGIN
    INSERT dbo.CAT_ROLES
    (
        NombreRol,
        Descripcion,
        Activo
    )
    VALUES
    (
        'USUARIO_BODEGA',
        'Acceso de bodega para inventario, préstamos y prestatarios',
        1
    );
END
ELSE
BEGIN
    UPDATE dbo.CAT_ROLES
    SET
        Descripcion = 'Acceso de bodega para inventario, préstamos y prestatarios',
        Activo = 1
    WHERE NombreRol = 'USUARIO_BODEGA';
END;
GO

SELECT
    IdRol,
    NombreRol,
    Descripcion,
    Activo
FROM dbo.CAT_ROLES
WHERE NombreRol = 'USUARIO_BODEGA';
GO

PRINT 'Requerimiento 7 - Fase 1: rol USUARIO_BODEGA disponible.';
GO
