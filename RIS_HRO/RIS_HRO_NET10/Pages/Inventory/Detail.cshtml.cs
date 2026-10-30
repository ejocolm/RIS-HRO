using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using RIS_HRO.Models;
using RIS_HRO.Repositories;

namespace RIS_HRO.Pages.Inventory;

[Authorize(Roles = "ADMINISTRADOR")]
public sealed class DetailModel : PageModel
{
    private readonly AppointmentRepository _appointments;

    public DetailModel(AppointmentRepository appointments)
    {
        _appointments = appointments;
    }

    public InventoryStudyDetail Study { get; private set; } = new();

    public async Task<IActionResult> OnGetAsync(
        int detailId,
        CancellationToken ct)
    {
        var study = await _appointments.GetInventoryStudyAsync(detailId, ct);

        if (study is null)
            return NotFound();

        Study = study;
        return Page();
    }

    public async Task<IActionResult> OnPostStartCorrectionAsync(
        int detailId,
        CancellationToken ct)
    {
        try
        {
            await _appointments.StartStudyReportCorrectionAsync(
                detailId,
                GetUserId(),
                ct);

            TempData["Success"] =
                "Se creó una nueva versión editable. La versión finalizada anterior quedó preservada en el historial.";

            return RedirectToPage(
                "/StudyReports/Edit",
                new { detailId });
        }
        catch (InvalidOperationException ex)
        {
            TempData["Error"] = ex.Message;
            return RedirectToPage(new { detailId });
        }
    }

    private string GetUserId()
    {
        return User.Identity?.Name
            ?? throw new InvalidOperationException(
                "No fue posible identificar al usuario actual.");
    }
}
