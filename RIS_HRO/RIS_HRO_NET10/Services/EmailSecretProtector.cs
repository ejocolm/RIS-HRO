using Microsoft.AspNetCore.DataProtection;

namespace RIS_HRO.Services;

public sealed class EmailSecretProtector
{
    private readonly IDataProtector _protector;

    public EmailSecretProtector(IDataProtectionProvider provider)
    {
        _protector = provider.CreateProtector(
            "RIS_HRO.EmailConfiguration.v1");
    }

    public string Protect(string secret) =>
        _protector.Protect(secret);

    public string Unprotect(string protectedSecret) =>
        _protector.Unprotect(protectedSecret);
}
