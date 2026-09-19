using System.Security.Claims;
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
    [BindProperty] public string? Observations { get; set; }
    [BindProperty] public string StudyIdsCsv { get; set; } = "";

    public async Task OnGetAsync(CancellationToken ct) => await LoadCatalogsAsync(ct);

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
        var study = string.IsNullOrWhiteSpace(code) ? null : await _catalogs.GetStudyAsync(code.Trim(), ct);
        return new JsonResult(new { found = study is not null, study });
    }

    public async Task<JsonResult> OnGetStudiesAsync(string? q, CancellationToken ct) =>
        new(await _catalogs.SearchStudiesAsync(q, ct));

    public async Task<JsonResult> OnGetAvailabilityAsync(
        int year, int month, string? studies, CancellationToken ct)
    {
        var ids = SplitStudies(studies);
        return new JsonResult(await _appointments.GetMonthAvailabilityAsync(year, month, ids, null, ct));
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        await LoadCatalogsAsync(ct);
        var studyIds = SplitStudies(StudyIdsCsv);

        Validate(studyIds);
        if (!ModelState.IsValid)
        {
            await LoadInitialStudiesAsync(studyIds, ct);
            ErrorMessage = string.Join(" ", ModelState.Values.SelectMany(x => x.Errors)
                .Select(x => x.ErrorMessage).Where(x => !string.IsNullOrWhiteSpace(x)));
            return Page();
        }

        var patient = await _patients.GetAsync(PatientId.Trim(), ct);
        if (patient is null)
        {
            if (string.IsNullOrWhiteSpace(PatientFirstName) || string.IsNullOrWhiteSpace(PatientFirstLastName))
            {
                await LoadInitialStudiesAsync(studyIds, ct);
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
        if (string.IsNullOrWhiteSpace(userId)) return Challenge();

        try
        {
            var result = await _appointments.CreateAsync(new CreateAppointmentCommand
            {
                IdPaciente = PatientId.Trim(),
                IdMedico = DoctorId,
                IdServicio = ServiceId,
                FechaCita = AppointmentDate,
                HoraCita = AppointmentTime,
                Observaciones = Observations,
                IdUsuario = userId,
                Estudios = studyIds
            }, ct);

            TempData["Success"] = $"Cita {result.NumeroCita} registrada correctamente.";
            return RedirectToPage("/Appointments/Index");
        }
        catch (InvalidOperationException ex)
        {
            await LoadInitialStudiesAsync(studyIds, ct);
            ErrorMessage = ex.Message;
            return Page();
        }
    }

    private void Validate(List<string> studies)
    {
        if (string.IsNullOrWhiteSpace(PatientId)) ModelState.AddModelError("", "Debe seleccionar un paciente.");
        if (string.IsNullOrWhiteSpace(DoctorId)) ModelState.AddModelError("", "Debe seleccionar un médico.");
        if (string.IsNullOrWhiteSpace(ServiceId)) ModelState.AddModelError("", "Debe seleccionar un servicio.");
        if (studies.Count == 0) ModelState.AddModelError("", "Debe agregar por lo menos un estudio.");
    }

    private async Task LoadCatalogsAsync(CancellationToken ct)
    {
        Doctors = await _catalogs.GetDoctorsAsync(ct);
        Services = await _catalogs.GetServicesAsync(ct);
    }

    private async Task LoadInitialStudiesAsync(IEnumerable<string> ids, CancellationToken ct)
    {
        InitialStudies = [];
        foreach (var id in ids)
        {
            var study = await _catalogs.GetStudyAsync(id, ct);
            if (study is not null)
                InitialStudies.Add(study);
        }
    }

    private static List<string> SplitStudies(string? csv) =>
        (csv ?? "").Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Distinct(StringComparer.OrdinalIgnoreCase).ToList();
}
