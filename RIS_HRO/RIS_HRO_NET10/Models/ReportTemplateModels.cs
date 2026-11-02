namespace RIS_HRO.Models;

public static class ReportTemplateTypes
{
    public const string Hallazgos = "HALLAZGOS";
    public const string Conclusiones = "CONCLUSIONES";

    public static bool IsValid(string? value) =>
        string.Equals(value, Hallazgos, StringComparison.OrdinalIgnoreCase) ||
        string.Equals(value, Conclusiones, StringComparison.OrdinalIgnoreCase);
}

public sealed class ReportTemplateItem
{
    public int IdPlantilla { get; set; }
    public string Nombre { get; set; } = "";
    public string Tipo { get; set; } = ReportTemplateTypes.Hallazgos;
    public string ContenidoHtml { get; set; } = "";
    public bool Activo { get; set; } = true;
    public string? IdUsuarioModificacion { get; set; }
    public DateTime? FechaModificacion { get; set; }
}

public sealed class ReportTemplateEditModel
{
    public int IdPlantilla { get; set; }
    public string Nombre { get; set; } = "";
    public string Tipo { get; set; } = ReportTemplateTypes.Hallazgos;
    public string? ContenidoHtml { get; set; }
    public bool Activo { get; set; } = true;
}

public sealed class StudyReportTemplateDefaults
{
    public string IdPrueba { get; set; } = "";
    public int? IdPlantillaHallazgos { get; set; }
    public int? IdPlantillaConclusiones { get; set; }
}
