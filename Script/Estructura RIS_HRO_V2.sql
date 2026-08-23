/* ============================================================
   PROYECTO: RIS_HRO
   VERSION: 1.1 - Capacidad por prueba/examen
   MOTOR: Microsoft SQL Server

   CAMBIO PRINCIPAL:
   - La capacidad diaria se controla por IdPrueba.
   - Cada estudio registrado en DETALLE_CITA consume 1 cupo.
   ============================================================ */

USE master;
GO

IF DB_ID('RIS_HRO') IS NULL
BEGIN
    CREATE DATABASE RIS_HRO;
END;
GO

USE RIS_HRO;
GO

/* ============================================================
   1. CAT_ROLES
   ============================================================ */
CREATE TABLE dbo.CAT_ROLES
(
    IdRol               INT IDENTITY(1,1) NOT NULL,
    NombreRol           VARCHAR(50) NOT NULL,
    Descripcion         VARCHAR(200) NULL,
    Activo              BIT NOT NULL CONSTRAINT DF_CAT_ROLES_Activo DEFAULT (1),
    FechaCreacion       DATETIME2(0) NOT NULL CONSTRAINT DF_CAT_ROLES_FechaCreacion DEFAULT (SYSDATETIME()),

    CONSTRAINT PK_CAT_ROLES PRIMARY KEY (IdRol),
    CONSTRAINT UQ_CAT_ROLES_NombreRol UNIQUE (NombreRol)
);
GO

/* ============================================================
   2. CAT_USUARIOS
   ============================================================ */
CREATE TABLE dbo.CAT_USUARIOS
(
    IdUsuario           VARCHAR(30) NOT NULL,
    IdRol               INT NOT NULL,
    NombreCompleto      VARCHAR(150) NOT NULL,
    ContrasenaHash      VARCHAR(255) NOT NULL,
    Correo              VARCHAR(100) NULL,
    Activo              BIT NOT NULL CONSTRAINT DF_CAT_USUARIOS_Activo DEFAULT (1),
    FechaCreacion       DATETIME2(0) NOT NULL CONSTRAINT DF_CAT_USUARIOS_FechaCreacion DEFAULT (SYSDATETIME()),
    UltimoAcceso        DATETIME2(0) NULL,

    CONSTRAINT PK_CAT_USUARIOS PRIMARY KEY (IdUsuario),
    CONSTRAINT FK_CAT_USUARIOS_CAT_ROLES
        FOREIGN KEY (IdRol) REFERENCES dbo.CAT_ROLES(IdRol)
);
GO

/* ============================================================
   3. CAT_PACIENTES
   ============================================================ */
CREATE TABLE dbo.CAT_PACIENTES
(
    IdPaciente          VARCHAR(30) NOT NULL,
    PrimerNombre        VARCHAR(50) NOT NULL,
    SegundoNombre       VARCHAR(50) NULL,
    PrimerApellido      VARCHAR(50) NOT NULL,
    SegundoApellido     VARCHAR(50) NULL,
    FechaNacimiento     DATE NULL,
    Sexo                CHAR(1) NULL,
    Telefono            VARCHAR(20) NULL,
    Activo              BIT NOT NULL CONSTRAINT DF_CAT_PACIENTES_Activo DEFAULT (1),
    FechaCreacion       DATETIME2(0) NOT NULL CONSTRAINT DF_CAT_PACIENTES_FechaCreacion DEFAULT (SYSDATETIME()),

    CONSTRAINT PK_CAT_PACIENTES PRIMARY KEY (IdPaciente),
    CONSTRAINT CK_CAT_PACIENTES_Sexo
        CHECK (Sexo IS NULL OR Sexo IN ('M','F'))
);
GO

/* ============================================================
   4. CAT_MEDICOS
   ============================================================ */
CREATE TABLE dbo.CAT_MEDICOS
(
    IdMedico            VARCHAR(30) NOT NULL,
    Nombres             VARCHAR(100) NOT NULL,
    Apellidos           VARCHAR(100) NOT NULL,
    NoColegiado         VARCHAR(30) NULL,
    Telefono            VARCHAR(20) NULL,
    Correo              VARCHAR(100) NULL,
    Activo              BIT NOT NULL CONSTRAINT DF_CAT_MEDICOS_Activo DEFAULT (1),
    FechaCreacion       DATETIME2(0) NOT NULL CONSTRAINT DF_CAT_MEDICOS_FechaCreacion DEFAULT (SYSDATETIME()),

    CONSTRAINT PK_CAT_MEDICOS PRIMARY KEY (IdMedico)
);
GO

/* ============================================================
   5. CAT_TECNICOS_RADIOLOGOS
   ============================================================ */
CREATE TABLE dbo.CAT_TECNICOS_RADIOLOGOS
(
    IdTecnico           VARCHAR(30) NOT NULL,
    Nombres             VARCHAR(100) NOT NULL,
    Apellidos           VARCHAR(100) NOT NULL,
    Telefono            VARCHAR(20) NULL,
    Correo              VARCHAR(100) NULL,
    Activo              BIT NOT NULL CONSTRAINT DF_CAT_TECNICOS_RADIOLOGOS_Activo DEFAULT (1),
    FechaCreacion       DATETIME2(0) NOT NULL CONSTRAINT DF_CAT_TECNICOS_RADIOLOGOS_FechaCreacion DEFAULT (SYSDATETIME()),

    CONSTRAINT PK_CAT_TECNICOS_RADIOLOGOS PRIMARY KEY (IdTecnico)
);
GO

/* ============================================================
   6. CAT_SERVICIOS_HOSPITALARIOS
   ============================================================ */
CREATE TABLE dbo.CAT_SERVICIOS_HOSPITALARIOS
(
    IdServicio          VARCHAR(30) NOT NULL,
    NombreServicio      VARCHAR(100) NOT NULL,
    Descripcion         VARCHAR(200) NULL,
    Activo              BIT NOT NULL CONSTRAINT DF_CAT_SERVICIOS_HOSPITALARIOS_Activo DEFAULT (1),
    FechaCreacion       DATETIME2(0) NOT NULL CONSTRAINT DF_CAT_SERVICIOS_HOSPITALARIOS_FechaCreacion DEFAULT (SYSDATETIME()),

    CONSTRAINT PK_CAT_SERVICIOS_HOSPITALARIOS PRIMARY KEY (IdServicio)
);
GO

/* ============================================================
   7. CAT_CATEGORIAS_PRUEBAS
   Se conserva únicamente para clasificación de estudios.
   Ya NO controla la capacidad.
   ============================================================ */
CREATE TABLE dbo.CAT_CATEGORIAS_PRUEBAS
(
    IdCategoria         VARCHAR(20) NOT NULL,
    NombreCategoria     VARCHAR(100) NOT NULL,
    Descripcion         VARCHAR(250) NULL,
    Activo              BIT NOT NULL CONSTRAINT DF_CAT_CATEGORIAS_PRUEBAS_Activo DEFAULT (1),
    FechaCreacion       DATETIME2(0) NOT NULL CONSTRAINT DF_CAT_CATEGORIAS_PRUEBAS_FechaCreacion DEFAULT (SYSDATETIME()),

    CONSTRAINT PK_CAT_CATEGORIAS_PRUEBAS PRIMARY KEY (IdCategoria),
    CONSTRAINT UQ_CAT_CATEGORIAS_PRUEBAS_NombreCategoria UNIQUE (NombreCategoria)
);
GO

/* ============================================================
   8. CAT_PRUEBAS
   ============================================================ */
CREATE TABLE dbo.CAT_PRUEBAS
(
    IdPrueba            VARCHAR(30) NOT NULL,
    IdCategoria         VARCHAR(20) NOT NULL,
    NombrePrueba        VARCHAR(150) NOT NULL,
    Descripcion         VARCHAR(250) NULL,
    DuracionMinutos     INT NULL,
    Activo              BIT NOT NULL CONSTRAINT DF_CAT_PRUEBAS_Activo DEFAULT (1),
    FechaCreacion       DATETIME2(0) NOT NULL CONSTRAINT DF_CAT_PRUEBAS_FechaCreacion DEFAULT (SYSDATETIME()),

    CONSTRAINT PK_CAT_PRUEBAS PRIMARY KEY (IdPrueba),
    CONSTRAINT FK_CAT_PRUEBAS_CAT_CATEGORIAS_PRUEBAS
        FOREIGN KEY (IdCategoria)
        REFERENCES dbo.CAT_CATEGORIAS_PRUEBAS(IdCategoria),
    CONSTRAINT CK_CAT_PRUEBAS_DuracionMinutos
        CHECK (DuracionMinutos IS NULL OR DuracionMinutos > 0)
);
GO

/* ============================================================
   9. CAPACIDAD
   CAMBIO V1.1:
   La capacidad se configura por PRUEBA y día de la semana.
   DiaSemana:
   1=Lunes, 2=Martes, 3=Miércoles, 4=Jueves,
   5=Viernes, 6=Sábado, 7=Domingo
   ============================================================ */
CREATE TABLE dbo.CAPACIDAD
(
    IdCapacidad             INT IDENTITY(1,1) NOT NULL,
    IdPrueba                VARCHAR(30) NOT NULL,
    DiaSemana               TINYINT NOT NULL,
    CantidadMaxima          INT NOT NULL,
    Activo                  BIT NOT NULL CONSTRAINT DF_CAPACIDAD_Activo DEFAULT (1),
    IdUsuarioCreacion       VARCHAR(30) NOT NULL,
    FechaCreacion           DATETIME2(0) NOT NULL CONSTRAINT DF_CAPACIDAD_FechaCreacion DEFAULT (SYSDATETIME()),
    IdUsuarioModificacion   VARCHAR(30) NULL,
    FechaModificacion       DATETIME2(0) NULL,

    CONSTRAINT PK_CAPACIDAD PRIMARY KEY (IdCapacidad),

    CONSTRAINT FK_CAPACIDAD_CAT_PRUEBAS
        FOREIGN KEY (IdPrueba)
        REFERENCES dbo.CAT_PRUEBAS(IdPrueba),

    CONSTRAINT FK_CAPACIDAD_USUARIO_CREACION
        FOREIGN KEY (IdUsuarioCreacion)
        REFERENCES dbo.CAT_USUARIOS(IdUsuario),

    CONSTRAINT FK_CAPACIDAD_USUARIO_MODIFICACION
        FOREIGN KEY (IdUsuarioModificacion)
        REFERENCES dbo.CAT_USUARIOS(IdUsuario),

    CONSTRAINT CK_CAPACIDAD_DiaSemana
        CHECK (DiaSemana BETWEEN 1 AND 7),

    CONSTRAINT CK_CAPACIDAD_CantidadMaxima
        CHECK (CantidadMaxima > 0),

    CONSTRAINT UQ_CAPACIDAD_Prueba_Dia
        UNIQUE (IdPrueba, DiaSemana)
);
GO

/* ============================================================
   10. CITA
   Encabezado de la cita.
   ============================================================ */
CREATE TABLE dbo.CITA
(
    IdCita                  INT IDENTITY(1,1) NOT NULL,
    NumeroCita              VARCHAR(30) NOT NULL,
    IdPaciente              VARCHAR(30) NOT NULL,
    IdMedico                VARCHAR(30) NOT NULL,
    IdServicio              VARCHAR(30) NOT NULL,
    FechaCita               DATE NOT NULL,
    HoraCita                TIME(0) NOT NULL,
    Estado                  VARCHAR(20) NOT NULL
                                CONSTRAINT DF_CITA_Estado DEFAULT ('PROGRAMADA'),
    Observaciones           VARCHAR(500) NULL,
    IdUsuarioCreacion       VARCHAR(30) NOT NULL,
    FechaCreacion           DATETIME2(0) NOT NULL
                                CONSTRAINT DF_CITA_FechaCreacion DEFAULT (SYSDATETIME()),
    IdUsuarioModificacion   VARCHAR(30) NULL,
    FechaModificacion       DATETIME2(0) NULL,
    Activo                  BIT NOT NULL CONSTRAINT DF_CITA_Activo DEFAULT (1),

    CONSTRAINT PK_CITA PRIMARY KEY (IdCita),
    CONSTRAINT UQ_CITA_NumeroCita UNIQUE (NumeroCita),

    CONSTRAINT FK_CITA_CAT_PACIENTES
        FOREIGN KEY (IdPaciente)
        REFERENCES dbo.CAT_PACIENTES(IdPaciente),

    CONSTRAINT FK_CITA_CAT_MEDICOS
        FOREIGN KEY (IdMedico)
        REFERENCES dbo.CAT_MEDICOS(IdMedico),

    CONSTRAINT FK_CITA_CAT_SERVICIOS_HOSPITALARIOS
        FOREIGN KEY (IdServicio)
        REFERENCES dbo.CAT_SERVICIOS_HOSPITALARIOS(IdServicio),

    CONSTRAINT FK_CITA_USUARIO_CREACION
        FOREIGN KEY (IdUsuarioCreacion)
        REFERENCES dbo.CAT_USUARIOS(IdUsuario),

    CONSTRAINT FK_CITA_USUARIO_MODIFICACION
        FOREIGN KEY (IdUsuarioModificacion)
        REFERENCES dbo.CAT_USUARIOS(IdUsuario),

    CONSTRAINT CK_CITA_Estado
        CHECK (Estado IN ('PROGRAMADA','ATENDIDA','CANCELADA','NO_ASISTIO'))
);
GO

/* ============================================================
   11. DETALLE_CITA
   CAMBIO V1.1:
   Cada registro de detalle representa un estudio solicitado
   y consume 1 cupo de la prueba correspondiente.
   ============================================================ */
CREATE TABLE dbo.DETALLE_CITA
(
    IdDetalleCita           INT IDENTITY(1,1) NOT NULL,
    IdCita                  INT NOT NULL,
    IdPrueba                VARCHAR(30) NOT NULL,
    IdTecnico               VARCHAR(30) NULL,
    Estado                  VARCHAR(20) NOT NULL
                                CONSTRAINT DF_DETALLE_CITA_Estado DEFAULT ('PENDIENTE'),
    Observaciones           VARCHAR(300) NULL,
    FechaCreacion           DATETIME2(0) NOT NULL
                                CONSTRAINT DF_DETALLE_CITA_FechaCreacion DEFAULT (SYSDATETIME()),

    CONSTRAINT PK_DETALLE_CITA PRIMARY KEY (IdDetalleCita),

    CONSTRAINT FK_DETALLE_CITA_CITA
        FOREIGN KEY (IdCita)
        REFERENCES dbo.CITA(IdCita),

    CONSTRAINT FK_DETALLE_CITA_CAT_PRUEBAS
        FOREIGN KEY (IdPrueba)
        REFERENCES dbo.CAT_PRUEBAS(IdPrueba),

    CONSTRAINT FK_DETALLE_CITA_CAT_TECNICOS_RADIOLOGOS
        FOREIGN KEY (IdTecnico)
        REFERENCES dbo.CAT_TECNICOS_RADIOLOGOS(IdTecnico),

    CONSTRAINT CK_DETALLE_CITA_Estado
        CHECK (Estado IN ('PENDIENTE','REALIZADO','CANCELADO'))
);
GO

/* ============================================================
   ÍNDICES BÁSICOS
   ============================================================ */

CREATE INDEX IX_CITA_FechaCita
    ON dbo.CITA (FechaCita);
GO

CREATE INDEX IX_CITA_Paciente_Fecha
    ON dbo.CITA (IdPaciente, FechaCita);
GO

CREATE INDEX IX_CITA_Fecha_Hora
    ON dbo.CITA (FechaCita, HoraCita);
GO

CREATE INDEX IX_DETALLE_CITA_IdCita
    ON dbo.DETALLE_CITA (IdCita);
GO

CREATE INDEX IX_DETALLE_CITA_IdPrueba
    ON dbo.DETALLE_CITA (IdPrueba);
GO

CREATE INDEX IX_CAT_PRUEBAS_IdCategoria
    ON dbo.CAT_PRUEBAS (IdCategoria);
GO

CREATE INDEX IX_CAPACIDAD_IdPrueba_DiaSemana
    ON dbo.CAPACIDAD (IdPrueba, DiaSemana);
GO

/* ============================================================
   DATOS INICIALES DE ROLES
   ============================================================ */

INSERT INTO dbo.CAT_ROLES (NombreRol, Descripcion)
VALUES
('ADMINISTRADOR', 'Acceso completo a la administración y operación del sistema'),
('USUARIO_CITAS', 'Acceso operativo para registrar y consultar citas');
GO

/* ============================================================
   EJEMPLO DE LA NUEVA REGLA DE CAPACIDAD

   Si una cita tiene:
       RX001 - Rayos X de tórax
       RX002 - Rayos X de columna
       US001 - Ultrasonido abdominal

   entonces consume:
       RX001 = 1 cupo
       RX002 = 1 cupo
       US001 = 1 cupo

   Aunque todos pertenezcan al mismo paciente.
   ============================================================ */

/* ============================================================
   FIN DEL SCRIPT - RIS_HRO V1.1
   ============================================================ */
