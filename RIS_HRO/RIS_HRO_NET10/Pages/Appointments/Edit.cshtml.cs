using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using RIS_HRO.Models;
using RIS_HRO.Repositories;
using RIS_HRO.Services;

namespace RIS_HRO.Pages.Appointments;

public sealed class EditModel : PageModel
{
    private readonly AppointmentRepository _appointments;
    private readonly CatalogRepository _catalogs;
    private readonly PdfService _pdf;

    public EditModel(AppointmentRepository appointments, CatalogRepository catalogs, PdfService pdf)
    {
        _appointments = appointments;
        _catalogs = catalogs;
        _pdf = pdf;
    }

    [BindProperty] public int Id { get; set; }
    public string Number { get; private set; } = "";
    [BindProperty] public string PatientId { get; set; } = "";
    public string PatientName { get; private set; } = "";
    [BindProperty] public string DoctorId { get; set; } = "";
    [BindProperty] public string ServiceId { get; set; } = "";
    [BindProperty] public DateTime AppointmentDate { get; set; }
    [BindProperty] public TimeSpan AppointmentTime { get; set; }
    [BindProperty] public string? Observations { get; set; }
    [BindProperty] public string StudyIdsCsv { get; set; } = "";
    public string Status { get; private set; } = "";
    public string? ErrorMessage { get; private set; }

    public List<DoctorItem> Doctors { get; private set; } = [];
    public List<HospitalServiceItem> Services { get; private set; } = [];
    public List<StudyItem> InitialStudies { get; private set; } = [];

    public async Task<IActionResult> OnGetAsync(int id, CancellationToken ct)
    {
        Id = id;
        var ok = await LoadAsync(id, ct);
        return ok ? Page() : NotFound();
    }

    public async Task<JsonResult> OnGetStudyAsync(string code, CancellationToken ct)
    {
        var study = string.IsNullOrWhiteSpace(code) ? null : await _catalogs.GetStudyAsync(code.Trim(), ct);
        return new JsonResult(new { found = study is not null, study });
    }

    public async Task<JsonResult> OnGetStudiesAsync(string? q, CancellationToken ct) =>
        new(await _catalogs.SearchStudiesAsync(q, ct));

    public async Task<JsonResult> OnGetAvailabilityAsync(
        int year, int month, string? studies, int? excludeIdCita, CancellationToken ct)
    {
        var ids = SplitStudies(studies);
        return new JsonResult(await _appointments.GetMonthAvailabilityAsync(year, month, ids, excludeIdCita, ct));
    }

    public async Task<IActionResult> OnGetPdfAsync(int id, CancellationToken ct)
    {
        var detail = await _appointments.GetAsync(id, ct);
        if (detail is null) return NotFound();
        return File(_pdf.AppointmentReceipt(detail), "application/pdf", $"Constancia_{detail.NumeroCita}.pdf");
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        var current = await _appointments.GetAsync(Id, ct);
        if (current is null) return NotFound();

        var studies = SplitStudies(StudyIdsCsv);
        if (studies.Count == 0)
        {
            await LoadAsync(Id, ct);
            ErrorMessage = "Debe conservar por lo menos un estudio.";
            return Page();
        }

        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(userId)) return Challenge();

        try
        {
            var result = await _appointments.UpdateAsync(new UpdateAppointmentCommand
            {
                IdCita = Id,
                IdPaciente = current.IdPaciente,
                IdMedico = DoctorId,
                IdServicio = ServiceId,
                FechaCita = AppointmentDate,
                HoraCita = AppointmentTime,
                Observaciones = Observations,
                IdUsuario = userId,
                Estudios = studies
            }, ct);

            TempData["Success"] = $"Cita {result.NumeroCita} actualizada correctamente.";
            return RedirectToPage("/Appointments/Index");
        }
        catch (InvalidOperationException ex)
        {
            await LoadAsync(Id, ct);
            ErrorMessage = ex.Message;
            return Page();
        }
    }

    public async Task<IActionResult> OnPostChangeStatusAsync(int id, string status, CancellationToken ct)
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(userId)) return Challenge();

        await _appointments.ChangeStatusAsync(id, status, userId, ct);
        TempData["Success"] = $"Estado de la cita actualizado a {status}.";
        return RedirectToPage("/Appointments/Index");
    }

    private async Task<bool> LoadAsync(int id, CancellationToken ct)
    {
        var detail = await _appointments.GetAsync(id, ct);
        if (detail is null) return false;

        Id = detail.IdCita;
        Number = detail.NumeroCita;
        PatientId = detail.IdPaciente;
        PatientName = detail.Paciente;
        DoctorId = detail.IdMedico;
        ServiceId = detail.IdServicio;
        AppointmentDate = detail.FechaCita;
        AppointmentTime = detail.HoraCita;
        Observations = detail.Observaciones;
        Status = detail.Estado;

        Doctors = await _catalogs.GetDoctorsAsync(ct);
        Services = await _catalogs.GetServicesAsync(ct);

        InitialStudies = detail.Estudios.Select(x => new StudyItem
        {
            IdPrueba = x.IdPrueba,
            NombrePrueba = x.NombrePrueba,
            NombreCategoria = x.NombreCategoria
        }).ToList();

        StudyIdsCsv = string.Join(",", InitialStudies.Select(x => x.IdPrueba));
        return true;
    }

    private static List<string> SplitStudies(string? csv) =>
        (csv ?? "").Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Distinct(StringComparer.OrdinalIgnoreCase).ToList();
}
