using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace RIS_HRO.Pages.Account;

[Authorize]
public sealed class AccessDeniedModel : PageModel
{
    public void OnGet()
    {
    }
}
