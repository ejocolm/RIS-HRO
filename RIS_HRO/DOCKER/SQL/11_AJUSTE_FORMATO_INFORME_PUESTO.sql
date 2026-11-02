USE RIS_HRO;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ============================================================================
   RIS_HRO - AJUSTE DE FORMATO DE INFORME
   - Agrega Puesto a CAT_MEDICOS_INFORMANTES.
   - Mantiene REF. VR/BH fijo temporalmente.
   - La impresión clínica NO incluye la tabla de películas/imágenes.
   - Los recursos siguen almacenándose para reportes y estadísticas.
   ============================================================================ */


/* ============================================================================
   1. AGREGAR PUESTO AL CATÁLOGO DE MÉDICOS INFORMANTES
   ============================================================================ */
IF COL_LENGTH('dbo.CAT_MEDICOS_INFORMANTES', 'Puesto') IS NULL
BEGIN
    ALTER TABLE dbo.CAT_MEDICOS_INFORMANTES
    ADD Puesto VARCHAR(100) NULL;
END;
GO


/* ============================================================================
   2. PROCEDIMIENTOS BASE DEL CATÁLOGO
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.sp_MedicoInformante_Listar
    @Texto VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Filtro VARCHAR(100) = NULLIF(LTRIM(RTRIM(@Texto)), '');

    SELECT
        IdMedicoInformante,
        Nombres,
        Apellidos,
        Puesto,
        NoColegiado,
        Telefono,
        Correo,
        Activo,
        FechaCreacion
    FROM dbo.CAT_MEDICOS_INFORMANTES
    WHERE @Filtro IS NULL
       OR IdMedicoInformante LIKE '%' + @Filtro + '%'
       OR Nombres LIKE '%' + @Filtro + '%'
       OR Apellidos LIKE '%' + @Filtro + '%'
       OR Puesto LIKE '%' + @Filtro + '%'
       OR NoColegiado LIKE '%' + @Filtro + '%'
    ORDER BY Apellidos, Nombres;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_MedicoInformante_ListarActivos
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdMedicoInformante,
        Nombres,
        Apellidos,
        Puesto,
        NoColegiado
    FROM dbo.CAT_MEDICOS_INFORMANTES
    WHERE Activo = 1
    ORDER BY Apellidos, Nombres;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_MedicoInformante_Obtener
    @IdMedicoInformante VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdMedicoInformante,
        Nombres,
        Apellidos,
        Puesto,
        NoColegiado,
        Telefono,
        Correo,
        Activo,
        FechaCreacion
    FROM dbo.CAT_MEDICOS_INFORMANTES
    WHERE IdMedicoInformante = @IdMedicoInformante;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_MedicoInformante_Guardar
    @IdMedicoInformante VARCHAR(30),
    @Nombres VARCHAR(100),
    @Apellidos VARCHAR(100),
    @Puesto VARCHAR(100) = NULL,
    @NoColegiado VARCHAR(30) = NULL,
    @Telefono VARCHAR(20) = NULL,
    @Correo VARCHAR(100) = NULL,
    @Activo BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    SET @IdMedicoInformante = NULLIF(LTRIM(RTRIM(@IdMedicoInformante)), '');
    SET @Nombres = NULLIF(LTRIM(RTRIM(@Nombres)), '');
    SET @Apellidos = NULLIF(LTRIM(RTRIM(@Apellidos)), '');
    SET @Puesto = NULLIF(LTRIM(RTRIM(@Puesto)), '');

    IF @IdMedicoInformante IS NULL
        THROW 50200, 'El código del médico informante es obligatorio.', 1;

    IF @Nombres IS NULL
        THROW 50201, 'Los nombres del médico informante son obligatorios.', 1;

    IF @Apellidos IS NULL
        THROW 50202, 'Los apellidos del médico informante son obligatorios.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.CAT_MEDICOS_INFORMANTES
        WHERE IdMedicoInformante = @IdMedicoInformante
    )
    BEGIN
        UPDATE dbo.CAT_MEDICOS_INFORMANTES
        SET Nombres = @Nombres,
            Apellidos = @Apellidos,
            Puesto = @Puesto,
            NoColegiado = NULLIF(LTRIM(RTRIM(@NoColegiado)), ''),
            Telefono = NULLIF(LTRIM(RTRIM(@Telefono)), ''),
            Correo = NULLIF(LTRIM(RTRIM(@Correo)), ''),
            Activo = @Activo
        WHERE IdMedicoInformante = @IdMedicoInformante;
    END
    ELSE
    BEGIN
        INSERT dbo.CAT_MEDICOS_INFORMANTES
        (
            IdMedicoInformante,
            Nombres,
            Apellidos,
            Puesto,
            NoColegiado,
            Telefono,
            Correo,
            Activo
        )
        VALUES
        (
            @IdMedicoInformante,
            @Nombres,
            @Apellidos,
            @Puesto,
            NULLIF(LTRIM(RTRIM(@NoColegiado)), ''),
            NULLIF(LTRIM(RTRIM(@Telefono)), ''),
            NULLIF(LTRIM(RTRIM(@Correo)), ''),
            @Activo
        );
    END;
END;
GO


/* ============================================================================
   3. ADAPTADORES PARA EL CATÁLOGO GENÉRICO
   Se usa Descripcion para transportar el campo Puesto.
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.sp_MedicoInformante_ListarUI
    @Texto VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Filtro VARCHAR(100) = NULLIF(LTRIM(RTRIM(@Texto)), '');

    SELECT
        Id = IdMedicoInformante,
        Nombre = Nombres,
        Descripcion = Puesto,
        Extra1 = Apellidos,
        Extra2 = NoColegiado,
        Extra3 = Telefono,
        Extra4 = Correo,
        Activo
    FROM dbo.CAT_MEDICOS_INFORMANTES
    WHERE @Filtro IS NULL
       OR IdMedicoInformante LIKE '%' + @Filtro + '%'
       OR Nombres LIKE '%' + @Filtro + '%'
       OR Apellidos LIKE '%' + @Filtro + '%'
       OR Puesto LIKE '%' + @Filtro + '%'
       OR NoColegiado LIKE '%' + @Filtro + '%'
    ORDER BY Apellidos, Nombres;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_MedicoInformante_ObtenerUI
    @Id VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id = IdMedicoInformante,
        Nombre = Nombres,
        Descripcion = Puesto,
        Extra1 = Apellidos,
        Extra2 = NoColegiado,
        Extra3 = Telefono,
        Extra4 = Correo,
        Activo
    FROM dbo.CAT_MEDICOS_INFORMANTES
    WHERE IdMedicoInformante = @Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_MedicoInformante_GuardarUI
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

    EXEC dbo.sp_MedicoInformante_Guardar
        @IdMedicoInformante = @Id,
        @Nombres = @Nombre,
        @Apellidos = @Extra1,
        @Puesto = @Descripcion,
        @NoColegiado = @Extra2,
        @Telefono = @Extra3,
        @Correo = @Extra4,
        @Activo = @Activo;
END;
GO


/* ============================================================================
   4. IMPRESIÓN DE LA VERSIÓN VIGENTE
   La tabla de películas/imágenes NO forma parte del informe clínico impreso.
   El segundo resultset se conserva por compatibilidad y para uso estadístico,
   aunque PdfService ya no lo renderizará.
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.sp_InformeEstudio_Impresion
    @IdDetalleCita INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IE.IdInforme,
        IE.IdDetalleCita,
        IE.NumeroVersion,
        IE.IdInternoRadiologia,
        IE.Hallazgos,
        IE.Conclusiones,
        IE.FechaHoraInforme,
        IE.FechaFinalizacion,

        C.IdCita,
        C.NumeroCita,
        C.FechaCita,
        C.HoraCita,
        C.IdPaciente,
        CONCAT(
            PAC.PrimerNombre, ' ',
            COALESCE(PAC.SegundoNombre + ' ', ''),
            PAC.PrimerApellido,
            COALESCE(' ' + PAC.SegundoApellido, '')
        ) AS Paciente,

        C.IdMedico AS IdMedicoSolicitante,
        CONCAT(MED.Nombres, ' ', MED.Apellidos) AS MedicoSolicitante,
        C.IdServicio,
        SER.NombreServicio AS Servicio,

        DC.IdPrueba,
        PR.NombrePrueba,
        CAT.NombreCategoria,
        ISNULL(PC.PartesCuerpo, '') AS PartesCuerpo,

        IE.IdTecnicoRealiza,
        CONCAT(TR.Nombres, ' ', TR.Apellidos) AS TecnicoRealiza,

        IE.IdTecnicoPosiciona,
        CONCAT(TP.Nombres, ' ', TP.Apellidos) AS TecnicoPosiciona,

        IE.IdMedicoInformante,
        CONCAT(MI.Nombres, ' ', MI.Apellidos) AS MedicoInformante,
        MI.Puesto AS PuestoMedicoInformante,
        MI.NoColegiado AS NoColegiadoInformante
    FROM dbo.INFORME_ESTUDIO IE
    INNER JOIN dbo.DETALLE_CITA DC
        ON DC.IdDetalleCita = IE.IdDetalleCita
    INNER JOIN dbo.CITA C
        ON C.IdCita = DC.IdCita
    INNER JOIN dbo.CAT_PACIENTES PAC
        ON PAC.IdPaciente = C.IdPaciente
    INNER JOIN dbo.CAT_MEDICOS MED
        ON MED.IdMedico = C.IdMedico
    INNER JOIN dbo.CAT_SERVICIOS_HOSPITALARIOS SER
        ON SER.IdServicio = C.IdServicio
    INNER JOIN dbo.CAT_PRUEBAS PR
        ON PR.IdPrueba = DC.IdPrueba
    INNER JOIN dbo.CAT_CATEGORIAS_PRUEBAS CAT
        ON CAT.IdCategoria = PR.IdCategoria
    INNER JOIN dbo.CAT_TECNICOS_RADIOLOGOS TR
        ON TR.IdTecnico = IE.IdTecnicoRealiza
    INNER JOIN dbo.CAT_TECNICOS_RADIOLOGOS TP
        ON TP.IdTecnico = IE.IdTecnicoPosiciona
    INNER JOIN dbo.CAT_MEDICOS_INFORMANTES MI
        ON MI.IdMedicoInformante = IE.IdMedicoInformante
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
    WHERE IE.IdDetalleCita = @IdDetalleCita
      AND IE.Estado = 'FINALIZADO'
      AND C.Estado = 'ATENDIDA'
      AND DC.Estado = 'REALIZADO'
      AND C.Activo = 1;

    /* Se conserva para estadísticas/reportes mensuales. */
    SELECT
        R.TamanoPelicula,
        R.PeliculasEntregadas,
        R.ImagenesDigitales,
        R.SistemaAdquisicionCDDR
    FROM dbo.INFORME_ESTUDIO_RECURSOS R
    INNER JOIN dbo.INFORME_ESTUDIO IE
        ON IE.IdInforme = R.IdInforme
    WHERE IE.IdDetalleCita = @IdDetalleCita
      AND IE.Estado = 'FINALIZADO'
    ORDER BY CASE R.TamanoPelicula
        WHEN '8x10' THEN 1
        WHEN '10x14' THEN 2
        WHEN '14x17' THEN 3
        ELSE 4
    END;
END;
GO


/* ============================================================================
   5. VERIFICACIÓN
   ============================================================================ */
SELECT
    CampoPuesto =
        CASE WHEN COL_LENGTH('dbo.CAT_MEDICOS_INFORMANTES', 'Puesto') IS NOT NULL
             THEN 'OK' ELSE 'FALTA' END,
    CatalogoUI =
        CASE WHEN OBJECT_ID(N'dbo.sp_MedicoInformante_GuardarUI', N'P') IS NOT NULL
             THEN 'OK' ELSE 'FALTA' END,
    Impresion =
        CASE WHEN OBJECT_ID(N'dbo.sp_InformeEstudio_Impresion', N'P') IS NOT NULL
             THEN 'OK' ELSE 'FALTA' END;
GO

PRINT 'Ajuste de formato de informe instalado correctamente.';
PRINT 'REF. VR/BH permanece fijo temporalmente.';
PRINT 'Los recursos de películas/imágenes se conservan en base de datos pero ya no se imprimen.';
GO
