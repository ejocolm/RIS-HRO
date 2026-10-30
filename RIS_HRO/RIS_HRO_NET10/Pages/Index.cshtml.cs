using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace RIS_HRO.Pages;

public sealed class IndexModel : PageModel
{
    public IActionResult OnGet()
    {
        if (User.IsInRole("USUARIO_BODEGA"))
            return RedirectToPage("/Inventory/Index");

        return RedirectToPage("/Dashboard/Index");
    }
}
