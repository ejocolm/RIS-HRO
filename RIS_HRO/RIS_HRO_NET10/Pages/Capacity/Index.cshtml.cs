using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using RIS_HRO.Models;
using RIS_HRO.Repositories;

namespace RIS_HRO.Pages.Capacity;

[Authorize(Roles = "ADMINISTRADOR")]
public sealed class IndexModel : PageModel
{
    private readonly CapacityRepository _capacity;
    public IndexModel(CapacityRepository capacity) => _capacity = capacity;

    public List<CapacityEditModel> Rows { get; private set; } = [];
    [BindProperty] public CapacityEditModel Edit { get; set; } = new();

    public async Task OnGetAsync(CancellationToken ct) =>
        Rows = await _capacity.ListAsync(ct);

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(userId)) return Challenge();

        await _capacity.SaveAsync(Edit, userId, ct);
        TempData["Success"] = $"Capacidad de {Edit.IdPrueba} actualizada.";
        return RedirectToPage("/Capacity/Index");
    }
}
