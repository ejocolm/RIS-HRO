namespace RIS_HRO.Models;

public sealed class RecoveryUser
{
    public string IdUsuario { get; set; } = "";
    public string NombreCompleto { get; set; } = "";
    public string Correo { get; set; } = "";
    public string ContrasenaHash { get; set; } = "";
    public bool DebeCambiarContrasena { get; set; }
}

public sealed class EmailSettings
{
    public string ServidorSmtp { get; set; } = "smtp.gmail.com";
    public int Puerto { get; set; } = 587;
    public bool UsarSsl { get; set; } = true;
    public string NombreRemitente { get; set; } = "RIS HRO";
    public string CorreoRemitente { get; set; } = "";
    public string UsuarioSmtp { get; set; } = "";
    public string? ClaveProtegida { get; set; }
    public string? ClaveDesprotegida { get; set; }
    public bool Activo { get; set; }
}
