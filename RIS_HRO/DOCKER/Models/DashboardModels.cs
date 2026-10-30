namespace RIS_HRO.Models;

public sealed class DashboardSummary
{
    public int CitasHoy { get; set; }
    public int Pendientes { get; set; }
    public int Atendidas { get; set; }
    public int Canceladas { get; set; }
}

public sealed class CapacityCard
{
    public string IdPrueba { get; set; } = "";
    public string NombrePrueba { get; set; } = "";
    public string NombreCategoria { get; set; } = "";
    public int Capacidad { get; set; }
    public int Utilizados { get; set; }
    public int Disponibles { get; set; }
    public decimal PorcentajeUso { get; set; }
}

public sealed class AppointmentRow
{
    public int IdCita { get; set; }
    public string NumeroCita { get; set; } = "";
    public DateTime FechaCita { get; set; }
    public TimeSpan HoraCita { get; set; }
    public string IdPaciente { get; set; } = "";
    public string Paciente { get; set; } = "";
    public string Medico { get; set; } = "";
    public string Servicio { get; set; } = "";
    public string Estudios { get; set; } = "";
    public string Estado { get; set; } = "";
}
