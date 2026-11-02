using System.Security.Claims;
using System.Text.Json;
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

    public EditModel(
        AppointmentRepository appointments,
        CatalogRepository catalogs,
        PdfService pdf)
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
    [BindProperty] public string TipoRegistro { get; set; } = "CITA";
    [BindProperty] public bool EsMovil { get; set; }
    [BindProperty] public string? Observations { get; set; }

    [BindProperty] public string StudyIdsCsv { get; set; } = "";
    [BindProperty] public string StudyBodyPartsJson { get; set; } = "[]";
    [BindProperty] public List<AppointmentResource> Resources { get; set; } = [];

    public string Status { get; private set; } = "";
    public string? ErrorMessage { get; private set; }

    public bool CanEditAppointment => Status == "PROGRAMADA";
    public bool CanCorrectStudyStatus => Status == "ATENDIDA";
    public bool CanManageReports => User.IsInRole("ADMINISTRADOR") || User.IsInRole("USUARIO_INFORMES");
    public bool CanManageResources =>
        User.IsInRole("ADMINISTRADOR") ||
        User.IsInRole("USUARIO_CITAS") ||
        User.IsInRole("USUARIO_INFORMES");

    public List<DoctorItem> Doctors { get; private set; } = [];
    public List<HospitalServiceItem> Services { get; private set; } = [];
    public List<BodyPartItem> BodyParts { get; private set; } = [];
    public List<StudyItem> InitialStudies { get; private set; } = [];
    public List<AppointmentDetailItem> AppointmentStudies { get; private set; } = [];

    public async Task<IActionResult> OnGetAsync(int id, CancellationToken ct)
    {
        Id = id;
        var ok = await LoadAsync(id, ct);
        return ok ? Page() : NotFound();
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
        int year,
        int month,
        string? studies,
        int? excludeIdCita,
        CancellationToken ct)
    {
        var ids = SplitStudies(studies);

        return new JsonResult(
            await _appointments.GetMonthAvailabilityAsync(
                year,
                month,
                ids,
                excludeIdCita,
                ct));
    }

    public async Task<IActionResult> OnGetPdfAsync(int id, CancellationToken ct)
    {
        var detail = await _appointments.GetAsync(id, ct);
        if (detail is null)
            return NotFound();

        return File(
            _pdf.AppointmentReceipt(detail),
            "application/pdf",
            $"Constancia_{detail.NumeroCita}.pdf");
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        var current = await _appointments.GetAsync(Id, ct);
        if (current is null)
            return NotFound();

        if (current.Estado != "PROGRAMADA")
        {
            TempData["Error"] = "Solo los registros PROGRAMADOS pueden modificarse.";
            return RedirectToPage("/Appointments/Edit", new { id = Id });
        }

        TipoRegistro = (TipoRegistro ?? "").Trim().ToUpperInvariant();

        if (TipoRegistro != "CITA" && TipoRegistro != "SOLICITUD_DIA")
            ModelState.AddModelError("", "Debe seleccionar un tipo de registro válido.");

        if (TipoRegistro == "CITA")
            EsMovil = false;

        if (TipoRegistro == "SOLICITUD_DIA" && current.TipoRegistro != "SOLICITUD_DIA")
        {
            var now = DateTime.Now;
            AppointmentDate = now.Date;
            AppointmentTime = new TimeSpan(now.Hour, now.Minute, 0);
        }

        var studies = SplitStudies(StudyIdsCsv);
        var studyBodyParts = ParseStudyBodyParts(StudyBodyPartsJson);

        if (studies.Count == 0)
            ModelState.AddModelError("", "Debe conservar por lo menos un estudio.");

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

        if (!ModelState.IsValid)
        {
            await LoadPostedStateAsync(current, studies, studyBodyParts, ct);
            ErrorMessage = string.Join(" ",
                ModelState.Values
                    .SelectMany(x => x.Errors)
                    .Select(x => x.ErrorMessage)
                    .Where(x => !string.IsNullOrWhiteSpace(x)));

            return Page();
        }

        var userId = GetUserId();
        if (userId is null)
            return Challenge();

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
                TipoRegistro = TipoRegistro,
                EsMovil = EsMovil,
                Observaciones = Observations,
                IdUsuario = userId,
                Estudios = studies,
                EstudioPartes = studyBodyParts
            }, ct);

            var tipoTexto = TipoRegistro == "SOLICITUD_DIA" ? "Solicitud" : "Cita";
            TempData["Success"] = $"{tipoTexto} {result.NumeroCita} actualizada correctamente.";
            return RedirectToPage("/Appointments/Edit", new { id = Id });
        }
        catch (InvalidOperationException ex)
        {
            await LoadPostedStateAsync(current, studies, studyBodyParts, ct);
            ErrorMessage = ex.Message;
            return Page();
        }
    }

    public async Task<IActionResult> OnPostAttendAsync(
        int id,
        List<int>? realizedStudyIds,
        CancellationToken ct)
    {
        if (!CanOperateAppointments())
            return Forbid();

        var userId = GetUserId();
        if (userId is null)
            return Challenge();

        try
        {
            await _appointments.MarkAttendedAsync(
                id,
                realizedStudyIds ?? [],
                userId,
                ct);

            TempData["Success"] =
                "La solicitud fue marcada como ATENDIDA y se registró el estado de cada estudio.";
        }
        catch (InvalidOperationException ex)
        {
            TempData["Error"] = ex.Message;
        }

        return RedirectToPage("/Appointments/Edit", new { id });
    }

    public async Task<IActionResult> OnPostSaveResourcesAsync(
        int id,
        CancellationToken ct)
    {
        if (!CanManageResources)
            return Forbid();

        var current = await _appointments.GetAsync(id, ct);
        if (current is null)
            return NotFound();

        if (!string.Equals(current.Estado, "ATENDIDA", StringComparison.OrdinalIgnoreCase))
        {
            TempData["Error"] =
                "Las películas e imágenes se registran cuando la solicitud está ATENDIDA.";
            return RedirectToPage("/Appointments/Edit", new { id });
        }

        var normalized = NormalizeResources(Resources);

        foreach (var row in normalized)
        {
            if (row.PeliculasEntregadas < 0 || row.ImagenesDigitales < 0)
            {
                TempData["Error"] =
                    "Las cantidades de películas e imágenes no pueden ser negativas.";
                return RedirectToPage("/Appointments/Edit", new { id });
            }

            if ((row.PeliculasEntregadas > 0 || row.ImagenesDigitales > 0) &&
                string.IsNullOrWhiteSpace(row.SistemaAdquisicionCDDR))
            {
                TempData["Error"] =
                    $"Complete el sistema de adquisición CD/DR para el tamaño {row.TamanoPelicula}.";
                return RedirectToPage("/Appointments/Edit", new { id });
            }
        }

        var userId = GetUserId();
        if (userId is null)
            return Challenge();

        try
        {
            await _appointments.SaveAppointmentResourcesAsync(
                id,
                normalized,
                userId,
                ct);

            TempData["Success"] =
                "Películas e imágenes de la solicitud guardadas correctamente.";
        }
        catch (InvalidOperationException ex)
        {
            TempData["Error"] = ex.Message;
        }

        return RedirectToPage("/Appointments/Edit", new { id });
    }

    public async Task<IActionResult> OnPostChangeStudyStatusAsync(
        int id,
        int detailId,
        string newStatus,
        string? observation,
        CancellationToken ct)
    {
        if (!CanOperateAppointments())
            return Forbid();

        var userId = GetUserId();
        if (userId is null)
            return Challenge();

        try
        {
            await _appointments.ChangeStudyPerformedStatusAsync(
                detailId,
                newStatus,
                userId,
                observation,
                ct);

            TempData["Success"] =
                $"El estudio fue actualizado a {newStatus}. El cambio quedó registrado en la trazabilidad.";
        }
        catch (InvalidOperationException ex)
        {
            TempData["Error"] = ex.Message;
        }

        return RedirectToPage("/Appointments/Edit", new { id });
    }

    public async Task<IActionResult> OnPostChangeStatusAsync(
        int id,
        string status,
        CancellationToken ct)
    {
        if (!CanOperateAppointments())
            return Forbid();

        if (string.Equals(status, "ATENDIDA", StringComparison.OrdinalIgnoreCase))
        {
            TempData["Error"] =
                "Para marcar la solicitud como atendida debe seleccionar los estudios realizados.";
            return RedirectToPage("/Appointments/Edit", new { id });
        }

        var userId = GetUserId();
        if (userId is null)
            return Challenge();

        try
        {
            await _appointments.ChangeStatusAsync(id, status, userId, ct);
            TempData["Success"] = $"Estado de la solicitud actualizado a {status}.";
        }
        catch (InvalidOperationException ex)
        {
            TempData["Error"] = ex.Message;
        }

        return RedirectToPage("/Appointments/Edit", new { id });
    }

    private async Task<bool> LoadAsync(int id, CancellationToken ct)
    {
        var detail = await _appointments.GetAsync(id, ct);
        if (detail is null)
            return false;

        Id = detail.IdCita;
        Number = detail.NumeroCita;
        PatientId = detail.IdPaciente;
        PatientName = detail.Paciente;
        DoctorId = detail.IdMedico;
        ServiceId = detail.IdServicio;
        AppointmentDate = detail.FechaCita;
        AppointmentTime = detail.HoraCita;
        TipoRegistro = detail.TipoRegistro;
        EsMovil = detail.EsMovil;
        Observations = detail.Observaciones;
        Status = detail.Estado;
        AppointmentStudies = detail.Estudios;
        Resources = NormalizeResources(await _appointments.GetAppointmentResourcesAsync(id, ct));

        await LoadCatalogsAsync(ct);

        InitialStudies = detail.Estudios.Select(x => new StudyItem
        {
            IdPrueba = x.IdPrueba,
            NombrePrueba = x.NombrePrueba,
            NombreCategoria = x.NombreCategoria,
            PartesCuerpo = x.PartesCuerpo.ToList()
        }).ToList();

        StudyIdsCsv = string.Join(",", InitialStudies.Select(x => x.IdPrueba));

        StudyBodyPartsJson = JsonSerializer.Serialize(
            detail.Estudios.SelectMany(study =>
                study.PartesCuerpo.Select(part => new StudyBodyPartSelection
                {
                    IdPrueba = study.IdPrueba,
                    IdParteCuerpo = part.IdParteCuerpo
                })),
            new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            });

        return true;
    }

    private async Task LoadPostedStateAsync(
        AppointmentDetail current,
        IEnumerable<string> studies,
        IReadOnlyCollection<StudyBodyPartSelection> selections,
        CancellationToken ct)
    {
        Number = current.NumeroCita;
        PatientId = current.IdPaciente;
        PatientName = current.Paciente;
        Status = current.Estado;
        AppointmentStudies = current.Estudios;

        await LoadCatalogsAsync(ct);

        InitialStudies = [];

        foreach (var id in studies)
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

    private async Task LoadCatalogsAsync(CancellationToken ct)
    {
        Doctors = await _catalogs.GetDoctorsAsync(ct);
        Services = await _catalogs.GetServicesAsync(ct);
        BodyParts = await _catalogs.GetBodyPartsAsync(null, ct);
    }

    private string? GetUserId() => User.FindFirstValue(ClaimTypes.NameIdentifier);

    private bool CanOperateAppointments() =>
        User.IsInRole("ADMINISTRADOR") ||
        User.IsInRole("USUARIO_CITAS") ||
        User.IsInRole("USUARIO_INFORMES");

    private static List<AppointmentResource> NormalizeResources(
        IEnumerable<AppointmentResource>? resources)
    {
        var source = resources?.ToList() ?? [];

        return new[] { "8x10", "10x14", "14x17" }
            .Select(size =>
            {
                var row = source.FirstOrDefault(x =>
                    string.Equals(x.TamanoPelicula, size, StringComparison.OrdinalIgnoreCase));

                return new AppointmentResource
                {
                    TamanoPelicula = size,
                    PeliculasEntregadas = row?.PeliculasEntregadas ?? 0,
                    ImagenesDigitales = row?.ImagenesDigitales ?? 0,
                    SistemaAdquisicionCDDR = string.IsNullOrWhiteSpace(row?.SistemaAdquisicionCDDR)
                        ? null
                        : row!.SistemaAdquisicionCDDR!.Trim()
                };
            })
            .ToList();
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
