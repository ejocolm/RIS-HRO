using System.Data;
using Microsoft.Data.SqlClient;
using RIS_HRO.Data;
using RIS_HRO.Models;

namespace RIS_HRO.Repositories;

public sealed class DashboardRepository
{
    private readonly SqlConnectionFactory _factory;
    public DashboardRepository(SqlConnectionFactory factory) => _factory = factory;

    public async Task<DashboardSummary> GetSummaryAsync(DateTime fecha, CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Dashboard_ResumenDia", cn)
        { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.Add("@Fecha", SqlDbType.Date).Value = fecha.Date;

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        if (!await r.ReadAsync(ct)) return new();

        return new DashboardSummary
        {
            CitasHoy = r.GetInt32(r.GetOrdinal("CitasHoy")),
            Pendientes = r.GetInt32(r.GetOrdinal("Pendientes")),
            Atendidas = r.GetInt32(r.GetOrdinal("Atendidas")),
            Canceladas = r.GetInt32(r.GetOrdinal("Canceladas"))
        };
    }

    public async Task<List<CapacityCard>> GetCapacityAsync(DateTime fecha, CancellationToken ct = default)
    {
        var result = new List<CapacityCard>();
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Dashboard_CapacidadDia", cn)
        { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.Add("@Fecha", SqlDbType.Date).Value = fecha.Date;

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            result.Add(new CapacityCard
            {
                IdPrueba = r.GetString(r.GetOrdinal("IdPrueba")),
                NombrePrueba = r.GetString(r.GetOrdinal("NombrePrueba")),
                NombreCategoria = r.GetString(r.GetOrdinal("NombreCategoria")),
                Capacidad = r.GetInt32(r.GetOrdinal("Capacidad")),
                Utilizados = r.GetInt32(r.GetOrdinal("Utilizados")),
                Disponibles = r.GetInt32(r.GetOrdinal("Disponibles")),
                PorcentajeUso = r.GetDecimal(r.GetOrdinal("PorcentajeUso"))
            });
        }
        return result;
    }

    public async Task<List<AppointmentRow>> GetUpcomingAsync(DateTime fecha, CancellationToken ct = default)
    {
        var result = new List<AppointmentRow>();
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Dashboard_ProximasCitas", cn)
        { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.Add("@Fecha", SqlDbType.Date).Value = fecha.Date;

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            result.Add(new AppointmentRow
            {
                IdCita = r.GetInt32(r.GetOrdinal("IdCita")),
                NumeroCita = r.GetString(r.GetOrdinal("NumeroCita")),
                FechaCita = r.GetDateTime(r.GetOrdinal("FechaCita")),
                HoraCita = r.GetTimeSpan(r.GetOrdinal("HoraCita")),
                IdPaciente = r.GetString(r.GetOrdinal("IdPaciente")),
                Paciente = r.GetString(r.GetOrdinal("Paciente")),
                Estudios = r.GetString(r.GetOrdinal("Estudios")),
                Estado = r.GetString(r.GetOrdinal("Estado"))
            });
        }
        return result;
    }
}
