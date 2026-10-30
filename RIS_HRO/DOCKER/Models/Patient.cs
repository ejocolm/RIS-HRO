namespace RIS_HRO.Models;

public sealed class Patient
{
    public string IdPaciente { get; set; } = "";
    public string PrimerNombre { get; set; } = "";
    public string? SegundoNombre { get; set; }
    public string PrimerApellido { get; set; } = "";
    public string? SegundoApellido { get; set; }
    public DateTime? FechaNacimiento { get; set; }
    public string? Sexo { get; set; }
    public string? Telefono { get; set; }
    public bool Activo { get; set; } = true;

    public string NombreCompleto =>
        string.Join(" ", new[] { PrimerNombre, SegundoNombre, PrimerApellido, SegundoApellido }
            .Where(x => !string.IsNullOrWhiteSpace(x)));
}
