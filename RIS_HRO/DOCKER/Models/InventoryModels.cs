namespace RIS_HRO.Models;

public sealed class InventoryStudyRow
{
    public int IdDetalleCita { get; set; }
    public int IdCita { get; set; }
    public string NumeroCita { get; set; } = "";
    public DateTime FechaRealizacion { get; set; }

    public string IdPaciente { get; set; } = "";
    public string Paciente { get; set; } = "";

    public string IdPrueba { get; set; } = "";
    public string NombrePrueba { get; set; } = "";
    public string NombreCategoria { get; set; } = "";
    public string PartesCuerpo { get; set; } = "";

    public int? IdInforme { get; set; }
    public string? IdInternoRadiologia { get; set; }
    public string EstadoInforme { get; set; } = "SIN_INFORME";
    public int NumeroVersion { get; set; }

    public int? IdPrestamoActivo { get; set; }
    public DateTime? FechaHoraPrestamo { get; set; }
    public string? IdPrestatarioActivo { get; set; }
    public string? PrestatarioActivo { get; set; }

    public bool EstaPrestado => IdPrestamoActivo.HasValue;

    public string EstadoInformeTexto => EstadoInforme switch
    {
        "BORRADOR" => "Borrador",
        "FINALIZADO" => "Finalizado",
        _ => "Sin informe"
    };
}

public sealed class InventoryResourceRow
{
    public string TamanoPelicula { get; set; } = "";
    public int PeliculasEntregadas { get; set; }
    public int ImagenesDigitales { get; set; }
    public string? SistemaAdquisicionCDDR { get; set; }

    public bool HasUsage =>
        PeliculasEntregadas > 0 ||
        ImagenesDigitales > 0 ||
        !string.IsNullOrWhiteSpace(SistemaAdquisicionCDDR);
}

public sealed class InventoryStudyDetail
{
    public int IdDetalleCita { get; set; }
    public int IdCita { get; set; }
    public string NumeroCita { get; set; } = "";
    public DateTime FechaRealizacion { get; set; }

    public string IdPaciente { get; set; } = "";
    public string Paciente { get; set; } = "";

    public string IdServicio { get; set; } = "";
    public string Servicio { get; set; } = "";
    public string IdMedicoSolicitante { get; set; } = "";
    public string MedicoSolicitante { get; set; } = "";
    public string? ObservacionesCita { get; set; }

    public string IdPrueba { get; set; } = "";
    public string NombrePrueba { get; set; } = "";
    public string NombreCategoria { get; set; } = "";
    public string PartesCuerpo { get; set; } = "";
    public string? ObservacionesEstudio { get; set; }

    public int? IdInforme { get; set; }
    public string? IdInternoRadiologia { get; set; }
    public string EstadoInforme { get; set; } = "SIN_INFORME";
    public int NumeroVersion { get; set; }
    public string? Hallazgos { get; set; }
    public string? Conclusiones { get; set; }
    public DateTime? FechaHoraInforme { get; set; }
    public DateTime? FechaFinalizacion { get; set; }

    public string? IdTecnicoRealiza { get; set; }
    public string? TecnicoRealiza { get; set; }
    public string? IdTecnicoPosiciona { get; set; }
    public string? TecnicoPosiciona { get; set; }

    public string? IdMedicoInformante { get; set; }
    public string? MedicoInformante { get; set; }
    public string? PuestoMedicoInformante { get; set; }

    public List<InventoryResourceRow> Recursos { get; set; } = [];

    public bool HasHistory => NumeroVersion > 1;

    public string EstadoInformeTexto => EstadoInforme switch
    {
        "BORRADOR" => "Borrador",
        "FINALIZADO" => "Finalizado",
        _ => "Sin informe"
    };
}
