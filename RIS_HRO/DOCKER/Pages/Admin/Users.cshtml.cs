using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using RIS_HRO.Models;
using RIS_HRO.Repositories;
using RIS_HRO.Services;

namespace RIS_HRO.Pages.Admin;

[Authorize(Roles = "ADMINISTRADOR")]
public sealed class UsersModel : PageModel
{
    private readonly UserRepository _users;
    private readonly CatalogRepository _catalogs;
    private readonly PasswordService _passwords;

    public UsersModel(UserRepository users, CatalogRepository catalogs, PasswordService passwords)
    {
        _users = users;
        _catalogs = catalogs;
        _passwords = passwords;
    }

    [BindProperty] public UserEditModel Edit { get; set; } = new();
    [BindProperty] public string? Password { get; set; }

    public List<UserListItem> Rows { get; private set; } = [];
    public List<RoleItem> Roles { get; private set; } = [];
    public string? Query { get; private set; }
    public bool IsEditing { get; private set; }
    public string? ErrorMessage { get; private set; }

    public async Task OnGetAsync(string? q, string? edit, CancellationToken ct)
    {
        Query = q;
        await LoadAsync(q, ct);

        if (!string.IsNullOrWhiteSpace(edit))
        {
            var item = await _users.GetAsync(edit, ct);
            if (item is not null)
            {
                Edit = item;
                IsEditing = true;
            }
        }
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        var existing = string.IsNullOrWhiteSpace(Edit.IdUsuario)
            ? null
            : await _users.GetAsync(Edit.IdUsuario, ct);

        if (string.IsNullOrWhiteSpace(Edit.IdUsuario) ||
            string.IsNullOrWhiteSpace(Edit.NombreCompleto) ||
            Edit.IdRol <= 0)
        {
            ErrorMessage = "Usuario, nombre y rol son obligatorios.";
            await LoadAsync(null, ct);
            IsEditing = existing is not null;
            return Page();
        }

        if (existing is null && string.IsNullOrWhiteSpace(Password))
        {
            ErrorMessage = "La contraseña es obligatoria para un usuario nuevo.";
            await LoadAsync(null, ct);
            return Page();
        }

        //Edgar -> validacion de contraseña

        if (!string.IsNullOrWhiteSpace(Password))
        {
            if (!PasswordPolicy.IsValid(
                Password,
                out var passwordError))
            {
                ErrorMessage = passwordError;

                await LoadAsync(null, ct);

                IsEditing = existing is not null;

                return Page();
            }
        }
        //

        var hash = string.IsNullOrWhiteSpace(Password) ? null : _passwords.Hash(Password);
        await _users.SaveAsync(Edit, hash, ct);

        TempData["Success"] = "Usuario guardado correctamente.";
        return RedirectToPage("/Admin/Users");
    }

    private async Task LoadAsync(string? q, CancellationToken ct)
    {
        Rows = await _users.ListAsync(q, ct);
        Roles = await _catalogs.GetRolesAsync(ct);
    }
}
