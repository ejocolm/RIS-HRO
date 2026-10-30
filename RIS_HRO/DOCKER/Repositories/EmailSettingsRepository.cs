using System.Data;
using Microsoft.Data.SqlClient;
using RIS_HRO.Data;
using RIS_HRO.Models;

namespace RIS_HRO.Repositories;

public sealed class EmailSettingsRepository
{
    private readonly SqlConnectionFactory _factory;

    public EmailSettingsRepository(SqlConnectionFactory factory)
    {
        _factory = factory;
    }

    public async Task<EmailSettings?> GetAsync(
        CancellationToken cancellationToken = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand(
            "dbo.sp_ConfigCorreo_Obtener", cn)
        {
            CommandType = CommandType.StoredProcedure
        };

        await cn.OpenAsync(cancellationToken);
        await using var reader =
            await cmd.ExecuteReaderAsync(cancellationToken);

        if (!await reader.ReadAsync(cancellationToken))
            return null;

        return new EmailSettings
        {
            ServidorSmtp = reader.GetString(reader.GetOrdinal("ServidorSmtp")),
            Puerto = reader.GetInt32(reader.GetOrdinal("Puerto")),
            UsarSsl = reader.GetBoolean(reader.GetOrdinal("UsarSsl")),
            NombreRemitente = reader.GetString(reader.GetOrdinal("NombreRemitente")),
            CorreoRemitente = reader.GetString(reader.GetOrdinal("CorreoRemitente")),
            UsuarioSmtp = reader.GetString(reader.GetOrdinal("UsuarioSmtp")),
            ClaveProtegida =
                reader.IsDBNull(reader.GetOrdinal("ClaveProtegida"))
                    ? null
                    : reader.GetString(reader.GetOrdinal("ClaveProtegida")),
            Activo = reader.GetBoolean(reader.GetOrdinal("Activo"))
        };
    }

    public async Task SaveAsync(
        EmailSettings settings,
        string? protectedPassword,
        string userId,
        CancellationToken cancellationToken = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand(
            "dbo.sp_ConfigCorreo_Guardar", cn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.Add("@ServidorSmtp", SqlDbType.VarChar, 150)
            .Value = settings.ServidorSmtp;
        cmd.Parameters.Add("@Puerto", SqlDbType.Int)
            .Value = settings.Puerto;
        cmd.Parameters.Add("@UsarSsl", SqlDbType.Bit)
            .Value = settings.UsarSsl;
        cmd.Parameters.Add("@NombreRemitente", SqlDbType.VarChar, 150)
            .Value = settings.NombreRemitente;
        cmd.Parameters.Add("@CorreoRemitente", SqlDbType.VarChar, 150)
            .Value = settings.CorreoRemitente;
        cmd.Parameters.Add("@UsuarioSmtp", SqlDbType.VarChar, 150)
            .Value = settings.UsuarioSmtp;
        cmd.Parameters.Add("@ClaveProtegida", SqlDbType.NVarChar, -1)
            .Value = (object?)protectedPassword ?? DBNull.Value;
        cmd.Parameters.Add("@Activo", SqlDbType.Bit)
            .Value = settings.Activo;
        cmd.Parameters.Add("@IdUsuarioModificacion", SqlDbType.VarChar, 30)
            .Value = userId;

        await cn.OpenAsync(cancellationToken);
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }
}
