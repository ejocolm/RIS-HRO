using System.Data;

using Microsoft.Data.SqlClient;

using RIS_HRO.Data;
using RIS_HRO.Models;


namespace RIS_HRO.Repositories;


public sealed class LoanRepository
{
    private readonly SqlConnectionFactory _factory;


    public LoanRepository(
        SqlConnectionFactory factory)
    {
        _factory = factory;
    }


    /* ========================================================================
       PRESTATARIOS
       ======================================================================== */

    public async Task<List<BorrowerRow>> ListBorrowersAsync(
        string? text,
        CancellationToken ct = default)
    {
        var result = new List<BorrowerRow>();


        await using var cn =
            _factory.Create();


        await using var cmd =
            new SqlCommand
            (
                "dbo.sp_Prestatario_Listar",
                cn
            )
            {
                CommandType =
                    CommandType.StoredProcedure
            };


        cmd.Parameters
            .Add
            (
                "@Texto",
                SqlDbType.VarChar,
                150
            )
            .Value = DbValue(text);


        await cn.OpenAsync(ct);


        await using var r =
            await cmd.ExecuteReaderAsync(ct);


        while (await r.ReadAsync(ct))
        {
            result.Add
            (
                ReadBorrower(r)
            );
        }


        return result;
    }


    public async Task<BorrowerRow?> GetBorrowerAsync(
        string idPrestatario,
        CancellationToken ct = default)
    {
        await using var cn =
            _factory.Create();


        await using var cmd =
            new SqlCommand
            (
                "dbo.sp_Prestatario_Obtener",
                cn
            )
            {
                CommandType =
                    CommandType.StoredProcedure
            };


        cmd.Parameters
            .Add
            (
                "@IdPrestatario",
                SqlDbType.VarChar,
                30
            )
            .Value = idPrestatario.Trim();


        await cn.OpenAsync(ct);


        await using var r =
            await cmd.ExecuteReaderAsync(ct);


        return await r.ReadAsync(ct)
            ? ReadBorrower(r)
            : null;
    }


    public async Task SaveBorrowerAsync(
        BorrowerSaveCommand request,
        CancellationToken ct = default)
    {
        await using var cn =
            _factory.Create();


        await using var cmd =
            new SqlCommand
            (
                "dbo.sp_Prestatario_Guardar",
                cn
            )
            {
                CommandType =
                    CommandType.StoredProcedure
            };


        cmd.Parameters
            .Add
            (
                "@IdPrestatario",
                SqlDbType.VarChar,
                30
            )
            .Value =
            request.IdPrestatario.Trim();


        cmd.Parameters
            .Add
            (
                "@NombreCompleto",
                SqlDbType.VarChar,
                150
            )
            .Value =
            request.NombreCompleto.Trim();


        cmd.Parameters
            .Add
            (
                "@Telefono",
                SqlDbType.VarChar,
                20
            )
            .Value =
            DbValue(request.Telefono);


        cmd.Parameters
            .Add
            (
                "@Correo",
                SqlDbType.VarChar,
                100
            )
            .Value =
            DbValue(request.Correo);


        cmd.Parameters
            .Add
            (
                "@Direccion",
                SqlDbType.VarChar,
                250
            )
            .Value =
            DbValue(request.Direccion);


        cmd.Parameters
            .Add
            (
                "@Documento1NombreArchivo",
                SqlDbType.VarChar,
                255
            )
            .Value =
            DbValue
            (
                request.Documento1NombreArchivo
            );


        cmd.Parameters
            .Add
            (
                "@Documento1TipoMime",
                SqlDbType.VarChar,
                50
            )
            .Value =
            DbValue
            (
                request.Documento1TipoMime
            );


        cmd.Parameters
            .Add
            (
                "@Documento1Imagen",
                SqlDbType.VarBinary,
                -1
            )
            .Value =
            (object?)request.Documento1Imagen
            ?? DBNull.Value;


        cmd.Parameters
            .Add
            (
                "@Documento2NombreArchivo",
                SqlDbType.VarChar,
                255
            )
            .Value =
            DbValue
            (
                request.Documento2NombreArchivo
            );


        cmd.Parameters
            .Add
            (
                "@Documento2TipoMime",
                SqlDbType.VarChar,
                50
            )
            .Value =
            DbValue
            (
                request.Documento2TipoMime
            );


        cmd.Parameters
            .Add
            (
                "@Documento2Imagen",
                SqlDbType.VarBinary,
                -1
            )
            .Value =
            (object?)request.Documento2Imagen
            ?? DBNull.Value;


        cmd.Parameters
            .Add
            (
                "@EliminarDocumento2",
                SqlDbType.Bit
            )
            .Value =
            request.EliminarDocumento2;


        cmd.Parameters
            .Add
            (
                "@Activo",
                SqlDbType.Bit
            )
            .Value =
            request.Activo;


        await cn.OpenAsync(ct);


        try
        {
            await cmd.ExecuteNonQueryAsync(ct);
        }
        catch (SqlException ex)
            when (ex.Number >= 50000)
        {
            throw new InvalidOperationException(
                ex.Message
            );
        }
    }


    public async Task<BorrowerDocumentData?>
        GetBorrowerDocumentAsync(
            string idPrestatario,
            int number,
            CancellationToken ct = default)
    {
        await using var cn =
            _factory.Create();


        await using var cmd =
            new SqlCommand
            (
                "dbo.sp_Prestatario_Documento",
                cn
            )
            {
                CommandType =
                    CommandType.StoredProcedure
            };


        cmd.Parameters
            .Add
            (
                "@IdPrestatario",
                SqlDbType.VarChar,
                30
            )
            .Value =
            idPrestatario.Trim();


        cmd.Parameters
            .Add
            (
                "@Numero",
                SqlDbType.TinyInt
            )
            .Value =
            number;


        await cn.OpenAsync(ct);


        try
        {
            await using var r =
                await cmd.ExecuteReaderAsync(ct);


            if (!await r.ReadAsync(ct))
            {
                return null;
            }


            return new BorrowerDocumentData
            {
                NombreArchivo =
                    r.GetString
                    (
                        r.GetOrdinal(
                            "NombreArchivo"
                        )
                    ),

                TipoMime =
                    r.GetString
                    (
                        r.GetOrdinal(
                            "TipoMime"
                        )
                    ),

                Imagen =
                    (byte[])r["Imagen"]
            };
        }
        catch (SqlException ex)
            when (ex.Number >= 50000)
        {
            throw new InvalidOperationException(
                ex.Message
            );
        }
    }



    /* ========================================================================
       CONTEXTO DE ESTUDIO
       ======================================================================== */

    public async Task<LoanStudyContext?>
        GetStudyContextAsync(
            int detailId,
            CancellationToken ct = default)
    {
        await using var cn =
            _factory.Create();


        await using var cmd =
            new SqlCommand
            (
                "dbo.sp_Prestamo_ContextoEstudio",
                cn
            )
            {
                CommandType =
                    CommandType.StoredProcedure
            };


        cmd.Parameters
            .Add
            (
                "@IdDetalleCita",
                SqlDbType.Int
            )
            .Value =
            detailId;


        await cn.OpenAsync(ct);


        await using var r =
            await cmd.ExecuteReaderAsync(ct);


        if (!await r.ReadAsync(ct))
        {
            return null;
        }


        return new LoanStudyContext
        {
            IdDetalleCita =
                r.GetInt32
                (
                    r.GetOrdinal(
                        "IdDetalleCita"
                    )
                ),

            IdCita =
                r.GetInt32
                (
                    r.GetOrdinal(
                        "IdCita"
                    )
                ),

            NumeroCita =
                r.GetString
                (
                    r.GetOrdinal(
                        "NumeroCita"
                    )
                ),

            IdPaciente =
                r.GetString
                (
                    r.GetOrdinal(
                        "IdPaciente"
                    )
                ),

            Paciente =
                r.GetString
                (
                    r.GetOrdinal(
                        "Paciente"
                    )
                ),

            IdPrueba =
                r.GetString
                (
                    r.GetOrdinal(
                        "IdPrueba"
                    )
                ),

            NombrePrueba =
                r.GetString
                (
                    r.GetOrdinal(
                        "NombrePrueba"
                    )
                ),

            NombreCategoria =
                r.GetString
                (
                    r.GetOrdinal(
                        "NombreCategoria"
                    )
                ),

            PartesCuerpo =
                NullableString(
                    r,
                    "PartesCuerpo"
                )
                ?? "",

            IdInternoRadiologia =
                NullableString
                (
                    r,
                    "IdInternoRadiologia"
                ),

            IdPrestamoActivo =
                NullableInt
                (
                    r,
                    "IdPrestamoActivo"
                ),

            FechaHoraPrestamo =
                NullableDateTime
                (
                    r,
                    "FechaHoraPrestamo"
                ),

            IdPrestatarioActivo =
                NullableString
                (
                    r,
                    "IdPrestatarioActivo"
                ),

            PrestatarioActivo =
                NullableString
                (
                    r,
                    "PrestatarioActivo"
                )
        };
    }



    /* ========================================================================
       CREAR PRÉSTAMO
       ======================================================================== */

    public async Task<int> CreateLoanAsync(
        int detailId,
        string borrowerId,
        string reason,
        string? observations,
        string userId,
        CancellationToken ct = default)
    {
        await using var cn =
            _factory.Create();


        await using var cmd =
            new SqlCommand
            (
                "dbo.sp_Prestamo_Crear",
                cn
            )
            {
                CommandType =
                    CommandType.StoredProcedure
            };


        cmd.Parameters
            .Add
            (
                "@IdDetalleCita",
                SqlDbType.Int
            )
            .Value =
            detailId;


        cmd.Parameters
            .Add
            (
                "@IdPrestatario",
                SqlDbType.VarChar,
                30
            )
            .Value =
            borrowerId.Trim();


        cmd.Parameters
            .Add
            (
                "@MotivoPrestamo",
                SqlDbType.VarChar,
                250
            )
            .Value =
            reason.Trim();


        cmd.Parameters
            .Add
            (
                "@Observaciones",
                SqlDbType.VarChar,
                500
            )
            .Value =
            DbValue(observations);


        cmd.Parameters
            .Add
            (
                "@UsuarioPrestamo",
                SqlDbType.VarChar,
                30
            )
            .Value =
            userId;


        await cn.OpenAsync(ct);


        try
        {
            var value =
                await cmd.ExecuteScalarAsync(ct);


            return Convert.ToInt32(value);
        }
        catch (SqlException ex)
            when (ex.Number >= 50000)
        {
            throw new InvalidOperationException(
                ex.Message
            );
        }
    }



    /* ========================================================================
       DEVOLVER
       ======================================================================== */

    public async Task ReturnLoanAsync(
        int loanId,
        string? returnPersonId,
        string? returnPersonName,
        string? returnObservations,
        string userId,
        CancellationToken ct = default)
    {
        await using var cn =
            _factory.Create();


        await using var cmd =
            new SqlCommand
            (
                "dbo.sp_Prestamo_Devolver",
                cn
            )
            {
                CommandType =
                    CommandType.StoredProcedure
            };


        cmd.Parameters
            .Add
            (
                "@IdPrestamo",
                SqlDbType.Int
            )
            .Value =
            loanId;


        cmd.Parameters
            .Add
            (
                "@DocumentoIdentificacionDevuelve",
                SqlDbType.VarChar,
                30
            )
            .Value =
            DbValue(returnPersonId);


        cmd.Parameters
            .Add
            (
                "@NombrePersonaDevuelve",
                SqlDbType.VarChar,
                150
            )
            .Value =
            DbValue(returnPersonName);


        cmd.Parameters
            .Add
            (
                "@ObservacionesDevolucion",
                SqlDbType.VarChar,
                500
            )
            .Value =
            DbValue(returnObservations);


        cmd.Parameters
            .Add
            (
                "@UsuarioDevolucion",
                SqlDbType.VarChar,
                30
            )
            .Value =
            userId;


        await cn.OpenAsync(ct);


        try
        {
            await cmd.ExecuteNonQueryAsync(ct);
        }
        catch (SqlException ex)
            when (ex.Number >= 50000)
        {
            throw new InvalidOperationException(
                ex.Message
            );
        }
    }



    /* ========================================================================
       FASE 2
       HISTORIAL GENERAL DE PRÉSTAMOS
       ======================================================================== */

    public async Task<List<LoanHistoryRow>>
        ListLoansAsync(
            DateTime? from,
            DateTime? to,
            string? patientId,
            string? internalRadiologyId,
            string? status,
            CancellationToken ct = default)
    {
        var result =
            new List<LoanHistoryRow>();


        await using var cn =
            _factory.Create();


        await using var cmd =
            new SqlCommand
            (
                "dbo.sp_Prestamo_Listar",
                cn
            )
            {
                CommandType =
                    CommandType.StoredProcedure
            };


        cmd.Parameters
            .Add
            (
                "@FechaInicio",
                SqlDbType.Date
            )
            .Value =
            (object?)from?.Date
            ?? DBNull.Value;


        cmd.Parameters
            .Add
            (
                "@FechaFin",
                SqlDbType.Date
            )
            .Value =
            (object?)to?.Date
            ?? DBNull.Value;


        cmd.Parameters
            .Add
            (
                "@IdPaciente",
                SqlDbType.VarChar,
                30
            )
            .Value =
            DbValue(patientId);


        cmd.Parameters
            .Add
            (
                "@IdInternoRadiologia",
                SqlDbType.VarChar,
                50
            )
            .Value =
            DbValue(internalRadiologyId);


        cmd.Parameters
            .Add
            (
                "@Estado",
                SqlDbType.VarChar,
                20
            )
            .Value =
            DbValue(status);


        await cn.OpenAsync(ct);


        try
        {
            await using var r =
                await cmd.ExecuteReaderAsync(ct);


            while (await r.ReadAsync(ct))
            {
                result.Add
                (
                    new LoanHistoryRow
                    {
                        IdPrestamo =
                            r.GetInt32
                            (
                                r.GetOrdinal(
                                    "IdPrestamo"
                                )
                            ),

                        IdDetalleCita =
                            r.GetInt32
                            (
                                r.GetOrdinal(
                                    "IdDetalleCita"
                                )
                            ),

                        FechaHoraPrestamo =
                            r.GetDateTime
                            (
                                r.GetOrdinal(
                                    "FechaHoraPrestamo"
                                )
                            ),

                        FechaHoraDevolucion =
                            NullableDateTime
                            (
                                r,
                                "FechaHoraDevolucion"
                            ),

                        DiasPrestamo =
                            r.GetInt32
                            (
                                r.GetOrdinal(
                                    "DiasPrestamo"
                                )
                            ),

                        EstadoPrestamo =
                            r.GetString
                            (
                                r.GetOrdinal(
                                    "EstadoPrestamo"
                                )
                            ),

                        IdInternoRadiologia =
                            NullableString
                            (
                                r,
                                "IdInternoRadiologia"
                            ),

                        IdPaciente =
                            r.GetString
                            (
                                r.GetOrdinal(
                                    "IdPaciente"
                                )
                            ),

                        Paciente =
                            r.GetString
                            (
                                r.GetOrdinal(
                                    "Paciente"
                                )
                            ),

                        IdPrueba =
                            r.GetString
                            (
                                r.GetOrdinal(
                                    "IdPrueba"
                                )
                            ),

                        NombrePrueba =
                            r.GetString
                            (
                                r.GetOrdinal(
                                    "NombrePrueba"
                                )
                            ),

                        PartesCuerpo =
                            NullableString
                            (
                                r,
                                "PartesCuerpo"
                            )
                            ?? "",

                        IdPrestatario =
                            r.GetString
                            (
                                r.GetOrdinal(
                                    "IdPrestatario"
                                )
                            ),

                        Prestatario =
                            r.GetString
                            (
                                r.GetOrdinal(
                                    "Prestatario"
                                )
                            ),

                        TelefonoPrestatario =
                            NullableString
                            (
                                r,
                                "TelefonoPrestatario"
                            ),

                        MotivoPrestamo =
                            r.GetString
                            (
                                r.GetOrdinal(
                                    "MotivoPrestamo"
                                )
                            ),

                        Observaciones =
                            NullableString
                            (
                                r,
                                "Observaciones"
                            ),

                        UsuarioPrestamo =
                            r.GetString
                            (
                                r.GetOrdinal(
                                    "UsuarioPrestamo"
                                )
                            ),

                        UsuarioDevolucion =
                            NullableString
                            (
                                r,
                                "UsuarioDevolucion"
                            )
                    }
                );
            }
        }
        catch (SqlException ex)
            when (ex.Number >= 50000)
        {
            throw new InvalidOperationException(
                ex.Message
            );
        }


        return result;
    }



    /* ========================================================================
       LISTADO DE ACTIVOS
       SE CONSERVA POR COMPATIBILIDAD
       ======================================================================== */

    public async Task<List<ActiveLoanRow>>
        ListActiveLoansAsync(
            CancellationToken ct = default)
    {
        var result =
            new List<ActiveLoanRow>();


        await using var cn =
            _factory.Create();


        await using var cmd =
            new SqlCommand
            (
                "dbo.sp_Prestamo_ListarActivos",
                cn
            )
            {
                CommandType =
                    CommandType.StoredProcedure
            };


        await cn.OpenAsync(ct);


        await using var r =
            await cmd.ExecuteReaderAsync(ct);


        while (await r.ReadAsync(ct))
        {
            result.Add
            (
                new ActiveLoanRow
                {
                    IdPrestamo =
                        r.GetInt32
                        (
                            r.GetOrdinal(
                                "IdPrestamo"
                            )
                        ),

                    IdDetalleCita =
                        r.GetInt32
                        (
                            r.GetOrdinal(
                                "IdDetalleCita"
                            )
                        ),

                    FechaHoraPrestamo =
                        r.GetDateTime
                        (
                            r.GetOrdinal(
                                "FechaHoraPrestamo"
                            )
                        ),

                    DiasPrestado =
                        r.GetInt32
                        (
                            r.GetOrdinal(
                                "DiasPrestado"
                            )
                        ),

                    IdInternoRadiologia =
                        NullableString
                        (
                            r,
                            "IdInternoRadiologia"
                        ),

                    IdPaciente =
                        r.GetString
                        (
                            r.GetOrdinal(
                                "IdPaciente"
                            )
                        ),

                    Paciente =
                        r.GetString
                        (
                            r.GetOrdinal(
                                "Paciente"
                            )
                        ),

                    IdPrueba =
                        r.GetString
                        (
                            r.GetOrdinal(
                                "IdPrueba"
                            )
                        ),

                    NombrePrueba =
                        r.GetString
                        (
                            r.GetOrdinal(
                                "NombrePrueba"
                            )
                        ),

                    PartesCuerpo =
                        NullableString
                        (
                            r,
                            "PartesCuerpo"
                        )
                        ?? "",

                    IdPrestatario =
                        r.GetString
                        (
                            r.GetOrdinal(
                                "IdPrestatario"
                            )
                        ),

                    Prestatario =
                        r.GetString
                        (
                            r.GetOrdinal(
                                "Prestatario"
                            )
                        ),

                    TelefonoPrestatario =
                        NullableString
                        (
                            r,
                            "TelefonoPrestatario"
                        ),

                    MotivoPrestamo =
                        r.GetString
                        (
                            r.GetOrdinal(
                                "MotivoPrestamo"
                            )
                        ),

                    Observaciones =
                        NullableString
                        (
                            r,
                            "Observaciones"
                        ),

                    UsuarioPrestamo =
                        r.GetString
                        (
                            r.GetOrdinal(
                                "UsuarioPrestamo"
                            )
                        )
                }
            );
        }


        return result;
    }



    /* ========================================================================
       DETALLE DEL PRÉSTAMO
       ======================================================================== */

    public async Task<LoanDetail?>
        GetLoanAsync(
            int loanId,
            CancellationToken ct = default)
    {
        await using var cn =
            _factory.Create();


        await using var cmd =
            new SqlCommand
            (
                "dbo.sp_Prestamo_Obtener",
                cn
            )
            {
                CommandType =
                    CommandType.StoredProcedure
            };


        cmd.Parameters
            .Add
            (
                "@IdPrestamo",
                SqlDbType.Int
            )
            .Value =
            loanId;


        await cn.OpenAsync(ct);


        await using var r =
            await cmd.ExecuteReaderAsync(ct);


        if (!await r.ReadAsync(ct))
        {
            return null;
        }


        return new LoanDetail
        {
            IdPrestamo =
                r.GetInt32
                (
                    r.GetOrdinal(
                        "IdPrestamo"
                    )
                ),

            IdDetalleCita =
                r.GetInt32
                (
                    r.GetOrdinal(
                        "IdDetalleCita"
                    )
                ),

            FechaHoraPrestamo =
                r.GetDateTime
                (
                    r.GetOrdinal(
                        "FechaHoraPrestamo"
                    )
                ),

            MotivoPrestamo =
                r.GetString
                (
                    r.GetOrdinal(
                        "MotivoPrestamo"
                    )
                ),

            Observaciones =
                NullableString
                (
                    r,
                    "Observaciones"
                ),

            Estado =
                r.GetString
                (
                    r.GetOrdinal(
                        "Estado"
                    )
                ),

            UsuarioPrestamo =
                r.GetString
                (
                    r.GetOrdinal(
                        "UsuarioPrestamo"
                    )
                ),


            DocumentoIdentificacionDevuelve =
                NullableString
                (
                    r,
                    "DocumentoIdentificacionDevuelve"
                ),

            NombrePersonaDevuelve =
                NullableString
                (
                    r,
                    "NombrePersonaDevuelve"
                ),

            FechaHoraDevolucion =
                NullableDateTime
                (
                    r,
                    "FechaHoraDevolucion"
                ),

            UsuarioDevolucion =
                NullableString
                (
                    r,
                    "UsuarioDevolucion"
                ),

            ObservacionesDevolucion =
                NullableString
                (
                    r,
                    "ObservacionesDevolucion"
                ),


            IdInternoRadiologia =
                NullableString
                (
                    r,
                    "IdInternoRadiologia"
                ),

            IdPaciente =
                r.GetString
                (
                    r.GetOrdinal(
                        "IdPaciente"
                    )
                ),

            Paciente =
                r.GetString
                (
                    r.GetOrdinal(
                        "Paciente"
                    )
                ),

            IdPrueba =
                r.GetString
                (
                    r.GetOrdinal(
                        "IdPrueba"
                    )
                ),

            NombrePrueba =
                r.GetString
                (
                    r.GetOrdinal(
                        "NombrePrueba"
                    )
                ),

            NombreCategoria =
                r.GetString
                (
                    r.GetOrdinal(
                        "NombreCategoria"
                    )
                ),

            PartesCuerpo =
                NullableString
                (
                    r,
                    "PartesCuerpo"
                )
                ?? "",


            IdPrestatario =
                r.GetString
                (
                    r.GetOrdinal(
                        "IdPrestatario"
                    )
                ),

            Prestatario =
                r.GetString
                (
                    r.GetOrdinal(
                        "Prestatario"
                    )
                ),

            TelefonoPrestatario =
                NullableString
                (
                    r,
                    "TelefonoPrestatario"
                ),

            CorreoPrestatario =
                NullableString
                (
                    r,
                    "CorreoPrestatario"
                ),

            DireccionPrestatario =
                NullableString
                (
                    r,
                    "DireccionPrestatario"
                ),

            TieneDocumento1 =
                r.GetBoolean
                (
                    r.GetOrdinal(
                        "TieneDocumento1"
                    )
                ),

            TieneDocumento2 =
                r.GetBoolean
                (
                    r.GetOrdinal(
                        "TieneDocumento2"
                    )
                )
        };
    }



    /* ========================================================================
       HELPERS
       ======================================================================== */

    private static BorrowerRow ReadBorrower(
        SqlDataReader r)
    {
        return new BorrowerRow
        {
            IdPrestatario =
                r.GetString
                (
                    r.GetOrdinal(
                        "IdPrestatario"
                    )
                ),

            NombreCompleto =
                r.GetString
                (
                    r.GetOrdinal(
                        "NombreCompleto"
                    )
                ),

            Telefono =
                NullableString
                (
                    r,
                    "Telefono"
                ),

            Correo =
                NullableString
                (
                    r,
                    "Correo"
                ),

            Direccion =
                NullableString
                (
                    r,
                    "Direccion"
                ),

            Activo =
                r.GetBoolean
                (
                    r.GetOrdinal(
                        "Activo"
                    )
                ),

            FechaCreacion =
                r.GetDateTime
                (
                    r.GetOrdinal(
                        "FechaCreacion"
                    )
                ),

            FechaModificacion =
                NullableDateTime
                (
                    r,
                    "FechaModificacion"
                ),

            TieneDocumento1 =
                r.GetBoolean
                (
                    r.GetOrdinal(
                        "TieneDocumento1"
                    )
                ),

            TieneDocumento2 =
                r.GetBoolean
                (
                    r.GetOrdinal(
                        "TieneDocumento2"
                    )
                )
        };
    }


    private static object DbValue(
        string? value)
    {
        return string.IsNullOrWhiteSpace(value)
            ? DBNull.Value
            : value.Trim();
    }


    private static string? NullableString(
        SqlDataReader r,
        string name)
    {
        var ordinal =
            r.GetOrdinal(name);


        return r.IsDBNull(ordinal)
            ? null
            : r.GetString(ordinal);
    }


    private static int? NullableInt(
        SqlDataReader r,
        string name)
    {
        var ordinal =
            r.GetOrdinal(name);


        return r.IsDBNull(ordinal)
            ? null
            : r.GetInt32(ordinal);
    }


    private static DateTime? NullableDateTime(
        SqlDataReader r,
        string name)
    {
        var ordinal =
            r.GetOrdinal(name);


        return r.IsDBNull(ordinal)
            ? null
            : r.GetDateTime(ordinal);
    }
}