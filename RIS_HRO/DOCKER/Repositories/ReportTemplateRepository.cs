using System.Data;
using Microsoft.Data.SqlClient;
using RIS_HRO.Data;
using RIS_HRO.Models;

namespace RIS_HRO.Repositories;

public sealed class ReportTemplateRepository
{
    private readonly SqlConnectionFactory _factory;
    public ReportTemplateRepository(SqlConnectionFactory factory) => _factory = factory;

    public async Task<List<ReportTemplateItem>> ListAsync(
        string? q,
        string? type,
        bool onlyActive,
        CancellationToken ct = default)
    {
        var result = new List<ReportTemplateItem>();
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_PlantillaInforme_Listar", cn)
        { CommandType = CommandType.StoredProcedure };

        cmd.Parameters.Add("@Texto", SqlDbType.VarChar, 150).Value =
            string.IsNullOrWhiteSpace(q) ? DBNull.Value : q.Trim();
        cmd.Parameters.Add("@Tipo", SqlDbType.VarChar, 20).Value =
            string.IsNullOrWhiteSpace(type) ? DBNull.Value : type.Trim().ToUpperInvariant();
        cmd.Parameters.Add("@SoloActivos", SqlDbType.Bit).Value = onlyActive;

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
            result.Add(Read(r));

        return result;
    }

    public async Task<ReportTemplateItem?> GetAsync(int idPlantilla, CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_PlantillaInforme_Obtener", cn)
        { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.Add("@IdPlantilla", SqlDbType.Int).Value = idPlantilla;

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        return await r.ReadAsync(ct) ? Read(r) : null;
    }

    public async Task<int> SaveAsync(
        ReportTemplateEditModel model,
        string userId,
        CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_PlantillaInforme_Guardar", cn)
        { CommandType = CommandType.StoredProcedure };

        cmd.Parameters.Add("@IdPlantilla", SqlDbType.Int).Value =
            model.IdPlantilla <= 0 ? DBNull.Value : model.IdPlantilla;
        cmd.Parameters.Add("@Nombre", SqlDbType.VarChar, 150).Value = model.Nombre.Trim();
        cmd.Parameters.Add("@Tipo", SqlDbType.VarChar, 20).Value = model.Tipo.Trim().ToUpperInvariant();
        cmd.Parameters.Add("@ContenidoHtml", SqlDbType.NVarChar, -1).Value =
            (object?)model.ContenidoHtml ?? DBNull.Value;
        cmd.Parameters.Add("@Activo", SqlDbType.Bit).Value = model.Activo;
        cmd.Parameters.Add("@IdUsuario", SqlDbType.VarChar, 30).Value = userId;

        await cn.OpenAsync(ct);
        var scalar = await cmd.ExecuteScalarAsync(ct);
        return Convert.ToInt32(scalar);
    }

    public Task<List<ReportTemplateItem>> GetActiveByTypeAsync(
        string type,
        CancellationToken ct = default) =>
        ListAsync(null, type, onlyActive: true, ct);

    public async Task<StudyReportTemplateDefaults> GetStudyDefaultsAsync(
        string idPrueba,
        CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_PruebaPlantillaPredeterminada_Obtener", cn)
        { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.Add("@IdPrueba", SqlDbType.VarChar, 30).Value = idPrueba;

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        if (!await r.ReadAsync(ct))
            return new StudyReportTemplateDefaults { IdPrueba = idPrueba };

        return new StudyReportTemplateDefaults
        {
            IdPrueba = idPrueba,
            IdPlantillaHallazgos = r.IsDBNull(r.GetOrdinal("IdPlantillaHallazgos"))
                ? null : r.GetInt32(r.GetOrdinal("IdPlantillaHallazgos")),
            IdPlantillaConclusiones = r.IsDBNull(r.GetOrdinal("IdPlantillaConclusiones"))
                ? null : r.GetInt32(r.GetOrdinal("IdPlantillaConclusiones"))
        };
    }

    public async Task SaveStudyDefaultsAsync(
        string idPrueba,
        int? hallazgosId,
        int? conclusionesId,
        string userId,
        CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_PruebaPlantillaPredeterminada_Guardar", cn)
        { CommandType = CommandType.StoredProcedure };

        cmd.Parameters.Add("@IdPrueba", SqlDbType.VarChar, 30).Value = idPrueba;
        cmd.Parameters.Add("@IdPlantillaHallazgos", SqlDbType.Int).Value =
            (object?)hallazgosId ?? DBNull.Value;
        cmd.Parameters.Add("@IdPlantillaConclusiones", SqlDbType.Int).Value =
            (object?)conclusionesId ?? DBNull.Value;
        cmd.Parameters.Add("@IdUsuario", SqlDbType.VarChar, 30).Value = userId;

        await cn.OpenAsync(ct);
        await cmd.ExecuteNonQueryAsync(ct);
    }

    public async Task<ReportTemplateItem?> GetDefaultForStudyAsync(
        string idPrueba,
        string type,
        CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_PruebaPlantillaPredeterminada_ObtenerContenido", cn)
        { CommandType = CommandType.StoredProcedure };

        cmd.Parameters.Add("@IdPrueba", SqlDbType.VarChar, 30).Value = idPrueba;
        cmd.Parameters.Add("@Tipo", SqlDbType.VarChar, 20).Value = type.Trim().ToUpperInvariant();

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        return await r.ReadAsync(ct) ? Read(r) : null;
    }

    private static ReportTemplateItem Read(SqlDataReader r) => new()
    {
        IdPlantilla = r.GetInt32(r.GetOrdinal("IdPlantilla")),
        Nombre = r.GetString(r.GetOrdinal("Nombre")),
        Tipo = r.GetString(r.GetOrdinal("Tipo")),
        ContenidoHtml = r.GetString(r.GetOrdinal("ContenidoHtml")),
        Activo = r.GetBoolean(r.GetOrdinal("Activo")),
        IdUsuarioModificacion = NullableString(r, "IdUsuarioModificacion"),
        FechaModificacion = NullableDate(r, "FechaModificacion")
    };

    private static string? NullableString(SqlDataReader r, string column)
    {
        var ordinal = r.GetOrdinal(column);
        return r.IsDBNull(ordinal) ? null : r.GetString(ordinal);
    }

    private static DateTime? NullableDate(SqlDataReader r, string column)
    {
        var ordinal = r.GetOrdinal(column);
        return r.IsDBNull(ordinal) ? null : r.GetDateTime(ordinal);
    }
}
