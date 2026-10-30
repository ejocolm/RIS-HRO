using System.Data;
using Microsoft.Data.SqlClient;
using RIS_HRO.Data;
using RIS_HRO.Models;

namespace RIS_HRO.Repositories;

public sealed class PasswordRecoveryRepository
{
    private readonly SqlConnectionFactory _factory;

    public PasswordRecoveryRepository(SqlConnectionFactory factory)
    {
        _factory = factory;
    }

    public async Task<RecoveryUser?> FindAsync(
        string identifier,
        CancellationToken cancellationToken = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand(
            "dbo.sp_Usuario_BuscarRecuperacion", cn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.Add("@Identificador", SqlDbType.VarChar, 150)
            .Value = identifier.Trim();

        await cn.OpenAsync(cancellationToken);
        await using var reader =
            await cmd.ExecuteReaderAsync(cancellationToken);

        if (!await reader.ReadAsync(cancellationToken))
            return null;

        return new RecoveryUser
        {
            IdUsuario = reader.GetString(reader.GetOrdinal("IdUsuario")),
            NombreCompleto = reader.GetString(reader.GetOrdinal("NombreCompleto")),
            Correo = reader.GetString(reader.GetOrdinal("Correo")),
            ContrasenaHash = reader.GetString(reader.GetOrdinal("ContrasenaHash")),
            DebeCambiarContrasena =
                reader.GetBoolean(reader.GetOrdinal("DebeCambiarContrasena"))
        };
    }

    public async Task SetTemporaryPasswordAsync(
        string idUsuario,
        string hash,
        CancellationToken cancellationToken = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand(
            "dbo.sp_Usuario_EstablecerPasswordTemporal", cn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.Add("@IdUsuario", SqlDbType.VarChar, 30)
            .Value = idUsuario;
        cmd.Parameters.Add("@ContrasenaHash", SqlDbType.VarChar, 255)
            .Value = hash;

        await cn.OpenAsync(cancellationToken);
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task RestorePasswordAsync(
        RecoveryUser user,
        CancellationToken cancellationToken = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand(
            "dbo.sp_Usuario_RestaurarPassword", cn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.Add("@IdUsuario", SqlDbType.VarChar, 30)
            .Value = user.IdUsuario;
        cmd.Parameters.Add("@ContrasenaHashAnterior", SqlDbType.VarChar, 255)
            .Value = user.ContrasenaHash;
        cmd.Parameters.Add("@DebeCambiarAnterior", SqlDbType.Bit)
            .Value = user.DebeCambiarContrasena;

        await cn.OpenAsync(cancellationToken);
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task ChangePasswordAsync(
        string idUsuario,
        string hash,
        CancellationToken cancellationToken = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand(
            "dbo.sp_Usuario_CambiarPassword", cn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.Add("@IdUsuario", SqlDbType.VarChar, 30)
            .Value = idUsuario;
        cmd.Parameters.Add("@ContrasenaHash", SqlDbType.VarChar, 255)
            .Value = hash;

        await cn.OpenAsync(cancellationToken);
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }
}
