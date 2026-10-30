using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using RIS_HRO.Models;
using RIS_HRO.Repositories;

namespace RIS_HRO.Pages.Patients;

public sealed class IndexModel : PageModel
{
    private readonly PatientRepository _patients;
    public IndexModel(PatientRepository patients) => _patients = patients;

    [BindProperty] public Patient Edit { get; set; } = new();
    public List<Patient> Rows { get; private set; } = [];
    public string? Query { get; private set; }
    public string? ErrorMessage { get; private set; }
    public bool IsEditing { get; private set; }

    public async Task OnGetAsync(string? q, string? edit, CancellationToken ct)
    {
        Query = q;
        Rows = await _patients.SearchAsync(q, ct);

        if (!string.IsNullOrWhiteSpace(edit))
        {
            var patient = await _patients.GetAsync(edit, ct);
            if (patient is not null)
            {
                Edit = patient;
                IsEditing = true;
            }
        }
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(Edit.IdPaciente) ||
            string.IsNullOrWhiteSpace(Edit.PrimerNombre) ||
            string.IsNullOrWhiteSpace(Edit.PrimerApellido))
        {
            ErrorMessage = "ID, primer nombre y primer apellido son obligatorios.";
            Rows = await _patients.SearchAsync(null, ct);
            return Page();
        }

        await _patients.SaveAsync(Edit, ct);
        TempData["Success"] = "Paciente guardado correctamente.";
        return RedirectToPage("/Patients/Index");
    }
}
