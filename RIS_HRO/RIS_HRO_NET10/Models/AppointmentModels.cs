namespace RIS_HRO.Models;

public sealed class AppointmentDetailItem
{
    public int IdDetalleCita { get; set; }
    public string IdPrueba { get; set; } = "";
    public string NombrePrueba { get; set; } = "";
    public string NombreCategoria { get; set; } = "";
    public string? IdTecnico { get; set; }
    public string? Tecnico { get; set; }
    public string Estado { get; set; } = "";
}

public sealed class AppointmentDetail
{
    public int IdCita { get; set; }
    public string NumeroCita { get; set; } = "";
    public string IdPaciente { get; set; } = "";
    public string Paciente { get; set; } = "";
    public string IdMedico { get; set; } = "";
    public string Medico { get; set; } = "";
    public string IdServicio { get; set; } = "";
    public string Servicio { get; set; } = "";
    public DateTime FechaCita { get; set; }
    public TimeSpan HoraCita { get; set; }
    public string Estado { get; set; } = "";
    public string? Observaciones { get; set; }
    public string UsuarioCreacion { get; set; } = "";
    public DateTime FechaCreacion { get; set; }
    public List<AppointmentDetailItem> Estudios { get; set; } = [];
}

public class CreateAppointmentCommand
{
    public string IdPaciente { get; set; } = "";
    public string IdMedico { get; set; } = "";
    public string IdServicio { get; set; } = "";
    public DateTime FechaCita { get; set; }
    public TimeSpan HoraCita { get; set; }
    public string? Observaciones { get; set; }
    public string IdUsuario { get; set; } = "";
    public List<string> Estudios { get; set; } = [];
}

public sealed class UpdateAppointmentCommand : CreateAppointmentCommand
{
    public int IdCita { get; set; }
}

public sealed class CreateAppointmentResult
{
    public int IdCita { get; set; }
    public string NumeroCita { get; set; } = "";
}
