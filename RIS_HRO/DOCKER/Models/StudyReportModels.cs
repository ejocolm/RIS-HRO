namespace RIS_HRO.Models;

public sealed class TechnicianItem
{
    public string IdTecnico { get; set; } = "";
    public string NombreCompleto { get; set; } = "";
}

public sealed class InformingDoctorItem
{
    public string IdMedicoInformante { get; set; } = "";
    public string NombreCompleto { get; set; } = "";
    public string? Puesto { get; set; }
    public string? NoColegiado { get; set; }
}

public sealed class StudyReportResource
{
    public string TamanoPelicula { get; set; } = "";
    public int PeliculasEntregadas { get; set; }
    public int ImagenesDigitales { get; set; }
    public string? SistemaAdquisicionCDDR { get; set; }
}

public sealed class StudyReportContext
{
    public int IdDetalleCita { get; set; }
    public int IdCita { get; set; }
    public string NumeroCita { get; set; } = "";
    public string EstadoCita { get; set; } = "";
    public DateTime FechaCita { get; set; }
    public TimeSpan HoraCita { get; set; }
    public string IdPaciente { get; set; } = "";
    public string Paciente { get; set; } = "";
    public string IdPrueba { get; set; } = "";
    public string NombrePrueba { get; set; } = "";
    public string NombreCategoria { get; set; } = "";
    public string EstadoEstudio { get; set; } = "";
    public string PartesCuerpo { get; set; } = "";

    public int? IdInforme { get; set; }
    public string? IdInternoRadiologia { get; set; }
    public string? Hallazgos { get; set; }
    public string? Conclusiones { get; set; }
    public string? IdTecnicoRealiza { get; set; }
    public string? IdTecnicoPosiciona { get; set; }
    public string? IdMedicoInformante { get; set; }
    public DateTime? FechaHoraInforme { get; set; }
    public string? EstadoInforme { get; set; }
    public int NumeroVersion { get; set; } = 1;
    public DateTime? FechaFinalizacion { get; set; }
    public DateTime? FechaCreacionInforme { get; set; }
    public DateTime? FechaModificacionInforme { get; set; }

    public List<StudyReportResource> Recursos { get; set; } = [];
}

public sealed class StudyReportInput
{
    public int IdDetalleCita { get; set; }
    public string? IdInternoRadiologia { get; set; }
    public string? Hallazgos { get; set; }
    public string? Conclusiones { get; set; }
    public string? IdTecnicoRealiza { get; set; }
    public string? IdTecnicoPosiciona { get; set; }
    public string? IdMedicoInformante { get; set; }
    public DateTime? FechaHoraInforme { get; set; }
    public List<StudyReportResource> Recursos { get; set; } = [];
}

public sealed class StudyReportSaveResult
{
    public int IdInforme { get; set; }
    public string Estado { get; set; } = "";
    public int NumeroVersion { get; set; }
    public DateTime? FechaFinalizacion { get; set; }
}


public sealed class StudyReportHistoryItem
{
    public int IdInformeHistorial { get; set; }
    public int IdInforme { get; set; }
    public int IdDetalleCita { get; set; }
    public int NumeroVersion { get; set; }
    public string Estado { get; set; } = "";
    public string? IdInternoRadiologia { get; set; }
    public DateTime? FechaHoraInforme { get; set; }
    public DateTime? FechaFinalizacion { get; set; }
    public DateTime FechaArchivado { get; set; }
    public string ArchivadoPor { get; set; } = "";
    public string? MotivoArchivado { get; set; }
}

public sealed class StudyReportHistoryContext
{
    public int IdInformeHistorial { get; set; }
    public int IdInforme { get; set; }
    public int IdDetalleCita { get; set; }
    public int NumeroVersion { get; set; }
    public string EstadoInforme { get; set; } = "";
    public string? IdInternoRadiologia { get; set; }
    public string? Hallazgos { get; set; }
    public string? Conclusiones { get; set; }
    public DateTime? FechaHoraInforme { get; set; }
    public DateTime? FechaFinalizacion { get; set; }
    public DateTime FechaArchivado { get; set; }
    public string ArchivadoPor { get; set; } = "";
    public string? MotivoArchivado { get; set; }

    public int IdCita { get; set; }
    public string NumeroCita { get; set; } = "";
    public DateTime FechaCita { get; set; }
    public TimeSpan HoraCita { get; set; }
    public string IdPaciente { get; set; } = "";
    public string Paciente { get; set; } = "";
    public string IdPrueba { get; set; } = "";
    public string NombrePrueba { get; set; } = "";
    public string NombreCategoria { get; set; } = "";
    public string PartesCuerpo { get; set; } = "";
    public string EstadoEstudio { get; set; } = "";

    public string? TecnicoRealiza { get; set; }
    public string? TecnicoPosiciona { get; set; }
    public string? MedicoInformante { get; set; }
    public string? NoColegiadoInformante { get; set; }

    public List<StudyReportResource> Recursos { get; set; } = [];
}

public sealed class StudyReportPrintData
{
    public int IdInforme { get; set; }
    public int IdDetalleCita { get; set; }
    public int NumeroVersion { get; set; }
    public string IdInternoRadiologia { get; set; } = "";
    public string Hallazgos { get; set; } = "";
    public string Conclusiones { get; set; } = "";
    public DateTime FechaHoraInforme { get; set; }
    public DateTime? FechaFinalizacion { get; set; }

    public int IdCita { get; set; }
    public string NumeroCita { get; set; } = "";
    public DateTime FechaCita { get; set; }
    public TimeSpan HoraCita { get; set; }
    public string IdPaciente { get; set; } = "";
    public string Paciente { get; set; } = "";

    public string MedicoSolicitante { get; set; } = "";
    public string Servicio { get; set; } = "";

    public string IdPrueba { get; set; } = "";
    public string NombrePrueba { get; set; } = "";
    public string NombreCategoria { get; set; } = "";
    public string PartesCuerpo { get; set; } = "";

    public string TecnicoRealiza { get; set; } = "";
    public string TecnicoPosiciona { get; set; } = "";
    public string MedicoInformante { get; set; } = "";
    public string? PuestoMedicoInformante { get; set; }
    public string? NoColegiadoInformante { get; set; }

    public List<StudyReportResource> Recursos { get; set; } = [];
}

public sealed class ReportHeaderConfiguration
{
    public byte[]? EncabezadoImagen { get; set; }
    public string? EncabezadoNombreArchivo { get; set; }
    public string? EncabezadoTipoMime { get; set; }
    public string? IdUsuarioModificacion { get; set; }
    public DateTime FechaModificacion { get; set; }

    public bool TieneEncabezado =>
        EncabezadoImagen is { Length: > 0 } &&
        !string.IsNullOrWhiteSpace(EncabezadoTipoMime);
}
