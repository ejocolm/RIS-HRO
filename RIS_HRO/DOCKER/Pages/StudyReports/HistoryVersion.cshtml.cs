using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using RIS_HRO.Models;
using RIS_HRO.Repositories;

namespace RIS_HRO.Pages.StudyReports;

[Authorize(Roles = "ADMINISTRADOR,USUARIO_INFORMES")]
public sealed class HistoryVersionModel : PageModel
{
    private readonly AppointmentRepository _appointments;

    public HistoryVersionModel(AppointmentRepository appointments)
    {
        _appointments = appointments;
    }

    public StudyReportHistoryContext Version { get; private set; } = new();

    public async Task<IActionResult> OnGetAsync(
        int historyId,
        CancellationToken ct)
    {
        var version =
            await _appointments.GetStudyReportHistoryVersionAsync(historyId, ct);

        if (version is null)
            return NotFound();

        Version = version;
        return Page();
    }
}
