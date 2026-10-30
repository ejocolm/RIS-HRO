using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using RIS_HRO.Models;
using RIS_HRO.Repositories;
using RIS_HRO.Services;

namespace RIS_HRO.Pages.Appointments;

public sealed class CreateModel : PageModel
{
    private readonly PatientLookupService _patientLookup;
    private readonly PatientRepository _patients;
    private readonly CatalogRepository _catalogs;
    private readonly AppointmentRepository _appointments;

    public CreateModel(
        PatientLookupService patientLookup,
        PatientRepository patients,
        CatalogRepository catalogs,
        AppointmentRepository appointments)
    {
        _patientLookup = patientLookup;
        _patients = patients;
        _catalogs = catalogs;
        _appointments = appointments;
    }

    public List<DoctorItem> Doctors { get; private set; } = [];
    public List<HospitalServiceItem> Services { get; private set; } = [];
    public List<BodyPartItem> BodyParts { get; private set; } = [];
    public List<StudyItem> InitialStudies { get; private set; } = [];
    public string? ErrorMessage { get; private set; }

    [BindProperty] public string PatientId { get; set; } = "";
    [BindProperty] public string PatientFirstName { get; set; } = "";
    [BindProperty] public string? PatientSecondName { get; set; }
    [BindProperty] public string PatientFirstLastName { get; set; } = "";
    [BindProperty] public string? PatientSecondLastName { get; set; }
    [BindProperty] public DateTime? PatientBirthDate { get; set; }
    [BindProperty] public string? PatientSex { get; set; }
    [BindProperty] public string? PatientPhone { get; set; }

    [BindProperty] public string DoctorId { get; set; } = "";
    [BindProperty] public string ServiceId { get; set; } = "";
    [BindProperty] public DateTime AppointmentDate { get; set; } = DateTime.Today;
    [BindProperty] public TimeSpan AppointmentTime { get; set; } = new(8, 0, 0);
    [BindProperty] public string TipoRegistro { get; set; } = "SOLICITUD_DIA";
    [BindProperty] public bool EsMovil { get; set; }
    [BindProperty] public string? Observations { get; set; }

    [BindProperty] public string StudyIdsCsv { get; set; } = "";
    [BindProperty] public string StudyBodyPartsJson { get; set; } = "[]";

    public async Task OnGetAsync(CancellationToken ct)
    {
        var now = DateTime.Now;

        TipoRegistro = "SOLICITUD_DIA";
        EsMovil = false;
        AppointmentDate = now.Date;
        AppointmentTime = new TimeSpan(now.Hour, now.Minute, 0);

        await LoadCatalogsAsync(ct);
    }

    public async Task<JsonResult> OnGetPatientAsync(string id, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(id))
            return new JsonResult(new { found = false, message = "Ingrese el ID del paciente." });

        var result = await _patientLookup.FindAsync(id.Trim(), ct);
        return new JsonResult(new
        {
            found = result.Found,
            source = result.Source,
            message = result.Message,
            patient = result.Patient
        });
    }

    public async Task<JsonResult> OnGetStudyAsync(string code, CancellationToken ct)
    {
        var study = string.IsNullOrWhiteSpace(code)
            ? null
            : await _catalogs.GetStudyAsync(code.Trim(), ct);

        return new JsonResult(new { found = study is not null, study });
    }

    public async Task<JsonResult> OnGetStudiesAsync(string? q, CancellationToken ct) =>
        new(await _catalogs.SearchStudiesAsync(q, ct));

    public async Task<JsonResult> OnGetAvailabilityAsync(
        int year, int month, string? studies, CancellationToken ct)
    {
        var ids = SplitStudies(studies);
        return new JsonResult(
            await _appointments.GetMonthAvailabilityAsync(year, month, ids, null, ct));
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        await LoadCatalogsAsync(ct);

        TipoRegistro = (TipoRegistro ?? "").Trim().ToUpperInvariant();

        if (TipoRegistro != "CITA" && TipoRegistro != "SOLICITUD_DIA")
            ModelState.AddModelError("", "Debe seleccionar un tipo de registro válido.");

        if (TipoRegistro == "CITA")
            EsMovil = false;

        if (TipoRegistro == "SOLICITUD_DIA")
            AppointmentDate = DateTime.Today;

        var studyIds = SplitStudies(StudyIdsCsv);
        var studyBodyParts = ParseStudyBodyParts(StudyBodyPartsJson);

        Validate(studyIds, studyBodyParts);

        if (!ModelState.IsValid)
        {
            await LoadInitialStudiesAsync(studyIds, studyBodyParts, ct);
            ErrorMessage = string.Join(" ",
                ModelState.Values
                    .SelectMany(x => x.Errors)
                    .Select(x => x.ErrorMessage)
                    .Where(x => !string.IsNullOrWhiteSpace(x)));

            return Page();
        }

        var patient = await _patients.GetAsync(PatientId.Trim(), ct);
        if (patient is null)
        {
            if (string.IsNullOrWhiteSpace(PatientFirstName) ||
                string.IsNullOrWhiteSpace(PatientFirstLastName))
            {
                await LoadInitialStudiesAsync(studyIds, studyBodyParts, ct);
                ErrorMessage = "Complete los datos del paciente antes de guardar.";
                return Page();
            }

            await _patients.SaveAsync(new Patient
            {
                IdPaciente = PatientId.Trim(),
                PrimerNombre = PatientFirstName.Trim(),
                SegundoNombre = PatientSecondName?.Trim(),
                PrimerApellido = PatientFirstLastName.Trim(),
                SegundoApellido = PatientSecondLastName?.Trim(),
                FechaNacimiento = PatientBirthDate,
                Sexo = PatientSex,
                Telefono = PatientPhone,
                Activo = true
            }, ct);
        }

        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(userId))
            return Challenge();

        try
        {
            var result = await _appointments.CreateAsync(new CreateAppointmentCommand
            {
                IdPaciente = PatientId.Trim(),
                IdMedico = DoctorId,
                IdServicio = ServiceId,
                FechaCita = AppointmentDate,
                HoraCita = AppointmentTime,
                TipoRegistro = TipoRegistro,
                EsMovil = EsMovil,
                Observaciones = Observations,
                IdUsuario = userId,
                Estudios = studyIds,
                EstudioPartes = studyBodyParts
            }, ct);

            var tipoTexto = TipoRegistro == "SOLICITUD_DIA" ? "Solicitud" : "Cita";
            TempData["Success"] = $"{tipoTexto} {result.NumeroCita} registrada correctamente.";
            return RedirectToPage("/Appointments/Index");
        }
        catch (InvalidOperationException ex)
        {
            await LoadInitialStudiesAsync(studyIds, studyBodyParts, ct);
            ErrorMessage = ex.Message;
            return Page();
        }
    }

    private void Validate(
        List<string> studies,
        List<StudyBodyPartSelection> studyBodyParts)
    {
        if (string.IsNullOrWhiteSpace(PatientId))
            ModelState.AddModelError("", "Debe seleccionar un paciente.");

        if (string.IsNullOrWhiteSpace(DoctorId))
            ModelState.AddModelError("", "Debe seleccionar un médico.");

        if (string.IsNullOrWhiteSpace(ServiceId))
            ModelState.AddModelError("", "Debe seleccionar un servicio.");

        if (studies.Count == 0)
        {
            ModelState.AddModelError("", "Debe agregar por lo menos un estudio.");
            return;
        }

        foreach (var studyId in studies)
        {
            if (!studyBodyParts.Any(x =>
                    string.Equals(x.IdPrueba, studyId, StringComparison.OrdinalIgnoreCase)))
            {
                ModelState.AddModelError(
                    "",
                    $"Debe seleccionar por lo menos una parte del cuerpo para el estudio {studyId}.");
            }
        }
    }

    private async Task LoadCatalogsAsync(CancellationToken ct)
    {
        Doctors = await _catalogs.GetDoctorsAsync(ct);
        Services = await _catalogs.GetServicesAsync(ct);
        BodyParts = await _catalogs.GetBodyPartsAsync(null, ct);
    }

    private async Task LoadInitialStudiesAsync(
        IEnumerable<string> ids,
        IReadOnlyCollection<StudyBodyPartSelection> selections,
        CancellationToken ct)
    {
        InitialStudies = [];

        foreach (var id in ids)
        {
            var study = await _catalogs.GetStudyAsync(id, ct);
            if (study is null)
                continue;

            study.PartesCuerpo = BodyParts
                .Where(part => selections.Any(selection =>
                    string.Equals(selection.IdPrueba, id, StringComparison.OrdinalIgnoreCase) &&
                    string.Equals(selection.IdParteCuerpo, part.IdParteCuerpo, StringComparison.OrdinalIgnoreCase)))
                .ToList();

            InitialStudies.Add(study);
        }
    }

    private static List<StudyBodyPartSelection> ParseStudyBodyParts(string? json)
    {
        if (string.IsNullOrWhiteSpace(json))
            return [];

        try
        {
            var items = JsonSerializer.Deserialize<List<StudyBodyPartSelection>>(
                json,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? [];

            return items
                .Where(x =>
                    !string.IsNullOrWhiteSpace(x.IdPrueba) &&
                    !string.IsNullOrWhiteSpace(x.IdParteCuerpo))
                .GroupBy(
                    x => $"{x.IdPrueba.Trim()}\u001F{x.IdParteCuerpo.Trim()}",
                    StringComparer.OrdinalIgnoreCase)
                .Select(g => new StudyBodyPartSelection
                {
                    IdPrueba = g.First().IdPrueba.Trim(),
                    IdParteCuerpo = g.First().IdParteCuerpo.Trim()
                })
                .ToList();
        }
        catch (JsonException)
        {
            return [];
        }
    }

    private static List<string> SplitStudies(string? csv) =>
        (csv ?? "")
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
}
