using System.Data;
using Microsoft.Data.SqlClient;
using RIS_HRO.Data;
using RIS_HRO.Models;

namespace RIS_HRO.Repositories;

public sealed class UserRepository
{
    private readonly SqlConnectionFactory _factory;
    public UserRepository(SqlConnectionFactory factory) => _factory = factory;

    public async Task<List<UserListItem>> ListAsync(string? q, CancellationToken ct = default)
    {
        var result = new List<UserListItem>();
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Usuario_Listar", cn)
        { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.Add("@Texto", SqlDbType.VarChar, 100).Value = (object?)q ?? DBNull.Value;

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
            result.Add(new UserListItem
            {
                IdUsuario = r.GetString(r.GetOrdinal("IdUsuario")),
                NombreCompleto = r.GetString(r.GetOrdinal("NombreCompleto")),
                NombreRol = r.GetString(r.GetOrdinal("NombreRol")),
                Correo = r.IsDBNull(r.GetOrdinal("Correo")) ? null : r.GetString(r.GetOrdinal("Correo")),
                Activo = r.GetBoolean(r.GetOrdinal("Activo")),
                UltimoAcceso = r.IsDBNull(r.GetOrdinal("UltimoAcceso")) ? null : r.GetDateTime(r.GetOrdinal("UltimoAcceso"))
            });
        return result;
    }

    public async Task<UserEditModel?> GetAsync(string idUsuario, CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Usuario_Obtener", cn)
        { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.Add("@IdUsuario", SqlDbType.VarChar, 30).Value = idUsuario;

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        if (!await r.ReadAsync(ct)) return null;

        return new UserEditModel
        {
            IdUsuario = r.GetString(r.GetOrdinal("IdUsuario")),
            IdRol = r.GetInt32(r.GetOrdinal("IdRol")),
            NombreCompleto = r.GetString(r.GetOrdinal("NombreCompleto")),
            Correo = r.IsDBNull(r.GetOrdinal("Correo")) ? null : r.GetString(r.GetOrdinal("Correo")),
            Activo = r.GetBoolean(r.GetOrdinal("Activo"))
        };
    }

    public async Task SaveAsync(UserEditModel user, string? passwordHash, CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Usuario_Guardar", cn)
        { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.Add("@IdUsuario", SqlDbType.VarChar, 30).Value = user.IdUsuario;
        cmd.Parameters.Add("@IdRol", SqlDbType.Int).Value = user.IdRol;
        cmd.Parameters.Add("@NombreCompleto", SqlDbType.VarChar, 150).Value = user.NombreCompleto;
        cmd.Parameters.Add("@Correo", SqlDbType.VarChar, 100).Value = (object?)user.Correo ?? DBNull.Value;
        cmd.Parameters.Add("@ContrasenaHash", SqlDbType.VarChar, 255).Value = (object?)passwordHash ?? DBNull.Value;
        cmd.Parameters.Add("@Activo", SqlDbType.Bit).Value = user.Activo;

        await cn.OpenAsync(ct);
        await cmd.ExecuteNonQueryAsync(ct);
    }
}
