USE RIS_HRO;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ============================================================================
   RIS_HRO - REQUERIMIENTO 2 - FASE 4
   Historial visible + impresión del informe vigente + configuración encabezado

   REGLAS:
   - Las versiones históricas son SOLO LECTURA.
   - Las versiones históricas NO se imprimen.
   - Solo se imprime la versión vigente cuando está FINALIZADA.
   - El encabezado configurable se obtiene de CONFIG_INFORMES.
   ============================================================================ */


/* ============================================================================
   1. LISTAR HISTORIAL DE VERSIONES DE UN ESTUDIO
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.sp_InformeEstudio_Historial_Listar
    @IdDetalleCita INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        H.IdInformeHistorial,
        H.IdInforme,
        H.IdDetalleCita,
        H.NumeroVersion,
        H.Estado,
        H.IdInternoRadiologia,
        H.FechaHoraInforme,
        H.FechaFinalizacion,
        H.FechaArchivado,
        H.MotivoArchivado,
        H.IdUsuarioArchivado,
        U.NombreCompleto AS ArchivadoPor
    FROM dbo.INFORME_ESTUDIO_HISTORIAL H
    INNER JOIN dbo.CAT_USUARIOS U
        ON U.IdUsuario = H.IdUsuarioArchivado
    WHERE H.IdDetalleCita = @IdDetalleCita
    ORDER BY H.NumeroVersion DESC, H.IdInformeHistorial DESC;
END;
GO


/* ============================================================================
   2. OBTENER UNA VERSIÓN HISTÓRICA - SOLO LECTURA
   Resultset 1: contexto + versión histórica.
   Resultset 2: recursos de esa versión.
   ============================================================================ */
CREATE OR ALTER PROCEDURE dbo.sp_InformeEstudio_Historial_Obtener
    @IdInformeHistorial INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        H.IdInformeHistorial,
        H.IdInforme,
        H.IdDetalleCita,
        H.NumeroVersion,
        H.Estado AS EstadoInforme,
        H.IdInternoRadiologia,
        H.Hallazgos,
        H.Conclusiones,
        H.IdTecnicoRealiza,
        H.IdTecnicoPosiciona,
        H.IdMedicoInformante,
        H.FechaHoraInforme,
        H.FechaFinalizacion,
        H.FechaCreacion AS FechaCreacionInforme,
        H.FechaModificacion AS FechaModificacionInforme,
        H.FechaArchivado,
        H.MotivoArchivado,
        H.IdUsuarioArchivado,
        UA.NombreCompleto AS ArchivadoPor,

        C.IdCita,
        C.NumeroCita,
        C.FechaCita,
        C.HoraCita,
        C.Estado AS EstadoCita,
        C.IdPaciente,
        CONCAT(
            PAC.PrimerNombre, ' ',
            COALESCE(PAC.SegundoNombre + ' ', ''),
            PAC.PrimerApellido,
            COALESCE(' ' + PAC.SegundoApellido, '')
        ) AS Paciente,

        DC.IdPrueba,
        PR.NombrePrueba,
        CAT.NombreCategoria,
        DC.Estado AS EstadoEstudio,
        ISNULL(PC.PartesCuerpo, '') AS PartesCuerpo,

        CASE WHEN TR.IdTecnico IS NULL THEN NULL
             ELSE CONCAT(TR.Nombres, ' ', TR.Apellidos) END AS TecnicoRealiza,
        CASE WHEN TP.IdTecnico IS NULL THEN NULL
             ELSE CONCAT(TP.Nombres, ' ', TP.Apellidos) END AS TecnicoPosiciona,
        CASE WHEN MI.IdMedicoInformante IS NULL THEN NULL
             ELSE CONCAT(MI.Nombres, ' ', MI.Apellidos) END AS MedicoInformante,
        MI.NoColegiado AS NoColegiadoInformante
    FROM dbo.INFORME_ESTUDIO_HISTORIAL H
    INNER JOIN dbo.DETALLE_CITA DC
        ON DC.IdDetalleCita = H.IdDetalleCita
    INNER JOIN dbo.CITA C
        ON C.IdCita = DC.IdCita
    INNER JOIN dbo.CAT_PACIENTES PAC
        ON PAC.IdPaciente = C.IdPaciente
    INNER JOIN dbo.CAT_PRUEBAS PR
        ON PR.IdPrueba = DC.IdPrueba
    INNER JOIN dbo.CAT_CATEGORIAS_PRUEBAS CAT
        ON CAT.IdCategoria = PR.IdCategoria
    INNER JOIN dbo.CAT_USUARIOS UA
        ON UA.IdUsuario = H.IdUsuarioArchivado
    LEFT JOIN dbo.CAT_TECNICOS_RADIOLOGOS TR
        ON TR.IdTecnico = H.IdTecnicoRealiza
    LEFT JOIN dbo.CAT_TECNICOS_RADIOLOGOS TP
        ON TP.IdTecnico = H.IdTecnicoPosiciona
    LEFT JOIN dbo.CAT_MEDICOS_INFORMANTES MI
        ON MI.IdMedicoInformante = H.IdMedicoInformante
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
    WHERE H.IdInformeHistorial = @IdInformeHistorial;

    SELECT
        RH.TamanoPelicula,
        RH.PeliculasEntregadas,
        RH.ImagenesDigitales,
        RH.SistemaAdquisicionCDDR
    FROM dbo.INFORME_ESTUDIO_RECURSOS_HISTORIAL RH
    WHERE RH.IdInformeHistorial = @IdInformeHistorial
    ORDER BY CASE RH.TamanoPelicula
        WHEN '8x10' THEN 1
        WHEN '10x14' THEN 2
        WHEN '14x17' THEN 3
        ELSE 4
    END;
END;
GO


/* ============================================================================
   3. DATOS PARA IMPRESIÓN DE LA VERSIÓN VIGENTE
   IMPORTANTE: únicamente devuelve información si está FINALIZADA.
   Resultset 1: datos del informe.
   Resultset 2: recursos.
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
   4. VERIFICACIÓN
   ============================================================================ */
SELECT
    HistorialListar = CASE
        WHEN OBJECT_ID(N'dbo.sp_InformeEstudio_Historial_Listar', N'P') IS NOT NULL
            THEN 'OK' ELSE 'FALTA' END,
    HistorialObtener = CASE
        WHEN OBJECT_ID(N'dbo.sp_InformeEstudio_Historial_Obtener', N'P') IS NOT NULL
            THEN 'OK' ELSE 'FALTA' END,
    ImpresionInforme = CASE
        WHEN OBJECT_ID(N'dbo.sp_InformeEstudio_Impresion', N'P') IS NOT NULL
            THEN 'OK' ELSE 'FALTA' END,
    ConfigInformes = CASE
        WHEN OBJECT_ID(N'dbo.CONFIG_INFORMES', N'U') IS NOT NULL
            THEN 'OK' ELSE 'FALTA' END;
GO

PRINT 'Requerimiento 2 - Fase 4 instalada correctamente.';
GO
