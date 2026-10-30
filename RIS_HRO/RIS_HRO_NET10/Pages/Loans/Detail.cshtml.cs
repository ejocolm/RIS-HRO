using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using RIS_HRO.Models;
using RIS_HRO.Repositories;

namespace RIS_HRO.Pages.Loans;

[Authorize(Roles = "ADMINISTRADOR,USUARIO_BODEGA")]
public sealed class DetailModel : PageModel
{
    private readonly LoanRepository _loans;

    public DetailModel(LoanRepository loans)
    {
        _loans = loans;
    }

    public LoanDetail Loan { get; private set; } = new();

    public async Task<IActionResult> OnGetAsync(
        int loanId,
        CancellationToken ct)
    {
        var loan = await _loans.GetLoanAsync(loanId, ct);

        if (loan is null)
            return NotFound();

        Loan = loan;
        return Page();
    }
}
