using System.Net.Http.Headers;
using RIS_HRO.Models;

namespace RIS_HRO.Services;

public sealed class HospitalPatientLookupResult
{
    public bool Success { get; init; }
    public bool Found { get; init; }
    public Patient? Patient { get; init; }
    public string Message { get; init; } = "";
}

public interface IHospitalPatientService
{
    Task<HospitalPatientLookupResult> FindAsync(
        string idPaciente,
        CancellationToken cancellationToken = default);
}

public sealed class HospitalPatientService : IHospitalPatientService
{
    private readonly IConfiguration _configuration;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly Hl7ParserService _parser;

    public HospitalPatientService(
        IConfiguration configuration,
        IHttpClientFactory httpClientFactory,
        Hl7ParserService parser)
    {
        _configuration = configuration;
        _httpClientFactory = httpClientFactory;
        _parser = parser;
    }

    public async Task<HospitalPatientLookupResult> FindAsync(
        string idPaciente,
        CancellationToken cancellationToken = default)
    {
        var section = _configuration.GetSection("HospitalPatientService");
        var enabled = section.GetValue<bool>("Enabled");
        var mode = section["Mode"] ?? "Disabled";

        if (!enabled || string.Equals(mode, "Disabled", StringComparison.OrdinalIgnoreCase))
        {
            return new HospitalPatientLookupResult
            {
                Success = false,
                Found = false,
                Message = "Servicio institucional deshabilitado; se utilizará la contingencia local."
            };
        }

        if (!string.Equals(mode, "HttpGetRawHl7", StringComparison.OrdinalIgnoreCase))
        {
            return new HospitalPatientLookupResult
            {
                Success = false,
                Found = false,
                Message = "Modo del servicio institucional no soportado."
            };
        }

        var baseUrl = section["BaseUrl"];
        var path = section["PatientPath"];
        var queryName = section["PatientIdQueryName"] ?? "idPaciente";
        var bearerToken = section["BearerToken"];

        if (string.IsNullOrWhiteSpace(baseUrl) || string.IsNullOrWhiteSpace(path))
        {
            return new HospitalPatientLookupResult
            {
                Success = false,
                Found = false,
                Message = "El servicio institucional no tiene URL configurada."
            };
        }

        var client = _httpClientFactory.CreateClient();
        client.BaseAddress = new Uri(baseUrl.TrimEnd('/') + "/");

        if (!string.IsNullOrWhiteSpace(bearerToken))
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", bearerToken);

        var url = $"{path.TrimStart('/')}?{Uri.EscapeDataString(queryName)}={Uri.EscapeDataString(idPaciente)}";

        try
        {
            using var response = await client.GetAsync(url, cancellationToken);

            if (response.StatusCode == System.Net.HttpStatusCode.NotFound)
            {
                return new HospitalPatientLookupResult
                {
                    Success = true,
                    Found = false,
                    Message = "Paciente no encontrado en el sistema institucional."
                };
            }

            if (!response.IsSuccessStatusCode)
            {
                return new HospitalPatientLookupResult
                {
                    Success = false,
                    Found = false,
                    Message = $"El servicio institucional respondió con HTTP {(int)response.StatusCode}."
                };
            }

            var rawHl7 = await response.Content.ReadAsStringAsync(cancellationToken);
            var patient = _parser.ParsePatient(rawHl7);

            return patient is null
                ? new HospitalPatientLookupResult
                {
                    Success = true,
                    Found = false,
                    Message = "La respuesta no contiene un paciente HL7 utilizable."
                }
                : new HospitalPatientLookupResult
                {
                    Success = true,
                    Found = true,
                    Patient = patient,
                    Message = "Paciente encontrado en el sistema institucional."
                };
        }
        catch (Exception ex)
        {
            return new HospitalPatientLookupResult
            {
                Success = false,
                Found = false,
                Message = $"No fue posible consultar el servicio institucional: {ex.Message}"
            };
        }
    }
}
