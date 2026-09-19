/* =============================================================
   RIS_HRO - INSTALACIÓN COMPLETA DE DESARROLLO
   Proyecto de graduación - Hospital Regional de Occidente
   Stack: ASP.NET Core / Razor Pages / ADO.NET / SQL Server
   -------------------------------------------------------------
   ADVERTENCIA:
   Este script ELIMINA la base RIS_HRO si ya existe.
   Úselo únicamente para desarrollo o demostración.
   ============================================================= */

USE master;
GO

IF DB_ID('RIS_HRO') IS NOT NULL
BEGIN
    ALTER DATABASE RIS_HRO SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE RIS_HRO;
END;
GO

CREATE DATABASE RIS_HRO;
GO
USE RIS_HRO;
GO

/* =============================================================
   1. TABLAS
   ============================================================= */

CREATE TABLE dbo.CAT_ROLES
(
    IdRol             INT IDENTITY(1,1) NOT NULL,
    NombreRol         VARCHAR(50) NOT NULL,
    Descripcion       VARCHAR(200) NULL,
    Activo            BIT NOT NULL CONSTRAINT DF_CAT_ROLES_Activo DEFAULT (1),
    FechaCreacion     DATETIME2(0) NOT NULL CONSTRAINT DF_CAT_ROLES_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_CAT_ROLES PRIMARY KEY (IdRol),
    CONSTRAINT UQ_CAT_ROLES_Nombre UNIQUE (NombreRol)
);
GO

CREATE TABLE dbo.CAT_USUARIOS
(
    IdUsuario         VARCHAR(30) NOT NULL,
    IdRol             INT NOT NULL,
    NombreCompleto    VARCHAR(150) NOT NULL,
    ContrasenaHash    VARCHAR(255) NOT NULL,
    Correo            VARCHAR(100) NULL,
    Activo            BIT NOT NULL CONSTRAINT DF_CAT_USUARIOS_Activo DEFAULT (1),
    FechaCreacion     DATETIME2(0) NOT NULL CONSTRAINT DF_CAT_USUARIOS_Fecha DEFAULT (SYSDATETIME()),
    UltimoAcceso      DATETIME2(0) NULL,
    CONSTRAINT PK_CAT_USUARIOS PRIMARY KEY (IdUsuario),
    CONSTRAINT FK_CAT_USUARIOS_ROL FOREIGN KEY (IdRol) REFERENCES dbo.CAT_ROLES(IdRol)
);
GO

CREATE TABLE dbo.CAT_PACIENTES
(
    IdPaciente        VARCHAR(30) NOT NULL,
    PrimerNombre      VARCHAR(50) NOT NULL,
    SegundoNombre     VARCHAR(50) NULL,
    PrimerApellido    VARCHAR(50) NOT NULL,
    SegundoApellido   VARCHAR(50) NULL,
    FechaNacimiento   DATE NULL,
    Sexo              CHAR(1) NULL,
    Telefono          VARCHAR(20) NULL,
    Activo            BIT NOT NULL CONSTRAINT DF_CAT_PACIENTES_Activo DEFAULT (1),
    FechaCreacion     DATETIME2(0) NOT NULL CONSTRAINT DF_CAT_PACIENTES_Fecha DEFAULT (SYSDATETIME()),
    FechaModificacion DATETIME2(0) NULL,
    CONSTRAINT PK_CAT_PACIENTES PRIMARY KEY (IdPaciente),
    CONSTRAINT CK_CAT_PACIENTES_Sexo CHECK (Sexo IS NULL OR Sexo IN ('M','F'))
);
GO

CREATE TABLE dbo.CAT_MEDICOS
(
    IdMedico          VARCHAR(30) NOT NULL,
    Nombres           VARCHAR(100) NOT NULL,
    Apellidos         VARCHAR(100) NOT NULL,
    NoColegiado       VARCHAR(30) NULL,
    Telefono          VARCHAR(20) NULL,
    Correo            VARCHAR(100) NULL,
    Activo            BIT NOT NULL CONSTRAINT DF_CAT_MEDICOS_Activo DEFAULT (1),
    FechaCreacion     DATETIME2(0) NOT NULL CONSTRAINT DF_CAT_MEDICOS_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_CAT_MEDICOS PRIMARY KEY (IdMedico)
);
GO

CREATE TABLE dbo.CAT_TECNICOS_RADIOLOGOS
(
    IdTecnico         VARCHAR(30) NOT NULL,
    Nombres           VARCHAR(100) NOT NULL,
    Apellidos         VARCHAR(100) NOT NULL,
    Telefono          VARCHAR(20) NULL,
    Correo            VARCHAR(100) NULL,
    Activo            BIT NOT NULL CONSTRAINT DF_CAT_TECNICOS_Activo DEFAULT (1),
    FechaCreacion     DATETIME2(0) NOT NULL CONSTRAINT DF_CAT_TECNICOS_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_CAT_TECNICOS PRIMARY KEY (IdTecnico)
);
GO

CREATE TABLE dbo.CAT_SERVICIOS_HOSPITALARIOS
(
    IdServicio        VARCHAR(30) NOT NULL,
    NombreServicio    VARCHAR(100) NOT NULL,
    Descripcion       VARCHAR(200) NULL,
    Activo            BIT NOT NULL CONSTRAINT DF_CAT_SERVICIOS_Activo DEFAULT (1),
    FechaCreacion     DATETIME2(0) NOT NULL CONSTRAINT DF_CAT_SERVICIOS_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_CAT_SERVICIOS PRIMARY KEY (IdServicio)
);
GO

CREATE TABLE dbo.CAT_CATEGORIAS_PRUEBAS
(
    IdCategoria       VARCHAR(20) NOT NULL,
    NombreCategoria   VARCHAR(100) NOT NULL,
    Descripcion       VARCHAR(250) NULL,
    Activo            BIT NOT NULL CONSTRAINT DF_CAT_CATEGORIAS_Activo DEFAULT (1),
    FechaCreacion     DATETIME2(0) NOT NULL CONSTRAINT DF_CAT_CATEGORIAS_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_CAT_CATEGORIAS PRIMARY KEY (IdCategoria),
    CONSTRAINT UQ_CAT_CATEGORIAS_Nombre UNIQUE (NombreCategoria)
);
GO

CREATE TABLE dbo.CAT_PRUEBAS
(
    IdPrueba          VARCHAR(30) NOT NULL,
    IdCategoria       VARCHAR(20) NOT NULL,
    NombrePrueba      VARCHAR(150) NOT NULL,
    Descripcion       VARCHAR(250) NULL,
    DuracionMinutos   INT NULL,
    Activo            BIT NOT NULL CONSTRAINT DF_CAT_PRUEBAS_Activo DEFAULT (1),
    FechaCreacion     DATETIME2(0) NOT NULL CONSTRAINT DF_CAT_PRUEBAS_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_CAT_PRUEBAS PRIMARY KEY (IdPrueba),
    CONSTRAINT FK_CAT_PRUEBAS_CATEGORIA FOREIGN KEY (IdCategoria) REFERENCES dbo.CAT_CATEGORIAS_PRUEBAS(IdCategoria),
    CONSTRAINT CK_CAT_PRUEBAS_Duracion CHECK (DuracionMinutos IS NULL OR DuracionMinutos > 0)
);
GO

CREATE TABLE dbo.CAPACIDAD
(
    IdCapacidad           INT IDENTITY(1,1) NOT NULL,
    IdPrueba              VARCHAR(30) NOT NULL,
    DiaSemana             TINYINT NOT NULL, -- 1=Lunes ... 7=Domingo
    CantidadMaxima        INT NOT NULL,
    Activo                BIT NOT NULL CONSTRAINT DF_CAPACIDAD_Activo DEFAULT (1),
    IdUsuarioCreacion     VARCHAR(30) NOT NULL,
    FechaCreacion         DATETIME2(0) NOT NULL CONSTRAINT DF_CAPACIDAD_Fecha DEFAULT (SYSDATETIME()),
    IdUsuarioModificacion VARCHAR(30) NULL,
    FechaModificacion     DATETIME2(0) NULL,
    CONSTRAINT PK_CAPACIDAD PRIMARY KEY (IdCapacidad),
    CONSTRAINT FK_CAPACIDAD_PRUEBA FOREIGN KEY (IdPrueba) REFERENCES dbo.CAT_PRUEBAS(IdPrueba),
    CONSTRAINT FK_CAPACIDAD_USUARIO_C FOREIGN KEY (IdUsuarioCreacion) REFERENCES dbo.CAT_USUARIOS(IdUsuario),
    CONSTRAINT FK_CAPACIDAD_USUARIO_M FOREIGN KEY (IdUsuarioModificacion) REFERENCES dbo.CAT_USUARIOS(IdUsuario),
    CONSTRAINT CK_CAPACIDAD_Dia CHECK (DiaSemana BETWEEN 1 AND 7),
    CONSTRAINT CK_CAPACIDAD_Cantidad CHECK (CantidadMaxima > 0),
    CONSTRAINT UQ_CAPACIDAD_Prueba_Dia UNIQUE (IdPrueba, DiaSemana)
);
GO

CREATE TABLE dbo.CITA
(
    IdCita                INT IDENTITY(1,1) NOT NULL,
    NumeroCita            VARCHAR(30) NOT NULL,
    IdPaciente            VARCHAR(30) NOT NULL,
    IdMedico              VARCHAR(30) NOT NULL,
    IdServicio            VARCHAR(30) NOT NULL,
    FechaCita             DATE NOT NULL,
    HoraCita              TIME(0) NOT NULL,
    Estado                VARCHAR(20) NOT NULL CONSTRAINT DF_CITA_Estado DEFAULT ('PROGRAMADA'),
    Observaciones         VARCHAR(500) NULL,
    IdUsuarioCreacion     VARCHAR(30) NOT NULL,
    FechaCreacion         DATETIME2(0) NOT NULL CONSTRAINT DF_CITA_Fecha DEFAULT (SYSDATETIME()),
    IdUsuarioModificacion VARCHAR(30) NULL,
    FechaModificacion     DATETIME2(0) NULL,
    Activo                BIT NOT NULL CONSTRAINT DF_CITA_Activo DEFAULT (1),
    CONSTRAINT PK_CITA PRIMARY KEY (IdCita),
    CONSTRAINT UQ_CITA_Numero UNIQUE (NumeroCita),
    CONSTRAINT FK_CITA_PACIENTE FOREIGN KEY (IdPaciente) REFERENCES dbo.CAT_PACIENTES(IdPaciente),
    CONSTRAINT FK_CITA_MEDICO FOREIGN KEY (IdMedico) REFERENCES dbo.CAT_MEDICOS(IdMedico),
    CONSTRAINT FK_CITA_SERVICIO FOREIGN KEY (IdServicio) REFERENCES dbo.CAT_SERVICIOS_HOSPITALARIOS(IdServicio),
    CONSTRAINT FK_CITA_USUARIO_C FOREIGN KEY (IdUsuarioCreacion) REFERENCES dbo.CAT_USUARIOS(IdUsuario),
    CONSTRAINT FK_CITA_USUARIO_M FOREIGN KEY (IdUsuarioModificacion) REFERENCES dbo.CAT_USUARIOS(IdUsuario),
    CONSTRAINT CK_CITA_Estado CHECK (Estado IN ('PROGRAMADA','ATENDIDA','CANCELADA','NO_ASISTIO'))
);
GO

CREATE TABLE dbo.DETALLE_CITA
(
    IdDetalleCita     INT IDENTITY(1,1) NOT NULL,
    IdCita            INT NOT NULL,
    IdPrueba          VARCHAR(30) NOT NULL,
    IdTecnico         VARCHAR(30) NULL,
    Estado            VARCHAR(20) NOT NULL CONSTRAINT DF_DETALLE_CITA_Estado DEFAULT ('PENDIENTE'),
    Observaciones     VARCHAR(300) NULL,
    FechaCreacion     DATETIME2(0) NOT NULL CONSTRAINT DF_DETALLE_CITA_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_DETALLE_CITA PRIMARY KEY (IdDetalleCita),
    CONSTRAINT FK_DETALLE_CITA_CITA FOREIGN KEY (IdCita) REFERENCES dbo.CITA(IdCita),
    CONSTRAINT FK_DETALLE_CITA_PRUEBA FOREIGN KEY (IdPrueba) REFERENCES dbo.CAT_PRUEBAS(IdPrueba),
    CONSTRAINT FK_DETALLE_CITA_TECNICO FOREIGN KEY (IdTecnico) REFERENCES dbo.CAT_TECNICOS_RADIOLOGOS(IdTecnico),
    CONSTRAINT CK_DETALLE_CITA_Estado CHECK (Estado IN ('PENDIENTE','REALIZADO','CANCELADO')),
    CONSTRAINT UQ_DETALLE_CITA_Cita_Prueba UNIQUE (IdCita, IdPrueba)
);
GO

CREATE INDEX IX_CITA_FechaEstado ON dbo.CITA(FechaCita, Estado, Activo, IdCita);
CREATE INDEX IX_CITA_PacienteFecha ON dbo.CITA(IdPaciente, FechaCita);
CREATE INDEX IX_DETALLE_CITA_PruebaEstado ON dbo.DETALLE_CITA(IdPrueba, Estado, IdCita);
CREATE INDEX IX_DETALLE_CITA_IdCita ON dbo.DETALLE_CITA(IdCita);
GO

CREATE TYPE dbo.TVP_EstudioCita AS TABLE
(
    IdPrueba VARCHAR(30) NOT NULL PRIMARY KEY
);
GO

/* =============================================================
   2. DATOS INICIALES
   ============================================================= */

INSERT dbo.CAT_ROLES (NombreRol, Descripcion)
VALUES
('ADMINISTRADOR', 'Acceso completo a administración y operación'),
('USUARIO_CITAS', 'Acceso operativo para gestión de citas');
GO

INSERT dbo.CAT_USUARIOS
(IdUsuario, IdRol, NombreCompleto, ContrasenaHash, Correo)
VALUES
('ADMIN01', 1, 'Administrador RIS HRO', 'PBKDF2-SHA256$100000$4oivxPMdlZ0nGuthDol7JA==$ZeWNXZzyQ52zuPNgUBAklJdkHtwrqJMMeEBg8wYCZUI=', 'admin@demo.local'),
('CITAS01', 2, 'Usuario de Citas', 'PBKDF2-SHA256$100000$QFY2FvvcqFs6cqSO+F7Hwg==$c5JpucKhE/w6zZHhHS4WpmfNKaDCdbwjESk190p40pk=', 'citas@demo.local');
GO

INSERT dbo.CAT_PACIENTES
(IdPaciente, PrimerNombre, SegundoNombre, PrimerApellido, SegundoApellido, FechaNacimiento, Sexo, Telefono)
VALUES
('152487', 'María', NULL, 'López', 'Hernández', '1985-06-12', 'F', '55550001'),
('100002', 'Juan', 'Carlos', 'Pérez', 'Gómez', '1978-02-21', 'M', '55550002'),
('100003', 'Ana', 'Lucía', 'García', 'Méndez', '1991-11-08', 'F', '55550003'),
('100004', 'Pedro', NULL, 'Díaz', 'Ramírez', '1969-03-15', 'M', '55550004'),
('100005', 'Sofía', 'Elena', 'Morales', 'Cifuentes', '1988-09-27', 'F', '55550005');
GO

INSERT dbo.CAT_MEDICOS
(IdMedico, Nombres, Apellidos, NoColegiado, Telefono, Correo)
VALUES
('MED001', 'Carlos', 'López', '12345', '55551001', 'clopez@demo.local'),
('MED002', 'Andrea', 'Ramírez', '22346', '55551002', 'aramirez@demo.local'),
('MED003', 'José', 'Mazariegos', '32347', '55551003', 'jmazariegos@demo.local');
GO

INSERT dbo.CAT_TECNICOS_RADIOLOGOS
(IdTecnico, Nombres, Apellidos, Telefono, Correo)
VALUES
('TEC001', 'José', 'Pérez', '55552001', 'jperez@demo.local'),
('TEC002', 'Marta', 'Cifuentes', '55552002', 'mcifuentes@demo.local'),
('TEC003', 'Luis', 'Gómez', '55552003', 'lgomez@demo.local');
GO

INSERT dbo.CAT_SERVICIOS_HOSPITALARIOS
(IdServicio, NombreServicio, Descripcion)
VALUES
('SER001', 'Emergencia', 'Servicio de emergencia'),
('SER002', 'Consulta Externa', 'Consulta externa'),
('SER003', 'Medicina Interna', 'Servicio de medicina interna'),
('SER004', 'Cirugía', 'Servicio de cirugía');
GO

INSERT dbo.CAT_CATEGORIAS_PRUEBAS
(IdCategoria, NombreCategoria, Descripcion)
VALUES
('RX', 'Rayos X', 'Estudios radiográficos'),
('US', 'Ultrasonido', 'Estudios por ultrasonido'),
('MAM', 'Mamografía', 'Estudios mamográficos');
GO

INSERT dbo.CAT_PRUEBAS
(IdPrueba, IdCategoria, NombrePrueba, Descripcion, DuracionMinutos)
VALUES
('RX001', 'RX', 'RX tórax', 'Radiografía de tórax', 15),
('RX002', 'RX', 'RX columna lumbar', 'Radiografía de columna lumbar', 20),
('RX003', 'RX', 'RX rodilla', 'Radiografía de rodilla', 15),
('US001', 'US', 'US abdominal', 'Ultrasonido abdominal', 25),
('US002', 'US', 'US renal', 'Ultrasonido renal', 25),
('MAM001', 'MAM', 'Mamografía bilateral', 'Mamografía bilateral', 30);
GO

;WITH Dias AS
(
    SELECT DiaSemana FROM (VALUES (1),(2),(3),(4),(5),(6),(7)) D(DiaSemana)
)
INSERT dbo.CAPACIDAD (IdPrueba, DiaSemana, CantidadMaxima, IdUsuarioCreacion)
SELECT P.IdPrueba,
       D.DiaSemana,
       CASE P.IdPrueba
           WHEN 'RX001' THEN 12
           WHEN 'RX002' THEN 10
           WHEN 'RX003' THEN 10
           WHEN 'US001' THEN 8
           WHEN 'US002' THEN 6
           WHEN 'MAM001' THEN 4
       END,
       'ADMIN01'
FROM dbo.CAT_PRUEBAS P
CROSS JOIN Dias D;
GO

/* =============================================================
   3. LOGIN Y USUARIOS
   ============================================================= */

CREATE OR ALTER PROCEDURE dbo.sp_Usuario_ObtenerLogin
    @IdUsuario VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT U.IdUsuario, U.NombreCompleto, U.ContrasenaHash, U.Activo, R.NombreRol
    FROM dbo.CAT_USUARIOS U
    INNER JOIN dbo.CAT_ROLES R ON R.IdRol = U.IdRol
    WHERE U.IdUsuario = @IdUsuario;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Usuario_ActualizarUltimoAcceso
    @IdUsuario VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.CAT_USUARIOS SET UltimoAcceso = SYSDATETIME()
    WHERE IdUsuario = @IdUsuario;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Usuario_Listar
    @Texto VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT U.IdUsuario, U.NombreCompleto, R.NombreRol, U.Correo, U.Activo, U.UltimoAcceso
    FROM dbo.CAT_USUARIOS U
    INNER JOIN dbo.CAT_ROLES R ON R.IdRol = U.IdRol
    WHERE @Texto IS NULL OR LTRIM(RTRIM(@Texto)) = ''
       OR U.IdUsuario LIKE '%' + @Texto + '%'
       OR U.NombreCompleto LIKE '%' + @Texto + '%'
       OR R.NombreRol LIKE '%' + @Texto + '%'
    ORDER BY U.NombreCompleto;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Usuario_Obtener
    @IdUsuario VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdUsuario, IdRol, NombreCompleto, Correo, Activo
    FROM dbo.CAT_USUARIOS
    WHERE IdUsuario = @IdUsuario;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Usuario_Guardar
    @IdUsuario VARCHAR(30),
    @IdRol INT,
    @NombreCompleto VARCHAR(150),
    @Correo VARCHAR(100) = NULL,
    @ContrasenaHash VARCHAR(255) = NULL,
    @Activo BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.CAT_USUARIOS WHERE IdUsuario = @IdUsuario)
    BEGIN
        UPDATE dbo.CAT_USUARIOS
        SET IdRol = @IdRol,
            NombreCompleto = @NombreCompleto,
            Correo = @Correo,
            ContrasenaHash = COALESCE(@ContrasenaHash, ContrasenaHash),
            Activo = @Activo
        WHERE IdUsuario = @IdUsuario;
    END
    ELSE
    BEGIN
        IF @ContrasenaHash IS NULL
            THROW 50010, 'La contraseña es obligatoria para un usuario nuevo.', 1;

        INSERT dbo.CAT_USUARIOS
        (IdUsuario, IdRol, NombreCompleto, ContrasenaHash, Correo, Activo)
        VALUES
        (@IdUsuario, @IdRol, @NombreCompleto, @ContrasenaHash, @Correo, @Activo);
    END
END;
GO

/* =============================================================
   4. PACIENTES
   ============================================================= */

CREATE OR ALTER PROCEDURE dbo.sp_Paciente_Obtener
    @IdPaciente VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdPaciente, PrimerNombre, SegundoNombre, PrimerApellido, SegundoApellido,
           FechaNacimiento, Sexo, Telefono, Activo
    FROM dbo.CAT_PACIENTES
    WHERE IdPaciente = @IdPaciente;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Paciente_Listar
    @Texto VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (200)
           IdPaciente, PrimerNombre, SegundoNombre, PrimerApellido, SegundoApellido,
           FechaNacimiento, Sexo, Telefono, Activo
    FROM dbo.CAT_PACIENTES
    WHERE @Texto IS NULL OR LTRIM(RTRIM(@Texto)) = ''
       OR IdPaciente LIKE '%' + @Texto + '%'
       OR CONCAT(PrimerNombre, ' ', ISNULL(SegundoNombre,''), ' ', PrimerApellido, ' ', ISNULL(SegundoApellido,'')) LIKE '%' + @Texto + '%'
    ORDER BY PrimerApellido, SegundoApellido, PrimerNombre;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Paciente_Guardar
    @IdPaciente VARCHAR(30),
    @PrimerNombre VARCHAR(50),
    @SegundoNombre VARCHAR(50) = NULL,
    @PrimerApellido VARCHAR(50),
    @SegundoApellido VARCHAR(50) = NULL,
    @FechaNacimiento DATE = NULL,
    @Sexo CHAR(1) = NULL,
    @Telefono VARCHAR(20) = NULL,
    @Activo BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.CAT_PACIENTES WHERE IdPaciente = @IdPaciente)
    BEGIN
        UPDATE dbo.CAT_PACIENTES
        SET PrimerNombre = @PrimerNombre,
            SegundoNombre = @SegundoNombre,
            PrimerApellido = @PrimerApellido,
            SegundoApellido = @SegundoApellido,
            FechaNacimiento = @FechaNacimiento,
            Sexo = @Sexo,
            Telefono = @Telefono,
            Activo = @Activo,
            FechaModificacion = SYSDATETIME()
        WHERE IdPaciente = @IdPaciente;
    END
    ELSE
    BEGIN
        INSERT dbo.CAT_PACIENTES
        (IdPaciente, PrimerNombre, SegundoNombre, PrimerApellido, SegundoApellido,
         FechaNacimiento, Sexo, Telefono, Activo)
        VALUES
        (@IdPaciente, @PrimerNombre, @SegundoNombre, @PrimerApellido, @SegundoApellido,
         @FechaNacimiento, @Sexo, @Telefono, @Activo);
    END
END;
GO

/* =============================================================
   5. CATÁLOGOS - MÉDICOS
   Los procedimientos CRUD genéricos devuelven alias uniformes
   para simplificar la capa ADO.NET.
   ============================================================= */

CREATE OR ALTER PROCEDURE dbo.sp_Medico_Listar @Texto VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdMedico AS Id, Nombres AS Nombre, CAST(NULL AS VARCHAR(250)) AS Descripcion,
           Apellidos AS Extra1, NoColegiado AS Extra2, Telefono AS Extra3, Correo AS Extra4, Activo
    FROM dbo.CAT_MEDICOS
    WHERE @Texto IS NULL OR LTRIM(RTRIM(@Texto)) = ''
       OR IdMedico LIKE '%' + @Texto + '%'
       OR Nombres LIKE '%' + @Texto + '%'
       OR Apellidos LIKE '%' + @Texto + '%'
    ORDER BY Apellidos, Nombres;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Medico_Obtener @Id VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdMedico AS Id, Nombres AS Nombre, CAST(NULL AS VARCHAR(250)) AS Descripcion,
           Apellidos AS Extra1, NoColegiado AS Extra2, Telefono AS Extra3, Correo AS Extra4, Activo
    FROM dbo.CAT_MEDICOS WHERE IdMedico = @Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Medico_Guardar
    @Id VARCHAR(30), @Nombre VARCHAR(150), @Descripcion VARCHAR(250)=NULL,
    @Extra1 VARCHAR(150)=NULL, @Extra2 VARCHAR(100)=NULL,
    @Extra3 VARCHAR(100)=NULL, @Extra4 VARCHAR(100)=NULL, @Activo BIT=1
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.CAT_MEDICOS WHERE IdMedico=@Id)
        UPDATE dbo.CAT_MEDICOS SET Nombres=@Nombre, Apellidos=@Extra1, NoColegiado=@Extra2,
               Telefono=@Extra3, Correo=@Extra4, Activo=@Activo WHERE IdMedico=@Id;
    ELSE
        INSERT dbo.CAT_MEDICOS(IdMedico,Nombres,Apellidos,NoColegiado,Telefono,Correo,Activo)
        VALUES(@Id,@Nombre,@Extra1,@Extra2,@Extra3,@Extra4,@Activo);
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Medico_ListarActivos
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdMedico, CONCAT(Nombres,' ',Apellidos) AS NombreCompleto
    FROM dbo.CAT_MEDICOS WHERE Activo=1 ORDER BY Apellidos,Nombres;
END;
GO

/* =============================================================
   6. CATÁLOGOS - TÉCNICOS
   ============================================================= */

CREATE OR ALTER PROCEDURE dbo.sp_Tecnico_Listar @Texto VARCHAR(100)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdTecnico AS Id, Nombres AS Nombre, CAST(NULL AS VARCHAR(250)) AS Descripcion,
           Apellidos AS Extra1, Telefono AS Extra2, Correo AS Extra3,
           CAST(NULL AS VARCHAR(100)) AS Extra4, Activo
    FROM dbo.CAT_TECNICOS_RADIOLOGOS
    WHERE @Texto IS NULL OR LTRIM(RTRIM(@Texto))=''
       OR IdTecnico LIKE '%' + @Texto + '%'
       OR Nombres LIKE '%' + @Texto + '%'
       OR Apellidos LIKE '%' + @Texto + '%'
    ORDER BY Apellidos,Nombres;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Tecnico_Obtener @Id VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdTecnico AS Id, Nombres AS Nombre, CAST(NULL AS VARCHAR(250)) AS Descripcion,
           Apellidos AS Extra1, Telefono AS Extra2, Correo AS Extra3,
           CAST(NULL AS VARCHAR(100)) AS Extra4, Activo
    FROM dbo.CAT_TECNICOS_RADIOLOGOS WHERE IdTecnico=@Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Tecnico_Guardar
    @Id VARCHAR(30), @Nombre VARCHAR(150), @Descripcion VARCHAR(250)=NULL,
    @Extra1 VARCHAR(150)=NULL, @Extra2 VARCHAR(100)=NULL,
    @Extra3 VARCHAR(100)=NULL, @Extra4 VARCHAR(100)=NULL, @Activo BIT=1
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.CAT_TECNICOS_RADIOLOGOS WHERE IdTecnico=@Id)
        UPDATE dbo.CAT_TECNICOS_RADIOLOGOS SET Nombres=@Nombre, Apellidos=@Extra1,
               Telefono=@Extra2, Correo=@Extra3, Activo=@Activo WHERE IdTecnico=@Id;
    ELSE
        INSERT dbo.CAT_TECNICOS_RADIOLOGOS(IdTecnico,Nombres,Apellidos,Telefono,Correo,Activo)
        VALUES(@Id,@Nombre,@Extra1,@Extra2,@Extra3,@Activo);
END;
GO

/* =============================================================
   7. CATÁLOGOS - SERVICIOS
   ============================================================= */

CREATE OR ALTER PROCEDURE dbo.sp_Servicio_Listar @Texto VARCHAR(100)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdServicio AS Id, NombreServicio AS Nombre, Descripcion,
           CAST(NULL AS VARCHAR(150)) AS Extra1, CAST(NULL AS VARCHAR(100)) AS Extra2,
           CAST(NULL AS VARCHAR(100)) AS Extra3, CAST(NULL AS VARCHAR(100)) AS Extra4, Activo
    FROM dbo.CAT_SERVICIOS_HOSPITALARIOS
    WHERE @Texto IS NULL OR LTRIM(RTRIM(@Texto))=''
       OR IdServicio LIKE '%' + @Texto + '%'
       OR NombreServicio LIKE '%' + @Texto + '%'
    ORDER BY NombreServicio;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Servicio_Obtener @Id VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdServicio AS Id, NombreServicio AS Nombre, Descripcion,
           CAST(NULL AS VARCHAR(150)) AS Extra1, CAST(NULL AS VARCHAR(100)) AS Extra2,
           CAST(NULL AS VARCHAR(100)) AS Extra3, CAST(NULL AS VARCHAR(100)) AS Extra4, Activo
    FROM dbo.CAT_SERVICIOS_HOSPITALARIOS WHERE IdServicio=@Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Servicio_Guardar
    @Id VARCHAR(30), @Nombre VARCHAR(150), @Descripcion VARCHAR(250)=NULL,
    @Extra1 VARCHAR(150)=NULL, @Extra2 VARCHAR(100)=NULL,
    @Extra3 VARCHAR(100)=NULL, @Extra4 VARCHAR(100)=NULL, @Activo BIT=1
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.CAT_SERVICIOS_HOSPITALARIOS WHERE IdServicio=@Id)
        UPDATE dbo.CAT_SERVICIOS_HOSPITALARIOS SET NombreServicio=@Nombre, Descripcion=@Descripcion,
               Activo=@Activo WHERE IdServicio=@Id;
    ELSE
        INSERT dbo.CAT_SERVICIOS_HOSPITALARIOS(IdServicio,NombreServicio,Descripcion,Activo)
        VALUES(@Id,@Nombre,@Descripcion,@Activo);
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Servicio_ListarActivos
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdServicio, NombreServicio
    FROM dbo.CAT_SERVICIOS_HOSPITALARIOS WHERE Activo=1 ORDER BY NombreServicio;
END;
GO

/* =============================================================
   8. CATÁLOGOS - CATEGORÍAS
   ============================================================= */

CREATE OR ALTER PROCEDURE dbo.sp_Categoria_Listar @Texto VARCHAR(100)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdCategoria AS Id, NombreCategoria AS Nombre, Descripcion,
           CAST(NULL AS VARCHAR(150)) AS Extra1, CAST(NULL AS VARCHAR(100)) AS Extra2,
           CAST(NULL AS VARCHAR(100)) AS Extra3, CAST(NULL AS VARCHAR(100)) AS Extra4, Activo
    FROM dbo.CAT_CATEGORIAS_PRUEBAS
    WHERE @Texto IS NULL OR LTRIM(RTRIM(@Texto))=''
       OR IdCategoria LIKE '%' + @Texto + '%'
       OR NombreCategoria LIKE '%' + @Texto + '%'
    ORDER BY NombreCategoria;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Categoria_Obtener @Id VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdCategoria AS Id, NombreCategoria AS Nombre, Descripcion,
           CAST(NULL AS VARCHAR(150)) AS Extra1, CAST(NULL AS VARCHAR(100)) AS Extra2,
           CAST(NULL AS VARCHAR(100)) AS Extra3, CAST(NULL AS VARCHAR(100)) AS Extra4, Activo
    FROM dbo.CAT_CATEGORIAS_PRUEBAS WHERE IdCategoria=@Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Categoria_Guardar
    @Id VARCHAR(30), @Nombre VARCHAR(150), @Descripcion VARCHAR(250)=NULL,
    @Extra1 VARCHAR(150)=NULL, @Extra2 VARCHAR(100)=NULL,
    @Extra3 VARCHAR(100)=NULL, @Extra4 VARCHAR(100)=NULL, @Activo BIT=1
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.CAT_CATEGORIAS_PRUEBAS WHERE IdCategoria=@Id)
        UPDATE dbo.CAT_CATEGORIAS_PRUEBAS SET NombreCategoria=@Nombre, Descripcion=@Descripcion,
               Activo=@Activo WHERE IdCategoria=@Id;
    ELSE
        INSERT dbo.CAT_CATEGORIAS_PRUEBAS(IdCategoria,NombreCategoria,Descripcion,Activo)
        VALUES(@Id,@Nombre,@Descripcion,@Activo);
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Categoria_ListarActivas
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdCategoria, NombreCategoria
    FROM dbo.CAT_CATEGORIAS_PRUEBAS WHERE Activo=1 ORDER BY NombreCategoria;
END;
GO

/* =============================================================
   9. CATÁLOGOS - PRUEBAS / ESTUDIOS
   ============================================================= */

CREATE OR ALTER PROCEDURE dbo.sp_Prueba_Listar @Texto VARCHAR(100)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT P.IdPrueba AS Id, P.NombrePrueba AS Nombre, P.Descripcion,
           P.IdCategoria AS Extra1, CAST(P.DuracionMinutos AS VARCHAR(100)) AS Extra2,
           C.NombreCategoria AS Extra3, CAST(NULL AS VARCHAR(100)) AS Extra4, P.Activo
    FROM dbo.CAT_PRUEBAS P
    INNER JOIN dbo.CAT_CATEGORIAS_PRUEBAS C ON C.IdCategoria=P.IdCategoria
    WHERE @Texto IS NULL OR LTRIM(RTRIM(@Texto))=''
       OR P.IdPrueba LIKE '%' + @Texto + '%'
       OR P.NombrePrueba LIKE '%' + @Texto + '%'
       OR C.NombreCategoria LIKE '%' + @Texto + '%'
    ORDER BY C.NombreCategoria,P.NombrePrueba;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Prueba_Obtener @Id VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT P.IdPrueba AS Id, P.NombrePrueba AS Nombre, P.Descripcion,
           P.IdCategoria AS Extra1, CAST(P.DuracionMinutos AS VARCHAR(100)) AS Extra2,
           C.NombreCategoria AS Extra3, CAST(NULL AS VARCHAR(100)) AS Extra4, P.Activo
    FROM dbo.CAT_PRUEBAS P
    INNER JOIN dbo.CAT_CATEGORIAS_PRUEBAS C ON C.IdCategoria=P.IdCategoria
    WHERE P.IdPrueba=@Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Prueba_Guardar
    @Id VARCHAR(30), @Nombre VARCHAR(150), @Descripcion VARCHAR(250)=NULL,
    @Extra1 VARCHAR(150)=NULL, @Extra2 VARCHAR(100)=NULL,
    @Extra3 VARCHAR(100)=NULL, @Extra4 VARCHAR(100)=NULL, @Activo BIT=1
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Duracion INT = TRY_CONVERT(INT, NULLIF(@Extra2,''));

    IF NOT EXISTS (SELECT 1 FROM dbo.CAT_CATEGORIAS_PRUEBAS WHERE IdCategoria=@Extra1)
        THROW 50020, 'La categoría seleccionada no existe.', 1;

    IF EXISTS (SELECT 1 FROM dbo.CAT_PRUEBAS WHERE IdPrueba=@Id)
        UPDATE dbo.CAT_PRUEBAS SET NombrePrueba=@Nombre, Descripcion=@Descripcion,
               IdCategoria=@Extra1, DuracionMinutos=@Duracion, Activo=@Activo
        WHERE IdPrueba=@Id;
    ELSE
        INSERT dbo.CAT_PRUEBAS(IdPrueba,IdCategoria,NombrePrueba,Descripcion,DuracionMinutos,Activo)
        VALUES(@Id,@Extra1,@Nombre,@Descripcion,@Duracion,@Activo);
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Prueba_ObtenerActiva @IdPrueba VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT P.IdPrueba,P.NombrePrueba,C.NombreCategoria
    FROM dbo.CAT_PRUEBAS P
    INNER JOIN dbo.CAT_CATEGORIAS_PRUEBAS C ON C.IdCategoria=P.IdCategoria
    WHERE P.IdPrueba=@IdPrueba AND P.Activo=1 AND C.Activo=1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Prueba_BuscarActivas @Texto VARCHAR(100)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (100) P.IdPrueba,P.NombrePrueba,C.NombreCategoria
    FROM dbo.CAT_PRUEBAS P
    INNER JOIN dbo.CAT_CATEGORIAS_PRUEBAS C ON C.IdCategoria=P.IdCategoria
    WHERE P.Activo=1 AND C.Activo=1
      AND (@Texto IS NULL OR LTRIM(RTRIM(@Texto))=''
        OR P.IdPrueba LIKE '%' + @Texto + '%'
        OR P.NombrePrueba LIKE '%' + @Texto + '%'
        OR C.NombreCategoria LIKE '%' + @Texto + '%')
    ORDER BY C.NombreCategoria,P.NombrePrueba;
END;
GO

/* =============================================================
   10. CATÁLOGOS - ROLES
   ============================================================= */

CREATE OR ALTER PROCEDURE dbo.sp_Rol_Listar @Texto VARCHAR(100)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CAST(IdRol AS VARCHAR(30)) AS Id, NombreRol AS Nombre, Descripcion,
           CAST(NULL AS VARCHAR(150)) AS Extra1, CAST(NULL AS VARCHAR(100)) AS Extra2,
           CAST(NULL AS VARCHAR(100)) AS Extra3, CAST(NULL AS VARCHAR(100)) AS Extra4, Activo
    FROM dbo.CAT_ROLES
    WHERE @Texto IS NULL OR LTRIM(RTRIM(@Texto))=''
       OR NombreRol LIKE '%' + @Texto + '%'
       OR Descripcion LIKE '%' + @Texto + '%'
    ORDER BY IdRol;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Rol_Obtener @Id VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CAST(IdRol AS VARCHAR(30)) AS Id, NombreRol AS Nombre, Descripcion,
           CAST(NULL AS VARCHAR(150)) AS Extra1, CAST(NULL AS VARCHAR(100)) AS Extra2,
           CAST(NULL AS VARCHAR(100)) AS Extra3, CAST(NULL AS VARCHAR(100)) AS Extra4, Activo
    FROM dbo.CAT_ROLES WHERE IdRol=TRY_CONVERT(INT,@Id);
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Rol_Guardar
    @Id VARCHAR(30)=NULL, @Nombre VARCHAR(150), @Descripcion VARCHAR(250)=NULL,
    @Extra1 VARCHAR(150)=NULL, @Extra2 VARCHAR(100)=NULL,
    @Extra3 VARCHAR(100)=NULL, @Extra4 VARCHAR(100)=NULL, @Activo BIT=1
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IdRol INT=TRY_CONVERT(INT,NULLIF(@Id,''));
    IF @IdRol IS NOT NULL AND EXISTS(SELECT 1 FROM dbo.CAT_ROLES WHERE IdRol=@IdRol)
        UPDATE dbo.CAT_ROLES SET NombreRol=@Nombre,Descripcion=@Descripcion,Activo=@Activo WHERE IdRol=@IdRol;
    ELSE
        INSERT dbo.CAT_ROLES(NombreRol,Descripcion,Activo) VALUES(@Nombre,@Descripcion,@Activo);
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Rol_ListarActivos
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdRol,NombreRol FROM dbo.CAT_ROLES WHERE Activo=1 ORDER BY NombreRol;
END;
GO

/* =============================================================
   11. CAPACIDAD
   ============================================================= */

CREATE OR ALTER PROCEDURE dbo.sp_Capacidad_Listar
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Dias AS
    (
        SELECT DiaSemana FROM (VALUES (1),(2),(3),(4),(5),(6),(7)) D(DiaSemana)
    )
    SELECT P.IdPrueba,P.NombrePrueba,D.DiaSemana,C.CantidadMaxima
    FROM dbo.CAT_PRUEBAS P
    CROSS JOIN Dias D
    LEFT JOIN dbo.CAPACIDAD C
      ON C.IdPrueba=P.IdPrueba AND C.DiaSemana=D.DiaSemana AND C.Activo=1
    WHERE P.Activo=1
    ORDER BY P.NombrePrueba,D.DiaSemana;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Capacidad_Guardar
    @IdPrueba VARCHAR(30),
    @DiaSemana TINYINT,
    @CantidadMaxima INT = NULL,
    @IdUsuario VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    IF @DiaSemana NOT BETWEEN 1 AND 7
        THROW 50030, 'Día de semana inválido.', 1;

    IF @CantidadMaxima IS NULL
    BEGIN
        UPDATE dbo.CAPACIDAD
        SET Activo=0, IdUsuarioModificacion=@IdUsuario, FechaModificacion=SYSDATETIME()
        WHERE IdPrueba=@IdPrueba AND DiaSemana=@DiaSemana;
        RETURN;
    END

    IF @CantidadMaxima <= 0
        THROW 50031, 'La capacidad debe ser mayor que cero.', 1;

    IF EXISTS(SELECT 1 FROM dbo.CAPACIDAD WHERE IdPrueba=@IdPrueba AND DiaSemana=@DiaSemana)
        UPDATE dbo.CAPACIDAD
        SET CantidadMaxima=@CantidadMaxima,Activo=1,
            IdUsuarioModificacion=@IdUsuario,FechaModificacion=SYSDATETIME()
        WHERE IdPrueba=@IdPrueba AND DiaSemana=@DiaSemana;
    ELSE
        INSERT dbo.CAPACIDAD(IdPrueba,DiaSemana,CantidadMaxima,IdUsuarioCreacion)
        VALUES(@IdPrueba,@DiaSemana,@CantidadMaxima,@IdUsuario);
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Capacidad_MesPorPruebas
    @Anio INT,
    @Mes INT,
    @IdsPruebas VARCHAR(MAX),
    @ExcluirIdCita INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET DATEFIRST 1;

    DECLARE @FechaInicio DATE=DATEFROMPARTS(@Anio,@Mes,1);
    DECLARE @FechaFin DATE=EOMONTH(@FechaInicio);

    CREATE TABLE #Selected(IdPrueba VARCHAR(30) NOT NULL PRIMARY KEY);
    INSERT #Selected
    SELECT DISTINCT LTRIM(RTRIM(value))
    FROM STRING_SPLIT(@IdsPruebas,',')
    WHERE LTRIM(RTRIM(value))<>'';

    CREATE TABLE #D
    (
        Fecha DATE NOT NULL,
        IdPrueba VARCHAR(30) NOT NULL,
        NombrePrueba VARCHAR(150) NOT NULL,
        Capacidad INT NULL,
        Utilizados INT NOT NULL,
        Disponibles INT NULL
    );

    ;WITH Dias AS
    (
        SELECT @FechaInicio Fecha
        UNION ALL SELECT DATEADD(DAY,1,Fecha) FROM Dias WHERE Fecha<@FechaFin
    )
    INSERT #D
    SELECT D.Fecha,P.IdPrueba,P.NombrePrueba,CAP.CantidadMaxima,
           ISNULL(U.Utilizados,0),
           CASE WHEN CAP.CantidadMaxima IS NULL THEN NULL
                WHEN CAP.CantidadMaxima-ISNULL(U.Utilizados,0)<0 THEN 0
                ELSE CAP.CantidadMaxima-ISNULL(U.Utilizados,0) END
    FROM Dias D
    CROSS JOIN #Selected S
    INNER JOIN dbo.CAT_PRUEBAS P ON P.IdPrueba=S.IdPrueba AND P.Activo=1
    OUTER APPLY
    (
        SELECT C.CantidadMaxima
        FROM dbo.CAPACIDAD C
        WHERE C.IdPrueba=P.IdPrueba
          AND C.DiaSemana=DATEPART(WEEKDAY,D.Fecha)
          AND C.Activo=1
    ) CAP
    OUTER APPLY
    (
        SELECT COUNT(*) Utilizados
        FROM dbo.DETALLE_CITA DC
        INNER JOIN dbo.CITA CI ON CI.IdCita=DC.IdCita
        WHERE DC.IdPrueba=P.IdPrueba
          AND CI.FechaCita=D.Fecha
          AND CI.Activo=1
          AND CI.Estado<>'CANCELADA'
          AND DC.Estado<>'CANCELADO'
          AND (@ExcluirIdCita IS NULL OR CI.IdCita<>@ExcluirIdCita)
    ) U
    OPTION(MAXRECURSION 100);

    SELECT Fecha,
           CASE WHEN SUM(CASE WHEN Capacidad IS NULL THEN 1 ELSE 0 END)>0 THEN 'NONE'
                WHEN MIN(Disponibles)<=0 THEN 'FULL'
                WHEN MIN(CAST(Disponibles AS DECIMAL(10,4))/NULLIF(Capacidad,0))<=0.25 THEN 'LOW'
                ELSE 'HIGH' END Estado
    FROM #D
    GROUP BY Fecha
    ORDER BY Fecha;

    SELECT Fecha,IdPrueba,NombrePrueba,Capacidad,Utilizados,Disponibles
    FROM #D ORDER BY Fecha,NombrePrueba;
END;
GO

/* =============================================================
   12. DASHBOARD
   ============================================================= */

CREATE OR ALTER PROCEDURE dbo.sp_Dashboard_ResumenDia @Fecha DATE
AS
BEGIN
    SET NOCOUNT ON;
    SELECT COUNT(*) CitasHoy,
           ISNULL(SUM(CASE WHEN Estado='PROGRAMADA' THEN 1 ELSE 0 END),0) Pendientes,
           ISNULL(SUM(CASE WHEN Estado='ATENDIDA' THEN 1 ELSE 0 END),0) Atendidas,
           ISNULL(SUM(CASE WHEN Estado='CANCELADA' THEN 1 ELSE 0 END),0) Canceladas
    FROM dbo.CITA
    WHERE FechaCita=@Fecha AND Activo=1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Dashboard_CapacidadDia @Fecha DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET DATEFIRST 1;
    DECLARE @DiaSemana TINYINT=DATEPART(WEEKDAY,@Fecha);

    ;WITH Uso AS
    (
        SELECT DC.IdPrueba,COUNT(*) Utilizados
        FROM dbo.DETALLE_CITA DC
        INNER JOIN dbo.CITA C ON C.IdCita=DC.IdCita
        WHERE C.FechaCita=@Fecha AND C.Activo=1
          AND C.Estado<>'CANCELADA' AND DC.Estado<>'CANCELADO'
        GROUP BY DC.IdPrueba
    )
    SELECT TOP (6)
           P.IdPrueba,P.NombrePrueba,CP.NombreCategoria,
           C.CantidadMaxima Capacidad,
           ISNULL(U.Utilizados,0) Utilizados,
           CASE WHEN C.CantidadMaxima-ISNULL(U.Utilizados,0)<0 THEN 0
                ELSE C.CantidadMaxima-ISNULL(U.Utilizados,0) END Disponibles,
           CAST(CASE WHEN C.CantidadMaxima=0 THEN 0
                     ELSE ISNULL(U.Utilizados,0)*100.0/C.CantidadMaxima END AS DECIMAL(6,2)) PorcentajeUso
    FROM dbo.CAPACIDAD C
    INNER JOIN dbo.CAT_PRUEBAS P ON P.IdPrueba=C.IdPrueba AND P.Activo=1
    INNER JOIN dbo.CAT_CATEGORIAS_PRUEBAS CP ON CP.IdCategoria=P.IdCategoria
    LEFT JOIN Uso U ON U.IdPrueba=P.IdPrueba
    WHERE C.DiaSemana=@DiaSemana AND C.Activo=1
    ORDER BY PorcentajeUso DESC,P.NombrePrueba;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Dashboard_ProximasCitas @Fecha DATE
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (8)
           C.IdCita,C.NumeroCita,C.FechaCita,C.HoraCita,C.IdPaciente,
           CONCAT(P.PrimerNombre,' ',COALESCE(P.SegundoNombre+' ',''),P.PrimerApellido,COALESCE(' '+P.SegundoApellido,'')) Paciente,
           ISNULL(E.Estudios,'') Estudios,C.Estado
    FROM dbo.CITA C
    INNER JOIN dbo.CAT_PACIENTES P ON P.IdPaciente=C.IdPaciente
    OUTER APPLY
    (
        SELECT STRING_AGG(PR.NombrePrueba,', ') Estudios
        FROM dbo.DETALLE_CITA DC
        INNER JOIN dbo.CAT_PRUEBAS PR ON PR.IdPrueba=DC.IdPrueba
        WHERE DC.IdCita=C.IdCita
    ) E
    WHERE C.FechaCita=@Fecha AND C.Activo=1 AND C.Estado<>'CANCELADA'
    ORDER BY C.HoraCita;
END;
GO

/* =============================================================
   13. CITAS
   ============================================================= */

CREATE OR ALTER PROCEDURE dbo.sp_Cita_Listar
    @FechaInicio DATE=NULL,
    @FechaFin DATE=NULL,
    @Paciente VARCHAR(100)=NULL,
    @Estado VARCHAR(20)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT C.IdCita,C.NumeroCita,C.FechaCita,C.HoraCita,C.IdPaciente,
           CONCAT(P.PrimerNombre,' ',COALESCE(P.SegundoNombre+' ',''),P.PrimerApellido,COALESCE(' '+P.SegundoApellido,'')) Paciente,
           CONCAT(M.Nombres,' ',M.Apellidos) Medico,
           S.NombreServicio Servicio,
           ISNULL(E.Estudios,'') Estudios,
           C.Estado
    FROM dbo.CITA C
    INNER JOIN dbo.CAT_PACIENTES P ON P.IdPaciente=C.IdPaciente
    INNER JOIN dbo.CAT_MEDICOS M ON M.IdMedico=C.IdMedico
    INNER JOIN dbo.CAT_SERVICIOS_HOSPITALARIOS S ON S.IdServicio=C.IdServicio
    OUTER APPLY
    (
        SELECT STRING_AGG(PR.NombrePrueba,', ') Estudios
        FROM dbo.DETALLE_CITA DC
        INNER JOIN dbo.CAT_PRUEBAS PR ON PR.IdPrueba=DC.IdPrueba
        WHERE DC.IdCita=C.IdCita
    ) E
    WHERE C.Activo=1
      AND (@FechaInicio IS NULL OR C.FechaCita>=@FechaInicio)
      AND (@FechaFin IS NULL OR C.FechaCita<=@FechaFin)
      AND (@Estado IS NULL OR @Estado='' OR C.Estado=@Estado)
      AND (@Paciente IS NULL OR @Paciente=''
           OR C.IdPaciente LIKE '%' + @Paciente + '%'
           OR CONCAT(P.PrimerNombre,' ',COALESCE(P.SegundoNombre+' ',''),P.PrimerApellido,' ',COALESCE(P.SegundoApellido,'')) LIKE '%' + @Paciente + '%')
    ORDER BY C.FechaCita DESC,C.HoraCita DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Cita_Obtener @IdCita INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT C.IdCita,C.NumeroCita,C.IdPaciente,
           CONCAT(P.PrimerNombre,' ',COALESCE(P.SegundoNombre+' ',''),P.PrimerApellido,COALESCE(' '+P.SegundoApellido,'')) Paciente,
           C.IdMedico,CONCAT(M.Nombres,' ',M.Apellidos) Medico,
           C.IdServicio,S.NombreServicio Servicio,
           C.FechaCita,C.HoraCita,C.Estado,C.Observaciones,
           U.NombreCompleto UsuarioCreacion,C.FechaCreacion
    FROM dbo.CITA C
    INNER JOIN dbo.CAT_PACIENTES P ON P.IdPaciente=C.IdPaciente
    INNER JOIN dbo.CAT_MEDICOS M ON M.IdMedico=C.IdMedico
    INNER JOIN dbo.CAT_SERVICIOS_HOSPITALARIOS S ON S.IdServicio=C.IdServicio
    INNER JOIN dbo.CAT_USUARIOS U ON U.IdUsuario=C.IdUsuarioCreacion
    WHERE C.IdCita=@IdCita AND C.Activo=1;

    SELECT DC.IdDetalleCita,DC.IdPrueba,P.NombrePrueba,CAT.NombreCategoria,
           DC.IdTecnico,
           CASE WHEN T.IdTecnico IS NULL THEN NULL ELSE CONCAT(T.Nombres,' ',T.Apellidos) END Tecnico,
           DC.Estado
    FROM dbo.DETALLE_CITA DC
    INNER JOIN dbo.CAT_PRUEBAS P ON P.IdPrueba=DC.IdPrueba
    INNER JOIN dbo.CAT_CATEGORIAS_PRUEBAS CAT ON CAT.IdCategoria=P.IdCategoria
    LEFT JOIN dbo.CAT_TECNICOS_RADIOLOGOS T ON T.IdTecnico=DC.IdTecnico
    WHERE DC.IdCita=@IdCita
    ORDER BY P.NombrePrueba;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Cita_Crear
    @IdPaciente VARCHAR(30),
    @IdMedico VARCHAR(30),
    @IdServicio VARCHAR(30),
    @FechaCita DATE,
    @HoraCita TIME(0),
    @Observaciones VARCHAR(500)=NULL,
    @IdUsuario VARCHAR(30),
    @Estudios dbo.TVP_EstudioCita READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET DATEFIRST 1;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    IF NOT EXISTS(SELECT 1 FROM @Estudios) THROW 50001,'Debe agregar por lo menos un estudio.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.CAT_PACIENTES WHERE IdPaciente=@IdPaciente AND Activo=1) THROW 50001,'Paciente inexistente o inactivo.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.CAT_MEDICOS WHERE IdMedico=@IdMedico AND Activo=1) THROW 50001,'Médico inexistente o inactivo.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.CAT_SERVICIOS_HOSPITALARIOS WHERE IdServicio=@IdServicio AND Activo=1) THROW 50001,'Servicio inexistente o inactivo.',1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @Dia TINYINT=DATEPART(WEEKDAY,@FechaCita);

        IF EXISTS
        (
            SELECT 1 FROM @Estudios E
            LEFT JOIN dbo.CAPACIDAD CAP WITH (UPDLOCK,HOLDLOCK)
              ON CAP.IdPrueba=E.IdPrueba AND CAP.DiaSemana=@Dia AND CAP.Activo=1
            WHERE CAP.IdCapacidad IS NULL
        )
            THROW 50001,'Uno o más estudios no tienen capacidad configurada para el día seleccionado.',1;

        IF EXISTS
        (
            SELECT 1
            FROM @Estudios E
            INNER JOIN dbo.CAPACIDAD CAP WITH (UPDLOCK,HOLDLOCK)
              ON CAP.IdPrueba=E.IdPrueba AND CAP.DiaSemana=@Dia AND CAP.Activo=1
            OUTER APPLY
            (
                SELECT COUNT(*) Utilizados
                FROM dbo.DETALLE_CITA DC
                INNER JOIN dbo.CITA C ON C.IdCita=DC.IdCita
                WHERE DC.IdPrueba=E.IdPrueba
                  AND C.FechaCita=@FechaCita
                  AND C.Activo=1
                  AND C.Estado<>'CANCELADA'
                  AND DC.Estado<>'CANCELADO'
            ) U
            WHERE ISNULL(U.Utilizados,0)>=CAP.CantidadMaxima
        )
            THROW 50001,'No existe cupo disponible para uno o más estudios seleccionados.',1;

        DECLARE @Tmp VARCHAR(30)=CONCAT('TMP-',REPLACE(CONVERT(VARCHAR(36),NEWID()),'-',''));
        INSERT dbo.CITA(NumeroCita,IdPaciente,IdMedico,IdServicio,FechaCita,HoraCita,Estado,Observaciones,IdUsuarioCreacion)
        VALUES(@Tmp,@IdPaciente,@IdMedico,@IdServicio,@FechaCita,@HoraCita,'PROGRAMADA',@Observaciones,@IdUsuario);

        DECLARE @IdCita INT=SCOPE_IDENTITY();
        DECLARE @Numero VARCHAR(30)=CONCAT('RAD-',YEAR(@FechaCita),'-',RIGHT('000000'+CAST(@IdCita AS VARCHAR(6)),6));

        UPDATE dbo.CITA SET NumeroCita=@Numero WHERE IdCita=@IdCita;
        INSERT dbo.DETALLE_CITA(IdCita,IdPrueba,Estado)
        SELECT @IdCita,IdPrueba,'PENDIENTE' FROM @Estudios;

        COMMIT;
        SELECT @IdCita IdCita,@Numero NumeroCita;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Cita_Actualizar
    @IdCita INT,
    @IdPaciente VARCHAR(30),
    @IdMedico VARCHAR(30),
    @IdServicio VARCHAR(30),
    @FechaCita DATE,
    @HoraCita TIME(0),
    @Observaciones VARCHAR(500)=NULL,
    @IdUsuario VARCHAR(30),
    @Estudios dbo.TVP_EstudioCita READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET DATEFIRST 1;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    IF NOT EXISTS(SELECT 1 FROM dbo.CITA WHERE IdCita=@IdCita AND Activo=1) THROW 50001,'La cita no existe.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.CITA WHERE IdCita=@IdCita AND Activo=1 AND Estado='PROGRAMADA')
        THROW 50001,'Solo las citas programadas pueden modificarse.',1;
    IF NOT EXISTS(SELECT 1 FROM @Estudios) THROW 50001,'Debe conservar por lo menos un estudio.',1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @Dia TINYINT=DATEPART(WEEKDAY,@FechaCita);

        IF EXISTS
        (
            SELECT 1 FROM @Estudios E
            LEFT JOIN dbo.CAPACIDAD CAP WITH (UPDLOCK,HOLDLOCK)
              ON CAP.IdPrueba=E.IdPrueba AND CAP.DiaSemana=@Dia AND CAP.Activo=1
            WHERE CAP.IdCapacidad IS NULL
        )
            THROW 50001,'Uno o más estudios no tienen capacidad configurada para el día seleccionado.',1;

        IF EXISTS
        (
            SELECT 1
            FROM @Estudios E
            INNER JOIN dbo.CAPACIDAD CAP WITH (UPDLOCK,HOLDLOCK)
              ON CAP.IdPrueba=E.IdPrueba AND CAP.DiaSemana=@Dia AND CAP.Activo=1
            OUTER APPLY
            (
                SELECT COUNT(*) Utilizados
                FROM dbo.DETALLE_CITA DC
                INNER JOIN dbo.CITA C ON C.IdCita=DC.IdCita
                WHERE DC.IdPrueba=E.IdPrueba
                  AND C.FechaCita=@FechaCita
                  AND C.IdCita<>@IdCita
                  AND C.Activo=1
                  AND C.Estado<>'CANCELADA'
                  AND DC.Estado<>'CANCELADO'
            ) U
            WHERE ISNULL(U.Utilizados,0)>=CAP.CantidadMaxima
        )
            THROW 50001,'No existe cupo disponible para uno o más estudios seleccionados.',1;

        UPDATE dbo.CITA
        SET IdMedico=@IdMedico,IdServicio=@IdServicio,FechaCita=@FechaCita,HoraCita=@HoraCita,
            Observaciones=@Observaciones,IdUsuarioModificacion=@IdUsuario,FechaModificacion=SYSDATETIME()
        WHERE IdCita=@IdCita;

        -- Se conservan los datos de detalle (por ejemplo IdTecnico) cuando el estudio
        -- continúa en la cita. Solo se eliminan estudios retirados y se insertan nuevos.
        DELETE DC
        FROM dbo.DETALLE_CITA DC
        WHERE DC.IdCita=@IdCita
          AND NOT EXISTS (SELECT 1 FROM @Estudios E WHERE E.IdPrueba=DC.IdPrueba);

        INSERT dbo.DETALLE_CITA(IdCita,IdPrueba,Estado)
        SELECT @IdCita,E.IdPrueba,'PENDIENTE'
        FROM @Estudios E
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.DETALLE_CITA DC
            WHERE DC.IdCita=@IdCita AND DC.IdPrueba=E.IdPrueba
        );

        DECLARE @Numero VARCHAR(30)=(SELECT NumeroCita FROM dbo.CITA WHERE IdCita=@IdCita);
        COMMIT;
        SELECT @IdCita IdCita,@Numero NumeroCita;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Cita_CambiarEstado
    @IdCita INT,
    @Estado VARCHAR(20),
    @IdUsuario VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    IF @Estado NOT IN ('PROGRAMADA','ATENDIDA','CANCELADA','NO_ASISTIO')
        THROW 50040,'Estado inválido.',1;

    IF NOT EXISTS(SELECT 1 FROM dbo.CITA WHERE IdCita=@IdCita AND Activo=1)
        THROW 50041,'La cita no existe.',1;

    IF @Estado<>'PROGRAMADA' AND NOT EXISTS(
        SELECT 1 FROM dbo.CITA WHERE IdCita=@IdCita AND Activo=1 AND Estado='PROGRAMADA')
        THROW 50042,'La cita ya no se encuentra en estado PROGRAMADA.',1;

    UPDATE dbo.CITA
    SET Estado=@Estado,IdUsuarioModificacion=@IdUsuario,FechaModificacion=SYSDATETIME()
    WHERE IdCita=@IdCita AND Activo=1;

    -- Regla provisional de la versión funcional:
    -- CANCELADA y NO_ASISTIO liberan los cupos; ATENDIDA marca estudios como realizados.
    IF @Estado='ATENDIDA'
        UPDATE dbo.DETALLE_CITA SET Estado='REALIZADO'
        WHERE IdCita=@IdCita AND Estado='PENDIENTE';
    ELSE IF @Estado IN ('CANCELADA','NO_ASISTIO')
        UPDATE dbo.DETALLE_CITA SET Estado='CANCELADO'
        WHERE IdCita=@IdCita AND Estado='PENDIENTE';
END;
GO

/* =============================================================
   14. REPORTES
   ============================================================= */

CREATE OR ALTER PROCEDURE dbo.sp_Reporte_Resumen
    @FechaInicio DATE,@FechaFin DATE
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        (SELECT COUNT(*) FROM dbo.CITA WHERE Activo=1 AND FechaCita BETWEEN @FechaInicio AND @FechaFin) TotalCitas,
        (SELECT COUNT(*) FROM dbo.CITA WHERE Activo=1 AND Estado='PROGRAMADA' AND FechaCita BETWEEN @FechaInicio AND @FechaFin) Programadas,
        (SELECT COUNT(*) FROM dbo.CITA WHERE Activo=1 AND Estado='ATENDIDA' AND FechaCita BETWEEN @FechaInicio AND @FechaFin) Atendidas,
        (SELECT COUNT(*) FROM dbo.CITA WHERE Activo=1 AND Estado='CANCELADA' AND FechaCita BETWEEN @FechaInicio AND @FechaFin) Canceladas,
        (SELECT COUNT(*) FROM dbo.CITA WHERE Activo=1 AND Estado='NO_ASISTIO' AND FechaCita BETWEEN @FechaInicio AND @FechaFin) NoAsistio,
        (SELECT COUNT(*)
         FROM dbo.DETALLE_CITA DC INNER JOIN dbo.CITA C ON C.IdCita=DC.IdCita
         WHERE C.Activo=1 AND C.FechaCita BETWEEN @FechaInicio AND @FechaFin AND DC.Estado='REALIZADO') EstudiosRealizados;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Reporte_EstudiosRealizados
    @FechaInicio DATE,@FechaFin DATE
AS
BEGIN
    SET NOCOUNT ON;
    SELECT P.IdPrueba,P.NombrePrueba,CAT.NombreCategoria Categoria,COUNT(*) Cantidad
    FROM dbo.DETALLE_CITA DC
    INNER JOIN dbo.CITA C ON C.IdCita=DC.IdCita
    INNER JOIN dbo.CAT_PRUEBAS P ON P.IdPrueba=DC.IdPrueba
    INNER JOIN dbo.CAT_CATEGORIAS_PRUEBAS CAT ON CAT.IdCategoria=P.IdCategoria
    WHERE C.Activo=1 AND C.FechaCita BETWEEN @FechaInicio AND @FechaFin
      AND DC.Estado='REALIZADO'
    GROUP BY P.IdPrueba,P.NombrePrueba,CAT.NombreCategoria
    ORDER BY Cantidad DESC,P.NombrePrueba;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Reporte_Citas
    @FechaInicio DATE,@FechaFin DATE
AS
BEGIN
    SET NOCOUNT ON;
    SELECT C.NumeroCita,C.FechaCita,C.HoraCita,C.IdPaciente,
           CONCAT(P.PrimerNombre,' ',COALESCE(P.SegundoNombre+' ',''),P.PrimerApellido,COALESCE(' '+P.SegundoApellido,'')) Paciente,
           S.NombreServicio Servicio,
           ISNULL(E.Estudios,'') Estudios,C.Estado
    FROM dbo.CITA C
    INNER JOIN dbo.CAT_PACIENTES P ON P.IdPaciente=C.IdPaciente
    INNER JOIN dbo.CAT_SERVICIOS_HOSPITALARIOS S ON S.IdServicio=C.IdServicio
    OUTER APPLY
    (
        SELECT STRING_AGG(PR.NombrePrueba,', ') Estudios
        FROM dbo.DETALLE_CITA DC
        INNER JOIN dbo.CAT_PRUEBAS PR ON PR.IdPrueba=DC.IdPrueba
        WHERE DC.IdCita=C.IdCita
    ) E
    WHERE C.Activo=1 AND C.FechaCita BETWEEN @FechaInicio AND @FechaFin
    ORDER BY C.FechaCita,C.HoraCita;
END;
GO

/* =============================================================
   15. DATOS DE DEMOSTRACIÓN DEL DÍA ACTUAL
   ============================================================= */

DECLARE @Hoy DATE=CAST(GETDATE() AS DATE);

INSERT dbo.CITA
(NumeroCita,IdPaciente,IdMedico,IdServicio,FechaCita,HoraCita,Estado,IdUsuarioCreacion)
VALUES
(CONCAT('RAD-',YEAR(@Hoy),'-DEMO01'),'152487','MED001','SER001',@Hoy,'08:00','ATENDIDA','ADMIN01'),
(CONCAT('RAD-',YEAR(@Hoy),'-DEMO02'),'100002','MED002','SER002',@Hoy,'08:30','PROGRAMADA','ADMIN01'),
(CONCAT('RAD-',YEAR(@Hoy),'-DEMO03'),'100003','MED001','SER003',@Hoy,'09:00','PROGRAMADA','ADMIN01'),
(CONCAT('RAD-',YEAR(@Hoy),'-DEMO04'),'100004','MED003','SER001',@Hoy,'09:30','PROGRAMADA','ADMIN01'),
(CONCAT('RAD-',YEAR(@Hoy),'-DEMO05'),'100005','MED002','SER004',@Hoy,'10:00','CANCELADA','ADMIN01'),
(CONCAT('RAD-',YEAR(@Hoy),'-DEMO06'),'152487','MED001','SER002',@Hoy,'10:30','ATENDIDA','ADMIN01'),
(CONCAT('RAD-',YEAR(@Hoy),'-DEMO07'),'100002','MED002','SER002',@Hoy,'11:00','PROGRAMADA','ADMIN01'),
(CONCAT('RAD-',YEAR(@Hoy),'-DEMO08'),'100003','MED001','SER003',@Hoy,'11:30','PROGRAMADA','ADMIN01');

DECLARE @D1 INT=(SELECT IdCita FROM dbo.CITA WHERE NumeroCita=CONCAT('RAD-',YEAR(@Hoy),'-DEMO01'));
DECLARE @D2 INT=(SELECT IdCita FROM dbo.CITA WHERE NumeroCita=CONCAT('RAD-',YEAR(@Hoy),'-DEMO02'));
DECLARE @D3 INT=(SELECT IdCita FROM dbo.CITA WHERE NumeroCita=CONCAT('RAD-',YEAR(@Hoy),'-DEMO03'));
DECLARE @D4 INT=(SELECT IdCita FROM dbo.CITA WHERE NumeroCita=CONCAT('RAD-',YEAR(@Hoy),'-DEMO04'));
DECLARE @D5 INT=(SELECT IdCita FROM dbo.CITA WHERE NumeroCita=CONCAT('RAD-',YEAR(@Hoy),'-DEMO05'));
DECLARE @D6 INT=(SELECT IdCita FROM dbo.CITA WHERE NumeroCita=CONCAT('RAD-',YEAR(@Hoy),'-DEMO06'));
DECLARE @D7 INT=(SELECT IdCita FROM dbo.CITA WHERE NumeroCita=CONCAT('RAD-',YEAR(@Hoy),'-DEMO07'));
DECLARE @D8 INT=(SELECT IdCita FROM dbo.CITA WHERE NumeroCita=CONCAT('RAD-',YEAR(@Hoy),'-DEMO08'));

INSERT dbo.DETALLE_CITA(IdCita,IdPrueba,IdTecnico,Estado)
VALUES
(@D1,'US001','TEC001','REALIZADO'),
(@D2,'RX001','TEC003','PENDIENTE'),
(@D2,'RX003','TEC003','PENDIENTE'),
(@D3,'MAM001','TEC002','PENDIENTE'),
(@D4,'US002','TEC001','PENDIENTE'),
(@D5,'RX001',NULL,'CANCELADO'),
(@D6,'MAM001','TEC002','REALIZADO'),
(@D7,'MAM001',NULL,'PENDIENTE'),
(@D8,'US001',NULL,'PENDIENTE');
GO

PRINT '=============================================================';
PRINT 'RIS_HRO instalado correctamente.';
PRINT 'Administrador: ADMIN01 / Admin123*';
PRINT 'Usuario citas: CITAS01 / Citas123*';
PRINT 'Paciente demo: 152487';
PRINT '=============================================================';
GO
