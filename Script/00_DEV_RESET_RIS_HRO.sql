/* ============================================================
   RIS_HRO - BASE DE DATOS DE DESARROLLO
   MVP: Login + Dashboard + Creación de citas
   IMPORTANTE: ESTE SCRIPT ELIMINA Y RECREA RIS_HRO.
   Utilícelo únicamente en el ambiente de desarrollo.
   ============================================================ */
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

CREATE TABLE dbo.CAT_ROLES
(
    IdRol INT IDENTITY(1,1) NOT NULL,
    NombreRol VARCHAR(50) NOT NULL,
    Descripcion VARCHAR(200) NULL,
    Activo BIT NOT NULL CONSTRAINT DF_CAT_ROLES_Activo DEFAULT (1),
    FechaCreacion DATETIME2(0) NOT NULL CONSTRAINT DF_CAT_ROLES_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_CAT_ROLES PRIMARY KEY (IdRol),
    CONSTRAINT UQ_CAT_ROLES_Nombre UNIQUE (NombreRol)
);
GO

CREATE TABLE dbo.CAT_USUARIOS
(
    IdUsuario VARCHAR(30) NOT NULL,
    IdRol INT NOT NULL,
    NombreCompleto VARCHAR(150) NOT NULL,
    ContrasenaHash VARCHAR(255) NOT NULL,
    Correo VARCHAR(100) NULL,
    Activo BIT NOT NULL CONSTRAINT DF_CAT_USUARIOS_Activo DEFAULT (1),
    FechaCreacion DATETIME2(0) NOT NULL CONSTRAINT DF_CAT_USUARIOS_Fecha DEFAULT (SYSDATETIME()),
    UltimoAcceso DATETIME2(0) NULL,
    CONSTRAINT PK_CAT_USUARIOS PRIMARY KEY (IdUsuario),
    CONSTRAINT FK_CAT_USUARIOS_ROL FOREIGN KEY (IdRol) REFERENCES dbo.CAT_ROLES(IdRol)
);
GO

CREATE TABLE dbo.CAT_PACIENTES
(
    IdPaciente VARCHAR(30) NOT NULL,
    PrimerNombre VARCHAR(50) NOT NULL,
    SegundoNombre VARCHAR(50) NULL,
    PrimerApellido VARCHAR(50) NOT NULL,
    SegundoApellido VARCHAR(50) NULL,
    FechaNacimiento DATE NULL,
    Sexo CHAR(1) NULL,
    Telefono VARCHAR(20) NULL,
    Activo BIT NOT NULL CONSTRAINT DF_CAT_PACIENTES_Activo DEFAULT (1),
    FechaCreacion DATETIME2(0) NOT NULL CONSTRAINT DF_CAT_PACIENTES_Fecha DEFAULT (SYSDATETIME()),
    FechaModificacion DATETIME2(0) NULL,
    CONSTRAINT PK_CAT_PACIENTES PRIMARY KEY (IdPaciente),
    CONSTRAINT CK_CAT_PACIENTES_Sexo CHECK (Sexo IS NULL OR Sexo IN ('M','F'))
);
GO

CREATE TABLE dbo.CAT_MEDICOS
(
    IdMedico VARCHAR(30) NOT NULL,
    Nombres VARCHAR(100) NOT NULL,
    Apellidos VARCHAR(100) NOT NULL,
    NoColegiado VARCHAR(30) NULL,
    Telefono VARCHAR(20) NULL,
    Correo VARCHAR(100) NULL,
    Activo BIT NOT NULL CONSTRAINT DF_CAT_MEDICOS_Activo DEFAULT (1),
    FechaCreacion DATETIME2(0) NOT NULL CONSTRAINT DF_CAT_MEDICOS_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_CAT_MEDICOS PRIMARY KEY (IdMedico)
);
GO

CREATE TABLE dbo.CAT_TECNICOS_RADIOLOGOS
(
    IdTecnico VARCHAR(30) NOT NULL,
    Nombres VARCHAR(100) NOT NULL,
    Apellidos VARCHAR(100) NOT NULL,
    Telefono VARCHAR(20) NULL,
    Correo VARCHAR(100) NULL,
    Activo BIT NOT NULL CONSTRAINT DF_CAT_TECNICOS_Activo DEFAULT (1),
    FechaCreacion DATETIME2(0) NOT NULL CONSTRAINT DF_CAT_TECNICOS_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_CAT_TECNICOS PRIMARY KEY (IdTecnico)
);
GO

CREATE TABLE dbo.CAT_SERVICIOS_HOSPITALARIOS
(
    IdServicio VARCHAR(30) NOT NULL,
    NombreServicio VARCHAR(100) NOT NULL,
    Descripcion VARCHAR(200) NULL,
    Activo BIT NOT NULL CONSTRAINT DF_CAT_SERVICIOS_Activo DEFAULT (1),
    FechaCreacion DATETIME2(0) NOT NULL CONSTRAINT DF_CAT_SERVICIOS_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_CAT_SERVICIOS PRIMARY KEY (IdServicio)
);
GO

CREATE TABLE dbo.CAT_CATEGORIAS_PRUEBAS
(
    IdCategoria VARCHAR(20) NOT NULL,
    NombreCategoria VARCHAR(100) NOT NULL,
    Descripcion VARCHAR(250) NULL,
    Activo BIT NOT NULL CONSTRAINT DF_CAT_CATEGORIAS_Activo DEFAULT (1),
    FechaCreacion DATETIME2(0) NOT NULL CONSTRAINT DF_CAT_CATEGORIAS_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_CAT_CATEGORIAS PRIMARY KEY (IdCategoria),
    CONSTRAINT UQ_CAT_CATEGORIAS_Nombre UNIQUE (NombreCategoria)
);
GO

CREATE TABLE dbo.CAT_PRUEBAS
(
    IdPrueba VARCHAR(30) NOT NULL,
    IdCategoria VARCHAR(20) NOT NULL,
    NombrePrueba VARCHAR(150) NOT NULL,
    Descripcion VARCHAR(250) NULL,
    DuracionMinutos INT NULL,
    Activo BIT NOT NULL CONSTRAINT DF_CAT_PRUEBAS_Activo DEFAULT (1),
    FechaCreacion DATETIME2(0) NOT NULL CONSTRAINT DF_CAT_PRUEBAS_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_CAT_PRUEBAS PRIMARY KEY (IdPrueba),
    CONSTRAINT FK_CAT_PRUEBAS_CATEGORIA FOREIGN KEY (IdCategoria)
        REFERENCES dbo.CAT_CATEGORIAS_PRUEBAS(IdCategoria),
    CONSTRAINT CK_CAT_PRUEBAS_Duracion CHECK (DuracionMinutos IS NULL OR DuracionMinutos > 0)
);
GO

CREATE TABLE dbo.CAPACIDAD
(
    IdCapacidad INT IDENTITY(1,1) NOT NULL,
    IdPrueba VARCHAR(30) NOT NULL,
    DiaSemana TINYINT NOT NULL,
    CantidadMaxima INT NOT NULL,
    Activo BIT NOT NULL CONSTRAINT DF_CAPACIDAD_Activo DEFAULT (1),
    IdUsuarioCreacion VARCHAR(30) NOT NULL,
    FechaCreacion DATETIME2(0) NOT NULL CONSTRAINT DF_CAPACIDAD_Fecha DEFAULT (SYSDATETIME()),
    IdUsuarioModificacion VARCHAR(30) NULL,
    FechaModificacion DATETIME2(0) NULL,
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
    IdCita INT IDENTITY(1,1) NOT NULL,
    NumeroCita VARCHAR(30) NOT NULL,
    IdPaciente VARCHAR(30) NOT NULL,
    IdMedico VARCHAR(30) NOT NULL,
    IdServicio VARCHAR(30) NOT NULL,
    FechaCita DATE NOT NULL,
    HoraCita TIME(0) NOT NULL,
    Estado VARCHAR(20) NOT NULL CONSTRAINT DF_CITA_Estado DEFAULT ('PROGRAMADA'),
    Observaciones VARCHAR(500) NULL,
    IdUsuarioCreacion VARCHAR(30) NOT NULL,
    FechaCreacion DATETIME2(0) NOT NULL CONSTRAINT DF_CITA_Fecha DEFAULT (SYSDATETIME()),
    IdUsuarioModificacion VARCHAR(30) NULL,
    FechaModificacion DATETIME2(0) NULL,
    Activo BIT NOT NULL CONSTRAINT DF_CITA_Activo DEFAULT (1),
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
    IdDetalleCita INT IDENTITY(1,1) NOT NULL,
    IdCita INT NOT NULL,
    IdPrueba VARCHAR(30) NOT NULL,
    IdTecnico VARCHAR(30) NULL,
    Estado VARCHAR(20) NOT NULL CONSTRAINT DF_DETALLE_CITA_Estado DEFAULT ('PENDIENTE'),
    Observaciones VARCHAR(300) NULL,
    FechaCreacion DATETIME2(0) NOT NULL CONSTRAINT DF_DETALLE_CITA_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_DETALLE_CITA PRIMARY KEY (IdDetalleCita),
    CONSTRAINT FK_DETALLE_CITA_CITA FOREIGN KEY (IdCita) REFERENCES dbo.CITA(IdCita),
    CONSTRAINT FK_DETALLE_CITA_PRUEBA FOREIGN KEY (IdPrueba) REFERENCES dbo.CAT_PRUEBAS(IdPrueba),
    CONSTRAINT FK_DETALLE_CITA_TECNICO FOREIGN KEY (IdTecnico) REFERENCES dbo.CAT_TECNICOS_RADIOLOGOS(IdTecnico),
    CONSTRAINT CK_DETALLE_CITA_Estado CHECK (Estado IN ('PENDIENTE','REALIZADO','CANCELADO')),
    CONSTRAINT UQ_DETALLE_CITA_Cita_Prueba UNIQUE (IdCita, IdPrueba)
);
GO

CREATE INDEX IX_CITA_Fecha ON dbo.CITA(FechaCita);
CREATE INDEX IX_CITA_Paciente_Fecha ON dbo.CITA(IdPaciente, FechaCita);
CREATE INDEX IX_DETALLE_CITA_Prueba ON dbo.DETALLE_CITA(IdPrueba);
GO

CREATE TYPE dbo.TVP_EstudioCita AS TABLE
(
    IdPrueba VARCHAR(30) NOT NULL PRIMARY KEY
);
GO

INSERT dbo.CAT_ROLES (NombreRol, Descripcion)
VALUES ('ADMINISTRADOR', 'Acceso completo al sistema'),
       ('USUARIO_CITAS', 'Acceso operativo para la gestión de citas');
GO

-- Contraseñas demo:
-- ADMIN01 / Admin123*
-- CITAS01 / Citas123*
INSERT dbo.CAT_USUARIOS (IdUsuario, IdRol, NombreCompleto, ContrasenaHash, Correo)
VALUES
('ADMIN01', 1, 'Administrador RIS HRO',
 'PBKDF2-SHA256$100000$tz6zcTDJFoPWsSqwFi/9Lg==$MqbwIR0etYTMdPMvle1Aw0oBasvJYklvVKoUtuYyBbU=',
 'admin@demo.local'),
('CITAS01', 2, 'Usuario de Citas',
 'PBKDF2-SHA256$100000$WhBYr6vGC4xxfXnyBUYAUg==$LsQ0z7q7U7EzrbqUUNQuNurEZxNUDyMU1ls5A815Gl0=',
 'citas@demo.local');
GO

INSERT dbo.CAT_PACIENTES
(IdPaciente, PrimerNombre, SegundoNombre, PrimerApellido, SegundoApellido, FechaNacimiento, Sexo, Telefono)
VALUES
('152487','María',NULL,'López','Hernández','1985-06-12','F','55550001'),
('100002','Juan','Carlos','Pérez','Gómez','1978-02-21','M','55550002'),
('100003','Ana','Lucía','García','Méndez','1991-11-08','F','55550003'),
('100004','Pedro',NULL,'Díaz','Ramírez','1969-03-15','M','55550004'),
('100005','Sofía','Elena','Morales','Cifuentes','1988-09-27','F','55550005');
GO

INSERT dbo.CAT_MEDICOS
(IdMedico, Nombres, Apellidos, NoColegiado, Telefono, Correo)
VALUES
('MED001','Carlos','López','12345','55551001','clopez@demo.local'),
('MED002','Andrea','Ramírez','22346','55551002','aramirez@demo.local'),
('MED003','José','Mazariegos','32347','55551003','jmazariegos@demo.local');
GO

INSERT dbo.CAT_TECNICOS_RADIOLOGOS
(IdTecnico, Nombres, Apellidos, Telefono, Correo)
VALUES
('TEC001','José','Pérez','55552001','jperez@demo.local'),
('TEC002','Marta','Cifuentes','55552002','mcifuentes@demo.local'),
('TEC003','Luis','Gómez','55552003','lgomez@demo.local');
GO

INSERT dbo.CAT_SERVICIOS_HOSPITALARIOS
(IdServicio, NombreServicio, Descripcion)
VALUES
('SER001','Emergencia','Servicio de emergencia'),
('SER002','Consulta Externa','Consulta externa'),
('SER003','Medicina Interna','Servicio de medicina interna'),
('SER004','Cirugía','Servicio de cirugía');
GO

INSERT dbo.CAT_CATEGORIAS_PRUEBAS
(IdCategoria, NombreCategoria, Descripcion)
VALUES
('RX','Rayos X','Estudios radiográficos'),
('US','Ultrasonido','Estudios por ultrasonido'),
('MAM','Mamografía','Estudios mamográficos');
GO

INSERT dbo.CAT_PRUEBAS
(IdPrueba, IdCategoria, NombrePrueba, Descripcion, DuracionMinutos)
VALUES
('RX001','RX','RX tórax','Radiografía de tórax',15),
('RX002','RX','RX columna lumbar','Radiografía de columna lumbar',20),
('RX003','RX','RX rodilla','Radiografía de rodilla',15),
('US001','US','US abdominal','Ultrasonido abdominal',25),
('US002','US','US renal','Ultrasonido renal',25),
('MAM001','MAM','Mamografía bilateral','Mamografía bilateral',30);
GO

;WITH Dias AS
(
    SELECT DiaSemana FROM (VALUES (1),(2),(3),(4),(5),(6)) D(DiaSemana)
)
INSERT dbo.CAPACIDAD (IdPrueba, DiaSemana, CantidadMaxima, IdUsuarioCreacion)
SELECT P.IdPrueba, D.DiaSemana,
       CASE P.IdPrueba
            WHEN 'RX001' THEN 12 WHEN 'RX002' THEN 10 WHEN 'RX003' THEN 10
            WHEN 'US001' THEN 8 WHEN 'US002' THEN 6 WHEN 'MAM001' THEN 4
       END,
       'ADMIN01'
FROM dbo.CAT_PRUEBAS P
CROSS JOIN Dias D;
GO

DECLARE @Hoy DATE = CAST(GETDATE() AS DATE);

INSERT dbo.CITA
(NumeroCita, IdPaciente, IdMedico, IdServicio, FechaCita, HoraCita, Estado, IdUsuarioCreacion)
VALUES
(CONCAT('RAD-',CONVERT(char(8),@Hoy,112),'-001'),'152487','MED001','SER001',@Hoy,'08:00','ATENDIDA','ADMIN01'),
(CONCAT('RAD-',CONVERT(char(8),@Hoy,112),'-002'),'100002','MED002','SER002',@Hoy,'08:30','PROGRAMADA','ADMIN01'),
(CONCAT('RAD-',CONVERT(char(8),@Hoy,112),'-003'),'100003','MED001','SER003',@Hoy,'09:00','PROGRAMADA','ADMIN01'),
(CONCAT('RAD-',CONVERT(char(8),@Hoy,112),'-004'),'100004','MED003','SER001',@Hoy,'09:30','PROGRAMADA','ADMIN01'),
(CONCAT('RAD-',CONVERT(char(8),@Hoy,112),'-005'),'100005','MED002','SER004',@Hoy,'10:00','CANCELADA','ADMIN01'),
(CONCAT('RAD-',CONVERT(char(8),@Hoy,112),'-006'),'152487','MED001','SER002',@Hoy,'10:30','ATENDIDA','ADMIN01'),
(CONCAT('RAD-',CONVERT(char(8),@Hoy,112),'-007'),'100002','MED002','SER002',@Hoy,'11:00','PROGRAMADA','ADMIN01'),
(CONCAT('RAD-',CONVERT(char(8),@Hoy,112),'-008'),'100003','MED001','SER003',@Hoy,'11:30','PROGRAMADA','ADMIN01');

DECLARE @Cita1 INT=(SELECT IdCita FROM dbo.CITA WHERE NumeroCita=CONCAT('RAD-',CONVERT(char(8),@Hoy,112),'-001'));
DECLARE @Cita2 INT=(SELECT IdCita FROM dbo.CITA WHERE NumeroCita=CONCAT('RAD-',CONVERT(char(8),@Hoy,112),'-002'));
DECLARE @Cita3 INT=(SELECT IdCita FROM dbo.CITA WHERE NumeroCita=CONCAT('RAD-',CONVERT(char(8),@Hoy,112),'-003'));
DECLARE @Cita4 INT=(SELECT IdCita FROM dbo.CITA WHERE NumeroCita=CONCAT('RAD-',CONVERT(char(8),@Hoy,112),'-004'));
DECLARE @Cita5 INT=(SELECT IdCita FROM dbo.CITA WHERE NumeroCita=CONCAT('RAD-',CONVERT(char(8),@Hoy,112),'-005'));
DECLARE @Cita6 INT=(SELECT IdCita FROM dbo.CITA WHERE NumeroCita=CONCAT('RAD-',CONVERT(char(8),@Hoy,112),'-006'));
DECLARE @Cita7 INT=(SELECT IdCita FROM dbo.CITA WHERE NumeroCita=CONCAT('RAD-',CONVERT(char(8),@Hoy,112),'-007'));
DECLARE @Cita8 INT=(SELECT IdCita FROM dbo.CITA WHERE NumeroCita=CONCAT('RAD-',CONVERT(char(8),@Hoy,112),'-008'));

INSERT dbo.DETALLE_CITA (IdCita, IdPrueba, IdTecnico, Estado)
VALUES
(@Cita1,'US001','TEC001','REALIZADO'),
(@Cita2,'RX001','TEC003','PENDIENTE'),
(@Cita2,'RX003','TEC003','PENDIENTE'),
(@Cita3,'MAM001','TEC002','PENDIENTE'),
(@Cita4,'US002','TEC001','PENDIENTE'),
(@Cita5,'RX001',NULL,'CANCELADO'),
(@Cita6,'MAM001','TEC002','REALIZADO'),
(@Cita7,'MAM001',NULL,'PENDIENTE'),
(@Cita8,'US001',NULL,'PENDIENTE');
GO

CREATE OR ALTER PROCEDURE dbo.sp_Usuario_ObtenerLogin
    @IdUsuario VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT U.IdUsuario,U.NombreCompleto,U.ContrasenaHash,U.Activo,R.NombreRol
    FROM dbo.CAT_USUARIOS U
    INNER JOIN dbo.CAT_ROLES R ON R.IdRol=U.IdRol
    WHERE U.IdUsuario=@IdUsuario;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Usuario_ActualizarUltimoAcceso
    @IdUsuario VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.CAT_USUARIOS SET UltimoAcceso=SYSDATETIME() WHERE IdUsuario=@IdUsuario;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Dashboard_ResumenDia
    @Fecha DATE
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CitasHoy=COUNT(*),
           Pendientes=SUM(CASE WHEN Estado='PROGRAMADA' THEN 1 ELSE 0 END),
           Atendidas=SUM(CASE WHEN Estado='ATENDIDA' THEN 1 ELSE 0 END),
           Canceladas=SUM(CASE WHEN Estado='CANCELADA' THEN 1 ELSE 0 END)
    FROM dbo.CITA
    WHERE FechaCita=@Fecha AND Activo=1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Dashboard_CapacidadDia
    @Fecha DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET DATEFIRST 1;
    DECLARE @DiaSemana TINYINT=DATEPART(WEEKDAY,@Fecha);

    ;WITH Uso AS
    (
        SELECT DC.IdPrueba,COUNT(*) AS Utilizados
        FROM dbo.DETALLE_CITA DC
        INNER JOIN dbo.CITA C ON C.IdCita=DC.IdCita
        WHERE C.FechaCita=@Fecha AND C.Activo=1
          AND C.Estado<>'CANCELADA' AND DC.Estado<>'CANCELADO'
        GROUP BY DC.IdPrueba
    )
    SELECT TOP (3)
           P.IdPrueba,P.NombrePrueba,CP.NombreCategoria,
           C.CantidadMaxima AS Capacidad,
           ISNULL(U.Utilizados,0) AS Utilizados,
           CASE WHEN C.CantidadMaxima-ISNULL(U.Utilizados,0)<0 THEN 0
                ELSE C.CantidadMaxima-ISNULL(U.Utilizados,0) END AS Disponibles,
           CAST(CASE WHEN C.CantidadMaxima=0 THEN 0
                     ELSE (ISNULL(U.Utilizados,0)*100.0)/C.CantidadMaxima END AS DECIMAL(6,2)) AS PorcentajeUso
    FROM dbo.CAPACIDAD C
    INNER JOIN dbo.CAT_PRUEBAS P ON P.IdPrueba=C.IdPrueba AND P.Activo=1
    INNER JOIN dbo.CAT_CATEGORIAS_PRUEBAS CP ON CP.IdCategoria=P.IdCategoria
    LEFT JOIN Uso U ON U.IdPrueba=P.IdPrueba
    WHERE C.DiaSemana=@DiaSemana AND C.Activo=1
    ORDER BY PorcentajeUso DESC,P.NombrePrueba;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Dashboard_ProximasCitas
    @Fecha DATE
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (5)
           C.IdCita,C.NumeroCita,C.HoraCita,
           CONCAT(P.PrimerNombre,' ',COALESCE(P.SegundoNombre+' ',''),P.PrimerApellido,COALESCE(' '+P.SegundoApellido,'')) AS Paciente,
           ISNULL(E.Estudios,'') AS Estudios,C.Estado
    FROM dbo.CITA C
    INNER JOIN dbo.CAT_PACIENTES P ON P.IdPaciente=C.IdPaciente
    OUTER APPLY
    (
        SELECT STRING_AGG(PR.NombrePrueba, ', ') AS Estudios
        FROM dbo.DETALLE_CITA DC
        INNER JOIN dbo.CAT_PRUEBAS PR ON PR.IdPrueba=DC.IdPrueba
        WHERE DC.IdCita=C.IdCita
    ) E
    WHERE C.FechaCita=@Fecha AND C.Activo=1 AND C.Estado<>'CANCELADA'
    ORDER BY C.HoraCita;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Paciente_Obtener
    @IdPaciente VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdPaciente,PrimerNombre,SegundoNombre,PrimerApellido,SegundoApellido,FechaNacimiento,Sexo,Telefono
    FROM dbo.CAT_PACIENTES WHERE IdPaciente=@IdPaciente AND Activo=1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Paciente_Upsert
    @IdPaciente VARCHAR(30), @PrimerNombre VARCHAR(50), @SegundoNombre VARCHAR(50)=NULL,
    @PrimerApellido VARCHAR(50), @SegundoApellido VARCHAR(50)=NULL,
    @FechaNacimiento DATE=NULL, @Sexo CHAR(1)=NULL, @Telefono VARCHAR(20)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS(SELECT 1 FROM dbo.CAT_PACIENTES WHERE IdPaciente=@IdPaciente)
    BEGIN
        UPDATE dbo.CAT_PACIENTES
        SET PrimerNombre=@PrimerNombre,SegundoNombre=@SegundoNombre,PrimerApellido=@PrimerApellido,
            SegundoApellido=@SegundoApellido,FechaNacimiento=@FechaNacimiento,Sexo=@Sexo,Telefono=@Telefono,
            Activo=1,FechaModificacion=SYSDATETIME()
        WHERE IdPaciente=@IdPaciente;
    END
    ELSE
    BEGIN
        INSERT dbo.CAT_PACIENTES
        (IdPaciente,PrimerNombre,SegundoNombre,PrimerApellido,SegundoApellido,FechaNacimiento,Sexo,Telefono)
        VALUES(@IdPaciente,@PrimerNombre,@SegundoNombre,@PrimerApellido,@SegundoApellido,@FechaNacimiento,@Sexo,@Telefono);
    END
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Medico_ListarActivos
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdMedico,CONCAT(Nombres,' ',Apellidos) AS NombreCompleto
    FROM dbo.CAT_MEDICOS WHERE Activo=1 ORDER BY Apellidos,Nombres;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Servicio_ListarActivos
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdServicio,NombreServicio
    FROM dbo.CAT_SERVICIOS_HOSPITALARIOS WHERE Activo=1 ORDER BY NombreServicio;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Prueba_Obtener
    @IdPrueba VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT P.IdPrueba,P.NombrePrueba,C.NombreCategoria
    FROM dbo.CAT_PRUEBAS P
    INNER JOIN dbo.CAT_CATEGORIAS_PRUEBAS C ON C.IdCategoria=P.IdCategoria
    WHERE P.IdPrueba=@IdPrueba AND P.Activo=1 AND C.Activo=1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Prueba_Buscar
    @Texto VARCHAR(100)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (50) P.IdPrueba,P.NombrePrueba,C.NombreCategoria
    FROM dbo.CAT_PRUEBAS P
    INNER JOIN dbo.CAT_CATEGORIAS_PRUEBAS C ON C.IdCategoria=P.IdCategoria
    WHERE P.Activo=1 AND C.Activo=1
      AND (@Texto IS NULL OR LTRIM(RTRIM(@Texto))=''
           OR P.IdPrueba LIKE '%'+@Texto+'%'
           OR P.NombrePrueba LIKE '%'+@Texto+'%'
           OR C.NombreCategoria LIKE '%'+@Texto+'%')
    ORDER BY C.NombreCategoria,P.NombrePrueba;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Capacidad_MesPorPruebas
    @Anio INT, @Mes INT, @IdsPruebas VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET DATEFIRST 1;
    DECLARE @FechaInicio DATE=DATEFROMPARTS(@Anio,@Mes,1);
    DECLARE @FechaFin DATE=EOMONTH(@FechaInicio);

    CREATE TABLE #Selected(IdPrueba VARCHAR(30) NOT NULL PRIMARY KEY);
    INSERT #Selected(IdPrueba)
    SELECT DISTINCT LTRIM(RTRIM(value))
    FROM STRING_SPLIT(@IdsPruebas,',')
    WHERE LTRIM(RTRIM(value))<>'';

    CREATE TABLE #AvailabilityDetail
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
        SELECT @FechaInicio AS Fecha
        UNION ALL
        SELECT DATEADD(DAY,1,Fecha) FROM Dias WHERE Fecha<@FechaFin
    )
    INSERT #AvailabilityDetail(Fecha,IdPrueba,NombrePrueba,Capacidad,Utilizados,Disponibles)
    SELECT D.Fecha,P.IdPrueba,P.NombrePrueba,CAP.CantidadMaxima,ISNULL(U.Utilizados,0),
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
        WHERE C.IdPrueba=P.IdPrueba AND C.DiaSemana=DATEPART(WEEKDAY,D.Fecha) AND C.Activo=1
    ) CAP
    OUTER APPLY
    (
        SELECT COUNT(*) AS Utilizados
        FROM dbo.DETALLE_CITA DC
        INNER JOIN dbo.CITA CI ON CI.IdCita=DC.IdCita
        WHERE DC.IdPrueba=P.IdPrueba AND CI.FechaCita=D.Fecha
          AND CI.Activo=1 AND CI.Estado<>'CANCELADA' AND DC.Estado<>'CANCELADO'
    ) U
    OPTION (MAXRECURSION 100);

    SELECT Fecha,
           CASE
               WHEN SUM(CASE WHEN Capacidad IS NULL THEN 1 ELSE 0 END)>0 THEN 'NONE'
               WHEN MIN(Disponibles)<=0 THEN 'FULL'
               WHEN MIN(CAST(Disponibles AS DECIMAL(10,4))/NULLIF(Capacidad,0))<=0.25 THEN 'LOW'
               ELSE 'HIGH'
           END AS Estado
    FROM #AvailabilityDetail
    GROUP BY Fecha
    ORDER BY Fecha;

    SELECT Fecha,IdPrueba,NombrePrueba,Capacidad,Utilizados,Disponibles
    FROM #AvailabilityDetail
    ORDER BY Fecha,NombrePrueba;
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

    IF NOT EXISTS(SELECT 1 FROM @Estudios)
        THROW 50001,'Debe agregar por lo menos un estudio.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.CAT_PACIENTES WHERE IdPaciente=@IdPaciente AND Activo=1)
        THROW 50001,'El paciente no existe o se encuentra inactivo.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.CAT_MEDICOS WHERE IdMedico=@IdMedico AND Activo=1)
        THROW 50001,'El médico seleccionado no existe o se encuentra inactivo.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.CAT_SERVICIOS_HOSPITALARIOS WHERE IdServicio=@IdServicio AND Activo=1)
        THROW 50001,'El servicio seleccionado no existe o se encuentra inactivo.',1;

    DECLARE @DiaSemana TINYINT=DATEPART(WEEKDAY,@FechaCita);

    IF EXISTS
    (
        SELECT 1
        FROM @Estudios E
        LEFT JOIN dbo.CAPACIDAD CAP ON CAP.IdPrueba=E.IdPrueba
                                   AND CAP.DiaSemana=@DiaSemana
                                   AND CAP.Activo=1
        WHERE CAP.IdCapacidad IS NULL
    )
        THROW 50001,'Uno o más estudios no tienen capacidad configurada para el día seleccionado.',1;

    IF EXISTS
    (
        SELECT 1
        FROM @Estudios E
        INNER JOIN dbo.CAPACIDAD CAP ON CAP.IdPrueba=E.IdPrueba
                                     AND CAP.DiaSemana=@DiaSemana
                                     AND CAP.Activo=1
        OUTER APPLY
        (
            SELECT COUNT(*) AS Utilizados
            FROM dbo.DETALLE_CITA DC
            INNER JOIN dbo.CITA C ON C.IdCita=DC.IdCita
            WHERE DC.IdPrueba=E.IdPrueba AND C.FechaCita=@FechaCita
              AND C.Activo=1 AND C.Estado<>'CANCELADA' AND DC.Estado<>'CANCELADO'
        ) U
        WHERE ISNULL(U.Utilizados,0)>=CAP.CantidadMaxima
    )
        THROW 50001,'No existe cupo disponible para uno o más estudios seleccionados.',1;

    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @Temporal VARCHAR(30)=CONCAT('TMP-',LEFT(REPLACE(CONVERT(VARCHAR(36),NEWID()),'-',''),26));

        INSERT dbo.CITA
        (NumeroCita,IdPaciente,IdMedico,IdServicio,FechaCita,HoraCita,Estado,Observaciones,IdUsuarioCreacion)
        VALUES(@Temporal,@IdPaciente,@IdMedico,@IdServicio,@FechaCita,@HoraCita,'PROGRAMADA',@Observaciones,@IdUsuario);

        DECLARE @IdCita INT=SCOPE_IDENTITY();
        DECLARE @NumeroCita VARCHAR(30)=CONCAT('RAD-',YEAR(@FechaCita),'-',RIGHT('000000'+CAST(@IdCita AS VARCHAR(6)),6));

        UPDATE dbo.CITA SET NumeroCita=@NumeroCita WHERE IdCita=@IdCita;

        INSERT dbo.DETALLE_CITA(IdCita,IdPrueba,Estado)
        SELECT @IdCita,E.IdPrueba,'PENDIENTE' FROM @Estudios E;

        COMMIT;
        SELECT @IdCita AS IdCita,@NumeroCita AS NumeroCita;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

PRINT 'RIS_HRO creado correctamente.';
PRINT 'ADMIN01 / Admin123*';
PRINT 'CITAS01 / Citas123*';
GO
