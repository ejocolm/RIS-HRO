using RIS_HRO.Models;

namespace RIS_HRO.Services;

/// <summary>
/// Parser básico para mensajes HL7 v2 con segmento PID.
/// Los campos reales deben confirmarse contra la interfaz institucional.
/// </summary>
public sealed class Hl7ParserService
{
    public Patient? ParsePatient(string hl7)
    {
        if (string.IsNullOrWhiteSpace(hl7))
            return null;

        var lines = hl7.Replace("\r\n", "\r").Replace("\n", "\r")
            .Split('\r', StringSplitOptions.RemoveEmptyEntries);

        var pid = lines.FirstOrDefault(x => x.StartsWith("PID|", StringComparison.OrdinalIgnoreCase));
        if (pid is null)
            return null;

        var f = pid.Split('|');

        // HL7 v2 convencional:
        // PID-3 = identificadores, PID-5 = nombre, PID-7 = nacimiento, PID-8 = sexo, PID-13 = teléfono.
        var id = Field(f, 3)?.Split('^').FirstOrDefault()?.Trim();
        var name = Field(f, 5)?.Split('^') ?? [];
        var birth = ParseHl7Date(Field(f, 7));
        var sex = Field(f, 8)?.Trim();
        var phone = Field(f, 13)?.Split('^').FirstOrDefault()?.Trim();

        if (string.IsNullOrWhiteSpace(id))
            return null;

        return new Patient
        {
            IdPaciente = id,
            PrimerApellido = Part(name, 0),
            SegundoApellido = Part(name, 1),
            PrimerNombre = Part(name, 2),
            SegundoNombre = Part(name, 3),
            FechaNacimiento = birth,
            Sexo = NormalizeSex(sex),
            Telefono = phone,
            Activo = true
        };
    }

    private static string? Field(string[] fields, int number) =>
        fields.Length > number ? fields[number] : null;

    private static string Part(string[] parts, int index) =>
        parts.Length > index ? parts[index].Trim() : "";

    private static DateTime? ParseHl7Date(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return null;

        var clean = value.Trim();
        if (clean.Length >= 8 &&
            DateTime.TryParseExact(clean[..8], "yyyyMMdd",
                System.Globalization.CultureInfo.InvariantCulture,
                System.Globalization.DateTimeStyles.None, out var date))
            return date;

        return null;
    }

    private static string? NormalizeSex(string? value)
    {
        if (string.Equals(value, "M", StringComparison.OrdinalIgnoreCase)) return "M";
        if (string.Equals(value, "F", StringComparison.OrdinalIgnoreCase)) return "F";
        return null;
    }
}
