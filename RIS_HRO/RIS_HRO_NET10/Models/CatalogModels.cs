namespace RIS_HRO.Models;

public enum CatalogType
{
    Medicos,
    Tecnicos,
    Servicios,
    Categorias,
    Pruebas,
    Roles
}

public sealed class CatalogRow
{
    public string Id { get; set; } = "";
    public string Nombre { get; set; } = "";
    public string? Descripcion { get; set; }
    public string? Extra1 { get; set; }
    public string? Extra2 { get; set; }
    public string? Extra3 { get; set; }
    public string? Extra4 { get; set; }
    public bool Activo { get; set; }
}

public sealed class CatalogEditModel
{
    public string Id { get; set; } = "";
    public string Nombre { get; set; } = "";
    public string? Descripcion { get; set; }
    public string? Extra1 { get; set; }
    public string? Extra2 { get; set; }
    public string? Extra3 { get; set; }
    public string? Extra4 { get; set; }
    public bool Activo { get; set; } = true;
}

public sealed class RoleItem
{
    public int IdRol { get; set; }
    public string NombreRol { get; set; } = "";
}

public sealed class DoctorItem
{
    public string IdMedico { get; set; } = "";
    public string NombreCompleto { get; set; } = "";
}

public sealed class HospitalServiceItem
{
    public string IdServicio { get; set; } = "";
    public string NombreServicio { get; set; } = "";
}

public sealed class StudyItem
{
    public string IdPrueba { get; set; } = "";
    public string NombrePrueba { get; set; } = "";
    public string NombreCategoria { get; set; } = "";
}

public sealed class CategoryItem
{
    public string IdCategoria { get; set; } = "";
    public string NombreCategoria { get; set; } = "";
}
