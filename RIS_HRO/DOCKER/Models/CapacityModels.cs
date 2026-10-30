namespace RIS_HRO.Models;

public sealed class CapacityEditModel
{
    public string IdPrueba { get; set; } = "";
    public string NombrePrueba { get; set; } = "";
    public int? Lunes { get; set; }
    public int? Martes { get; set; }
    public int? Miercoles { get; set; }
    public int? Jueves { get; set; }
    public int? Viernes { get; set; }
    public int? Sabado { get; set; }
    public int? Domingo { get; set; }
}

public sealed class AvailabilityDay
{
    public DateTime Fecha { get; set; }
    public string Estado { get; set; } = "NONE";
}

public sealed class AvailabilityDetail
{
    public DateTime Fecha { get; set; }
    public string IdPrueba { get; set; } = "";
    public string NombrePrueba { get; set; } = "";
    public int? Capacidad { get; set; }
    public int Utilizados { get; set; }
    public int? Disponibles { get; set; }
}

public sealed class AvailabilityMonthResponse
{
    public List<AvailabilityDay> Days { get; set; } = [];
    public List<AvailabilityDetail> Details { get; set; } = [];
}
