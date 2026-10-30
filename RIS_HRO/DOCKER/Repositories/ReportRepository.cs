using System.Data;
using Microsoft.Data.SqlClient;
using RIS_HRO.Data;
using RIS_HRO.Models;

namespace RIS_HRO.Repositories;

public sealed class ReportRepository
{
    private readonly SqlConnectionFactory _factory;
    public ReportRepository(SqlConnectionFactory factory) => _factory = factory;

    public async Task<ReportSummary> GetSummaryAsync(DateTime from, DateTime to, CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Reporte_Resumen", cn)
        { CommandType = CommandType.StoredProcedure };
        AddDates(cmd, from, to);

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        if (!await r.ReadAsync(ct)) return new();

        return new ReportSummary
        {
            TotalCitas = r.GetInt32(r.GetOrdinal("TotalCitas")),
            Programadas = r.GetInt32(r.GetOrdinal("Programadas")),
            Atendidas = r.GetInt32(r.GetOrdinal("Atendidas")),
            Canceladas = r.GetInt32(r.GetOrdinal("Canceladas")),
            NoAsistio = r.GetInt32(r.GetOrdinal("NoAsistio")),
            EstudiosRealizados = r.GetInt32(r.GetOrdinal("EstudiosRealizados"))
        };
    }

    public async Task<List<StudyReportRow>> GetStudiesAsync(DateTime from, DateTime to, CancellationToken ct = default)
    {
        var result = new List<StudyReportRow>();
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Reporte_EstudiosRealizados", cn)
        { CommandType = CommandType.StoredProcedure };
        AddDates(cmd, from, to);

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
            result.Add(new StudyReportRow
            {
                IdPrueba = r.GetString(r.GetOrdinal("IdPrueba")),
                NombrePrueba = r.GetString(r.GetOrdinal("NombrePrueba")),
                Categoria = r.GetString(r.GetOrdinal("Categoria")),
                Cantidad = r.GetInt32(r.GetOrdinal("Cantidad"))
            });
        return result;
    }

    public async Task<List<AppointmentReportRow>> GetAppointmentsAsync(DateTime from, DateTime to, CancellationToken ct = default)
    {
        var result = new List<AppointmentReportRow>();
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Reporte_Citas", cn)
        { CommandType = CommandType.StoredProcedure };
        AddDates(cmd, from, to);

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
            result.Add(new AppointmentReportRow
            {
                NumeroCita = r.GetString(r.GetOrdinal("NumeroCita")),
                FechaCita = r.GetDateTime(r.GetOrdinal("FechaCita")),
                HoraCita = r.GetTimeSpan(r.GetOrdinal("HoraCita")),
                IdPaciente = r.GetString(r.GetOrdinal("IdPaciente")),
                Paciente = r.GetString(r.GetOrdinal("Paciente")),
                Servicio = r.GetString(r.GetOrdinal("Servicio")),
                Estudios = r.GetString(r.GetOrdinal("Estudios")),
                Estado = r.GetString(r.GetOrdinal("Estado"))
            });
        return result;
    }

    private static void AddDates(SqlCommand cmd, DateTime from, DateTime to)
    {
        cmd.Parameters.Add("@FechaInicio", SqlDbType.Date).Value = from.Date;
        cmd.Parameters.Add("@FechaFin", SqlDbType.Date).Value = to.Date;
    }
}
