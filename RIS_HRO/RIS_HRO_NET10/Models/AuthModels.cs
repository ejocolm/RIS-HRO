namespace RIS_HRO.Models;

public sealed class UserLoginResult
{
    public string IdUsuario { get; set; } = "";
    public string NombreCompleto { get; set; } = "";
    public string NombreRol { get; set; } = "";
    public string ContrasenaHash { get; set; } = "";
    public bool Activo { get; set; }
    public bool DebeCambiarContrasena { get; set; }
}

public sealed class UserListItem
{
    public string IdUsuario { get; set; } = "";
    public string NombreCompleto { get; set; } = "";
    public string NombreRol { get; set; } = "";
    public string? Correo { get; set; }
    public bool Activo { get; set; }
    public DateTime? UltimoAcceso { get; set; }
}

public sealed class UserEditModel
{
    public string IdUsuario { get; set; } = "";
    public int IdRol { get; set; }
    public string NombreCompleto { get; set; } = "";
    public string? Correo { get; set; }
    public bool Activo { get; set; } = true;
}
