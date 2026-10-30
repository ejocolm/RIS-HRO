using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using RIS_HRO.Models;
using RIS_HRO.Repositories;
using RIS_HRO.Services;

namespace RIS_HRO.Pages.Admin;

[Authorize(Roles = "ADMINISTRADOR")]
public sealed class EmailSettingsModel : PageModel
{
    private readonly EmailSettingsRepository _repository;
    private readonly EmailSecretProtector _protector;
    private readonly EmailSenderService _emailSender;

    public EmailSettingsModel(
        EmailSettingsRepository repository,
        EmailSecretProtector protector,
        EmailSenderService emailSender)
    {
        _repository = repository;
        _protector = protector;
        _emailSender = emailSender;
    }

    [BindProperty]
    public EmailSettings Settings { get; set; } = new();

    [BindProperty]
    public string? NewPassword { get; set; }

    [BindProperty]
    public string? TestEmail { get; set; }

    public string? Message { get; private set; }
    public string? ErrorMessage { get; private set; }

    public async Task OnGetAsync(
        CancellationToken cancellationToken)
    {
        Settings =
            await _repository.GetAsync(cancellationToken)
            ?? new EmailSettings();
    }

    public async Task<IActionResult> OnPostAsync(
        CancellationToken cancellationToken)
    {
        var userId =
            User.FindFirstValue(ClaimTypes.NameIdentifier);

        if (string.IsNullOrWhiteSpace(userId))
            return Challenge();

        try
        {
            Validate();

            if (!ModelState.IsValid)
            {
                ErrorMessage =
                    string.Join(" ",
                        ModelState.Values
                            .SelectMany(x => x.Errors)
                            .Select(x => x.ErrorMessage));

                return Page();
            }

            string? protectedPassword = null;

            if (!string.IsNullOrWhiteSpace(NewPassword))
            {
                protectedPassword =
                    _protector.Protect(NewPassword);
            }

            await _repository.SaveAsync(
                Settings,
                protectedPassword,
                userId,
                cancellationToken);

            Message =
                "Configuración de correo guardada correctamente.";

            Settings =
                await _repository.GetAsync(cancellationToken)
                ?? Settings;

            NewPassword = null;

            return Page();
        }
        catch (Exception ex)
        {
            ErrorMessage =
                $"No fue posible guardar la configuración: {ex.Message}";
            return Page();
        }
    }

    public async Task<IActionResult> OnPostTestAsync(
        CancellationToken cancellationToken)
    {
        Settings =
            await _repository.GetAsync(cancellationToken)
            ?? new EmailSettings();

        if (string.IsNullOrWhiteSpace(TestEmail))
        {
            ErrorMessage =
                "Ingrese un correo de destino para la prueba.";
            return Page();
        }

        try
        {
            await _emailSender.SendTestAsync(
                TestEmail,
                cancellationToken);

            Message =
                "Correo de prueba enviado correctamente.";
        }
        catch (Exception ex)
        {
            ErrorMessage =
                $"No fue posible enviar el correo de prueba: {ex.Message}";
        }

        return Page();
    }

    private void Validate()
    {
        if (string.IsNullOrWhiteSpace(Settings.ServidorSmtp))
            ModelState.AddModelError("",
                "El servidor SMTP es obligatorio.");

        if (Settings.Puerto <= 0 ||
            Settings.Puerto > 65535)
            ModelState.AddModelError("",
                "El puerto SMTP no es válido.");

        if (string.IsNullOrWhiteSpace(Settings.CorreoRemitente))
            ModelState.AddModelError("",
                "El correo remitente es obligatorio.");

        if (string.IsNullOrWhiteSpace(Settings.UsuarioSmtp))
            ModelState.AddModelError("",
                "El usuario SMTP es obligatorio.");
    }
}
