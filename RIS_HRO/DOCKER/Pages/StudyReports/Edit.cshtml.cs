using System.Security.Claims;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using RIS_HRO.Models;
using RIS_HRO.Repositories;
using RIS_HRO.Services;

namespace RIS_HRO.Pages.StudyReports;

[Authorize(Roles = "ADMINISTRADOR,USUARIO_INFORMES")]
public sealed class EditModel : PageModel
{
    private readonly AppointmentRepository _appointments;
    private readonly PdfService _pdf;

    public EditModel(
        AppointmentRepository appointments,
        PdfService pdf)
    {
        _appointments = appointments;
        _pdf = pdf;
    }

    public StudyReportContext Context { get; private set; } = new();
    public List<TechnicianItem> Technicians { get; private set; } = [];
    public List<InformingDoctorItem> InformingDoctors { get; private set; } = [];

    [BindProperty]
    public StudyReportInput Input { get; set; } = new();

    public string? ErrorMessage { get; private set; }
    public bool IsFinalized =>
        string.Equals(Context.EstadoInforme, "FINALIZADO", StringComparison.OrdinalIgnoreCase);
    public bool IsDraft => !IsFinalized;
    public bool HasHistory => Context.NumeroVersion > 1;

    public async Task<IActionResult> OnGetAsync(int detailId, CancellationToken ct)
    {
        var loaded = await LoadAsync(detailId, initializeInput: true, ct);
        if (!loaded)
            return NotFound();

        if (Context.EstadoCita != "ATENDIDA" || Context.EstadoEstudio != "REALIZADO")
        {
            TempData["Error"] =
                "El informe solo está disponible para estudios REALIZADOS de citas ATENDIDAS.";
            return RedirectToPage("/Appointments/Edit", new { id = Context.IdCita });
        }

        return Page();
    }

    public async Task<IActionResult> OnGetPrintAsync(
        int detailId,
        bool withHeader,
        CancellationToken ct)
    {
        if (!CanManageReports())
            return Forbid();

        var report = await _appointments.GetStudyReportPrintAsync(detailId, ct);

        if (report is null)
        {
            TempData["Error"] =
                "Solo puede imprimirse la versión vigente de un informe FINALIZADO.";
            return RedirectToPage(new { detailId });
        }

        byte[]? header = null;

        if (withHeader)
        {
            var config = await _appointments.GetReportHeaderConfigurationAsync(ct);

            if (config is null || !config.TieneEncabezado)
            {
                TempData["Error"] =
                    "No existe un encabezado configurado. Un administrador debe cargarlo en Configuración de informes.";
                return RedirectToPage(new { detailId });
            }

            header = config.EncabezadoImagen;
        }

        var pdf = _pdf.RadiologyStudyReport(report, header);
        var internalId = SafeFileName(report.IdInternoRadiologia);

        return File(
            pdf,
            "application/pdf",
            $"Informe_{internalId}_V{report.NumeroVersion}.pdf");
    }

    public async Task<IActionResult> OnPostSaveDraftAsync(CancellationToken ct)
    {
        if (!CanManageReports())
            return Forbid();

        NormalizeInput();
        SanitizeRichText();

        if (!await LoadContextOnlyAsync(Input.IdDetalleCita, ct))
            return NotFound();

        if (!CanWriteCurrentContext())
            return InvalidContextRedirect();

        if (IsFinalized)
        {
            TempData["Error"] =
                "El informe está finalizado. Inicie una corrección antes de editarlo.";
            return RedirectToPage(new { detailId = Input.IdDetalleCita });
        }

        try
        {
            await _appointments.SaveStudyReportAsync(
                Input,
                GetUserId()!,
                finalize: false,
                ct);

            TempData["Success"] = "Borrador guardado correctamente.";
            return RedirectToPage(new { detailId = Input.IdDetalleCita });
        }
        catch (InvalidOperationException ex)
        {
            ErrorMessage = ex.Message;
            await LoadListsAsync(ct);
            return Page();
        }
    }

    public async Task<IActionResult> OnPostFinalizeAsync(CancellationToken ct)
    {
        if (!CanManageReports())
            return Forbid();

        NormalizeInput();
        SanitizeRichText();

        if (!await LoadContextOnlyAsync(Input.IdDetalleCita, ct))
            return NotFound();

        if (!CanWriteCurrentContext())
            return InvalidContextRedirect();

        if (IsFinalized)
        {
            TempData["Error"] = "El informe ya está finalizado.";
            return RedirectToPage(new { detailId = Input.IdDetalleCita });
        }

        ValidateForFinalization();

        if (!ModelState.IsValid)
        {
            ErrorMessage = string.Join(
                " ",
                ModelState.Values
                    .SelectMany(v => v.Errors)
                    .Select(e => e.ErrorMessage));

            await LoadListsAsync(ct);
            return Page();
        }

        try
        {
            var result = await _appointments.SaveStudyReportAsync(
                Input,
                GetUserId()!,
                finalize: true,
                ct);

            TempData["Success"] =
                $"Informe finalizado correctamente. Versión {result.NumeroVersion}.";
            TempData["OfferPrint"] = "1";

            return RedirectToPage(new { detailId = Input.IdDetalleCita });
        }
        catch (InvalidOperationException ex)
        {
            ErrorMessage = ex.Message;
            await LoadListsAsync(ct);
            return Page();
        }
    }

    public async Task<IActionResult> OnPostStartCorrectionAsync(
        int detailId,
        CancellationToken ct)
    {
        if (!CanManageReports())
            return Forbid();

        try
        {
            await _appointments.StartStudyReportCorrectionAsync(
                detailId,
                GetUserId()!,
                ct);

            TempData["Success"] =
                "Se creó una nueva versión editable. La versión finalizada anterior quedó preservada en el historial.";
        }
        catch (InvalidOperationException ex)
        {
            TempData["Error"] = ex.Message;
        }

        return RedirectToPage(new { detailId });
    }

    private async Task<bool> LoadAsync(
        int detailId,
        bool initializeInput,
        CancellationToken ct)
    {
        var context = await _appointments.GetStudyReportAsync(detailId, ct);
        if (context is null)
            return false;

        Context = context;
        await LoadListsAsync(ct);

        if (initializeInput)
            Input = ToInput(context);

        return true;
    }

    private async Task<bool> LoadContextOnlyAsync(
        int detailId,
        CancellationToken ct)
    {
        var context = await _appointments.GetStudyReportAsync(detailId, ct);

        if (context is null)
            return false;

        Context = context;
        return true;
    }

    private async Task LoadListsAsync(CancellationToken ct)
    {
        Technicians = await _appointments.GetActiveTechniciansAsync(ct);
        InformingDoctors = await _appointments.GetActiveInformingDoctorsAsync(ct);
    }

    private bool CanWriteCurrentContext() =>
        Context.EstadoCita == "ATENDIDA" &&
        Context.EstadoEstudio == "REALIZADO";

    private IActionResult InvalidContextRedirect()
    {
        TempData["Error"] =
            "El informe solo puede editarse para un estudio REALIZADO de una cita ATENDIDA.";

        return RedirectToPage(
            "/Appointments/Edit",
            new { id = Context.IdCita });
    }

    private void SanitizeRichText()
    {
        Input.Hallazgos = RichTextSanitizer.Sanitize(Input.Hallazgos);
        Input.Conclusiones = RichTextSanitizer.Sanitize(Input.Conclusiones);
    }

    private void NormalizeInput()
    {
        Input.Recursos ??= [];
        var fixedRows = new List<StudyReportResource>();

        foreach (var size in new[] { "8x10", "10x14", "14x17" })
        {
            var row = Input.Recursos.FirstOrDefault(x =>
                string.Equals(
                    x.TamanoPelicula,
                    size,
                    StringComparison.OrdinalIgnoreCase));

            fixedRows.Add(new StudyReportResource
            {
                TamanoPelicula = size,
                PeliculasEntregadas = row?.PeliculasEntregadas ?? 0,
                ImagenesDigitales = row?.ImagenesDigitales ?? 0,
                SistemaAdquisicionCDDR =
                    string.IsNullOrWhiteSpace(row?.SistemaAdquisicionCDDR)
                        ? null
                        : row!.SistemaAdquisicionCDDR!.Trim()
            });
        }

        Input.Recursos = fixedRows;
        Input.IdInternoRadiologia = NullIfWhite(Input.IdInternoRadiologia);
        Input.IdTecnicoRealiza = NullIfWhite(Input.IdTecnicoRealiza);
        Input.IdTecnicoPosiciona = NullIfWhite(Input.IdTecnicoPosiciona);
        Input.IdMedicoInformante = NullIfWhite(Input.IdMedicoInformante);
    }

    private void ValidateForFinalization()
    {
        if (string.IsNullOrWhiteSpace(Input.IdInternoRadiologia))
            ModelState.AddModelError(
                "",
                "El ID interno de radiología es obligatorio.");

        if (!RichTextSanitizer.HasVisibleText(Input.Hallazgos))
            ModelState.AddModelError(
                "",
                "Los hallazgos son obligatorios.");

        if (!RichTextSanitizer.HasVisibleText(Input.Conclusiones))
            ModelState.AddModelError(
                "",
                "Las conclusiones son obligatorias.");

        if (string.IsNullOrWhiteSpace(Input.IdTecnicoRealiza))
            ModelState.AddModelError(
                "",
                "Debe seleccionar el técnico que realizó el estudio.");

        if (string.IsNullOrWhiteSpace(Input.IdTecnicoPosiciona))
            ModelState.AddModelError(
                "",
                "Debe seleccionar el técnico que posicionó al paciente.");

        if (string.IsNullOrWhiteSpace(Input.IdMedicoInformante))
            ModelState.AddModelError(
                "",
                "Debe seleccionar el médico informante.");

        if (!Input.FechaHoraInforme.HasValue)
            ModelState.AddModelError(
                "",
                "La fecha y hora del informe son obligatorias.");

        foreach (var row in Input.Recursos)
        {
            if (row.PeliculasEntregadas < 0 ||
                row.ImagenesDigitales < 0)
            {
                ModelState.AddModelError(
                    "",
                    "Las cantidades de películas e imágenes no pueden ser negativas.");
            }

            if ((row.PeliculasEntregadas > 0 ||
                 row.ImagenesDigitales > 0) &&
                string.IsNullOrWhiteSpace(row.SistemaAdquisicionCDDR))
            {
                ModelState.AddModelError(
                    "",
                    $"Complete el sistema de adquisición CD/DR para el tamaño {row.TamanoPelicula}.");
            }
        }
    }

    private static StudyReportInput ToInput(StudyReportContext context)
    {
        return new StudyReportInput
        {
            IdDetalleCita = context.IdDetalleCita,
            IdInternoRadiologia = context.IdInternoRadiologia,
            Hallazgos = context.Hallazgos,
            Conclusiones = context.Conclusiones,
            IdTecnicoRealiza = context.IdTecnicoRealiza,
            IdTecnicoPosiciona = context.IdTecnicoPosiciona,
            IdMedicoInformante = context.IdMedicoInformante,
            FechaHoraInforme = context.IdInforme.HasValue
                ? context.FechaHoraInforme
                : DateTime.Now,
            Recursos = EnsureResources(context.Recursos)
        };
    }

    private static List<StudyReportResource> EnsureResources(
        IEnumerable<StudyReportResource> resources)
    {
        var source = resources.ToList();

        return new[] { "8x10", "10x14", "14x17" }
            .Select(size =>
                source.FirstOrDefault(x => x.TamanoPelicula == size)
                ?? new StudyReportResource
                {
                    TamanoPelicula = size
                })
            .ToList();
    }

    private string? GetUserId() =>
        User.FindFirstValue(ClaimTypes.NameIdentifier);

    private bool CanManageReports() =>
        User.IsInRole("ADMINISTRADOR") ||
        User.IsInRole("USUARIO_INFORMES");

    private static string? NullIfWhite(string? value) =>
        string.IsNullOrWhiteSpace(value)
            ? null
            : value.Trim();

    private static string SafeFileName(string? value)
    {
        var candidate = string.IsNullOrWhiteSpace(value)
            ? "Informe"
            : value.Trim();

        return Regex.Replace(
            candidate,
            @"[^A-Za-z0-9_-]+",
            "_");
    }
}
