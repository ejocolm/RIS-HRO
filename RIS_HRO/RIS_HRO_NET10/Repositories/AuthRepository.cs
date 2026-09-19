using Microsoft.Data.SqlClient;
using RIS_HRO.Data;
using RIS_HRO.Models;
using System.Data;
using System.Reflection.PortableExecutable;

namespace RIS_HRO.Repositories;

public sealed class AuthRepository
{
    private readonly SqlConnectionFactory _factory;
    public AuthRepository(SqlConnectionFactory factory) => _factory = factory;

    public async Task<UserLoginResult?> GetForLoginAsync(string idUsuario, CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Usuario_ObtenerLogin", cn)
        { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.Add("@IdUsuario", SqlDbType.VarChar, 30).Value = idUsuario;

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        if (!await r.ReadAsync(ct)) return null;

        return new UserLoginResult
        {
            IdUsuario = r.GetString(r.GetOrdinal("IdUsuario")),
            NombreCompleto = r.GetString(r.GetOrdinal("NombreCompleto")),
            NombreRol = r.GetString(r.GetOrdinal("NombreRol")),
            ContrasenaHash = r.GetString(r.GetOrdinal("ContrasenaHash")),
            Activo = r.GetBoolean(r.GetOrdinal("Activo")),
            DebeCambiarContrasena =    r.GetBoolean(r.GetOrdinal("DebeCambiarContrasena"))
        };
    }

    public async Task UpdateLastAccessAsync(string idUsuario, CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Usuario_ActualizarUltimoAcceso", cn)
        { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.Add("@IdUsuario", SqlDbType.VarChar, 30).Value = idUsuario;
        await cn.OpenAsync(ct);
        await cmd.ExecuteNonQueryAsync(ct);
    }
}
