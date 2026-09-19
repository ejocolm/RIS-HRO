using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using RIS_HRO.Models;
using RIS_HRO.Repositories;
using RIS_HRO.Services;

namespace RIS_HRO.Pages.Reports;

public sealed class IndexModel : PageModel
{
    private readonly ReportRepository _reports;
    private readonly PdfService _pdf;

    public IndexModel(ReportRepository reports, PdfService pdf)
    {
        _reports = reports;
        _pdf = pdf;
    }

    public DateTime From { get; private set; }
    public DateTime To { get; private set; }
    public ReportSummary Summary { get; private set; } = new();
    public List<StudyReportRow> Studies { get; private set; } = [];
    public List<AppointmentReportRow> Appointments { get; private set; } = [];
    public string FromValue => From.ToString("yyyy-MM-dd");
    public string ToValue => To.ToString("yyyy-MM-dd");

    public async Task OnGetAsync(DateTime? from, DateTime? to, CancellationToken ct)
    {
        From = from ?? new DateTime(DateTime.Today.Year, DateTime.Today.Month, 1);
        To = to ?? DateTime.Today;
        if (To < From) (From, To) = (To, From);
        await LoadAsync(ct);
    }

    public async Task<IActionResult> OnGetStudiesPdfAsync(DateTime from, DateTime to, CancellationToken ct)
    {
        var rows = await _reports.GetStudiesAsync(from, to, ct);
        return File(_pdf.StudyReport(rows, from, to), "application/pdf",
            $"Estudios_{from:yyyyMMdd}_{to:yyyyMMdd}.pdf");
    }

    public async Task<IActionResult> OnGetAppointmentsPdfAsync(DateTime from, DateTime to, CancellationToken ct)
    {
        var rows = await _reports.GetAppointmentsAsync(from, to, ct);
        return File(_pdf.AppointmentReport(rows, from, to), "application/pdf",
            $"Citas_{from:yyyyMMdd}_{to:yyyyMMdd}.pdf");
    }

    private async Task LoadAsync(CancellationToken ct)
    {
        Summary = await _reports.GetSummaryAsync(From, To, ct);
        Studies = await _reports.GetStudiesAsync(From, To, ct);
        Appointments = await _reports.GetAppointmentsAsync(From, To, ct);
    }
}
