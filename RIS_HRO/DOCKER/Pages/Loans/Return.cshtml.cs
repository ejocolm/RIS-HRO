using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using RIS_HRO.Models;
using RIS_HRO.Repositories;

namespace RIS_HRO.Pages.Loans;

[Authorize(Roles = "ADMINISTRADOR,USUARIO_BODEGA")]
public sealed class ReturnModel : PageModel
{
    private readonly LoanRepository _loans;

    public ReturnModel(LoanRepository loans)
    {
        _loans = loans;
    }

    public LoanDetail Loan { get; private set; } = new();

    [BindProperty(SupportsGet = true)]
    public int LoanId { get; set; }

    [BindProperty]
    public string? DocumentoIdentificacionDevuelve { get; set; }

    [BindProperty]
    public string? NombrePersonaDevuelve { get; set; }

    [BindProperty]
    public string? ObservacionesDevolucion { get; set; }

    public async Task<IActionResult> OnGetAsync(CancellationToken ct)
    {
        var result = await LoadAsync(ct);
        return result ?? Page();
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        var result = await LoadAsync(ct);
        if (result is not null)
            return result;

        DocumentoIdentificacionDevuelve =
            NullIfWhite(DocumentoIdentificacionDevuelve);
        NombrePersonaDevuelve =
            NullIfWhite(NombrePersonaDevuelve);
        ObservacionesDevolucion =
            NullIfWhite(ObservacionesDevolucion);

        try
        {
            await _loans.ReturnLoanAsync(
                LoanId,
                DocumentoIdentificacionDevuelve,
                NombrePersonaDevuelve,
                ObservacionesDevolucion,
                GetUserId(),
                ct);

            TempData["Success"] = "Devolución registrada correctamente.";
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
        if (LoanId <= 0)
            return BadRequest();

        var loan = await _loans.GetLoanAsync(LoanId, ct);

        if (loan is null)
            return NotFound();

        if (!loan.EstaActivo)
            return RedirectToPage("/Loans/Detail", new { loanId = LoanId });

        Loan = loan;
        return null;
    }

    private string GetUserId() =>
        User.FindFirstValue(ClaimTypes.NameIdentifier)
        ?? throw new InvalidOperationException(
            "No fue posible identificar el ID del usuario actual.");

    private static string? NullIfWhite(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
