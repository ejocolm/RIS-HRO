/* ============================================================================
   RIS_HRO - REQUERIMIENTO 1 - FASE 2
   Integración de partes del cuerpo en creación, edición y consulta de citas

   PRERREQUISITO
   Haber ejecutado correctamente:
       03_REQUERIMIENTO_1_PARTES_CUERPO.sql

   REGLAS IMPLEMENTADAS
   1. Cada IdPrueba enviado en @Estudios debe tener al menos una parte del cuerpo.
   2. Un estudio puede tener varias partes del cuerpo.
   3. Una parte del cuerpo solo puede relacionarse con un estudio incluido en @Estudios.
   4. Solo se aceptan partes del cuerpo existentes y activas.
   5. Varias partes del cuerpo NO incrementan el consumo de cupos.
      El cupo continúa calculándose por DETALLE_CITA / IdPrueba.
   6. Al editar, se conserva DETALLE_CITA si el estudio permanece en la cita.
      Las relaciones anatómicas se sincronizan con lo enviado desde la interfaz.
   ============================================================================ */

USE RIS_HRO;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ============================================================================
   1. OBTENER CITA
   - Resultset 1: cabecera
   - Resultset 2: estudios
   - Resultset 3: partes del cuerpo por IdDetalleCita
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.sp_Cita_Obtener
    @IdCita INT
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
           DC.Estado,
           ISNULL(PC.PartesCuerpo,'') PartesCuerpo
    FROM dbo.DETALLE_CITA DC
    INNER JOIN dbo.CAT_PRUEBAS P ON P.IdPrueba=DC.IdPrueba
    INNER JOIN dbo.CAT_CATEGORIAS_PRUEBAS CAT ON CAT.IdCategoria=P.IdCategoria
    LEFT JOIN dbo.CAT_TECNICOS_RADIOLOGOS T ON T.IdTecnico=DC.IdTecnico
    OUTER APPLY
    (
        SELECT STRING_AGG(X.NombreParte, ', ') WITHIN GROUP (ORDER BY X.NombreParte) PartesCuerpo
        FROM
        (
            SELECT CP.NombreParte
            FROM dbo.DETALLE_CITA_PARTE_CUERPO DCP
            INNER JOIN dbo.CAT_PARTES_CUERPO CP
                ON CP.IdParteCuerpo=DCP.IdParteCuerpo
            WHERE DCP.IdDetalleCita=DC.IdDetalleCita
        ) X
    ) PC
    WHERE DC.IdCita=@IdCita
    ORDER BY P.NombrePrueba;

    SELECT DCP.IdDetalleCita,
           DCP.IdParteCuerpo,
           PC.NombreParte
    FROM dbo.DETALLE_CITA_PARTE_CUERPO DCP
    INNER JOIN dbo.DETALLE_CITA DC
        ON DC.IdDetalleCita=DCP.IdDetalleCita
    INNER JOIN dbo.CAT_PARTES_CUERPO PC
        ON PC.IdParteCuerpo=DCP.IdParteCuerpo
    WHERE DC.IdCita=@IdCita
    ORDER BY DCP.IdDetalleCita,PC.NombreParte;
END;
GO

/* ============================================================================
   2. CREAR CITA CON PARTES DEL CUERPO
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.sp_Cita_Crear
    @IdPaciente VARCHAR(30),
    @IdMedico VARCHAR(30),
    @IdServicio VARCHAR(30),
    @FechaCita DATE,
    @HoraCita TIME(0),
    @Observaciones VARCHAR(500)=NULL,
    @IdUsuario VARCHAR(30),
    @Estudios dbo.TVP_EstudioCita READONLY,
    @EstudioPartes dbo.TVP_EstudioParteCuerpo READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET DATEFIRST 1;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    IF NOT EXISTS(SELECT 1 FROM @Estudios)
        THROW 50001,'Debe agregar por lo menos un estudio.',1;

    IF NOT EXISTS(SELECT 1 FROM dbo.CAT_PACIENTES WHERE IdPaciente=@IdPaciente AND Activo=1)
        THROW 50001,'Paciente inexistente o inactivo.',1;

    IF NOT EXISTS(SELECT 1 FROM dbo.CAT_MEDICOS WHERE IdMedico=@IdMedico AND Activo=1)
        THROW 50001,'Médico inexistente o inactivo.',1;

    IF NOT EXISTS(SELECT 1 FROM dbo.CAT_SERVICIOS_HOSPITALARIOS WHERE IdServicio=@IdServicio AND Activo=1)
        THROW 50001,'Servicio inexistente o inactivo.',1;

    -- Cada estudio debe tener por lo menos una parte del cuerpo.
    IF EXISTS
    (
        SELECT 1
        FROM @Estudios E
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM @EstudioPartes EP
            WHERE EP.IdPrueba=E.IdPrueba
        )
    )
        THROW 50001,'Debe seleccionar por lo menos una parte del cuerpo para cada estudio.',1;

    -- No se aceptan relaciones para estudios que no forman parte de la cita.
    IF EXISTS
    (
        SELECT 1
        FROM @EstudioPartes EP
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM @Estudios E
            WHERE E.IdPrueba=EP.IdPrueba
        )
    )
        THROW 50001,'Se recibió una parte del cuerpo para un estudio que no pertenece a la cita.',1;

    -- Todas las partes deben existir y estar activas.
    IF EXISTS
    (
        SELECT 1
        FROM @EstudioPartes EP
        LEFT JOIN dbo.CAT_PARTES_CUERPO PC
            ON PC.IdParteCuerpo=EP.IdParteCuerpo
           AND PC.Activo=1
        WHERE PC.IdParteCuerpo IS NULL
    )
        THROW 50001,'Una o más partes del cuerpo no existen o están inactivas.',1;

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

        INSERT dbo.CITA
        (
            NumeroCita,IdPaciente,IdMedico,IdServicio,FechaCita,HoraCita,
            Estado,Observaciones,IdUsuarioCreacion
        )
        VALUES
        (
            @Tmp,@IdPaciente,@IdMedico,@IdServicio,@FechaCita,@HoraCita,
            'PROGRAMADA',@Observaciones,@IdUsuario
        );

        DECLARE @IdCita INT=SCOPE_IDENTITY();
        DECLARE @Numero VARCHAR(30)=CONCAT('RAD-',YEAR(@FechaCita),'-',RIGHT('000000'+CAST(@IdCita AS VARCHAR(6)),6));

        UPDATE dbo.CITA
        SET NumeroCita=@Numero
        WHERE IdCita=@IdCita;

        INSERT dbo.DETALLE_CITA(IdCita,IdPrueba,Estado)
        SELECT @IdCita,E.IdPrueba,'PENDIENTE'
        FROM @Estudios E;

        INSERT dbo.DETALLE_CITA_PARTE_CUERPO(IdDetalleCita,IdParteCuerpo)
        SELECT DC.IdDetalleCita,EP.IdParteCuerpo
        FROM @EstudioPartes EP
        INNER JOIN dbo.DETALLE_CITA DC
            ON DC.IdCita=@IdCita
           AND DC.IdPrueba=EP.IdPrueba;

        COMMIT;

        SELECT @IdCita IdCita,@Numero NumeroCita;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

/* ============================================================================
   3. ACTUALIZAR CITA CON PARTES DEL CUERPO
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.sp_Cita_Actualizar
    @IdCita INT,
    @IdPaciente VARCHAR(30),
    @IdMedico VARCHAR(30),
    @IdServicio VARCHAR(30),
    @FechaCita DATE,
    @HoraCita TIME(0),
    @Observaciones VARCHAR(500)=NULL,
    @IdUsuario VARCHAR(30),
    @Estudios dbo.TVP_EstudioCita READONLY,
    @EstudioPartes dbo.TVP_EstudioParteCuerpo READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET DATEFIRST 1;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    IF NOT EXISTS(SELECT 1 FROM dbo.CITA WHERE IdCita=@IdCita AND Activo=1)
        THROW 50001,'La cita no existe.',1;

    IF NOT EXISTS(SELECT 1 FROM dbo.CITA WHERE IdCita=@IdCita AND Activo=1 AND Estado='PROGRAMADA')
        THROW 50001,'Solo las citas programadas pueden modificarse.',1;

    IF NOT EXISTS(SELECT 1 FROM @Estudios)
        THROW 50001,'Debe conservar por lo menos un estudio.',1;

    -- Cada estudio debe tener por lo menos una parte del cuerpo.
    IF EXISTS
    (
        SELECT 1
        FROM @Estudios E
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM @EstudioPartes EP
            WHERE EP.IdPrueba=E.IdPrueba
        )
    )
        THROW 50001,'Debe seleccionar por lo menos una parte del cuerpo para cada estudio.',1;

    -- No se aceptan relaciones para estudios que no forman parte de la cita.
    IF EXISTS
    (
        SELECT 1
        FROM @EstudioPartes EP
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM @Estudios E
            WHERE E.IdPrueba=EP.IdPrueba
        )
    )
        THROW 50001,'Se recibió una parte del cuerpo para un estudio que no pertenece a la cita.',1;

    -- Todas las partes deben existir y estar activas.
    IF EXISTS
    (
        SELECT 1
        FROM @EstudioPartes EP
        LEFT JOIN dbo.CAT_PARTES_CUERPO PC
            ON PC.IdParteCuerpo=EP.IdParteCuerpo
           AND PC.Activo=1
        WHERE PC.IdParteCuerpo IS NULL
    )
        THROW 50001,'Una o más partes del cuerpo no existen o están inactivas.',1;

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
        SET IdMedico=@IdMedico,
            IdServicio=@IdServicio,
            FechaCita=@FechaCita,
            HoraCita=@HoraCita,
            Observaciones=@Observaciones,
            IdUsuarioModificacion=@IdUsuario,
            FechaModificacion=SYSDATETIME()
        WHERE IdCita=@IdCita;

        -- Los estudios retirados se eliminan. La FK con ON DELETE CASCADE
        -- elimina automáticamente sus partes del cuerpo.
        DELETE DC
        FROM dbo.DETALLE_CITA DC
        WHERE DC.IdCita=@IdCita
          AND NOT EXISTS
          (
              SELECT 1
              FROM @Estudios E
              WHERE E.IdPrueba=DC.IdPrueba
          );

        -- Los estudios que continúan conservan IdDetalleCita y cualquier dato
        -- ya almacenado en DETALLE_CITA. Solo se insertan estudios nuevos.
        INSERT dbo.DETALLE_CITA(IdCita,IdPrueba,Estado)
        SELECT @IdCita,E.IdPrueba,'PENDIENTE'
        FROM @Estudios E
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.DETALLE_CITA DC
            WHERE DC.IdCita=@IdCita
              AND DC.IdPrueba=E.IdPrueba
        );

        -- Sincronizar las partes anatómicas de todos los estudios de la cita.
        DELETE DCP
        FROM dbo.DETALLE_CITA_PARTE_CUERPO DCP
        INNER JOIN dbo.DETALLE_CITA DC
            ON DC.IdDetalleCita=DCP.IdDetalleCita
        WHERE DC.IdCita=@IdCita;

        INSERT dbo.DETALLE_CITA_PARTE_CUERPO(IdDetalleCita,IdParteCuerpo)
        SELECT DC.IdDetalleCita,EP.IdParteCuerpo
        FROM @EstudioPartes EP
        INNER JOIN dbo.DETALLE_CITA DC
            ON DC.IdCita=@IdCita
           AND DC.IdPrueba=EP.IdPrueba;

        DECLARE @Numero VARCHAR(30)=
        (
            SELECT NumeroCita
            FROM dbo.CITA
            WHERE IdCita=@IdCita
        );

        COMMIT;

        SELECT @IdCita IdCita,@Numero NumeroCita;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

/* ============================================================================
   4. VERIFICACIÓN
   ============================================================================ */
SELECT
    ProcedimientoCrear = CASE WHEN OBJECT_ID(N'dbo.sp_Cita_Crear',N'P') IS NOT NULL THEN 'OK' ELSE 'FALTA' END,
    ProcedimientoActualizar = CASE WHEN OBJECT_ID(N'dbo.sp_Cita_Actualizar',N'P') IS NOT NULL THEN 'OK' ELSE 'FALTA' END,
    ProcedimientoObtener = CASE WHEN OBJECT_ID(N'dbo.sp_Cita_Obtener',N'P') IS NOT NULL THEN 'OK' ELSE 'FALTA' END,
    TipoPartes = CASE WHEN TYPE_ID(N'dbo.TVP_EstudioParteCuerpo') IS NOT NULL THEN 'OK' ELSE 'FALTA' END;
GO

SELECT
    P.name Parametro,
    TYPE_NAME(P.user_type_id) Tipo
FROM sys.parameters P
WHERE P.object_id=OBJECT_ID(N'dbo.sp_Cita_Crear')
ORDER BY P.parameter_id;
GO

PRINT 'Requerimiento 1 - Fase 2 instalada correctamente: citas y partes del cuerpo integradas en SQL.';
GO
