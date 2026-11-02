USE RIS_HRO;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ============================================================================
   RIS_HRO - REQUERIMIENTO 2 - FASE 3
   Creación, edición, borrador, finalización y corrección de informes por estudio.

   PRERREQUISITOS
   - 07_REQUERIMIENTO_2_FASE1_BASE_DATOS.sql
   - 08_REQUERIMIENTO_2_FASE2_ATENCION_ESTUDIOS.sql

   SCRIPT INCREMENTAL: NO elimina ni recrea la base de datos.
   ============================================================================ */

/* ============================================================================
   1. TVP PARA LAS TRES FILAS FIJAS DE PELÍCULAS / IMÁGENES
   ============================================================================ */
IF TYPE_ID(N'dbo.TVP_InformeRecurso') IS NULL
BEGIN
    EXEC(N'
        CREATE TYPE dbo.TVP_InformeRecurso AS TABLE
        (
            TamanoPelicula VARCHAR(10) NOT NULL PRIMARY KEY,
            PeliculasEntregadas INT NOT NULL,
            ImagenesDigitales INT NOT NULL,
            SistemaAdquisicionCDDR VARCHAR(100) NULL
        );
    ');
END;
GO

/* ============================================================================
   2. ADAPTADORES PARA EL CATÁLOGO GENÉRICO DE MÉDICOS INFORMANTES
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
        Descripcion = CAST(NULL AS VARCHAR(250)),
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
        Descripcion = CAST(NULL AS VARCHAR(250)),
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
        @NoColegiado = @Extra2,
        @Telefono = @Extra3,
        @Correo = @Extra4,
        @Activo = @Activo;
END;
GO

/* Lista simple para los selectores del informe. */
CREATE OR ALTER PROCEDURE dbo.sp_Tecnico_ListarActivos
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdTecnico,
        CONCAT(Nombres, ' ', Apellidos) AS NombreCompleto
    FROM dbo.CAT_TECNICOS_RADIOLOGOS
    WHERE Activo = 1
    ORDER BY Apellidos, Nombres;
END;
GO

/* ============================================================================
   3. OBTENER CONTEXTO + VERSIÓN VIGENTE DEL INFORME
   Resultset 1: contexto, estudio e informe vigente.
   Resultset 2: filas fijas 8x10, 10x14, 14x17.
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.sp_InformeEstudio_Obtener
    @IdDetalleCita INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        DC.IdDetalleCita,
        C.IdCita,
        C.NumeroCita,
        C.Estado AS EstadoCita,
        C.FechaCita,
        C.HoraCita,
        C.IdPaciente,
        CONCAT(
            PCT.PrimerNombre, ' ',
            COALESCE(PCT.SegundoNombre + ' ', ''),
            PCT.PrimerApellido,
            COALESCE(' ' + PCT.SegundoApellido, '')
        ) AS Paciente,
        DC.IdPrueba,
        PR.NombrePrueba,
        CAT.NombreCategoria,
        DC.Estado AS EstadoEstudio,
        ISNULL(PC.PartesCuerpo, '') AS PartesCuerpo,

        IE.IdInforme,
        IE.IdInternoRadiologia,
        IE.Hallazgos,
        IE.Conclusiones,
        IE.IdTecnicoRealiza,
        IE.IdTecnicoPosiciona,
        IE.IdMedicoInformante,
        IE.FechaHoraInforme,
        IE.Estado AS EstadoInforme,
        IE.NumeroVersion,
        IE.FechaFinalizacion,
        IE.IdUsuarioFinalizacion,
        IE.IdUsuarioCreacion,
        IE.FechaCreacion,
        IE.IdUsuarioModificacion,
        IE.FechaModificacion
    FROM dbo.DETALLE_CITA DC
    INNER JOIN dbo.CITA C
        ON C.IdCita = DC.IdCita
    INNER JOIN dbo.CAT_PACIENTES PCT
        ON PCT.IdPaciente = C.IdPaciente
    INNER JOIN dbo.CAT_PRUEBAS PR
        ON PR.IdPrueba = DC.IdPrueba
    INNER JOIN dbo.CAT_CATEGORIAS_PRUEBAS CAT
        ON CAT.IdCategoria = PR.IdCategoria
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
    WHERE DC.IdDetalleCita = @IdDetalleCita
      AND C.Activo = 1;

    ;WITH Tamanos AS
    (
        SELECT 1 AS Orden, CAST('8x10' AS VARCHAR(10)) AS TamanoPelicula
        UNION ALL SELECT 2, '10x14'
        UNION ALL SELECT 3, '14x17'
    )
    SELECT
        T.TamanoPelicula,
        ISNULL(R.PeliculasEntregadas, 0) AS PeliculasEntregadas,
        ISNULL(R.ImagenesDigitales, 0) AS ImagenesDigitales,
        R.SistemaAdquisicionCDDR
    FROM Tamanos T
    LEFT JOIN dbo.INFORME_ESTUDIO IE
        ON IE.IdDetalleCita = @IdDetalleCita
    LEFT JOIN dbo.INFORME_ESTUDIO_RECURSOS R
        ON R.IdInforme = IE.IdInforme
       AND R.TamanoPelicula = T.TamanoPelicula
    ORDER BY T.Orden;
END;
GO

/* ============================================================================
   4. GUARDAR BORRADOR / FINALIZAR INFORME
   - Solo para cita ATENDIDA + estudio REALIZADO.
   - Un FINALIZADO no se edita directamente: primero se inicia corrección.
   - Finalizar exige todos los campos principales.
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.sp_InformeEstudio_Guardar
    @IdDetalleCita INT,
    @IdInternoRadiologia VARCHAR(50) = NULL,
    @Hallazgos NVARCHAR(MAX) = NULL,
    @Conclusiones NVARCHAR(MAX) = NULL,
    @IdTecnicoRealiza VARCHAR(30) = NULL,
    @IdTecnicoPosiciona VARCHAR(30) = NULL,
    @IdMedicoInformante VARCHAR(30) = NULL,
    @FechaHoraInforme DATETIME2(0) = NULL,
    @IdUsuario VARCHAR(30),
    @Finalizar BIT,
    @Recursos dbo.TVP_InformeRecurso READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @IdInternoRadiologia = NULLIF(LTRIM(RTRIM(@IdInternoRadiologia)), '');
    SET @IdTecnicoRealiza = NULLIF(LTRIM(RTRIM(@IdTecnicoRealiza)), '');
    SET @IdTecnicoPosiciona = NULLIF(LTRIM(RTRIM(@IdTecnicoPosiciona)), '');
    SET @IdMedicoInformante = NULLIF(LTRIM(RTRIM(@IdMedicoInformante)), '');

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.CAT_USUARIOS
        WHERE IdUsuario = @IdUsuario
          AND Activo = 1
    )
        THROW 50400, 'El usuario no existe o se encuentra inactivo.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.DETALLE_CITA DC
        INNER JOIN dbo.CITA C ON C.IdCita = DC.IdCita
        WHERE DC.IdDetalleCita = @IdDetalleCita
          AND C.Activo = 1
          AND C.Estado = 'ATENDIDA'
          AND DC.Estado = 'REALIZADO'
    )
        THROW 50401, 'El informe solo puede registrarse para un estudio REALIZADO de una cita ATENDIDA.', 1;

    DECLARE @IdInforme INT =
    (
        SELECT IdInforme
        FROM dbo.INFORME_ESTUDIO
        WHERE IdDetalleCita = @IdDetalleCita
    );

    IF @IdInforme IS NOT NULL
       AND EXISTS
       (
           SELECT 1
           FROM dbo.INFORME_ESTUDIO
           WHERE IdInforme = @IdInforme
             AND Estado = 'FINALIZADO'
       )
        THROW 50402, 'El informe está FINALIZADO. Debe iniciar una corrección antes de modificarlo.', 1;

    IF @IdTecnicoRealiza IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1 FROM dbo.CAT_TECNICOS_RADIOLOGOS
           WHERE IdTecnico = @IdTecnicoRealiza AND Activo = 1
       )
        THROW 50403, 'El técnico que realizó el estudio no existe o está inactivo.', 1;

    IF @IdTecnicoPosiciona IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1 FROM dbo.CAT_TECNICOS_RADIOLOGOS
           WHERE IdTecnico = @IdTecnicoPosiciona AND Activo = 1
       )
        THROW 50404, 'El técnico que posicionó al paciente no existe o está inactivo.', 1;

    IF @IdMedicoInformante IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1 FROM dbo.CAT_MEDICOS_INFORMANTES
           WHERE IdMedicoInformante = @IdMedicoInformante AND Activo = 1
       )
        THROW 50405, 'El médico informante no existe o está inactivo.', 1;

    /* El mismo ID interno puede mantenerse entre versiones del MISMO informe,
       pero nunca pertenecer a otro estudio/informe. */
    IF @IdInternoRadiologia IS NOT NULL
       AND
       (
           EXISTS
           (
               SELECT 1
               FROM dbo.INFORME_ESTUDIO IE
               WHERE IE.IdInternoRadiologia = @IdInternoRadiologia
                 AND (@IdInforme IS NULL OR IE.IdInforme <> @IdInforme)
           )
           OR EXISTS
           (
               SELECT 1
               FROM dbo.INFORME_ESTUDIO_HISTORIAL H
               WHERE H.IdInternoRadiologia = @IdInternoRadiologia
                 AND (@IdInforme IS NULL OR H.IdInforme <> @IdInforme)
           )
       )
        THROW 50406, 'El ID interno de radiología ya está asignado a otro estudio.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @Recursos
        WHERE TamanoPelicula NOT IN ('8x10','10x14','14x17')
           OR PeliculasEntregadas < 0
           OR ImagenesDigitales < 0
    )
        THROW 50407, 'Los datos de películas e imágenes no son válidos.', 1;

    IF @Finalizar = 1
    BEGIN
        IF @IdInternoRadiologia IS NULL
            THROW 50410, 'El ID interno de radiología es obligatorio para finalizar.', 1;
        IF NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(MAX), @Hallazgos))), '') IS NULL
            THROW 50411, 'Los hallazgos son obligatorios para finalizar.', 1;
        IF NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(MAX), @Conclusiones))), '') IS NULL
            THROW 50412, 'Las conclusiones son obligatorias para finalizar.', 1;
        IF @IdTecnicoRealiza IS NULL
            THROW 50413, 'Debe seleccionar el técnico que realizó el estudio.', 1;
        IF @IdTecnicoPosiciona IS NULL
            THROW 50414, 'Debe seleccionar el técnico que posicionó al paciente.', 1;
        IF @IdMedicoInformante IS NULL
            THROW 50415, 'Debe seleccionar el médico informante.', 1;
        IF @FechaHoraInforme IS NULL
            THROW 50416, 'La fecha y hora del informe son obligatorias.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM @Recursos
            WHERE (PeliculasEntregadas > 0 OR ImagenesDigitales > 0)
              AND NULLIF(LTRIM(RTRIM(SistemaAdquisicionCDDR)), '') IS NULL
        )
            THROW 50417, 'Complete el sistema de adquisición CD/DR en las filas utilizadas.', 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @IdInforme IS NULL
        BEGIN
            INSERT dbo.INFORME_ESTUDIO
            (
                IdDetalleCita,
                IdInternoRadiologia,
                Hallazgos,
                Conclusiones,
                IdTecnicoRealiza,
                IdTecnicoPosiciona,
                IdMedicoInformante,
                FechaHoraInforme,
                Estado,
                NumeroVersion,
                FechaFinalizacion,
                IdUsuarioFinalizacion,
                IdUsuarioCreacion
            )
            VALUES
            (
                @IdDetalleCita,
                @IdInternoRadiologia,
                @Hallazgos,
                @Conclusiones,
                @IdTecnicoRealiza,
                @IdTecnicoPosiciona,
                @IdMedicoInformante,
                @FechaHoraInforme,
                CASE WHEN @Finalizar = 1 THEN 'FINALIZADO' ELSE 'BORRADOR' END,
                1,
                CASE WHEN @Finalizar = 1 THEN SYSDATETIME() ELSE NULL END,
                CASE WHEN @Finalizar = 1 THEN @IdUsuario ELSE NULL END,
                @IdUsuario
            );

            SET @IdInforme = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE dbo.INFORME_ESTUDIO
            SET IdInternoRadiologia = @IdInternoRadiologia,
                Hallazgos = @Hallazgos,
                Conclusiones = @Conclusiones,
                IdTecnicoRealiza = @IdTecnicoRealiza,
                IdTecnicoPosiciona = @IdTecnicoPosiciona,
                IdMedicoInformante = @IdMedicoInformante,
                FechaHoraInforme = @FechaHoraInforme,
                Estado = CASE WHEN @Finalizar = 1 THEN 'FINALIZADO' ELSE 'BORRADOR' END,
                FechaFinalizacion = CASE WHEN @Finalizar = 1 THEN SYSDATETIME() ELSE NULL END,
                IdUsuarioFinalizacion = CASE WHEN @Finalizar = 1 THEN @IdUsuario ELSE NULL END,
                IdUsuarioModificacion = @IdUsuario,
                FechaModificacion = SYSDATETIME()
            WHERE IdInforme = @IdInforme;
        END;

        DELETE FROM dbo.INFORME_ESTUDIO_RECURSOS
        WHERE IdInforme = @IdInforme;

        ;WITH Tamanos AS
        (
            SELECT CAST('8x10' AS VARCHAR(10)) AS TamanoPelicula
            UNION ALL SELECT '10x14'
            UNION ALL SELECT '14x17'
        )
        INSERT dbo.INFORME_ESTUDIO_RECURSOS
        (
            IdInforme,
            TamanoPelicula,
            PeliculasEntregadas,
            ImagenesDigitales,
            SistemaAdquisicionCDDR
        )
        SELECT
            @IdInforme,
            T.TamanoPelicula,
            ISNULL(R.PeliculasEntregadas, 0),
            ISNULL(R.ImagenesDigitales, 0),
            NULLIF(LTRIM(RTRIM(R.SistemaAdquisicionCDDR)), '')
        FROM Tamanos T
        LEFT JOIN @Recursos R
            ON R.TamanoPelicula = T.TamanoPelicula;

        COMMIT;

        SELECT
            IdInforme,
            Estado,
            NumeroVersion,
            FechaFinalizacion
        FROM dbo.INFORME_ESTUDIO
        WHERE IdInforme = @IdInforme;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

/* ============================================================================
   5. INICIAR CORRECCIÓN DE UN INFORME FINALIZADO
   - Archiva la versión finalizada actual.
   - Archiva también sus tres filas de recursos.
   - La versión vigente pasa a BORRADOR con NumeroVersion + 1.
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.sp_InformeEstudio_IniciarCorreccion
    @IdDetalleCita INT,
    @IdUsuario VARCHAR(30)
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
        THROW 50430, 'El usuario no existe o se encuentra inactivo.', 1;

    DECLARE @IdInforme INT;
    DECLARE @VersionActual INT;

    SELECT
        @IdInforme = IE.IdInforme,
        @VersionActual = IE.NumeroVersion
    FROM dbo.INFORME_ESTUDIO IE
    INNER JOIN dbo.DETALLE_CITA DC
        ON DC.IdDetalleCita = IE.IdDetalleCita
    INNER JOIN dbo.CITA C
        ON C.IdCita = DC.IdCita
    WHERE IE.IdDetalleCita = @IdDetalleCita
      AND IE.Estado = 'FINALIZADO'
      AND DC.Estado = 'REALIZADO'
      AND C.Estado = 'ATENDIDA'
      AND C.Activo = 1;

    IF @IdInforme IS NULL
        THROW 50431, 'No existe un informe FINALIZADO disponible para iniciar corrección.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.INFORME_ESTUDIO_HISTORIAL
            WHERE IdInforme = @IdInforme
              AND NumeroVersion = @VersionActual
        )
            THROW 50432, 'La versión actual ya fue archivada anteriormente.', 1;

        DECLARE @Archivado TABLE (IdInformeHistorial INT);

        INSERT dbo.INFORME_ESTUDIO_HISTORIAL
        (
            IdInforme,
            IdDetalleCita,
            NumeroVersion,
            IdInternoRadiologia,
            Hallazgos,
            Conclusiones,
            IdTecnicoRealiza,
            IdTecnicoPosiciona,
            IdMedicoInformante,
            FechaHoraInforme,
            Estado,
            FechaFinalizacion,
            IdUsuarioFinalizacion,
            IdUsuarioCreacion,
            FechaCreacion,
            IdUsuarioModificacion,
            FechaModificacion,
            IdUsuarioArchivado,
            MotivoArchivado
        )
        OUTPUT inserted.IdInformeHistorial INTO @Archivado(IdInformeHistorial)
        SELECT
            IE.IdInforme,
            IE.IdDetalleCita,
            IE.NumeroVersion,
            IE.IdInternoRadiologia,
            IE.Hallazgos,
            IE.Conclusiones,
            IE.IdTecnicoRealiza,
            IE.IdTecnicoPosiciona,
            IE.IdMedicoInformante,
            IE.FechaHoraInforme,
            IE.Estado,
            IE.FechaFinalizacion,
            IE.IdUsuarioFinalizacion,
            IE.IdUsuarioCreacion,
            IE.FechaCreacion,
            IE.IdUsuarioModificacion,
            IE.FechaModificacion,
            @IdUsuario,
            'Corrección de informe finalizado'
        FROM dbo.INFORME_ESTUDIO IE
        WHERE IE.IdInforme = @IdInforme;

        DECLARE @IdInformeHistorial INT =
            (SELECT TOP (1) IdInformeHistorial FROM @Archivado);

        INSERT dbo.INFORME_ESTUDIO_RECURSOS_HISTORIAL
        (
            IdInformeHistorial,
            TamanoPelicula,
            PeliculasEntregadas,
            ImagenesDigitales,
            SistemaAdquisicionCDDR
        )
        SELECT
            @IdInformeHistorial,
            R.TamanoPelicula,
            R.PeliculasEntregadas,
            R.ImagenesDigitales,
            R.SistemaAdquisicionCDDR
        FROM dbo.INFORME_ESTUDIO_RECURSOS R
        WHERE R.IdInforme = @IdInforme;

        UPDATE dbo.INFORME_ESTUDIO
        SET Estado = 'BORRADOR',
            NumeroVersion = NumeroVersion + 1,
            FechaFinalizacion = NULL,
            IdUsuarioFinalizacion = NULL,
            IdUsuarioModificacion = @IdUsuario,
            FechaModificacion = SYSDATETIME()
        WHERE IdInforme = @IdInforme;

        COMMIT;

        SELECT
            IdInforme,
            Estado,
            NumeroVersion
        FROM dbo.INFORME_ESTUDIO
        WHERE IdInforme = @IdInforme;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

/* ============================================================================
   6. VERIFICACIÓN
   ============================================================================ */
SELECT
    TipoRecursos = CASE WHEN TYPE_ID(N'dbo.TVP_InformeRecurso') IS NOT NULL THEN 'OK' ELSE 'FALTA' END,
    ObtenerInforme = CASE WHEN OBJECT_ID(N'dbo.sp_InformeEstudio_Obtener', N'P') IS NOT NULL THEN 'OK' ELSE 'FALTA' END,
    GuardarInforme = CASE WHEN OBJECT_ID(N'dbo.sp_InformeEstudio_Guardar', N'P') IS NOT NULL THEN 'OK' ELSE 'FALTA' END,
    IniciarCorreccion = CASE WHEN OBJECT_ID(N'dbo.sp_InformeEstudio_IniciarCorreccion', N'P') IS NOT NULL THEN 'OK' ELSE 'FALTA' END,
    CatalogoInformantesUI = CASE WHEN OBJECT_ID(N'dbo.sp_MedicoInformante_ListarUI', N'P') IS NOT NULL THEN 'OK' ELSE 'FALTA' END,
    TecnicosActivos = CASE WHEN OBJECT_ID(N'dbo.sp_Tecnico_ListarActivos', N'P') IS NOT NULL THEN 'OK' ELSE 'FALTA' END;
GO

PRINT 'Requerimiento 2 - Fase 3 instalada correctamente.';
GO
