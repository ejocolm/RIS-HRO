using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using RIS_HRO.Models;
using RIS_HRO.Repositories;

namespace RIS_HRO.Pages.Borrowers;

[Authorize(Roles = "ADMINISTRADOR,USUARIO_BODEGA")]
public sealed class IndexModel : PageModel
{
    private readonly LoanRepository _loans;

    public IndexModel(LoanRepository loans)
    {
        _loans = loans;
    }

    [BindProperty(SupportsGet = true)]
    public string? Q { get; set; }

    public List<BorrowerRow> Rows { get; private set; } = [];

    public async Task OnGetAsync(CancellationToken ct)
    {
        Q = string.IsNullOrWhiteSpace(Q) ? null : Q.Trim();
        Rows = await _loans.ListBorrowersAsync(Q, ct);
    }
}
