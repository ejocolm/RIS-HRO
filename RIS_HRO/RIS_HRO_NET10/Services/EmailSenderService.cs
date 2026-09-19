using System.Net;
using System.Net.Mail;
using RIS_HRO.Repositories;

namespace RIS_HRO.Services;

public sealed class EmailSenderService
{
    private readonly EmailSettingsRepository _repository;
    private readonly EmailSecretProtector _protector;

    public EmailSenderService(
        EmailSettingsRepository repository,
        EmailSecretProtector protector)
    {
        _repository = repository;
        _protector = protector;
    }

    public async Task SendPasswordRecoveryAsync(
        string destination,
        string userId,
        string name,
        string temporaryPassword,
        CancellationToken cancellationToken = default)
    {
        var settings = await _repository.GetAsync(cancellationToken)
            ?? throw new InvalidOperationException(
                "No existe configuración de correo.");

        if (!settings.Activo)
            throw new InvalidOperationException(
                "El envío de correo está deshabilitado.");

        if (string.IsNullOrWhiteSpace(settings.ClaveProtegida))
            throw new InvalidOperationException(
                "No se ha configurado la credencial SMTP.");

        var password = _protector.Unprotect(settings.ClaveProtegida);

        using var message = new MailMessage
        {
            From = new MailAddress(
                settings.CorreoRemitente,
                settings.NombreRemitente),
            Subject = "RIS HRO - Recuperación de contraseña",
            Body = BuildRecoveryBody(
                name, userId, temporaryPassword),
            IsBodyHtml = true
        };

        message.To.Add(destination);

        using var smtp = new SmtpClient(
            settings.ServidorSmtp,
            settings.Puerto)
        {
            EnableSsl = settings.UsarSsl,
            UseDefaultCredentials = false,
            Credentials = new NetworkCredential(
                settings.UsuarioSmtp,
                password),
            DeliveryMethod = SmtpDeliveryMethod.Network
        };

        cancellationToken.ThrowIfCancellationRequested();
        await smtp.SendMailAsync(message);
    }

    public async Task SendTestAsync(
        string destination,
        CancellationToken cancellationToken = default)
    {
        var settings = await _repository.GetAsync(cancellationToken)
            ?? throw new InvalidOperationException(
                "No existe configuración de correo.");

        if (string.IsNullOrWhiteSpace(settings.ClaveProtegida))
            throw new InvalidOperationException(
                "No se ha configurado la credencial SMTP.");

        var password = _protector.Unprotect(settings.ClaveProtegida);

        using var message = new MailMessage
        {
            From = new MailAddress(
                settings.CorreoRemitente,
                settings.NombreRemitente),
            Subject = "RIS HRO - Correo de prueba",
            Body = """
                <div style="font-family:Arial,sans-serif">
                    <h2 style="color:#004082">RIS HRO</h2>
                    <p>La configuración SMTP está funcionando correctamente.</p>
                </div>
                """,
            IsBodyHtml = true
        };

        message.To.Add(destination);

        using var smtp = new SmtpClient(
            settings.ServidorSmtp,
            settings.Puerto)
        {
            EnableSsl = settings.UsarSsl,
            UseDefaultCredentials = false,
            Credentials = new NetworkCredential(
                settings.UsuarioSmtp,
                password)
        };

        cancellationToken.ThrowIfCancellationRequested();
        await smtp.SendMailAsync(message);
    }

    private static string BuildRecoveryBody(
        string name,
        string userId,
        string temporaryPassword)
    {
        return $"""
            <div style="font-family:Arial,sans-serif;
                        max-width:600px;margin:auto;
                        color:#1d3557">
                <div style="background:#004082;
                            color:white;
                            padding:22px;
                            border-radius:12px 12px 0 0">
                    <h2 style="margin:0">RIS HRO</h2>
                    <div>Sistema de Citas de Radiología</div>
                </div>

                <div style="border:1px solid #dfe7f1;
                            border-top:0;
                            padding:26px;
                            border-radius:0 0 12px 12px">
                    <p>Hola <strong>{WebUtility.HtmlEncode(name)}</strong>,</p>

                    <p>Se solicitó la recuperación de la contraseña
                       de su cuenta en RIS HRO.</p>

                    <p>
                        Usuario:
                        <strong>{WebUtility.HtmlEncode(userId)}</strong>
                    </p>

                    <div style="background:#eef5ff;
                                border-left:4px solid #10b8c8;
                                padding:16px;
                                margin:20px 0">
                        Contraseña temporal:
                        <strong style="font-size:18px">
                            {WebUtility.HtmlEncode(temporaryPassword)}
                        </strong>
                    </div>

                    <p>
                        Inicie sesión con esta contraseña temporal.
                        El sistema le solicitará establecer una nueva
                        contraseña antes de continuar.
                    </p>

                    <p style="color:#6c7b96;font-size:12px">
                        Si usted no solicitó este cambio,
                        comuníquese con el administrador de RIS HRO.
                    </p>
                </div>
            </div>
            """;
    }
}
