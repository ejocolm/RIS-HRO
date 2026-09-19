using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using RIS_HRO.Repositories;
using RIS_HRO.Services;

namespace RIS_HRO.Pages.Account;

public sealed class LoginModel : PageModel
{
    private readonly AuthRepository _authRepository;
    private readonly PasswordService _passwordService;

    public LoginModel(AuthRepository authRepository, PasswordService passwordService)
    {
        _authRepository = authRepository;
        _passwordService = passwordService;
    }

    [BindProperty, Required]
    public string IdUsuario { get; set; } = "";

    [BindProperty, Required]
    public string Password { get; set; } = "";

    public string? ErrorMessage { get; set; }

    public IActionResult OnGet()
    {
        if (User.Identity?.IsAuthenticated == true)
            return RedirectToPage("/Dashboard/Index");
        return Page();
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
        {
            ErrorMessage = "Ingrese usuario y contraseña.";
            return Page();
        }

        var user = await _authRepository.GetForLoginAsync(IdUsuario.Trim(), cancellationToken);

        if (user is null || !user.Activo || !_passwordService.Verify(Password, user.ContrasenaHash))
        {
            ErrorMessage = "Usuario o contraseña incorrectos.";
            return Page();
        }

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.IdUsuario),
            new(ClaimTypes.Name, user.NombreCompleto),
            new(ClaimTypes.Role, user.NombreRol),
            new Claim("RIS_HRO.MustChangePassword", user.DebeCambiarContrasena ? "true" : "false")
        };

        var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);

        await HttpContext.SignInAsync(
            CookieAuthenticationDefaults.AuthenticationScheme,
            new ClaimsPrincipal(identity),
            new AuthenticationProperties { IsPersistent = false, AllowRefresh = true });

        await _authRepository.UpdateLastAccessAsync(user.IdUsuario, cancellationToken);
        //return RedirectToPage("/Dashboard/Index");
        if (user.DebeCambiarContrasena) 
            return RedirectToPage("/Account/ChangePassword");

        return RedirectToPage("/Dashboard/Index");
    }
}
