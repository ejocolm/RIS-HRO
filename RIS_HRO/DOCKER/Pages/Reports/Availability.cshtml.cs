using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using RIS_HRO.Models;
using RIS_HRO.Repositories;

namespace RIS_HRO.Pages.Reports;

public sealed class AvailabilityModel : PageModel
{
    private readonly CatalogRepository _catalogs;
    private readonly AppointmentRepository _appointments;

    public AvailabilityModel(CatalogRepository catalogs, AppointmentRepository appointments)
    {
        _catalogs = catalogs;
        _appointments = appointments;
    }

    public List<StudyItem> Studies { get; private set; } = [];
    public string CurrentMonthValue => DateTime.Today.ToString("yyyy-MM");

    public async Task OnGetAsync(CancellationToken ct)
    {
        Studies = await _catalogs.SearchStudiesAsync(null, ct);
    }

    public async Task<JsonResult> OnGetMonthAsync(int year, int month, string study, CancellationToken ct)
    {
        var result = await _appointments.GetMonthAvailabilityAsync(year, month, new[] { study }, null, ct);
        return new JsonResult(result);
    }
}
