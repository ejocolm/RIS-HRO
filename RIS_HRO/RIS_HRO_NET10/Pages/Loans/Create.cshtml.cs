using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using RIS_HRO.Models;
using RIS_HRO.Repositories;

namespace RIS_HRO.Pages.Loans;

[Authorize(Roles = "ADMINISTRADOR,USUARIO_BODEGA")]
public sealed class CreateModel : PageModel
{
    private readonly LoanRepository _loans;

    public CreateModel(LoanRepository loans)
    {
        _loans = loans;
    }

    public LoanStudyContext Study { get; private set; } = new();
    public BorrowerRow? Borrower { get; private set; }

    public bool CanLoan =>
        !string.IsNullOrWhiteSpace(Study.IdInternoRadiologia);

    [BindProperty(SupportsGet = true)]
    public int DetailId { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? BorrowerId { get; set; }

    [BindProperty]
    public string MotivoPrestamo { get; set; } = "";

    [BindProperty]
    public string? Observaciones { get; set; }

    public async Task<IActionResult> OnGetAsync(CancellationToken ct)
    {
        var result = await LoadAsync(ct);
        if (result is not null)
            return result;

        if (!CanLoan)
        {
            ModelState.AddModelError(
                "",
                "Este estudio no puede prestarse porque aún no tiene un ID interno de radiología.");
        }

        return Page();
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        BorrowerId = string.IsNullOrWhiteSpace(BorrowerId)
            ? null
            : BorrowerId.Trim();

        MotivoPrestamo = MotivoPrestamo?.Trim() ?? "";
        Observaciones = string.IsNullOrWhiteSpace(Observaciones)
            ? null
            : Observaciones.Trim();

        var result = await LoadAsync(ct);
        if (result is not null)
            return result;

        if (!CanLoan)
            ModelState.AddModelError(
                "",
                "Este estudio no puede prestarse porque aún no tiene un ID interno de radiología.");

        if (Borrower is null)
            ModelState.AddModelError(
                nameof(BorrowerId),
                "Debe buscar y seleccionar un prestatario registrado.");

        if (Borrower is not null && !Borrower.Activo)
            ModelState.AddModelError(
                nameof(BorrowerId),
                "El prestatario se encuentra inactivo.");

        if (string.IsNullOrWhiteSpace(MotivoPrestamo))
            ModelState.AddModelError(
                nameof(MotivoPrestamo),
                "El motivo del préstamo es obligatorio.");

        if (!ModelState.IsValid)
            return Page();

        try
        {
            await _loans.CreateLoanAsync(
                DetailId,
                Borrower!.IdPrestatario,
                MotivoPrestamo,
                Observaciones,
                GetUserId(),
                ct);

            TempData["Success"] = "Préstamo registrado correctamente.";
            return RedirectToPage("/Loans/Index");
        }
        catch (InvalidOperationException ex)
        {
            ModelState.AddModelError("", ex.Message);
            return Page();
        }
    }

    private async Task<IActionResult?> LoadAsync(CancellationToken ct)
    {
        if (DetailId <= 0)
            return BadRequest();

        var study = await _loans.GetStudyContextAsync(DetailId, ct);

        if (study is null)
            return NotFound();

        if (study.EstaPrestado)
        {
            return RedirectToPage(
                "/Loans/Return",
                new { loanId = study.IdPrestamoActivo!.Value });
        }

        Study = study;

        if (!string.IsNullOrWhiteSpace(BorrowerId))
            Borrower = await _loans.GetBorrowerAsync(BorrowerId.Trim(), ct);

        return null;
    }

    private string GetUserId() =>
        User.FindFirstValue(ClaimTypes.NameIdentifier)
        ?? throw new InvalidOperationException(
            "No fue posible identificar el ID del usuario actual.");
}
