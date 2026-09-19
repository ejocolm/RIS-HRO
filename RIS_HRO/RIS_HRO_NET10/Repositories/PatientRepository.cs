using System.Data;
using Microsoft.Data.SqlClient;
using RIS_HRO.Data;
using RIS_HRO.Models;

namespace RIS_HRO.Repositories;

public sealed class PatientRepository
{
    private readonly SqlConnectionFactory _factory;
    public PatientRepository(SqlConnectionFactory factory) => _factory = factory;

    public async Task<Patient?> GetAsync(string idPaciente, CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Paciente_Obtener", cn)
        { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.Add("@IdPaciente", SqlDbType.VarChar, 30).Value = idPaciente;

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        return await r.ReadAsync(ct) ? Read(r) : null;
    }

    public async Task<List<Patient>> SearchAsync(string? q, CancellationToken ct = default)
    {
        var result = new List<Patient>();
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Paciente_Listar", cn)
        { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.Add("@Texto", SqlDbType.VarChar, 100).Value = (object?)q ?? DBNull.Value;

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct)) result.Add(Read(r));
        return result;
    }

    public async Task SaveAsync(Patient patient, CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Paciente_Guardar", cn)
        { CommandType = CommandType.StoredProcedure };

        cmd.Parameters.Add("@IdPaciente", SqlDbType.VarChar, 30).Value = patient.IdPaciente;
        cmd.Parameters.Add("@PrimerNombre", SqlDbType.VarChar, 50).Value = patient.PrimerNombre;
        cmd.Parameters.Add("@SegundoNombre", SqlDbType.VarChar, 50).Value = (object?)patient.SegundoNombre ?? DBNull.Value;
        cmd.Parameters.Add("@PrimerApellido", SqlDbType.VarChar, 50).Value = patient.PrimerApellido;
        cmd.Parameters.Add("@SegundoApellido", SqlDbType.VarChar, 50).Value = (object?)patient.SegundoApellido ?? DBNull.Value;
        cmd.Parameters.Add("@FechaNacimiento", SqlDbType.Date).Value = (object?)patient.FechaNacimiento?.Date ?? DBNull.Value;
        cmd.Parameters.Add("@Sexo", SqlDbType.Char, 1).Value = (object?)patient.Sexo ?? DBNull.Value;
        cmd.Parameters.Add("@Telefono", SqlDbType.VarChar, 20).Value = (object?)patient.Telefono ?? DBNull.Value;
        cmd.Parameters.Add("@Activo", SqlDbType.Bit).Value = patient.Activo;

        await cn.OpenAsync(ct);
        await cmd.ExecuteNonQueryAsync(ct);
    }

    private static Patient Read(SqlDataReader r)
    {
        string? S(string name)
        {
            var i = r.GetOrdinal(name);
            return r.IsDBNull(i) ? null : r.GetString(i);
        }

        DateTime? D(string name)
        {
            var i = r.GetOrdinal(name);
            return r.IsDBNull(i) ? null : r.GetDateTime(i);
        }

        var activoOrdinal = r.GetOrdinal("Activo");

        return new Patient
        {
            IdPaciente = r.GetString(r.GetOrdinal("IdPaciente")),
            PrimerNombre = r.GetString(r.GetOrdinal("PrimerNombre")),
            SegundoNombre = S("SegundoNombre"),
            PrimerApellido = r.GetString(r.GetOrdinal("PrimerApellido")),
            SegundoApellido = S("SegundoApellido"),
            FechaNacimiento = D("FechaNacimiento"),
            Sexo = S("Sexo"),
            Telefono = S("Telefono"),
            Activo = !r.IsDBNull(activoOrdinal) && r.GetBoolean(activoOrdinal)
        };
    }
}
