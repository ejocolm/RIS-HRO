namespace RIS_HRO.Models;

public sealed class ReportSummary
{
    public int TotalCitas { get; set; }
    public int Programadas { get; set; }
    public int Atendidas { get; set; }
    public int Canceladas { get; set; }
    public int NoAsistio { get; set; }
    public int EstudiosRealizados { get; set; }
}

public sealed class StudyReportRow
{
    public string IdPrueba { get; set; } = "";
    public string NombrePrueba { get; set; } = "";
    public string Categoria { get; set; } = "";
    public int Cantidad { get; set; }
}

public sealed class AppointmentReportRow
{
    public string NumeroCita { get; set; } = "";
    public DateTime FechaCita { get; set; }
    public TimeSpan HoraCita { get; set; }
    public string IdPaciente { get; set; } = "";
    public string Paciente { get; set; } = "";
    public string Servicio { get; set; } = "";
    public string Estudios { get; set; } = "";
    public string Estado { get; set; } = "";
}
