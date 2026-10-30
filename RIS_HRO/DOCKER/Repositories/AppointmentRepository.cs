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
            TipoRegistro = r.GetString(r.GetOrdinal("TipoRegistro")),
            EsMovil = r.GetBoolean(r.GetOrdinal("EsMovil")),
            Observaciones = r.IsDBNull(r.GetOrdinal("Observaciones")) ? null : r.GetString(r.GetOrdinal("Observaciones")),
            UsuarioCreacion = r.GetString(r.GetOrdinal("UsuarioCreacion")),
            FechaCreacion = r.GetDateTime(r.GetOrdinal("FechaCreacion"))
        };

        // Resultset 2: estudios de la cita.
        if (await r.NextResultAsync(ct))
        {
            while (await r.ReadAsync(ct))
            {
                detail.Estudios.Add(new AppointmentDetailItem
                {
                    IdDetalleCita = r.GetInt32(r.GetOrdinal("IdDetalleCita")),
                    IdPrueba = r.GetString(r.GetOrdinal("IdPrueba")),
                    NombrePrueba = r.GetString(r.GetOrdinal("NombrePrueba")),
                    NombreCategoria = r.GetString(r.GetOrdinal("NombreCategoria")),
                    IdTecnico = r.IsDBNull(r.GetOrdinal("IdTecnico")) ? null : r.GetString(r.GetOrdinal("IdTecnico")),
                    Tecnico = r.IsDBNull(r.GetOrdinal("Tecnico")) ? null : r.GetString(r.GetOrdinal("Tecnico")),
                    Estado = r.GetString(r.GetOrdinal("Estado")),
                    PartesCuerpoTexto = r.IsDBNull(r.GetOrdinal("PartesCuerpo"))
                        ? ""
                        : r.GetString(r.GetOrdinal("PartesCuerpo")),
                    IdInforme = r.IsDBNull(r.GetOrdinal("IdInforme"))
                        ? null
                        : r.GetInt32(r.GetOrdinal("IdInforme")),
                    EstadoInforme = r.IsDBNull(r.GetOrdinal("EstadoInforme"))
                        ? null
                        : r.GetString(r.GetOrdinal("EstadoInforme")),
                    NumeroVersionInforme = r.IsDBNull(r.GetOrdinal("NumeroVersionInforme"))
                        ? null
                        : r.GetInt32(r.GetOrdinal("NumeroVersionInforme"))
                });
            }
        }

        // Resultset 3: partes del cuerpo asociadas a cada IdDetalleCita.
        if (await r.NextResultAsync(ct))
        {
            while (await r.ReadAsync(ct))
            {
                var idDetalle = r.GetInt32(r.GetOrdinal("IdDetalleCita"));
                var study = detail.Estudios.FirstOrDefault(x => x.IdDetalleCita == idDetalle);
                if (study is null) continue;

                study.PartesCuerpo.Add(new BodyPartItem
                {
                    IdParteCuerpo = r.GetString(r.GetOrdinal("IdParteCuerpo")),
                    NombreParte = r.GetString(r.GetOrdinal("NombreParte"))
                });
            }
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
        if (string.Equals(status, "ATENDIDA", StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException(
                "Para marcar una cita como atendida debe seleccionar los estudios realizados.");

        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Cita_CambiarEstado", cn)
        { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.Add("@IdCita", SqlDbType.Int).Value = idCita;
        cmd.Parameters.Add("@Estado", SqlDbType.VarChar, 20).Value = status;
        cmd.Parameters.Add("@IdUsuario", SqlDbType.VarChar, 30).Value = userId;

        await cn.OpenAsync(ct);
        try
        {
            await cmd.ExecuteNonQueryAsync(ct);
        }
        catch (SqlException ex) when (ex.Number >= 50000)
        {
            throw new InvalidOperationException(ex.Message);
        }
    }

    public async Task MarkAttendedAsync(
        int idCita,
        IReadOnlyCollection<int> performedDetailIds,
        string userId,
        CancellationToken ct = default)
    {
        var tvp = new DataTable();
        tvp.Columns.Add("IdDetalleCita", typeof(int));

        foreach (var id in performedDetailIds.Distinct())
            tvp.Rows.Add(id);

        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Cita_MarcarAtendida", cn)
        { CommandType = CommandType.StoredProcedure };

        cmd.Parameters.Add("@IdCita", SqlDbType.Int).Value = idCita;
        cmd.Parameters.Add("@IdUsuario", SqlDbType.VarChar, 30).Value = userId;

        var p = cmd.Parameters.AddWithValue("@EstudiosRealizados", tvp);
        p.SqlDbType = SqlDbType.Structured;
        p.TypeName = "dbo.TVP_DetalleCitaRealizado";

        await cn.OpenAsync(ct);
        try
        {
            await cmd.ExecuteNonQueryAsync(ct);
        }
        catch (SqlException ex) when (ex.Number >= 50000)
        {
            throw new InvalidOperationException(ex.Message);
        }
    }

    public async Task ChangeStudyPerformedStatusAsync(
        int idDetalleCita,
        string newStatus,
        string userId,
        string? observation = null,
        CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_DetalleCita_CambiarRealizacion", cn)
        { CommandType = CommandType.StoredProcedure };

        cmd.Parameters.Add("@IdDetalleCita", SqlDbType.Int).Value = idDetalleCita;
        cmd.Parameters.Add("@NuevoEstado", SqlDbType.VarChar, 20).Value = newStatus;
        cmd.Parameters.Add("@IdUsuario", SqlDbType.VarChar, 30).Value = userId;
        cmd.Parameters.Add("@Observacion", SqlDbType.VarChar, 300).Value =
            (object?)observation ?? DBNull.Value;

        await cn.OpenAsync(ct);
        try
        {
            await cmd.ExecuteNonQueryAsync(ct);
        }
        catch (SqlException ex) when (ex.Number >= 50000)
        {
            throw new InvalidOperationException(ex.Message);
        }
    }

    private async Task<CreateAppointmentResult> ExecuteSaveAsync(
        string procedure, CreateAppointmentCommand request, int? idCita, CancellationToken ct)
    {
        var studiesTvp = new DataTable();
        studiesTvp.Columns.Add("IdPrueba", typeof(string));

        foreach (var id in request.Estudios
                     .Where(x => !string.IsNullOrWhiteSpace(x))
                     .Select(x => x.Trim())
                     .Distinct(StringComparer.OrdinalIgnoreCase))
        {
            studiesTvp.Rows.Add(id);
        }

        var bodyPartsTvp = new DataTable();
        bodyPartsTvp.Columns.Add("IdPrueba", typeof(string));
        bodyPartsTvp.Columns.Add("IdParteCuerpo", typeof(string));

        var uniqueRelations = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var relation in request.EstudioPartes)
        {
            var idPrueba = relation.IdPrueba?.Trim();
            var idParte = relation.IdParteCuerpo?.Trim();

            if (string.IsNullOrWhiteSpace(idPrueba) || string.IsNullOrWhiteSpace(idParte))
                continue;

            var key = $"{idPrueba}\u001F{idParte}";
            if (uniqueRelations.Add(key))
                bodyPartsTvp.Rows.Add(idPrueba, idParte);
        }

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
        cmd.Parameters.Add("@TipoRegistro", SqlDbType.VarChar, 20).Value =
            string.IsNullOrWhiteSpace(request.TipoRegistro)
                ? "CITA"
                : request.TipoRegistro.Trim().ToUpperInvariant();
        cmd.Parameters.Add("@EsMovil", SqlDbType.Bit).Value = request.EsMovil;

        var studiesParameter = cmd.Parameters.AddWithValue("@Estudios", studiesTvp);
        studiesParameter.SqlDbType = SqlDbType.Structured;
        studiesParameter.TypeName = "dbo.TVP_EstudioCita";

        var bodyPartsParameter = cmd.Parameters.AddWithValue("@EstudioPartes", bodyPartsTvp);
        bodyPartsParameter.SqlDbType = SqlDbType.Structured;
        bodyPartsParameter.TypeName = "dbo.TVP_EstudioParteCuerpo";

        await cn.OpenAsync(ct);

        try
        {
            await using var r = await cmd.ExecuteReaderAsync(ct);
            if (!await r.ReadAsync(ct))
                throw new InvalidOperationException("No se obtuvo respuesta al guardar la solicitud.");

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

    public async Task<StudyReportContext?> GetStudyReportAsync(
        int idDetalleCita,
        CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_InformeEstudio_Obtener", cn)
        { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.Add("@IdDetalleCita", SqlDbType.Int).Value = idDetalleCita;

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);

        if (!await r.ReadAsync(ct))
            return null;

        var context = new StudyReportContext
        {
            IdDetalleCita = r.GetInt32(r.GetOrdinal("IdDetalleCita")),
            IdCita = r.GetInt32(r.GetOrdinal("IdCita")),
            NumeroCita = r.GetString(r.GetOrdinal("NumeroCita")),
            EstadoCita = r.GetString(r.GetOrdinal("EstadoCita")),
            FechaCita = r.GetDateTime(r.GetOrdinal("FechaCita")),
            HoraCita = r.GetTimeSpan(r.GetOrdinal("HoraCita")),
            IdPaciente = r.GetString(r.GetOrdinal("IdPaciente")),
            Paciente = r.GetString(r.GetOrdinal("Paciente")),
            IdPrueba = r.GetString(r.GetOrdinal("IdPrueba")),
            NombrePrueba = r.GetString(r.GetOrdinal("NombrePrueba")),
            NombreCategoria = r.GetString(r.GetOrdinal("NombreCategoria")),
            EstadoEstudio = r.GetString(r.GetOrdinal("EstadoEstudio")),
            PartesCuerpo = r.IsDBNull(r.GetOrdinal("PartesCuerpo")) ? "" : r.GetString(r.GetOrdinal("PartesCuerpo")),
            IdInforme = r.IsDBNull(r.GetOrdinal("IdInforme")) ? null : r.GetInt32(r.GetOrdinal("IdInforme")),
            IdInternoRadiologia = DbNullableString(r, "IdInternoRadiologia"),
            Hallazgos = DbNullableString(r, "Hallazgos"),
            Conclusiones = DbNullableString(r, "Conclusiones"),
            IdTecnicoRealiza = DbNullableString(r, "IdTecnicoRealiza"),
            IdTecnicoPosiciona = DbNullableString(r, "IdTecnicoPosiciona"),
            IdMedicoInformante = DbNullableString(r, "IdMedicoInformante"),
            FechaHoraInforme = DbNullableDateTime(r, "FechaHoraInforme"),
            EstadoInforme = DbNullableString(r, "EstadoInforme"),
            NumeroVersion = r.IsDBNull(r.GetOrdinal("NumeroVersion")) ? 1 : r.GetInt32(r.GetOrdinal("NumeroVersion")),
            FechaFinalizacion = DbNullableDateTime(r, "FechaFinalizacion"),
            FechaCreacionInforme = DbNullableDateTime(r, "FechaCreacion"),
            FechaModificacionInforme = DbNullableDateTime(r, "FechaModificacion")
        };

        if (await r.NextResultAsync(ct))
        {
            while (await r.ReadAsync(ct))
            {
                context.Recursos.Add(new StudyReportResource
                {
                    TamanoPelicula = r.GetString(r.GetOrdinal("TamanoPelicula")),
                    PeliculasEntregadas = r.GetInt32(r.GetOrdinal("PeliculasEntregadas")),
                    ImagenesDigitales = r.GetInt32(r.GetOrdinal("ImagenesDigitales")),
                    SistemaAdquisicionCDDR = DbNullableString(r, "SistemaAdquisicionCDDR")
                });
            }
        }

        return context;
    }

    public async Task<List<TechnicianItem>> GetActiveTechniciansAsync(CancellationToken ct = default)
    {
        var result = new List<TechnicianItem>();
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Tecnico_ListarActivos", cn)
        { CommandType = CommandType.StoredProcedure };

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            result.Add(new TechnicianItem
            {
                IdTecnico = r.GetString(r.GetOrdinal("IdTecnico")),
                NombreCompleto = r.GetString(r.GetOrdinal("NombreCompleto"))
            });
        }

        return result;
    }

    public async Task<List<InformingDoctorItem>> GetActiveInformingDoctorsAsync(CancellationToken ct = default)
    {
        var result = new List<InformingDoctorItem>();
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_MedicoInformante_ListarActivos", cn)
        { CommandType = CommandType.StoredProcedure };

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            result.Add(new InformingDoctorItem
            {
                IdMedicoInformante = r.GetString(r.GetOrdinal("IdMedicoInformante")),
                NombreCompleto = $"{r.GetString(r.GetOrdinal("Nombres"))} {r.GetString(r.GetOrdinal("Apellidos"))}",
                Puesto = DbNullableString(r, "Puesto"),
                NoColegiado = DbNullableString(r, "NoColegiado")
            });
        }

        return result;
    }

    public async Task<StudyReportSaveResult> SaveStudyReportAsync(
        StudyReportInput input,
        string userId,
        bool finalize,
        CancellationToken ct = default)
    {
        var resources = new DataTable();
        resources.Columns.Add("TamanoPelicula", typeof(string));
        resources.Columns.Add("PeliculasEntregadas", typeof(int));
        resources.Columns.Add("ImagenesDigitales", typeof(int));
        resources.Columns.Add("SistemaAdquisicionCDDR", typeof(string));

        foreach (var size in new[] { "8x10", "10x14", "14x17" })
        {
            var item = input.Recursos.FirstOrDefault(x =>
                string.Equals(x.TamanoPelicula, size, StringComparison.OrdinalIgnoreCase));

            resources.Rows.Add(
                size,
                item?.PeliculasEntregadas ?? 0,
                item?.ImagenesDigitales ?? 0,
                string.IsNullOrWhiteSpace(item?.SistemaAdquisicionCDDR)
                    ? DBNull.Value
                    : item!.SistemaAdquisicionCDDR!.Trim());
        }

        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_InformeEstudio_Guardar", cn)
        { CommandType = CommandType.StoredProcedure };

        cmd.Parameters.Add("@IdDetalleCita", SqlDbType.Int).Value = input.IdDetalleCita;
        cmd.Parameters.Add("@IdInternoRadiologia", SqlDbType.VarChar, 50).Value = DbValue(input.IdInternoRadiologia);
        cmd.Parameters.Add("@Hallazgos", SqlDbType.NVarChar, -1).Value = DbValue(input.Hallazgos);
        cmd.Parameters.Add("@Conclusiones", SqlDbType.NVarChar, -1).Value = DbValue(input.Conclusiones);
        cmd.Parameters.Add("@IdTecnicoRealiza", SqlDbType.VarChar, 30).Value = DbValue(input.IdTecnicoRealiza);
        cmd.Parameters.Add("@IdTecnicoPosiciona", SqlDbType.VarChar, 30).Value = DbValue(input.IdTecnicoPosiciona);
        cmd.Parameters.Add("@IdMedicoInformante", SqlDbType.VarChar, 30).Value = DbValue(input.IdMedicoInformante);
        cmd.Parameters.Add("@FechaHoraInforme", SqlDbType.DateTime2).Value = (object?)input.FechaHoraInforme ?? DBNull.Value;
        cmd.Parameters.Add("@IdUsuario", SqlDbType.VarChar, 30).Value = userId;
        cmd.Parameters.Add("@Finalizar", SqlDbType.Bit).Value = finalize;

        var p = cmd.Parameters.AddWithValue("@Recursos", resources);
        p.SqlDbType = SqlDbType.Structured;
        p.TypeName = "dbo.TVP_InformeRecurso";

        await cn.OpenAsync(ct);
        try
        {
            await using var r = await cmd.ExecuteReaderAsync(ct);
            if (!await r.ReadAsync(ct))
                throw new InvalidOperationException("No se obtuvo respuesta al guardar el informe.");

            return new StudyReportSaveResult
            {
                IdInforme = r.GetInt32(r.GetOrdinal("IdInforme")),
                Estado = r.GetString(r.GetOrdinal("Estado")),
                NumeroVersion = r.GetInt32(r.GetOrdinal("NumeroVersion")),
                FechaFinalizacion = DbNullableDateTime(r, "FechaFinalizacion")
            };
        }
        catch (SqlException ex) when (ex.Number >= 50000)
        {
            throw new InvalidOperationException(ex.Message);
        }
    }

    public async Task StartStudyReportCorrectionAsync(
        int idDetalleCita,
        string userId,
        CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_InformeEstudio_IniciarCorreccion", cn)
        { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.Add("@IdDetalleCita", SqlDbType.Int).Value = idDetalleCita;
        cmd.Parameters.Add("@IdUsuario", SqlDbType.VarChar, 30).Value = userId;

        await cn.OpenAsync(ct);
        try
        {
            await cmd.ExecuteNonQueryAsync(ct);
        }
        catch (SqlException ex) when (ex.Number >= 50000)
        {
            throw new InvalidOperationException(ex.Message);
        }
    }


    public async Task<List<StudyReportHistoryItem>> GetStudyReportHistoryAsync(
        int idDetalleCita,
        CancellationToken ct = default)
    {
        var result = new List<StudyReportHistoryItem>();

        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_InformeEstudio_Historial_Listar", cn)
        { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.Add("@IdDetalleCita", SqlDbType.Int).Value = idDetalleCita;

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);

        while (await r.ReadAsync(ct))
        {
            result.Add(new StudyReportHistoryItem
            {
                IdInformeHistorial = r.GetInt32(r.GetOrdinal("IdInformeHistorial")),
                IdInforme = r.GetInt32(r.GetOrdinal("IdInforme")),
                IdDetalleCita = r.GetInt32(r.GetOrdinal("IdDetalleCita")),
                NumeroVersion = r.GetInt32(r.GetOrdinal("NumeroVersion")),
                Estado = r.GetString(r.GetOrdinal("Estado")),
                IdInternoRadiologia = DbNullableString(r, "IdInternoRadiologia"),
                FechaHoraInforme = DbNullableDateTime(r, "FechaHoraInforme"),
                FechaFinalizacion = DbNullableDateTime(r, "FechaFinalizacion"),
                FechaArchivado = r.GetDateTime(r.GetOrdinal("FechaArchivado")),
                ArchivadoPor = r.GetString(r.GetOrdinal("ArchivadoPor")),
                MotivoArchivado = DbNullableString(r, "MotivoArchivado")
            });
        }

        return result;
    }

    public async Task<StudyReportHistoryContext?> GetStudyReportHistoryVersionAsync(
        int idInformeHistorial,
        CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_InformeEstudio_Historial_Obtener", cn)
        { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.Add("@IdInformeHistorial", SqlDbType.Int).Value = idInformeHistorial;

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);

        if (!await r.ReadAsync(ct))
            return null;

        var item = new StudyReportHistoryContext
        {
            IdInformeHistorial = r.GetInt32(r.GetOrdinal("IdInformeHistorial")),
            IdInforme = r.GetInt32(r.GetOrdinal("IdInforme")),
            IdDetalleCita = r.GetInt32(r.GetOrdinal("IdDetalleCita")),
            NumeroVersion = r.GetInt32(r.GetOrdinal("NumeroVersion")),
            EstadoInforme = r.GetString(r.GetOrdinal("EstadoInforme")),
            IdInternoRadiologia = DbNullableString(r, "IdInternoRadiologia"),
            Hallazgos = DbNullableString(r, "Hallazgos"),
            Conclusiones = DbNullableString(r, "Conclusiones"),
            FechaHoraInforme = DbNullableDateTime(r, "FechaHoraInforme"),
            FechaFinalizacion = DbNullableDateTime(r, "FechaFinalizacion"),
            FechaArchivado = r.GetDateTime(r.GetOrdinal("FechaArchivado")),
            ArchivadoPor = r.GetString(r.GetOrdinal("ArchivadoPor")),
            MotivoArchivado = DbNullableString(r, "MotivoArchivado"),
            IdCita = r.GetInt32(r.GetOrdinal("IdCita")),
            NumeroCita = r.GetString(r.GetOrdinal("NumeroCita")),
            FechaCita = r.GetDateTime(r.GetOrdinal("FechaCita")),
            HoraCita = r.GetTimeSpan(r.GetOrdinal("HoraCita")),
            IdPaciente = r.GetString(r.GetOrdinal("IdPaciente")),
            Paciente = r.GetString(r.GetOrdinal("Paciente")),
            IdPrueba = r.GetString(r.GetOrdinal("IdPrueba")),
            NombrePrueba = r.GetString(r.GetOrdinal("NombrePrueba")),
            NombreCategoria = r.GetString(r.GetOrdinal("NombreCategoria")),
            EstadoEstudio = r.GetString(r.GetOrdinal("EstadoEstudio")),
            PartesCuerpo = r.IsDBNull(r.GetOrdinal("PartesCuerpo"))
                ? ""
                : r.GetString(r.GetOrdinal("PartesCuerpo")),
            TecnicoRealiza = DbNullableString(r, "TecnicoRealiza"),
            TecnicoPosiciona = DbNullableString(r, "TecnicoPosiciona"),
            MedicoInformante = DbNullableString(r, "MedicoInformante"),
            NoColegiadoInformante = DbNullableString(r, "NoColegiadoInformante")
        };

        if (await r.NextResultAsync(ct))
        {
            while (await r.ReadAsync(ct))
            {
                item.Recursos.Add(new StudyReportResource
                {
                    TamanoPelicula = r.GetString(r.GetOrdinal("TamanoPelicula")),
                    PeliculasEntregadas = r.GetInt32(r.GetOrdinal("PeliculasEntregadas")),
                    ImagenesDigitales = r.GetInt32(r.GetOrdinal("ImagenesDigitales")),
                    SistemaAdquisicionCDDR = DbNullableString(r, "SistemaAdquisicionCDDR")
                });
            }
        }

        return item;
    }

    public async Task<StudyReportPrintData?> GetStudyReportPrintAsync(
        int idDetalleCita,
        CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_InformeEstudio_Impresion", cn)
        { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.Add("@IdDetalleCita", SqlDbType.Int).Value = idDetalleCita;

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);

        if (!await r.ReadAsync(ct))
            return null;

        var item = new StudyReportPrintData
        {
            IdInforme = r.GetInt32(r.GetOrdinal("IdInforme")),
            IdDetalleCita = r.GetInt32(r.GetOrdinal("IdDetalleCita")),
            NumeroVersion = r.GetInt32(r.GetOrdinal("NumeroVersion")),
            IdInternoRadiologia = r.GetString(r.GetOrdinal("IdInternoRadiologia")),
            Hallazgos = r.GetString(r.GetOrdinal("Hallazgos")),
            Conclusiones = r.GetString(r.GetOrdinal("Conclusiones")),
            FechaHoraInforme = r.GetDateTime(r.GetOrdinal("FechaHoraInforme")),
            FechaFinalizacion = DbNullableDateTime(r, "FechaFinalizacion"),
            IdCita = r.GetInt32(r.GetOrdinal("IdCita")),
            NumeroCita = r.GetString(r.GetOrdinal("NumeroCita")),
            FechaCita = r.GetDateTime(r.GetOrdinal("FechaCita")),
            HoraCita = r.GetTimeSpan(r.GetOrdinal("HoraCita")),
            IdPaciente = r.GetString(r.GetOrdinal("IdPaciente")),
            Paciente = r.GetString(r.GetOrdinal("Paciente")),
            MedicoSolicitante = r.GetString(r.GetOrdinal("MedicoSolicitante")),
            Servicio = r.GetString(r.GetOrdinal("Servicio")),
            IdPrueba = r.GetString(r.GetOrdinal("IdPrueba")),
            NombrePrueba = r.GetString(r.GetOrdinal("NombrePrueba")),
            NombreCategoria = r.GetString(r.GetOrdinal("NombreCategoria")),
            PartesCuerpo = r.IsDBNull(r.GetOrdinal("PartesCuerpo"))
                ? ""
                : r.GetString(r.GetOrdinal("PartesCuerpo")),
            TecnicoRealiza = r.GetString(r.GetOrdinal("TecnicoRealiza")),
            TecnicoPosiciona = r.GetString(r.GetOrdinal("TecnicoPosiciona")),
            MedicoInformante = r.GetString(r.GetOrdinal("MedicoInformante")),
            PuestoMedicoInformante = DbNullableString(r, "PuestoMedicoInformante"),
            NoColegiadoInformante = DbNullableString(r, "NoColegiadoInformante")
        };

        if (await r.NextResultAsync(ct))
        {
            while (await r.ReadAsync(ct))
            {
                item.Recursos.Add(new StudyReportResource
                {
                    TamanoPelicula = r.GetString(r.GetOrdinal("TamanoPelicula")),
                    PeliculasEntregadas = r.GetInt32(r.GetOrdinal("PeliculasEntregadas")),
                    ImagenesDigitales = r.GetInt32(r.GetOrdinal("ImagenesDigitales")),
                    SistemaAdquisicionCDDR = DbNullableString(r, "SistemaAdquisicionCDDR")
                });
            }
        }

        return item;
    }

    public async Task<ReportHeaderConfiguration?> GetReportHeaderConfigurationAsync(
        CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_ConfigInformes_Obtener", cn)
        { CommandType = CommandType.StoredProcedure };

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);

        if (!await r.ReadAsync(ct))
            return null;

        return new ReportHeaderConfiguration
        {
            EncabezadoImagen = r.IsDBNull(r.GetOrdinal("EncabezadoImagen"))
                ? null
                : (byte[])r["EncabezadoImagen"],
            EncabezadoNombreArchivo = DbNullableString(r, "EncabezadoNombreArchivo"),
            EncabezadoTipoMime = DbNullableString(r, "EncabezadoTipoMime"),
            IdUsuarioModificacion = DbNullableString(r, "IdUsuarioModificacion"),
            FechaModificacion = r.GetDateTime(r.GetOrdinal("FechaModificacion"))
        };
    }

    public async Task SaveReportHeaderAsync(
        byte[] image,
        string fileName,
        string mimeType,
        string userId,
        CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_ConfigInformes_GuardarEncabezado", cn)
        { CommandType = CommandType.StoredProcedure };

        cmd.Parameters.Add("@EncabezadoImagen", SqlDbType.VarBinary, -1).Value = image;
        cmd.Parameters.Add("@EncabezadoNombreArchivo", SqlDbType.VarChar, 255).Value = fileName;
        cmd.Parameters.Add("@EncabezadoTipoMime", SqlDbType.VarChar, 100).Value = mimeType;
        cmd.Parameters.Add("@IdUsuarioModificacion", SqlDbType.VarChar, 30).Value = userId;

        await cn.OpenAsync(ct);

        try
        {
            await cmd.ExecuteNonQueryAsync(ct);
        }
        catch (SqlException ex) when (ex.Number >= 50000)
        {
            throw new InvalidOperationException(ex.Message);
        }
    }

    public async Task DeleteReportHeaderAsync(
        string userId,
        CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_ConfigInformes_EliminarEncabezado", cn)
        { CommandType = CommandType.StoredProcedure };

        cmd.Parameters.Add("@IdUsuarioModificacion", SqlDbType.VarChar, 30).Value = userId;

        await cn.OpenAsync(ct);

        try
        {
            await cmd.ExecuteNonQueryAsync(ct);
        }
        catch (SqlException ex) when (ex.Number >= 50000)
        {
            throw new InvalidOperationException(ex.Message);
        }
    }


    public async Task<List<InventoryStudyRow>> ListInventoryStudiesAsync(
        string? internalRadiologyId,
        string? patientId,
        string? patientName,
        string? studyCode,
        string? studyName,
        DateTime? from,
        DateTime? to,
        string? reportStatus,
        CancellationToken ct = default)
    {
        var result = new List<InventoryStudyRow>();

        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Inventario_Estudios_Listar", cn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.Add("@IdInternoRadiologia", SqlDbType.VarChar, 50).Value =
            DbValue(internalRadiologyId);
        cmd.Parameters.Add("@IdPaciente", SqlDbType.VarChar, 30).Value =
            DbValue(patientId);
        cmd.Parameters.Add("@Paciente", SqlDbType.VarChar, 150).Value =
            DbValue(patientName);
        cmd.Parameters.Add("@IdPrueba", SqlDbType.VarChar, 30).Value =
            DbValue(studyCode);
        cmd.Parameters.Add("@NombrePrueba", SqlDbType.VarChar, 150).Value =
            DbValue(studyName);
        cmd.Parameters.Add("@FechaInicio", SqlDbType.Date).Value =
            (object?)from?.Date ?? DBNull.Value;
        cmd.Parameters.Add("@FechaFin", SqlDbType.Date).Value =
            (object?)to?.Date ?? DBNull.Value;
        cmd.Parameters.Add("@EstadoInforme", SqlDbType.VarChar, 20).Value =
            DbValue(reportStatus);

        await cn.OpenAsync(ct);

        try
        {
            await using var r = await cmd.ExecuteReaderAsync(ct);

            while (await r.ReadAsync(ct))
            {
                result.Add(new InventoryStudyRow
                {
                    IdDetalleCita = r.GetInt32(r.GetOrdinal("IdDetalleCita")),
                    IdCita = r.GetInt32(r.GetOrdinal("IdCita")),
                    NumeroCita = r.GetString(r.GetOrdinal("NumeroCita")),
                    FechaRealizacion = r.GetDateTime(r.GetOrdinal("FechaRealizacion")),
                    IdPaciente = r.GetString(r.GetOrdinal("IdPaciente")),
                    Paciente = r.GetString(r.GetOrdinal("Paciente")),
                    IdPrueba = r.GetString(r.GetOrdinal("IdPrueba")),
                    NombrePrueba = r.GetString(r.GetOrdinal("NombrePrueba")),
                    NombreCategoria = r.GetString(r.GetOrdinal("NombreCategoria")),
                    PartesCuerpo = r.IsDBNull(r.GetOrdinal("PartesCuerpo"))
                        ? ""
                        : r.GetString(r.GetOrdinal("PartesCuerpo")),
                    IdInforme = r.IsDBNull(r.GetOrdinal("IdInforme"))
                        ? null
                        : r.GetInt32(r.GetOrdinal("IdInforme")),
                    IdInternoRadiologia = DbNullableString(r, "IdInternoRadiologia"),
                    EstadoInforme = r.GetString(r.GetOrdinal("EstadoInforme")),
                    NumeroVersion = r.GetInt32(r.GetOrdinal("NumeroVersion")),
                    IdPrestamoActivo = r.IsDBNull(r.GetOrdinal("IdPrestamoActivo"))
                        ? null
                        : r.GetInt32(r.GetOrdinal("IdPrestamoActivo")),
                    FechaHoraPrestamo = DbNullableDateTime(r, "FechaHoraPrestamo"),
                    IdPrestatarioActivo = DbNullableString(r, "IdPrestatarioActivo"),
                    PrestatarioActivo = DbNullableString(r, "PrestatarioActivo")
                });
            }
        }
        catch (SqlException ex) when (ex.Number >= 50000)
        {
            throw new InvalidOperationException(ex.Message);
        }

        return result;
    }

    public async Task<InventoryStudyDetail?> GetInventoryStudyAsync(
        int idDetalleCita,
        CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Inventario_Estudio_Obtener", cn)
        {
            CommandType = CommandType.StoredProcedure
        };

        cmd.Parameters.Add("@IdDetalleCita", SqlDbType.Int).Value = idDetalleCita;

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);

        if (!await r.ReadAsync(ct))
            return null;

        var detail = new InventoryStudyDetail
        {
            IdDetalleCita = r.GetInt32(r.GetOrdinal("IdDetalleCita")),
            IdCita = r.GetInt32(r.GetOrdinal("IdCita")),
            NumeroCita = r.GetString(r.GetOrdinal("NumeroCita")),
            FechaRealizacion = r.GetDateTime(r.GetOrdinal("FechaRealizacion")),

            IdPaciente = r.GetString(r.GetOrdinal("IdPaciente")),
            Paciente = r.GetString(r.GetOrdinal("Paciente")),

            IdServicio = r.GetString(r.GetOrdinal("IdServicio")),
            Servicio = r.GetString(r.GetOrdinal("Servicio")),
            IdMedicoSolicitante = r.GetString(r.GetOrdinal("IdMedicoSolicitante")),
            MedicoSolicitante = r.GetString(r.GetOrdinal("MedicoSolicitante")),
            ObservacionesCita = DbNullableString(r, "ObservacionesCita"),

            IdPrueba = r.GetString(r.GetOrdinal("IdPrueba")),
            NombrePrueba = r.GetString(r.GetOrdinal("NombrePrueba")),
            NombreCategoria = r.GetString(r.GetOrdinal("NombreCategoria")),
            PartesCuerpo = r.IsDBNull(r.GetOrdinal("PartesCuerpo"))
                ? ""
                : r.GetString(r.GetOrdinal("PartesCuerpo")),
            ObservacionesEstudio = DbNullableString(r, "ObservacionesEstudio"),

            IdInforme = r.IsDBNull(r.GetOrdinal("IdInforme"))
                ? null
                : r.GetInt32(r.GetOrdinal("IdInforme")),
            IdInternoRadiologia = DbNullableString(r, "IdInternoRadiologia"),
            EstadoInforme = r.GetString(r.GetOrdinal("EstadoInforme")),
            NumeroVersion = r.GetInt32(r.GetOrdinal("NumeroVersion")),

            Hallazgos = DbNullableString(r, "Hallazgos"),
            Conclusiones = DbNullableString(r, "Conclusiones"),
            FechaHoraInforme = DbNullableDateTime(r, "FechaHoraInforme"),
            FechaFinalizacion = DbNullableDateTime(r, "FechaFinalizacion"),

            IdTecnicoRealiza = DbNullableString(r, "IdTecnicoRealiza"),
            TecnicoRealiza = DbNullableString(r, "TecnicoRealiza"),
            IdTecnicoPosiciona = DbNullableString(r, "IdTecnicoPosiciona"),
            TecnicoPosiciona = DbNullableString(r, "TecnicoPosiciona"),

            IdMedicoInformante = DbNullableString(r, "IdMedicoInformante"),
            MedicoInformante = DbNullableString(r, "MedicoInformante"),
            PuestoMedicoInformante = DbNullableString(r, "PuestoMedicoInformante")
        };

        if (await r.NextResultAsync(ct))
        {
            while (await r.ReadAsync(ct))
            {
                detail.Recursos.Add(new InventoryResourceRow
                {
                    TamanoPelicula = r.GetString(r.GetOrdinal("TamanoPelicula")),
                    PeliculasEntregadas = r.GetInt32(r.GetOrdinal("PeliculasEntregadas")),
                    ImagenesDigitales = r.GetInt32(r.GetOrdinal("ImagenesDigitales")),
                    SistemaAdquisicionCDDR =
                        DbNullableString(r, "SistemaAdquisicionCDDR")
                });
            }
        }

        return detail;
    }

    private static object DbValue(string? value) =>
        string.IsNullOrWhiteSpace(value) ? DBNull.Value : value.Trim();

    private static string? DbNullableString(SqlDataReader r, string name)
    {
        var ordinal = r.GetOrdinal(name);
        return r.IsDBNull(ordinal) ? null : r.GetString(ordinal);
    }

    private static DateTime? DbNullableDateTime(SqlDataReader r, string name)
    {
        var ordinal = r.GetOrdinal(name);
        return r.IsDBNull(ordinal) ? null : r.GetDateTime(ordinal);
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
