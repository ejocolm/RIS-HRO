using System.Data;
using Microsoft.Data.SqlClient;
using RIS_HRO.Data;
using RIS_HRO.Models;

namespace RIS_HRO.Repositories;

public sealed class CapacityRepository
{
    private readonly SqlConnectionFactory _factory;
    public CapacityRepository(SqlConnectionFactory factory) => _factory = factory;

    public async Task<List<CapacityEditModel>> ListAsync(CancellationToken ct = default)
    {
        var map = new Dictionary<string, CapacityEditModel>(StringComparer.OrdinalIgnoreCase);

        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Capacidad_Listar", cn)
        { CommandType = CommandType.StoredProcedure };

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            var id = r.GetString(r.GetOrdinal("IdPrueba"));
            if (!map.TryGetValue(id, out var row))
            {
                row = new CapacityEditModel
                {
                    IdPrueba = id,
                    NombrePrueba = r.GetString(r.GetOrdinal("NombrePrueba"))
                };
                map[id] = row;
            }

            var day = Convert.ToInt32(r["DiaSemana"]);
            var value = r.IsDBNull(r.GetOrdinal("CantidadMaxima")) ? (int?)null : r.GetInt32(r.GetOrdinal("CantidadMaxima"));
            SetDay(row, day, value);
        }

        return map.Values.OrderBy(x => x.NombrePrueba).ToList();
    }

    public async Task SaveAsync(CapacityEditModel m, string userId, CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await cn.OpenAsync(ct);

        for (var day = 1; day <= 7; day++)
        {
            await using var cmd = new SqlCommand("dbo.sp_Capacidad_Guardar", cn)
            { CommandType = CommandType.StoredProcedure };
            cmd.Parameters.Add("@IdPrueba", SqlDbType.VarChar, 30).Value = m.IdPrueba;
            cmd.Parameters.Add("@DiaSemana", SqlDbType.TinyInt).Value = day;
            cmd.Parameters.Add("@CantidadMaxima", SqlDbType.Int).Value = (object?)GetDay(m, day) ?? DBNull.Value;
            cmd.Parameters.Add("@IdUsuario", SqlDbType.VarChar, 30).Value = userId;
            await cmd.ExecuteNonQueryAsync(ct);
        }
    }

    private static int? GetDay(CapacityEditModel m, int d) => d switch
    {
        1 => m.Lunes, 2 => m.Martes, 3 => m.Miercoles, 4 => m.Jueves,
        5 => m.Viernes, 6 => m.Sabado, 7 => m.Domingo, _ => null
    };

    private static void SetDay(CapacityEditModel m, int d, int? value)
    {
        switch (d)
        {
            case 1: m.Lunes = value; break;
            case 2: m.Martes = value; break;
            case 3: m.Miercoles = value; break;
            case 4: m.Jueves = value; break;
            case 5: m.Viernes = value; break;
            case 6: m.Sabado = value; break;
            case 7: m.Domingo = value; break;
        }
    }
}
