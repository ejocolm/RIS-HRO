using Microsoft.AspNetCore.Mvc.RazorPages;
using RIS_HRO.Models;
using RIS_HRO.Repositories;

namespace RIS_HRO.Pages.Appointments;

public sealed class IndexModel : PageModel
{
    private readonly AppointmentRepository _appointments;
    public IndexModel(AppointmentRepository appointments) => _appointments = appointments;

    public List<AppointmentRow> Rows { get; private set; } = [];

    public DateTime? From { get; set; }
    public DateTime? To { get; set; }
    public string? Patient { get; set; }
    public string? Status { get; set; }

    public async Task OnGetAsync(DateTime? from, DateTime? to, string? patient, string? status, CancellationToken ct)
    {
        //Edgar -> cambio para que el filtro funcione iniciando y finalizando el día en curso
        //From = from ?? DateTime.Today.AddDays(-7);
        From = from ?? DateTime.Today;
        //To = to ?? DateTime.Today.AddDays(30);
        To = to ?? DateTime.Today;
        Patient = patient;
        Status = status;
        Rows = await _appointments.ListAsync(From, To, Patient, Status, ct);
    }
}
