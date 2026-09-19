USE RIS_HRO;
GO

/* =============================================================
   RECUPERACIÓN DE CONTRASEÑA Y CONFIGURACIÓN SMTP
   Script incremental: NO elimina la base de datos.
   ============================================================= */

IF COL_LENGTH('dbo.CAT_USUARIOS', 'DebeCambiarContrasena') IS NULL
BEGIN
    ALTER TABLE dbo.CAT_USUARIOS
    ADD DebeCambiarContrasena BIT NOT NULL
        CONSTRAINT DF_CAT_USUARIOS_DebeCambiarContrasena DEFAULT (0);
END;
GO

IF OBJECT_ID('dbo.CONFIG_CORREO', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CONFIG_CORREO
    (
        IdConfiguracion     INT NOT NULL
            CONSTRAINT PK_CONFIG_CORREO PRIMARY KEY,
        ServidorSmtp        VARCHAR(150) NOT NULL,
        Puerto              INT NOT NULL,
        UsarSsl             BIT NOT NULL,
        NombreRemitente     VARCHAR(150) NOT NULL,
        CorreoRemitente     VARCHAR(150) NOT NULL,
        UsuarioSmtp         VARCHAR(150) NOT NULL,
        ClaveProtegida      NVARCHAR(MAX) NULL,
        Activo              BIT NOT NULL
            CONSTRAINT DF_CONFIG_CORREO_Activo DEFAULT (0),
        IdUsuarioModificacion VARCHAR(30) NULL,
        FechaModificacion   DATETIME2(0) NOT NULL
            CONSTRAINT DF_CONFIG_CORREO_Fecha DEFAULT (SYSDATETIME()),
        CONSTRAINT CK_CONFIG_CORREO_Unico CHECK (IdConfiguracion = 1),
        CONSTRAINT FK_CONFIG_CORREO_Usuario
            FOREIGN KEY (IdUsuarioModificacion)
            REFERENCES dbo.CAT_USUARIOS(IdUsuario)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.CONFIG_CORREO WHERE IdConfiguracion = 1)
BEGIN
    INSERT dbo.CONFIG_CORREO
    (
        IdConfiguracion,
        ServidorSmtp,
        Puerto,
        UsarSsl,
        NombreRemitente,
        CorreoRemitente,
        UsuarioSmtp,
        ClaveProtegida,
        Activo
    )
    VALUES
    (
        1,
        'smtp.gmail.com',
        587,
        1,
        'RIS HRO',
        'inforishro@gmail.com',
        'inforishro@gmail.com',
        NULL,
        0
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Usuario_BuscarRecuperacion
    @Identificador VARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
        IdUsuario,
        NombreCompleto,
        Correo,
        ContrasenaHash,
        DebeCambiarContrasena,
        Activo
    FROM dbo.CAT_USUARIOS
    WHERE Activo = 1
      AND Correo IS NOT NULL
      AND LTRIM(RTRIM(Correo)) <> ''
      AND
      (
          IdUsuario = @Identificador
          OR LOWER(Correo) = LOWER(@Identificador)
      );
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Usuario_EstablecerPasswordTemporal
    @IdUsuario VARCHAR(30),
    @ContrasenaHash VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.CAT_USUARIOS
    SET ContrasenaHash = @ContrasenaHash,
        DebeCambiarContrasena = 1
    WHERE IdUsuario = @IdUsuario
      AND Activo = 1;

    IF @@ROWCOUNT = 0
        THROW 50100, 'No fue posible actualizar la contraseña temporal.', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Usuario_RestaurarPassword
    @IdUsuario VARCHAR(30),
    @ContrasenaHashAnterior VARCHAR(255),
    @DebeCambiarAnterior BIT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.CAT_USUARIOS
    SET ContrasenaHash = @ContrasenaHashAnterior,
        DebeCambiarContrasena = @DebeCambiarAnterior
    WHERE IdUsuario = @IdUsuario;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Usuario_CambiarPassword
    @IdUsuario VARCHAR(30),
    @ContrasenaHash VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.CAT_USUARIOS
    SET ContrasenaHash = @ContrasenaHash,
        DebeCambiarContrasena = 0
    WHERE IdUsuario = @IdUsuario
      AND Activo = 1;

    IF @@ROWCOUNT = 0
        THROW 50101, 'No fue posible cambiar la contraseña.', 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ConfigCorreo_Obtener
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        IdConfiguracion,
        ServidorSmtp,
        Puerto,
        UsarSsl,
        NombreRemitente,
        CorreoRemitente,
        UsuarioSmtp,
        ClaveProtegida,
        Activo
    FROM dbo.CONFIG_CORREO
    WHERE IdConfiguracion = 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ConfigCorreo_Guardar
    @ServidorSmtp VARCHAR(150),
    @Puerto INT,
    @UsarSsl BIT,
    @NombreRemitente VARCHAR(150),
    @CorreoRemitente VARCHAR(150),
    @UsuarioSmtp VARCHAR(150),
    @ClaveProtegida NVARCHAR(MAX) = NULL,
    @Activo BIT,
    @IdUsuarioModificacion VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    IF @Puerto <= 0 OR @Puerto > 65535
        THROW 50110, 'El puerto SMTP no es válido.', 1;

    UPDATE dbo.CONFIG_CORREO
    SET ServidorSmtp = @ServidorSmtp,
        Puerto = @Puerto,
        UsarSsl = @UsarSsl,
        NombreRemitente = @NombreRemitente,
        CorreoRemitente = @CorreoRemitente,
        UsuarioSmtp = @UsuarioSmtp,
        ClaveProtegida = COALESCE(@ClaveProtegida, ClaveProtegida),
        Activo = @Activo,
        IdUsuarioModificacion = @IdUsuarioModificacion,
        FechaModificacion = SYSDATETIME()
    WHERE IdConfiguracion = 1;
END;
GO

/* Se amplía el SP de login para informar si la contraseña debe cambiarse. */
CREATE OR ALTER PROCEDURE dbo.sp_Usuario_ObtenerLogin
    @IdUsuario VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        U.IdUsuario,
        U.NombreCompleto,
        U.ContrasenaHash,
        U.Activo,
        U.DebeCambiarContrasena,
        R.NombreRol
    FROM dbo.CAT_USUARIOS U
    INNER JOIN dbo.CAT_ROLES R ON R.IdRol = U.IdRol
    WHERE U.IdUsuario = @IdUsuario;
END;
GO

PRINT 'Recuperación de contraseña y configuración SMTP instaladas correctamente.';
GO
