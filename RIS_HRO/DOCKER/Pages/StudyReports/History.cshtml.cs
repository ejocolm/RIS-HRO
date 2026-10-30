using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using RIS_HRO.Models;
using RIS_HRO.Repositories;

namespace RIS_HRO.Pages.StudyReports;

[Authorize(Roles = "ADMINISTRADOR,USUARIO_INFORMES")]
public sealed class HistoryModel : PageModel
{
    private readonly AppointmentRepository _appointments;

    public HistoryModel(AppointmentRepository appointments)
    {
        _appointments = appointments;
    }

    public StudyReportContext Current { get; private set; } = new();
    public List<StudyReportHistoryItem> Versions { get; private set; } = [];

    public async Task<IActionResult> OnGetAsync(
        int detailId,
        CancellationToken ct)
    {
        var current = await _appointments.GetStudyReportAsync(detailId, ct);

        if (current is null || !current.IdInforme.HasValue)
            return NotFound();

        Current = current;
        Versions = await _appointments.GetStudyReportHistoryAsync(detailId, ct);

        return Page();
    }
}
