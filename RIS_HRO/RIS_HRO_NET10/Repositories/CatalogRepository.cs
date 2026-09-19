using System.Data;
using Microsoft.Data.SqlClient;
using RIS_HRO.Data;
using RIS_HRO.Models;

namespace RIS_HRO.Repositories;

public sealed class CatalogRepository
{
    private readonly SqlConnectionFactory _factory;
    public CatalogRepository(SqlConnectionFactory factory) => _factory = factory;

    public async Task<List<CatalogRow>> ListAsync(CatalogType type, string? q, CancellationToken ct = default)
    {
        var result = new List<CatalogRow>();
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand(GetListProc(type), cn)
        { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.Add("@Texto", SqlDbType.VarChar, 100).Value = (object?)q ?? DBNull.Value;

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
        {
            result.Add(new CatalogRow
            {
                Id = r["Id"]?.ToString() ?? "",
                Nombre = r["Nombre"]?.ToString() ?? "",
                Descripcion = DbString(r, "Descripcion"),
                Extra1 = DbString(r, "Extra1"),
                Extra2 = DbString(r, "Extra2"),
                Extra3 = DbString(r, "Extra3"),
                Extra4 = DbString(r, "Extra4"),
                Activo = Convert.ToBoolean(r["Activo"])
            });
        }
        return result;
    }

    public async Task<CatalogEditModel?> GetAsync(CatalogType type, string id, CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand(GetGetProc(type), cn)
        { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.Add("@Id", SqlDbType.VarChar, 30).Value = id;

        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        if (!await r.ReadAsync(ct)) return null;

        return new CatalogEditModel
        {
            Id = r["Id"]?.ToString() ?? "",
            Nombre = r["Nombre"]?.ToString() ?? "",
            Descripcion = DbString(r, "Descripcion"),
            Extra1 = DbString(r, "Extra1"),
            Extra2 = DbString(r, "Extra2"),
            Extra3 = DbString(r, "Extra3"),
            Extra4 = DbString(r, "Extra4"),
            Activo = Convert.ToBoolean(r["Activo"])
        };
    }

    public async Task SaveAsync(CatalogType type, CatalogEditModel m, CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand(GetSaveProc(type), cn)
        { CommandType = CommandType.StoredProcedure };

        cmd.Parameters.Add("@Id", SqlDbType.VarChar, 30).Value = m.Id;
        cmd.Parameters.Add("@Nombre", SqlDbType.VarChar, 150).Value = m.Nombre;
        cmd.Parameters.Add("@Descripcion", SqlDbType.VarChar, 250).Value = (object?)m.Descripcion ?? DBNull.Value;
        cmd.Parameters.Add("@Extra1", SqlDbType.VarChar, 150).Value = (object?)m.Extra1 ?? DBNull.Value;
        cmd.Parameters.Add("@Extra2", SqlDbType.VarChar, 100).Value = (object?)m.Extra2 ?? DBNull.Value;
        cmd.Parameters.Add("@Extra3", SqlDbType.VarChar, 100).Value = (object?)m.Extra3 ?? DBNull.Value;
        cmd.Parameters.Add("@Extra4", SqlDbType.VarChar, 100).Value = (object?)m.Extra4 ?? DBNull.Value;
        cmd.Parameters.Add("@Activo", SqlDbType.Bit).Value = m.Activo;

        await cn.OpenAsync(ct);
        await cmd.ExecuteNonQueryAsync(ct);
    }

    public async Task<List<DoctorItem>> GetDoctorsAsync(CancellationToken ct = default)
    {
        var result = new List<DoctorItem>();
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Medico_ListarActivos", cn)
        { CommandType = CommandType.StoredProcedure };
        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
            result.Add(new DoctorItem
            {
                IdMedico = r.GetString(r.GetOrdinal("IdMedico")),
                NombreCompleto = r.GetString(r.GetOrdinal("NombreCompleto"))
            });
        return result;
    }

    public async Task<List<HospitalServiceItem>> GetServicesAsync(CancellationToken ct = default)
    {
        var result = new List<HospitalServiceItem>();
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Servicio_ListarActivos", cn)
        { CommandType = CommandType.StoredProcedure };
        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
            result.Add(new HospitalServiceItem
            {
                IdServicio = r.GetString(r.GetOrdinal("IdServicio")),
                NombreServicio = r.GetString(r.GetOrdinal("NombreServicio"))
            });
        return result;
    }

    public async Task<List<RoleItem>> GetRolesAsync(CancellationToken ct = default)
    {
        var result = new List<RoleItem>();
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Rol_ListarActivos", cn)
        { CommandType = CommandType.StoredProcedure };
        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
            result.Add(new RoleItem
            {
                IdRol = r.GetInt32(r.GetOrdinal("IdRol")),
                NombreRol = r.GetString(r.GetOrdinal("NombreRol"))
            });
        return result;
    }

    public async Task<List<CategoryItem>> GetCategoriesAsync(CancellationToken ct = default)
    {
        var result = new List<CategoryItem>();
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Categoria_ListarActivas", cn)
        { CommandType = CommandType.StoredProcedure };
        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
            result.Add(new CategoryItem
            {
                IdCategoria = r.GetString(r.GetOrdinal("IdCategoria")),
                NombreCategoria = r.GetString(r.GetOrdinal("NombreCategoria"))
            });
        return result;
    }

    public async Task<StudyItem?> GetStudyAsync(string idPrueba, CancellationToken ct = default)
    {
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Prueba_ObtenerActiva", cn)
        { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.Add("@IdPrueba", SqlDbType.VarChar, 30).Value = idPrueba;
        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        if (!await r.ReadAsync(ct)) return null;

        return new StudyItem
        {
            IdPrueba = r.GetString(r.GetOrdinal("IdPrueba")),
            NombrePrueba = r.GetString(r.GetOrdinal("NombrePrueba")),
            NombreCategoria = r.GetString(r.GetOrdinal("NombreCategoria"))
        };
    }

    public async Task<List<StudyItem>> SearchStudiesAsync(string? q, CancellationToken ct = default)
    {
        var result = new List<StudyItem>();
        await using var cn = _factory.Create();
        await using var cmd = new SqlCommand("dbo.sp_Prueba_BuscarActivas", cn)
        { CommandType = CommandType.StoredProcedure };
        cmd.Parameters.Add("@Texto", SqlDbType.VarChar, 100).Value = (object?)q ?? DBNull.Value;
        await cn.OpenAsync(ct);
        await using var r = await cmd.ExecuteReaderAsync(ct);
        while (await r.ReadAsync(ct))
            result.Add(new StudyItem
            {
                IdPrueba = r.GetString(r.GetOrdinal("IdPrueba")),
                NombrePrueba = r.GetString(r.GetOrdinal("NombrePrueba")),
                NombreCategoria = r.GetString(r.GetOrdinal("NombreCategoria"))
            });
        return result;
    }

    private static string GetListProc(CatalogType type) => type switch
    {
        CatalogType.Medicos => "dbo.sp_Medico_Listar",
        CatalogType.Tecnicos => "dbo.sp_Tecnico_Listar",
        CatalogType.Servicios => "dbo.sp_Servicio_Listar",
        CatalogType.Categorias => "dbo.sp_Categoria_Listar",
        CatalogType.Pruebas => "dbo.sp_Prueba_Listar",
        CatalogType.Roles => "dbo.sp_Rol_Listar",
        _ => throw new ArgumentOutOfRangeException(nameof(type))
    };

    private static string GetGetProc(CatalogType type) => type switch
    {
        CatalogType.Medicos => "dbo.sp_Medico_Obtener",
        CatalogType.Tecnicos => "dbo.sp_Tecnico_Obtener",
        CatalogType.Servicios => "dbo.sp_Servicio_Obtener",
        CatalogType.Categorias => "dbo.sp_Categoria_Obtener",
        CatalogType.Pruebas => "dbo.sp_Prueba_Obtener",
        CatalogType.Roles => "dbo.sp_Rol_Obtener",
        _ => throw new ArgumentOutOfRangeException(nameof(type))
    };

    private static string GetSaveProc(CatalogType type) => type switch
    {
        CatalogType.Medicos => "dbo.sp_Medico_Guardar",
        CatalogType.Tecnicos => "dbo.sp_Tecnico_Guardar",
        CatalogType.Servicios => "dbo.sp_Servicio_Guardar",
        CatalogType.Categorias => "dbo.sp_Categoria_Guardar",
        CatalogType.Pruebas => "dbo.sp_Prueba_Guardar",
        CatalogType.Roles => "dbo.sp_Rol_Guardar",
        _ => throw new ArgumentOutOfRangeException(nameof(type))
    };

    private static string? DbString(SqlDataReader r, string name)
    {
        var ordinal = r.GetOrdinal(name);
        return r.IsDBNull(ordinal) ? null : r.GetValue(ordinal)?.ToString();
    }
}
