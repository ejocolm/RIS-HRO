USE RIS_HRO;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ============================================================================
   RIS_HRO - REQUERIMIENTO 2 - FASE 1
   Estructura base para informes radiológicos por estudio

   SCRIPT INCREMENTAL
   - NO elimina ni recrea la base de datos.
   - Conserva los datos existentes.

   IMPORTANTE
   Todavía NO se modifica el flujo actual de sp_Cita_CambiarEstado.
   La selección de estudios REALIZADO / NO_REALIZADO se integrará junto con
   backend e interfaz en la siguiente fase para no romper la aplicación actual.
   ============================================================================ */

/* 1. NUEVO ROL: USUARIO_INFORMES */
IF NOT EXISTS (SELECT 1 FROM dbo.CAT_ROLES WHERE NombreRol='USUARIO_INFORMES')
BEGIN
    INSERT dbo.CAT_ROLES(NombreRol,Descripcion,Activo)
    VALUES('USUARIO_INFORMES','Acceso operativo a citas e informes radiológicos',1);
END
ELSE
BEGIN
    UPDATE dbo.CAT_ROLES
    SET Descripcion='Acceso operativo a citas e informes radiológicos',Activo=1
    WHERE NombreRol='USUARIO_INFORMES';
END;
GO

/* 2. CATÁLOGO DE MÉDICOS INFORMANTES */
IF OBJECT_ID(N'dbo.CAT_MEDICOS_INFORMANTES',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.CAT_MEDICOS_INFORMANTES
    (
        IdMedicoInformante VARCHAR(30) NOT NULL,
        Nombres VARCHAR(100) NOT NULL,
        Apellidos VARCHAR(100) NOT NULL,
        NoColegiado VARCHAR(30) NULL,
        Telefono VARCHAR(20) NULL,
        Correo VARCHAR(100) NULL,
        Activo BIT NOT NULL CONSTRAINT DF_CAT_MEDICOS_INFORMANTES_Activo DEFAULT(1),
        FechaCreacion DATETIME2(0) NOT NULL CONSTRAINT DF_CAT_MEDICOS_INFORMANTES_Fecha DEFAULT(SYSDATETIME()),
        CONSTRAINT PK_CAT_MEDICOS_INFORMANTES PRIMARY KEY(IdMedicoInformante)
    );
END;
GO

IF NOT EXISTS(
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'dbo.CAT_MEDICOS_INFORMANTES')
      AND name=N'IX_CAT_MEDICOS_INFORMANTES_Nombre')
BEGIN
    CREATE INDEX IX_CAT_MEDICOS_INFORMANTES_Nombre
    ON dbo.CAT_MEDICOS_INFORMANTES(Apellidos,Nombres)
    INCLUDE(NoColegiado,Activo);
END;
GO

/* 3. NUEVO ESTADO NO_REALIZADO EN DETALLE_CITA */
IF OBJECT_ID(N'dbo.CK_DETALLE_CITA_Estado',N'C') IS NOT NULL
BEGIN
    ALTER TABLE dbo.DETALLE_CITA DROP CONSTRAINT CK_DETALLE_CITA_Estado;
END;
GO

ALTER TABLE dbo.DETALLE_CITA WITH CHECK
ADD CONSTRAINT CK_DETALLE_CITA_Estado
CHECK(Estado IN ('PENDIENTE','REALIZADO','NO_REALIZADO','CANCELADO'));
GO

/* 4. INFORME VIGENTE POR ESTUDIO */
IF OBJECT_ID(N'dbo.INFORME_ESTUDIO',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.INFORME_ESTUDIO
    (
        IdInforme INT IDENTITY(1,1) NOT NULL,
        IdDetalleCita INT NOT NULL,
        IdInternoRadiologia VARCHAR(50) NULL,
        Hallazgos NVARCHAR(MAX) NULL,
        Conclusiones NVARCHAR(MAX) NULL,
        IdTecnicoRealiza VARCHAR(30) NULL,
        IdTecnicoPosiciona VARCHAR(30) NULL,
        IdMedicoInformante VARCHAR(30) NULL,
        FechaHoraInforme DATETIME2(0) NULL CONSTRAINT DF_INFORME_ESTUDIO_FechaHoraInforme DEFAULT(SYSDATETIME()),
        Estado VARCHAR(20) NOT NULL CONSTRAINT DF_INFORME_ESTUDIO_Estado DEFAULT('BORRADOR'),
        NumeroVersion INT NOT NULL CONSTRAINT DF_INFORME_ESTUDIO_NumeroVersion DEFAULT(1),
        FechaFinalizacion DATETIME2(0) NULL,
        IdUsuarioFinalizacion VARCHAR(30) NULL,
        IdUsuarioCreacion VARCHAR(30) NOT NULL,
        FechaCreacion DATETIME2(0) NOT NULL CONSTRAINT DF_INFORME_ESTUDIO_FechaCreacion DEFAULT(SYSDATETIME()),
        IdUsuarioModificacion VARCHAR(30) NULL,
        FechaModificacion DATETIME2(0) NULL,

        CONSTRAINT PK_INFORME_ESTUDIO PRIMARY KEY(IdInforme),
        CONSTRAINT UQ_INFORME_ESTUDIO_Detalle UNIQUE(IdDetalleCita),
        CONSTRAINT FK_INFORME_ESTUDIO_Detalle FOREIGN KEY(IdDetalleCita) REFERENCES dbo.DETALLE_CITA(IdDetalleCita),
        CONSTRAINT FK_INFORME_ESTUDIO_TecnicoRealiza FOREIGN KEY(IdTecnicoRealiza) REFERENCES dbo.CAT_TECNICOS_RADIOLOGOS(IdTecnico),
        CONSTRAINT FK_INFORME_ESTUDIO_TecnicoPosiciona FOREIGN KEY(IdTecnicoPosiciona) REFERENCES dbo.CAT_TECNICOS_RADIOLOGOS(IdTecnico),
        CONSTRAINT FK_INFORME_ESTUDIO_MedicoInformante FOREIGN KEY(IdMedicoInformante) REFERENCES dbo.CAT_MEDICOS_INFORMANTES(IdMedicoInformante),
        CONSTRAINT FK_INFORME_ESTUDIO_UsuarioCreacion FOREIGN KEY(IdUsuarioCreacion) REFERENCES dbo.CAT_USUARIOS(IdUsuario),
        CONSTRAINT FK_INFORME_ESTUDIO_UsuarioModificacion FOREIGN KEY(IdUsuarioModificacion) REFERENCES dbo.CAT_USUARIOS(IdUsuario),
        CONSTRAINT FK_INFORME_ESTUDIO_UsuarioFinalizacion FOREIGN KEY(IdUsuarioFinalizacion) REFERENCES dbo.CAT_USUARIOS(IdUsuario),
        CONSTRAINT CK_INFORME_ESTUDIO_Estado CHECK(Estado IN ('BORRADOR','FINALIZADO')),
        CONSTRAINT CK_INFORME_ESTUDIO_NumeroVersion CHECK(NumeroVersion>=1),
        CONSTRAINT CK_INFORME_ESTUDIO_FinalizadoCompleto CHECK
        (
            Estado='BORRADOR'
            OR
            (
                NULLIF(LTRIM(RTRIM(IdInternoRadiologia)),'') IS NOT NULL
                AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(MAX),Hallazgos))),'') IS NOT NULL
                AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(MAX),Conclusiones))),'') IS NOT NULL
                AND IdTecnicoRealiza IS NOT NULL
                AND IdTecnicoPosiciona IS NOT NULL
                AND IdMedicoInformante IS NOT NULL
                AND FechaHoraInforme IS NOT NULL
                AND FechaFinalizacion IS NOT NULL
                AND IdUsuarioFinalizacion IS NOT NULL
            )
        )
    );
END;
GO

IF NOT EXISTS(
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'dbo.INFORME_ESTUDIO')
      AND name=N'UX_INFORME_ESTUDIO_IdInternoRadiologia')
BEGIN
    CREATE UNIQUE INDEX UX_INFORME_ESTUDIO_IdInternoRadiologia
    ON dbo.INFORME_ESTUDIO(IdInternoRadiologia)
    WHERE IdInternoRadiologia IS NOT NULL;
END;
GO

IF NOT EXISTS(
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'dbo.INFORME_ESTUDIO')
      AND name=N'IX_INFORME_ESTUDIO_Estado')
BEGIN
    CREATE INDEX IX_INFORME_ESTUDIO_Estado
    ON dbo.INFORME_ESTUDIO(Estado,IdDetalleCita)
    INCLUDE(NumeroVersion,IdInternoRadiologia,FechaHoraInforme);
END;
GO

/* 5. RECURSOS / PELÍCULAS DE LA VERSIÓN VIGENTE */
IF OBJECT_ID(N'dbo.INFORME_ESTUDIO_RECURSOS',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.INFORME_ESTUDIO_RECURSOS
    (
        IdRecurso INT IDENTITY(1,1) NOT NULL,
        IdInforme INT NOT NULL,
        TamanoPelicula VARCHAR(10) NOT NULL,
        PeliculasEntregadas INT NOT NULL CONSTRAINT DF_INFORME_RECURSOS_Peliculas DEFAULT(0),
        ImagenesDigitales INT NOT NULL CONSTRAINT DF_INFORME_RECURSOS_Imagenes DEFAULT(0),
        SistemaAdquisicionCDDR VARCHAR(100) NULL,

        CONSTRAINT PK_INFORME_ESTUDIO_RECURSOS PRIMARY KEY(IdRecurso),
        CONSTRAINT FK_INFORME_RECURSOS_Informe FOREIGN KEY(IdInforme) REFERENCES dbo.INFORME_ESTUDIO(IdInforme) ON DELETE CASCADE,
        CONSTRAINT UQ_INFORME_RECURSOS_InformeTamano UNIQUE(IdInforme,TamanoPelicula),
        CONSTRAINT CK_INFORME_RECURSOS_Tamano CHECK(TamanoPelicula IN ('8x10','10x14','14x17')),
        CONSTRAINT CK_INFORME_RECURSOS_Peliculas CHECK(PeliculasEntregadas>=0),
        CONSTRAINT CK_INFORME_RECURSOS_Imagenes CHECK(ImagenesDigitales>=0)
    );
END;
GO

/* 6. HISTORIAL DE VERSIONES DEL INFORME */
IF OBJECT_ID(N'dbo.INFORME_ESTUDIO_HISTORIAL',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.INFORME_ESTUDIO_HISTORIAL
    (
        IdInformeHistorial INT IDENTITY(1,1) NOT NULL,
        IdInforme INT NOT NULL,
        IdDetalleCita INT NOT NULL,
        NumeroVersion INT NOT NULL,
        IdInternoRadiologia VARCHAR(50) NULL,
        Hallazgos NVARCHAR(MAX) NULL,
        Conclusiones NVARCHAR(MAX) NULL,
        IdTecnicoRealiza VARCHAR(30) NULL,
        IdTecnicoPosiciona VARCHAR(30) NULL,
        IdMedicoInformante VARCHAR(30) NULL,
        FechaHoraInforme DATETIME2(0) NULL,
        Estado VARCHAR(20) NOT NULL,
        FechaFinalizacion DATETIME2(0) NULL,
        IdUsuarioFinalizacion VARCHAR(30) NULL,
        IdUsuarioCreacion VARCHAR(30) NOT NULL,
        FechaCreacion DATETIME2(0) NOT NULL,
        IdUsuarioModificacion VARCHAR(30) NULL,
        FechaModificacion DATETIME2(0) NULL,
        IdUsuarioArchivado VARCHAR(30) NOT NULL,
        FechaArchivado DATETIME2(0) NOT NULL CONSTRAINT DF_INFORME_HIST_FechaArchivado DEFAULT(SYSDATETIME()),
        MotivoArchivado VARCHAR(250) NULL,

        CONSTRAINT PK_INFORME_ESTUDIO_HISTORIAL PRIMARY KEY(IdInformeHistorial),
        CONSTRAINT FK_INFORME_HIST_Informe FOREIGN KEY(IdInforme) REFERENCES dbo.INFORME_ESTUDIO(IdInforme),
        CONSTRAINT FK_INFORME_HIST_Detalle FOREIGN KEY(IdDetalleCita) REFERENCES dbo.DETALLE_CITA(IdDetalleCita),
        CONSTRAINT FK_INFORME_HIST_TecnicoRealiza FOREIGN KEY(IdTecnicoRealiza) REFERENCES dbo.CAT_TECNICOS_RADIOLOGOS(IdTecnico),
        CONSTRAINT FK_INFORME_HIST_TecnicoPosiciona FOREIGN KEY(IdTecnicoPosiciona) REFERENCES dbo.CAT_TECNICOS_RADIOLOGOS(IdTecnico),
        CONSTRAINT FK_INFORME_HIST_MedicoInformante FOREIGN KEY(IdMedicoInformante) REFERENCES dbo.CAT_MEDICOS_INFORMANTES(IdMedicoInformante),
        CONSTRAINT FK_INFORME_HIST_UsuarioCreacion FOREIGN KEY(IdUsuarioCreacion) REFERENCES dbo.CAT_USUARIOS(IdUsuario),
        CONSTRAINT FK_INFORME_HIST_UsuarioModificacion FOREIGN KEY(IdUsuarioModificacion) REFERENCES dbo.CAT_USUARIOS(IdUsuario),
        CONSTRAINT FK_INFORME_HIST_UsuarioFinalizacion FOREIGN KEY(IdUsuarioFinalizacion) REFERENCES dbo.CAT_USUARIOS(IdUsuario),
        CONSTRAINT FK_INFORME_HIST_UsuarioArchivado FOREIGN KEY(IdUsuarioArchivado) REFERENCES dbo.CAT_USUARIOS(IdUsuario),
        CONSTRAINT UQ_INFORME_HIST_InformeVersion UNIQUE(IdInforme,NumeroVersion),
        CONSTRAINT CK_INFORME_HIST_NumeroVersion CHECK(NumeroVersion>=1),
        CONSTRAINT CK_INFORME_HIST_Estado CHECK(Estado IN ('BORRADOR','FINALIZADO'))
    );
END;
GO

IF NOT EXISTS(
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'dbo.INFORME_ESTUDIO_HISTORIAL')
      AND name=N'IX_INFORME_HIST_DetalleVersion')
BEGIN
    CREATE INDEX IX_INFORME_HIST_DetalleVersion
    ON dbo.INFORME_ESTUDIO_HISTORIAL(IdDetalleCita,NumeroVersion DESC);
END;
GO

/* 7. RECURSOS DE LAS VERSIONES HISTÓRICAS */
IF OBJECT_ID(N'dbo.INFORME_ESTUDIO_RECURSOS_HISTORIAL',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.INFORME_ESTUDIO_RECURSOS_HISTORIAL
    (
        IdRecursoHistorial INT IDENTITY(1,1) NOT NULL,
        IdInformeHistorial INT NOT NULL,
        TamanoPelicula VARCHAR(10) NOT NULL,
        PeliculasEntregadas INT NOT NULL,
        ImagenesDigitales INT NOT NULL,
        SistemaAdquisicionCDDR VARCHAR(100) NULL,

        CONSTRAINT PK_INFORME_RECURSOS_HIST PRIMARY KEY(IdRecursoHistorial),
        CONSTRAINT FK_INFORME_RECURSOS_HIST_InformeHist FOREIGN KEY(IdInformeHistorial) REFERENCES dbo.INFORME_ESTUDIO_HISTORIAL(IdInformeHistorial) ON DELETE CASCADE,
        CONSTRAINT UQ_INFORME_RECURSOS_HIST_Tamano UNIQUE(IdInformeHistorial,TamanoPelicula),
        CONSTRAINT CK_INFORME_RECURSOS_HIST_Tamano CHECK(TamanoPelicula IN ('8x10','10x14','14x17')),
        CONSTRAINT CK_INFORME_RECURSOS_HIST_Peliculas CHECK(PeliculasEntregadas>=0),
        CONSTRAINT CK_INFORME_RECURSOS_HIST_Imagenes CHECK(ImagenesDigitales>=0)
    );
END;
GO

/* 8. TRAZABILIDAD DEL ESTADO DE CADA ESTUDIO */
IF OBJECT_ID(N'dbo.HISTORIAL_ESTADO_DETALLE_CITA',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.HISTORIAL_ESTADO_DETALLE_CITA
    (
        IdHistorialEstado INT IDENTITY(1,1) NOT NULL,
        IdDetalleCita INT NOT NULL,
        EstadoAnterior VARCHAR(20) NULL,
        EstadoNuevo VARCHAR(20) NOT NULL,
        IdUsuario VARCHAR(30) NOT NULL,
        FechaHoraCambio DATETIME2(0) NOT NULL CONSTRAINT DF_HIST_ESTADO_DETALLE_Fecha DEFAULT(SYSDATETIME()),
        Observacion VARCHAR(300) NULL,

        CONSTRAINT PK_HISTORIAL_ESTADO_DETALLE_CITA PRIMARY KEY(IdHistorialEstado),
        CONSTRAINT FK_HIST_ESTADO_DETALLE_Detalle FOREIGN KEY(IdDetalleCita) REFERENCES dbo.DETALLE_CITA(IdDetalleCita),
        CONSTRAINT FK_HIST_ESTADO_DETALLE_Usuario FOREIGN KEY(IdUsuario) REFERENCES dbo.CAT_USUARIOS(IdUsuario),
        CONSTRAINT CK_HIST_ESTADO_DETALLE_Anterior CHECK(EstadoAnterior IS NULL OR EstadoAnterior IN ('PENDIENTE','REALIZADO','NO_REALIZADO','CANCELADO')),
        CONSTRAINT CK_HIST_ESTADO_DETALLE_Nuevo CHECK(EstadoNuevo IN ('PENDIENTE','REALIZADO','NO_REALIZADO','CANCELADO'))
    );
END;
GO

IF NOT EXISTS(
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'dbo.HISTORIAL_ESTADO_DETALLE_CITA')
      AND name=N'IX_HIST_ESTADO_DETALLE_DetalleFecha')
BEGIN
    CREATE INDEX IX_HIST_ESTADO_DETALLE_DetalleFecha
    ON dbo.HISTORIAL_ESTADO_DETALLE_CITA(IdDetalleCita,FechaHoraCambio DESC);
END;
GO

/* 9. CONFIGURACIÓN DE INFORMES / ENCABEZADO */
IF OBJECT_ID(N'dbo.CONFIG_INFORMES',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.CONFIG_INFORMES
    (
        IdConfiguracion INT NOT NULL,
        EncabezadoImagen VARBINARY(MAX) NULL,
        EncabezadoNombreArchivo VARCHAR(255) NULL,
        EncabezadoTipoMime VARCHAR(100) NULL,
        IdUsuarioModificacion VARCHAR(30) NULL,
        FechaModificacion DATETIME2(0) NOT NULL CONSTRAINT DF_CONFIG_INFORMES_Fecha DEFAULT(SYSDATETIME()),

        CONSTRAINT PK_CONFIG_INFORMES PRIMARY KEY(IdConfiguracion),
        CONSTRAINT CK_CONFIG_INFORMES_Unico CHECK(IdConfiguracion=1),
        CONSTRAINT CK_CONFIG_INFORMES_TipoMime CHECK(EncabezadoTipoMime IS NULL OR EncabezadoTipoMime IN ('image/png','image/jpeg')),
        CONSTRAINT CK_CONFIG_INFORMES_ImagenCompleta CHECK
        (
            (EncabezadoImagen IS NULL AND EncabezadoNombreArchivo IS NULL AND EncabezadoTipoMime IS NULL)
            OR
            (EncabezadoImagen IS NOT NULL AND EncabezadoNombreArchivo IS NOT NULL AND EncabezadoTipoMime IS NOT NULL)
        ),
        CONSTRAINT FK_CONFIG_INFORMES_Usuario FOREIGN KEY(IdUsuarioModificacion) REFERENCES dbo.CAT_USUARIOS(IdUsuario)
    );
END;
GO

IF NOT EXISTS(SELECT 1 FROM dbo.CONFIG_INFORMES WHERE IdConfiguracion=1)
BEGIN
    INSERT dbo.CONFIG_INFORMES
    (IdConfiguracion,EncabezadoImagen,EncabezadoNombreArchivo,EncabezadoTipoMime,IdUsuarioModificacion)
    VALUES(1,NULL,NULL,NULL,NULL);
END;
GO

/* 10. PROCEDIMIENTOS BÁSICOS - MÉDICOS INFORMANTES */
CREATE OR ALTER PROCEDURE dbo.sp_MedicoInformante_Listar
    @Texto VARCHAR(100)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Filtro VARCHAR(100)=NULLIF(LTRIM(RTRIM(@Texto)),'');

    SELECT IdMedicoInformante,Nombres,Apellidos,NoColegiado,Telefono,Correo,Activo,FechaCreacion
    FROM dbo.CAT_MEDICOS_INFORMANTES
    WHERE @Filtro IS NULL
       OR IdMedicoInformante LIKE '%'+@Filtro+'%'
       OR Nombres LIKE '%'+@Filtro+'%'
       OR Apellidos LIKE '%'+@Filtro+'%'
       OR NoColegiado LIKE '%'+@Filtro+'%'
    ORDER BY Apellidos,Nombres;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_MedicoInformante_ListarActivos
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdMedicoInformante,Nombres,Apellidos,NoColegiado
    FROM dbo.CAT_MEDICOS_INFORMANTES
    WHERE Activo=1
    ORDER BY Apellidos,Nombres;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_MedicoInformante_Obtener
    @IdMedicoInformante VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdMedicoInformante,Nombres,Apellidos,NoColegiado,Telefono,Correo,Activo,FechaCreacion
    FROM dbo.CAT_MEDICOS_INFORMANTES
    WHERE IdMedicoInformante=@IdMedicoInformante;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_MedicoInformante_Guardar
    @IdMedicoInformante VARCHAR(30),
    @Nombres VARCHAR(100),
    @Apellidos VARCHAR(100),
    @NoColegiado VARCHAR(30)=NULL,
    @Telefono VARCHAR(20)=NULL,
    @Correo VARCHAR(100)=NULL,
    @Activo BIT=1
AS
BEGIN
    SET NOCOUNT ON;

    SET @IdMedicoInformante=NULLIF(LTRIM(RTRIM(@IdMedicoInformante)),'');
    SET @Nombres=NULLIF(LTRIM(RTRIM(@Nombres)),'');
    SET @Apellidos=NULLIF(LTRIM(RTRIM(@Apellidos)),'');

    IF @IdMedicoInformante IS NULL THROW 50200,'El código del médico informante es obligatorio.',1;
    IF @Nombres IS NULL THROW 50201,'Los nombres del médico informante son obligatorios.',1;
    IF @Apellidos IS NULL THROW 50202,'Los apellidos del médico informante son obligatorios.',1;

    IF EXISTS(SELECT 1 FROM dbo.CAT_MEDICOS_INFORMANTES WHERE IdMedicoInformante=@IdMedicoInformante)
    BEGIN
        UPDATE dbo.CAT_MEDICOS_INFORMANTES
        SET Nombres=@Nombres,
            Apellidos=@Apellidos,
            NoColegiado=NULLIF(LTRIM(RTRIM(@NoColegiado)),''),
            Telefono=NULLIF(LTRIM(RTRIM(@Telefono)),''),
            Correo=NULLIF(LTRIM(RTRIM(@Correo)),''),
            Activo=@Activo
        WHERE IdMedicoInformante=@IdMedicoInformante;
    END
    ELSE
    BEGIN
        INSERT dbo.CAT_MEDICOS_INFORMANTES
        (IdMedicoInformante,Nombres,Apellidos,NoColegiado,Telefono,Correo,Activo)
        VALUES
        (@IdMedicoInformante,@Nombres,@Apellidos,
         NULLIF(LTRIM(RTRIM(@NoColegiado)),''),
         NULLIF(LTRIM(RTRIM(@Telefono)),''),
         NULLIF(LTRIM(RTRIM(@Correo)),''),@Activo);
    END;
END;
GO

/* 11. PROCEDIMIENTOS BÁSICOS - CONFIGURACIÓN DE INFORMES */
CREATE OR ALTER PROCEDURE dbo.sp_ConfigInformes_Obtener
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdConfiguracion,EncabezadoImagen,EncabezadoNombreArchivo,EncabezadoTipoMime,
           IdUsuarioModificacion,FechaModificacion
    FROM dbo.CONFIG_INFORMES
    WHERE IdConfiguracion=1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ConfigInformes_GuardarEncabezado
    @EncabezadoImagen VARBINARY(MAX),
    @EncabezadoNombreArchivo VARCHAR(255),
    @EncabezadoTipoMime VARCHAR(100),
    @IdUsuarioModificacion VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    IF @EncabezadoImagen IS NULL OR DATALENGTH(@EncabezadoImagen)=0
        THROW 50210,'Debe seleccionar una imagen de encabezado.',1;
    IF NULLIF(LTRIM(RTRIM(@EncabezadoNombreArchivo)),'') IS NULL
        THROW 50211,'El nombre del archivo es obligatorio.',1;
    IF @EncabezadoTipoMime NOT IN ('image/png','image/jpeg')
        THROW 50212,'El encabezado debe ser una imagen PNG, JPG o JPEG.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.CAT_USUARIOS WHERE IdUsuario=@IdUsuarioModificacion AND Activo=1)
        THROW 50213,'El usuario que modifica la configuración no es válido.',1;

    UPDATE dbo.CONFIG_INFORMES
    SET EncabezadoImagen=@EncabezadoImagen,
        EncabezadoNombreArchivo=@EncabezadoNombreArchivo,
        EncabezadoTipoMime=@EncabezadoTipoMime,
        IdUsuarioModificacion=@IdUsuarioModificacion,
        FechaModificacion=SYSDATETIME()
    WHERE IdConfiguracion=1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ConfigInformes_EliminarEncabezado
    @IdUsuarioModificacion VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS(SELECT 1 FROM dbo.CAT_USUARIOS WHERE IdUsuario=@IdUsuarioModificacion AND Activo=1)
        THROW 50214,'El usuario que modifica la configuración no es válido.',1;

    UPDATE dbo.CONFIG_INFORMES
    SET EncabezadoImagen=NULL,
        EncabezadoNombreArchivo=NULL,
        EncabezadoTipoMime=NULL,
        IdUsuarioModificacion=@IdUsuarioModificacion,
        FechaModificacion=SYSDATETIME()
    WHERE IdConfiguracion=1;
END;
GO

/* 12. VERIFICACIÓN */
SELECT
    RolUsuarioInformes=CASE WHEN EXISTS(SELECT 1 FROM dbo.CAT_ROLES WHERE NombreRol='USUARIO_INFORMES' AND Activo=1) THEN 'OK' ELSE 'FALTA' END,
    CatalogoMedicosInformantes=CASE WHEN OBJECT_ID(N'dbo.CAT_MEDICOS_INFORMANTES',N'U') IS NOT NULL THEN 'OK' ELSE 'FALTA' END,
    InformeEstudio=CASE WHEN OBJECT_ID(N'dbo.INFORME_ESTUDIO',N'U') IS NOT NULL THEN 'OK' ELSE 'FALTA' END,
    RecursosInforme=CASE WHEN OBJECT_ID(N'dbo.INFORME_ESTUDIO_RECURSOS',N'U') IS NOT NULL THEN 'OK' ELSE 'FALTA' END,
    HistorialInforme=CASE WHEN OBJECT_ID(N'dbo.INFORME_ESTUDIO_HISTORIAL',N'U') IS NOT NULL THEN 'OK' ELSE 'FALTA' END,
    RecursosHistorial=CASE WHEN OBJECT_ID(N'dbo.INFORME_ESTUDIO_RECURSOS_HISTORIAL',N'U') IS NOT NULL THEN 'OK' ELSE 'FALTA' END,
    HistorialEstadoDetalle=CASE WHEN OBJECT_ID(N'dbo.HISTORIAL_ESTADO_DETALLE_CITA',N'U') IS NOT NULL THEN 'OK' ELSE 'FALTA' END,
    ConfigInformes=CASE WHEN OBJECT_ID(N'dbo.CONFIG_INFORMES',N'U') IS NOT NULL THEN 'OK' ELSE 'FALTA' END;
GO

SELECT NombreRol,Descripcion,Activo
FROM dbo.CAT_ROLES
WHERE NombreRol IN ('ADMINISTRADOR','USUARIO_CITAS','USUARIO_INFORMES')
ORDER BY IdRol;
GO

SELECT cc.name AS ConstraintEstadoDetalle,cc.definition AS Definicion
FROM sys.check_constraints cc
WHERE cc.parent_object_id=OBJECT_ID(N'dbo.DETALLE_CITA')
  AND cc.name=N'CK_DETALLE_CITA_Estado';
GO

PRINT 'Requerimiento 2 - Fase 1 instalada correctamente.';
PRINT 'IMPORTANTE: todavía no pruebe el nuevo flujo ATENDIDA/REALIZADO/NO_REALIZADO.';
PRINT 'Ese flujo se habilitará junto con procedimientos, backend e interfaz en la siguiente fase.';
GO
