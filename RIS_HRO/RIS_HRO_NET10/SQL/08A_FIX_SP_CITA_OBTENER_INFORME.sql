USE RIS_HRO;
GO

SET NOCOUNT ON;
GO

/* ============================================================================
   RIS_HRO - HOTFIX REQ2 FASE 2
   Corrige sp_Cita_Obtener para devolver los campos de informe que
   AppointmentRepository.GetAsync espera leer:

      IdInforme
      EstadoInforme
      NumeroVersionInforme

   Este script es incremental y no elimina datos.
   ============================================================================ */

CREATE OR ALTER PROCEDURE dbo.sp_Cita_Obtener
    @IdCita INT
AS
BEGIN
    SET NOCOUNT ON;

    /* Resultset 1: cabecera de la cita */
    SELECT
        C.IdCita,
        C.NumeroCita,
        C.IdPaciente,
        CONCAT(
            P.PrimerNombre, ' ',
            COALESCE(P.SegundoNombre + ' ', ''),
            P.PrimerApellido,
            COALESCE(' ' + P.SegundoApellido, '')
        ) AS Paciente,
        C.IdMedico,
        CONCAT(M.Nombres, ' ', M.Apellidos) AS Medico,
        C.IdServicio,
        S.NombreServicio AS Servicio,
        C.FechaCita,
        C.HoraCita,
        C.Estado,
        C.Observaciones,
        U.NombreCompleto AS UsuarioCreacion,
        C.FechaCreacion
    FROM dbo.CITA C
    INNER JOIN dbo.CAT_PACIENTES P
        ON P.IdPaciente = C.IdPaciente
    INNER JOIN dbo.CAT_MEDICOS M
        ON M.IdMedico = C.IdMedico
    INNER JOIN dbo.CAT_SERVICIOS_HOSPITALARIOS S
        ON S.IdServicio = C.IdServicio
    INNER JOIN dbo.CAT_USUARIOS U
        ON U.IdUsuario = C.IdUsuarioCreacion
    WHERE C.IdCita = @IdCita
      AND C.Activo = 1;

    /* Resultset 2: estudios + estado básico del informe */
    SELECT
        DC.IdDetalleCita,
        DC.IdPrueba,
        P.NombrePrueba,
        CAT.NombreCategoria,
        DC.IdTecnico,
        CASE
            WHEN T.IdTecnico IS NULL THEN NULL
            ELSE CONCAT(T.Nombres, ' ', T.Apellidos)
        END AS Tecnico,
        DC.Estado,
        ISNULL(PC.PartesCuerpo, '') AS PartesCuerpo,

        /* Estos tres campos son los que faltaban en el SP activo. */
        IE.IdInforme,
        IE.Estado AS EstadoInforme,
        IE.NumeroVersion AS NumeroVersionInforme

    FROM dbo.DETALLE_CITA DC
    INNER JOIN dbo.CAT_PRUEBAS P
        ON P.IdPrueba = DC.IdPrueba
    INNER JOIN dbo.CAT_CATEGORIAS_PRUEBAS CAT
        ON CAT.IdCategoria = P.IdCategoria
    LEFT JOIN dbo.CAT_TECNICOS_RADIOLOGOS T
        ON T.IdTecnico = DC.IdTecnico
    LEFT JOIN dbo.INFORME_ESTUDIO IE
        ON IE.IdDetalleCita = DC.IdDetalleCita
    OUTER APPLY
    (
        SELECT
            STRING_AGG(X.NombreParte, ', ')
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
    WHERE DC.IdCita = @IdCita
    ORDER BY P.NombrePrueba;

    /* Resultset 3: partes del cuerpo */
    SELECT
        DCP.IdDetalleCita,
        DCP.IdParteCuerpo,
        PC.NombreParte
    FROM dbo.DETALLE_CITA_PARTE_CUERPO DCP
    INNER JOIN dbo.DETALLE_CITA DC
        ON DC.IdDetalleCita = DCP.IdDetalleCita
    INNER JOIN dbo.CAT_PARTES_CUERPO PC
        ON PC.IdParteCuerpo = DCP.IdParteCuerpo
    WHERE DC.IdCita = @IdCita
    ORDER BY DCP.IdDetalleCita, PC.NombreParte;
END;
GO

/* Verificación básica */
SELECT
    Procedimiento = CASE
        WHEN OBJECT_ID(N'dbo.sp_Cita_Obtener', N'P') IS NOT NULL
            THEN 'OK'
        ELSE 'FALTA'
    END,
    TablaInformes = CASE
        WHEN OBJECT_ID(N'dbo.INFORME_ESTUDIO', N'U') IS NOT NULL
            THEN 'OK'
        ELSE 'FALTA'
    END;
GO

PRINT 'HOTFIX aplicado: sp_Cita_Obtener ya devuelve IdInforme, EstadoInforme y NumeroVersionInforme.';
GO
