using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using RIS_HRO.Repositories;
using RIS_HRO.Services;

namespace RIS_HRO.Pages.Account;

public sealed class ChangePasswordModel : PageModel
{
    private readonly PasswordRecoveryRepository _repository;
    private readonly PasswordService _passwordService;

    public ChangePasswordModel(
        PasswordRecoveryRepository repository,
        PasswordService passwordService)
    {
        _repository = repository;
        _passwordService = passwordService;
    }

    [BindProperty]
    public string NewPassword { get; set; } = "";

    [BindProperty]
    public string ConfirmPassword { get; set; } = "";

    public string? ErrorMessage { get; private set; }

    public async Task<IActionResult> OnPostAsync(
        CancellationToken cancellationToken)
    {

        // Edgar ->Cambio para aplicar nueva politica
        //if (!IsStrongPassword(NewPassword))
        //{
        //    ErrorMessage =
        //        "La contraseña debe tener al menos 10 caracteres " +
        //        "e incluir mayúscula, minúscula, número y símbolo.";
        //    return Page();
        //}

        if (!PasswordPolicy.IsValid(NewPassword, out var passwordError))
        {
            ErrorMessage = passwordError;
            return Page();
        }

        if (NewPassword != ConfirmPassword)
        {
            ErrorMessage = "Las contraseñas no coinciden.";
            return Page();
        }

        var userId = User.FindFirstValue(
            ClaimTypes.NameIdentifier);

        if (string.IsNullOrWhiteSpace(userId))
            return Challenge();

        var hash = _passwordService.Hash(NewPassword);

        await _repository.ChangePasswordAsync(
            userId,
            hash,
            cancellationToken);

        // Cerramos la sesión para eliminar el claim
        // que obligaba a cambiar la contraseña.
        await HttpContext.SignOutAsync(
            CookieAuthenticationDefaults.AuthenticationScheme);

        TempData["PasswordChanged"] =
            "Contraseña actualizada. Inicie sesión nuevamente.";

        return RedirectToPage("/Account/Login");
    }


    //Edgar -> Comentado por nueva politica de password
    //private static bool IsStrongPassword(string value)
    //{
    //    if (string.IsNullOrWhiteSpace(value) ||
    //        value.Length < 10)
    //        return false;

    //    return value.Any(char.IsUpper)
    //        && value.Any(char.IsLower)
    //        && value.Any(char.IsDigit)
    //        && value.Any(c => !char.IsLetterOrDigit(c));
    //}
}
