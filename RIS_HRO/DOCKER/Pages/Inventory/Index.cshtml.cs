using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using RIS_HRO.Models;
using RIS_HRO.Repositories;

namespace RIS_HRO.Pages.Inventory;

[Authorize(Roles = "ADMINISTRADOR,USUARIO_BODEGA")]
public sealed class IndexModel : PageModel
{
    private readonly AppointmentRepository _appointments;

    public IndexModel(AppointmentRepository appointments)
    {
        _appointments = appointments;
    }

    public List<InventoryStudyRow> Rows { get; private set; } = [];

    [BindProperty(SupportsGet = true)]
    public string? InternalId { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? PatientId { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? PatientName { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? StudyCode { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? StudyName { get; set; }

    [BindProperty(SupportsGet = true)]
    public DateTime? From { get; set; }

    [BindProperty(SupportsGet = true)]
    public DateTime? To { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? ReportStatus { get; set; }

    // El detalle clínico y los informes del Inventario quedan reservados
    // exclusivamente al Administrador.
    public bool CanManageReports =>
        User.IsInRole("ADMINISTRADOR");

    // Bodega únicamente puede ejecutar el flujo de préstamo/devolución.
    public bool CanManageLoans =>
        User.IsInRole("ADMINISTRADOR") ||
        User.IsInRole("USUARIO_BODEGA");

    public async Task OnGetAsync(CancellationToken ct)
    {
        Normalize();

        if (From.HasValue &&
            To.HasValue &&
            From.Value.Date > To.Value.Date)
        {
            ModelState.AddModelError(
                "",
                "La fecha inicial no puede ser posterior a la fecha final.");
            return;
        }

        try
        {
            Rows = await _appointments.ListInventoryStudiesAsync(
                InternalId,
                PatientId,
                PatientName,
                StudyCode,
                StudyName,
                From,
                To,
                ReportStatus,
                ct);
        }
        catch (InvalidOperationException ex)
        {
            ModelState.AddModelError("", ex.Message);
        }
    }

    private void Normalize()
    {
        InternalId = NullIfWhite(InternalId);
        PatientId = NullIfWhite(PatientId);
        PatientName = NullIfWhite(PatientName);
        StudyCode = NullIfWhite(StudyCode);
        StudyName = NullIfWhite(StudyName);
        ReportStatus = NullIfWhite(ReportStatus)?.ToUpperInvariant();
    }

    private static string? NullIfWhite(string? value) =>
        string.IsNullOrWhiteSpace(value)
            ? null
            : value.Trim();
}
