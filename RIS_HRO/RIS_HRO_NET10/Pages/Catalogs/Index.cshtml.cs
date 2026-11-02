using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using RIS_HRO.Models;
using RIS_HRO.Repositories;

namespace RIS_HRO.Pages.Catalogs;

[Authorize(Roles = "ADMINISTRADOR")]
public sealed class IndexModel : PageModel
{
    private readonly CatalogRepository _catalogs;
    private readonly ReportTemplateRepository _reportTemplates;

    public IndexModel(CatalogRepository catalogs, ReportTemplateRepository reportTemplates)
    {
        _catalogs = catalogs;
        _reportTemplates = reportTemplates;
    }

    [BindProperty(SupportsGet = true)] public CatalogType Type { get; set; } = CatalogType.Medicos;
    [BindProperty] public CatalogEditModel Edit { get; set; } = new();

    public List<CatalogRow> Rows { get; private set; } = [];
    public List<CategoryItem> Categories { get; private set; } = [];
    public List<ReportTemplateItem> FindingsTemplates { get; private set; } = [];
    public List<ReportTemplateItem> ConclusionsTemplates { get; private set; } = [];

    [BindProperty] public int? DefaultFindingsTemplateId { get; set; }
    [BindProperty] public int? DefaultConclusionsTemplateId { get; set; }
    public string? Query { get; private set; }
    public string? ErrorMessage { get; private set; }
    public bool IsEditing { get; private set; }

    public string Title => Type switch
    {
        CatalogType.Medicos => "Catálogo de médicos",
        CatalogType.MedicosInformantes => "Médicos informantes",
        CatalogType.Tecnicos => "Catálogo de técnicos radiólogos",
        CatalogType.Servicios => "Catálogo de servicios hospitalarios",
        CatalogType.Categorias => "Categorías de pruebas",
        CatalogType.Pruebas => "Catálogo de estudios",
        CatalogType.PartesCuerpo => "Catálogo de partes del cuerpo",
        CatalogType.Roles => "Catálogo de roles",
        _ => "Catálogo"
    };

    public string Subtitle => Type switch
    {
        CatalogType.MedicosInformantes => "Médicos del departamento de Imágenes autorizados para informar estudios",
        CatalogType.Pruebas => "Administración de estudios disponibles en el departamento",
        CatalogType.Categorias => "Clasificación de los estudios radiológicos",
        CatalogType.PartesCuerpo => "Administración de las regiones anatómicas disponibles para los estudios",
        _ => "Administración de registros del sistema"
    };

    public string Icon => Type switch
    {
        CatalogType.Medicos => "bi bi-person-badge",
        CatalogType.MedicosInformantes => "bi bi-person-vcard",
        CatalogType.Tecnicos => "bi bi-person-gear",
        CatalogType.Servicios => "bi bi-hospital",
        CatalogType.Categorias => "bi bi-folder2",
        CatalogType.Pruebas => "bi bi-file-earmark-medical",
        CatalogType.PartesCuerpo => "bi bi-person-bounding-box",
        CatalogType.Roles => "bi bi-shield-lock",
        _ => "bi bi-folder"
    };

    public string IdLabel => Type switch
    {
        CatalogType.Medicos => "Código médico",
        CatalogType.MedicosInformantes => "Código médico informante",
        CatalogType.Tecnicos => "Código técnico",
        CatalogType.Servicios => "Código servicio",
        CatalogType.Categorias => "Código categoría",
        CatalogType.Pruebas => "Código estudio",
        CatalogType.PartesCuerpo => "Código parte",
        CatalogType.Roles => "ID rol",
        _ => "Código"
    };

    public string NameLabel => Type switch
    {
        CatalogType.Medicos => "Médico",
        CatalogType.MedicosInformantes => "Médico informante",
        CatalogType.Tecnicos => "Técnico",
        CatalogType.Servicios => "Servicio",
        CatalogType.Categorias => "Categoría",
        CatalogType.Pruebas => "Estudio",
        CatalogType.PartesCuerpo => "Parte del cuerpo",
        CatalogType.Roles => "Rol",
        _ => "Nombre"
    };

    public async Task OnGetAsync(string? q, string? edit, CancellationToken ct)
    {
        Query = q;
        await LoadAsync(q, ct);

        if (!string.IsNullOrWhiteSpace(edit))
        {
            var item = await _catalogs.GetAsync(Type, edit, ct);
            if (item is not null)
            {
                Edit = item;
                IsEditing = true;

                if (Type == CatalogType.Pruebas)
                {
                    var defaults = await _reportTemplates.GetStudyDefaultsAsync(edit, ct);
                    DefaultFindingsTemplateId = defaults.IdPlantillaHallazgos;
                    DefaultConclusionsTemplateId = defaults.IdPlantillaConclusiones;
                }
            }
        }
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        try
        {
            Validate();
            if (!ModelState.IsValid)
            {
                ErrorMessage = string.Join(" ", ModelState.Values.SelectMany(v => v.Errors).Select(e => e.ErrorMessage));
                await LoadAsync(null, ct);
                return Page();
            }

            await _catalogs.SaveAsync(Type, Edit, ct);

            if (Type == CatalogType.Pruebas)
            {
                var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
                if (string.IsNullOrWhiteSpace(userId))
                    return Challenge();

                await _reportTemplates.SaveStudyDefaultsAsync(
                    Edit.Id.Trim(),
                    DefaultFindingsTemplateId,
                    DefaultConclusionsTemplateId,
                    userId,
                    ct);
            }

            TempData["Success"] = "Registro guardado correctamente.";
            return RedirectToPage("/Catalogs/Index", new { type = Type });
        }
        catch (Exception ex)
        {
            ErrorMessage = ex.Message;
            await LoadAsync(null, ct);
            return Page();
        }
    }

    private void Validate()
    {
        if (Type != CatalogType.Roles && string.IsNullOrWhiteSpace(Edit.Id)) ModelState.AddModelError("", "El código es obligatorio.");
        if (string.IsNullOrWhiteSpace(Edit.Nombre)) ModelState.AddModelError("", "El nombre es obligatorio.");
        if ((Type == CatalogType.Medicos || Type == CatalogType.MedicosInformantes || Type == CatalogType.Tecnicos) && string.IsNullOrWhiteSpace(Edit.Extra1))
            ModelState.AddModelError("", "Los apellidos son obligatorios.");
        if (Type == CatalogType.Pruebas && string.IsNullOrWhiteSpace(Edit.Extra1))
            ModelState.AddModelError("", "Debe seleccionar una categoría.");
    }

    private async Task LoadAsync(string? q, CancellationToken ct)
    {
        Rows = await _catalogs.ListAsync(Type, q, ct);
        if (Type == CatalogType.Pruebas)
        {
            Categories = await _catalogs.GetCategoriesAsync(ct);
            FindingsTemplates = await _reportTemplates.GetActiveByTypeAsync(ReportTemplateTypes.Hallazgos, ct);
            ConclusionsTemplates = await _reportTemplates.GetActiveByTypeAsync(ReportTemplateTypes.Conclusiones, ct);
        }
    }
}
