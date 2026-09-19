using System.Data;
using Microsoft.Data.SqlClient;
using RIS_HRO.Data;
using RIS_HRO.Models;

namespace RIS_HRO.Repositories;

public sealed class AppointmentRepository
{
    private readonly SqlConnectionFactory _factory;
    public AppointmentRepository(SqlConnectionFactory factory) => _factory = factory;

    public async Task<List<AppointmentRow>> ListAsync(
        DateTime? from, DateTime? to, string? patient, string? status,
        CancellationToken ct = default)
    {
        var result = new List<AppointmentRow>();
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Cita_Listar", cn)
        { CommandType = CommandType.StoredProcedure };

        cmd.Parameters.Add("@FechaInicio", SqlDbType.Date).Value = (object?)from?.Date ?? DBNull.Value;
        cmd.Parameters.Add("@FechaFin", SqlDbType.Date).Value = (object?)to?.Date ?? DBNull.Value;
        cmd.Parameters.Add("@Paciente", SqlDbType.VarChar, 100).Value = (object?)patient ?? DBNull.Value;
        cmd.Parameters.Add("@Estado", SqlDbType.VarChar, 20).Value = (object?)status ?? DBNull.Value;

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
            result.Add(ReadAppointmentRow(r));
        return result;
    }

    public async Task<AppointmentDetail?> GetAsync(int idCita, CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Cita_Obtener", cn)
        { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.Add("@IdCita", SqlDbType.Int).Value = idCita;

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        if (!await r.ReadAsync(ct)) return null;

        var detail = new AppointmentDetail
        {
            IdCita = r.GetInt32(r.GetOrdinal("IdCita")),
            NumeroCita = r.GetString(r.GetOrdinal("NumeroCita")),
            IdPaciente = r.GetString(r.GetOrdinal("IdPaciente")),
            Paciente = r.GetString(r.GetOrdinal("Paciente")),
            IdMedico = r.GetString(r.GetOrdinal("IdMedico")),
            Medico = r.GetString(r.GetOrdinal("Medico")),
            IdServicio = r.GetString(r.GetOrdinal("IdServicio")),
            Servicio = r.GetString(r.GetOrdinal("Servicio")),
            FechaCita = r.GetDateTime(r.GetOrdinal("FechaCita")),
            HoraCita = r.GetTimeSpan(r.GetOrdinal("HoraCita")),
            Estado = r.GetString(r.GetOrdinal("Estado")),
            Observaciones = r.IsDBNull(r.GetOrdinal("Observaciones")) ? null : r.GetString(r.GetOrdinal("Observaciones")),
            UsuarioCreacion = r.GetString(r.GetOrdinal("UsuarioCreacion")),
            FechaCreacion = r.GetDateTime(r.GetOrdinal("FechaCreacion"))
        };

        if (await r.NextResultAsync(ct))
        {
            while (await r.ReadAsync(ct))
                detail.Estudios.Add(new AppointmentDetailItem
                {
                    IdDetalleCita = r.GetInt32(r.GetOrdinal("IdDetalleCita")),
                    IdPrueba = r.GetString(r.GetOrdinal("IdPrueba")),
                    NombrePrueba = r.GetString(r.GetOrdinal("NombrePrueba")),
                    NombreCategoria = r.GetString(r.GetOrdinal("NombreCategoria")),
                    IdTecnico = r.IsDBNull(r.GetOrdinal("IdTecnico")) ? null : r.GetString(r.GetOrdinal("IdTecnico")),
                    Tecnico = r.IsDBNull(r.GetOrdinal("Tecnico")) ? null : r.GetString(r.GetOrdinal("Tecnico")),
                    Estado = r.GetString(r.GetOrdinal("Estado"))
                });
        }

        return detail;
    }

    public async Task<AvailabilityMonthResponse> GetMonthAvailabilityAsync(
        int year, int month, IReadOnlyCollection<string> studyIds,
        int? excludeAppointmentId = null,
        CancellationToken ct = default)
    {
        var response = new AvailabilityMonthResponse();
        if (studyIds.Count == 0) return response;

        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Capacidad_MesPorPruebas", cn)
        { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.Add("@Anio", SqlDbType.Int).Value = year;
        cmd.Parameters.Add("@Mes", SqlDbType.Int).Value = month;
        cmd.Parameters.Add("@IdsPruebas", SqlDbType.VarChar, -1).Value = string.Join(",", studyIds);
        cmd.Parameters.Add("@ExcluirIdCita", SqlDbType.Int).Value = (object?)excludeAppointmentId ?? DBNull.Value;

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
            response.Days.Add(new AvailabilityDay
            {
                Fecha = r.GetDateTime(r.GetOrdinal("Fecha")),
                Estado = r.GetString(r.GetOrdinal("Estado"))
            });

        if (await r.NextResultAsync(ct))
        {
            while (await r.ReadAsync(ct))
            {
                var cap = r.GetOrdinal("Capacidad");
                var disp = r.GetOrdinal("Disponibles");
                response.Details.Add(new AvailabilityDetail
                {
                    Fecha = r.GetDateTime(r.GetOrdinal("Fecha")),
                    IdPrueba = r.GetString(r.GetOrdinal("IdPrueba")),
                    NombrePrueba = r.GetString(r.GetOrdinal("NombrePrueba")),
                    Capacidad = r.IsDBNull(cap) ? null : r.GetInt32(cap),
                    Utilizados = r.GetInt32(r.GetOrdinal("Utilizados")),
                    Disponibles = r.IsDBNull(disp) ? null : r.GetInt32(disp)
                });
            }
        }

        return response;
    }

    public async Task<CreateAppointmentResult> CreateAsync(CreateAppointmentCommand request, CancellationToken ct = default)
    {
        return await ExecuteSaveAsync("dbo.sp_Cita_Crear", request, null, ct);
    }

    public async Task<CreateAppointmentResult> UpdateAsync(UpdateAppointmentCommand request, CancellationToken ct = default)
    {
        return await ExecuteSaveAsync("dbo.sp_Cita_Actualizar", request, request.IdCita, ct);
    }

    public async Task ChangeStatusAsync(int idCita, string status, string userId, CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Cita_CambiarEstado", cn)
        { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.Add("@IdCita", SqlDbType.Int).Value = idCita;
        cmd.Parameters.Add("@Estado", SqlDbType.VarChar, 20).Value = status;
        cmd.Parameters.Add("@IdUsuario", SqlDbType.VarChar, 30).Value = userId;
        await cn.OpenAsync(ct);
        await cmd.ExecuteNonQueryAsync(ct);
    }

    private async Task<CreateAppointmentResult> ExecuteSaveAsync(
        string procedure, CreateAppointmentCommand request, int? idCita, CancellationToken ct)
    {
        var tvp = new DataTable();
        tvp.Columns.Add("IdPrueba", typeof(string));
        foreach (var id in request.Estudios.Distinct(StringComparer.OrdinalIgnoreCase))
            tvp.Rows.Add(id);

        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand(procedure, cn)
        { CommandType = CommandType.StoredProcedure };

        if (idCita.HasValue)
            cmd.Parameters.Add("@IdCita", SqlDbType.Int).Value = idCita.Value;

        cmd.Parameters.Add("@IdPaciente", SqlDbType.VarChar, 30).Value = request.IdPaciente;
        cmd.Parameters.Add("@IdMedico", SqlDbType.VarChar, 30).Value = request.IdMedico;
        cmd.Parameters.Add("@IdServicio", SqlDbType.VarChar, 30).Value = request.IdServicio;
        cmd.Parameters.Add("@FechaCita", SqlDbType.Date).Value = request.FechaCita.Date;
        cmd.Parameters.Add("@HoraCita", SqlDbType.Time).Value = request.HoraCita;
        cmd.Parameters.Add("@Observaciones", SqlDbType.VarChar, 500).Value = (object?)request.Observaciones ?? DBNull.Value;
        cmd.Parameters.Add("@IdUsuario", SqlDbType.VarChar, 30).Value = request.IdUsuario;

        var p = cmd.Parameters.AddWithValue("@Estudios", tvp);
        p.SqlDbType = SqlDbType.Structured;
        p.TypeName = "dbo.TVP_EstudioCita";

        await cn.OpenAsync(ct);

        try
        {
            await using var r = await cmd.ExecuteReaderAsync(ct);
            if (!await r.ReadAsync(ct))
                throw new InvalidOperationException("No se obtuvo respuesta al guardar la cita.");

            return new CreateAppointmentResult
            {
                IdCita = r.GetInt32(r.GetOrdinal("IdCita")),
                NumeroCita = r.GetString(r.GetOrdinal("NumeroCita"))
            };
        }
        catch (SqlException ex) when (ex.Number >= 50000)
        {
            throw new InvalidOperationException(ex.Message);
        }
    }

    private static AppointmentRow ReadAppointmentRow(SqlDataReader r) => new()
    {
        IdCita = r.GetInt32(r.GetOrdinal("IdCita")),
        NumeroCita = r.GetString(r.GetOrdinal("NumeroCita")),
        FechaCita = r.GetDateTime(r.GetOrdinal("FechaCita")),
        HoraCita = r.GetTimeSpan(r.GetOrdinal("HoraCita")),
        IdPaciente = r.GetString(r.GetOrdinal("IdPaciente")),
        Paciente = r.GetString(r.GetOrdinal("Paciente")),
        Medico = r.GetString(r.GetOrdinal("Medico")),
        Servicio = r.GetString(r.GetOrdinal("Servicio")),
        Estudios = r.GetString(r.GetOrdinal("Estudios")),
        Estado = r.GetString(r.GetOrdinal("Estado"))
    };
}
