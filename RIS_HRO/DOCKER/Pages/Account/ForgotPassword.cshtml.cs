using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using RIS_HRO.Repositories;
using RIS_HRO.Services;

namespace RIS_HRO.Pages.Account;

public sealed class ForgotPasswordModel : PageModel
{
    private readonly PasswordRecoveryRepository _repository;
    private readonly PasswordService _passwordService;
    private readonly TemporaryPasswordGenerator _generator;
    private readonly EmailSenderService _emailSender;

    public ForgotPasswordModel(
        PasswordRecoveryRepository repository,
        PasswordService passwordService,
        TemporaryPasswordGenerator generator,
        EmailSenderService emailSender)
    {
        _repository = repository;
        _passwordService = passwordService;
        _generator = generator;
        _emailSender = emailSender;
    }

    [BindProperty]
    public string Identifier { get; set; } = "";

    public string? Message { get; private set; }

    public IActionResult OnGet()
    {
        if (User.Identity?.IsAuthenticated == true)
            return RedirectToPage("/Dashboard/Index");

        return Page();
    }

    public async Task<IActionResult> OnPostAsync(
        CancellationToken cancellationToken)
    {
        const string genericMessage =
            "Si existe una cuenta activa asociada a la información ingresada, " +
            "se enviará una nueva contraseña al correo registrado.";

        if (string.IsNullOrWhiteSpace(Identifier))
        {
            Message = "Ingrese su usuario o correo electrónico.";
            return Page();
        }

        var user = await _repository.FindAsync(
            Identifier.Trim(),
            cancellationToken);

        if (user is null)
        {
            // Mensaje deliberadamente genérico para no revelar
            // si un usuario/correo existe en el sistema.
            Message = genericMessage;
            return Page();
        }

        var temporaryPassword = _generator.Generate(12);
        var temporaryHash = _passwordService.Hash(
            temporaryPassword);

        try
        {
            // Primero cambiamos la contraseña.
            await _repository.SetTemporaryPasswordAsync(
                user.IdUsuario,
                temporaryHash,
                cancellationToken);

            try
            {
                await _emailSender.SendPasswordRecoveryAsync(
                    user.Correo,
                    user.IdUsuario,
                    user.NombreCompleto,
                    temporaryPassword,
                    cancellationToken);
            }
            catch
            {
                // Si SMTP falla, restauramos la contraseña anterior
                // para no bloquear al usuario.
                await _repository.RestorePasswordAsync(
                    user,
                    CancellationToken.None);

                throw;
            }

            Message = genericMessage;
        }
        catch
        {
            Message =
                "No fue posible procesar la recuperación en este momento. " +
                "Comuníquese con el administrador del sistema.";
        }

        return Page();
    }
}
