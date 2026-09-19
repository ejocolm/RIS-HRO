using Microsoft.AspNetCore.Mvc.RazorPages;
using RIS_HRO.Models;
using RIS_HRO.Repositories;

namespace RIS_HRO.Pages.Dashboard;

public sealed class IndexModel : PageModel
{
    private readonly DashboardRepository _dashboardRepository;

    public IndexModel(DashboardRepository dashboardRepository) => _dashboardRepository = dashboardRepository;

    public DashboardSummary Summary { get; private set; } = new();
    public List<CapacityCard> CapacityCards { get; private set; } = [];
    public List<AppointmentRow> Upcoming { get; private set; } = [];

    public async Task OnGetAsync(CancellationToken cancellationToken)
    {
        var today = DateTime.Today;
        Summary = await _dashboardRepository.GetSummaryAsync(today, cancellationToken);
        CapacityCards = await _dashboardRepository.GetCapacityAsync(today, cancellationToken);
        Upcoming = await _dashboardRepository.GetUpcomingAsync(today, cancellationToken);
    }
}
