using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using RIS_HRO.Models;
using RIS_HRO.Repositories;
using RIS_HRO.Services;

namespace RIS_HRO.Pages.Catalogs;

[Authorize(Roles = "ADMINISTRADOR")]
public sealed class ReportTemplatesModel : PageModel
{
    private readonly ReportTemplateRepository _templates;

    public ReportTemplatesModel(ReportTemplateRepository templates) => _templates = templates;

    [BindProperty]
    public ReportTemplateEditModel Edit { get; set; } = new();

    public List<ReportTemplateItem> Rows { get; private set; } = [];
    public string? Query { get; private set; }
    public string? TypeFilter { get; private set; }
    public string? ErrorMessage { get; private set; }
    public bool IsEditing => Edit.IdPlantilla > 0;

    public async Task OnGetAsync(
        string? q,
        string? typeFilter,
        int? edit,
        CancellationToken ct)
    {
        Query = q;
        TypeFilter = NormalizeTypeOrNull(typeFilter);

        if (edit.HasValue)
        {
            var item = await _templates.GetAsync(edit.Value, ct);
            if (item is not null)
            {
                Edit = new ReportTemplateEditModel
                {
                    IdPlantilla = item.IdPlantilla,
                    Nombre = item.Nombre,
                    Tipo = item.Tipo,
                    ContenidoHtml = item.ContenidoHtml,
                    Activo = item.Activo
                };
            }
        }

        await LoadRowsAsync(ct);
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        Edit.Nombre = Edit.Nombre?.Trim() ?? "";
        Edit.Tipo = (Edit.Tipo ?? "").Trim().ToUpperInvariant();
        Edit.ContenidoHtml = RichTextSanitizer.Sanitize(Edit.ContenidoHtml);

        if (string.IsNullOrWhiteSpace(Edit.Nombre))
            ModelState.AddModelError("", "El nombre de la plantilla es obligatorio.");

        if (!ReportTemplateTypes.IsValid(Edit.Tipo))
            ModelState.AddModelError("", "Debe seleccionar si la plantilla corresponde a Hallazgos o Conclusiones.");

        if (!RichTextSanitizer.HasVisibleText(Edit.ContenidoHtml))
            ModelState.AddModelError("", "El contenido de la plantilla es obligatorio.");

        if (!ModelState.IsValid)
        {
            ErrorMessage = string.Join(" ", ModelState.Values
                .SelectMany(v => v.Errors)
                .Select(e => e.ErrorMessage));
            await LoadRowsAsync(ct);
            return Page();
        }

        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(userId))
            return Challenge();

        try
        {
            var id = await _templates.SaveAsync(Edit, userId, ct);
            TempData["Success"] = $"Plantilla #{id} guardada correctamente.";
            return RedirectToPage("/Catalogs/ReportTemplates");
        }
        catch (Exception ex)
        {
            ErrorMessage = ex.Message;
            await LoadRowsAsync(ct);
            return Page();
        }
    }

    public async Task<IActionResult> OnPostToggleAsync(int id, CancellationToken ct)
    {
        var item = await _templates.GetAsync(id, ct);
        if (item is null)
            return NotFound();

        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(userId))
            return Challenge();

        var edit = new ReportTemplateEditModel
        {
            IdPlantilla = item.IdPlantilla,
            Nombre = item.Nombre,
            Tipo = item.Tipo,
            ContenidoHtml = item.ContenidoHtml,
            Activo = !item.Activo
        };

        try
        {
            await _templates.SaveAsync(edit, userId, ct);
            TempData["Success"] = edit.Activo
                ? "Plantilla habilitada correctamente."
                : "Plantilla deshabilitada correctamente. Se retiró de las asignaciones predeterminadas.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
        }

        return RedirectToPage("/Catalogs/ReportTemplates");
    }

    private async Task LoadRowsAsync(CancellationToken ct)
    {
        Rows = await _templates.ListAsync(Query, TypeFilter, onlyActive: false, ct);
    }

    private static string? NormalizeTypeOrNull(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;
        var normalized = value.Trim().ToUpperInvariant();
        return ReportTemplateTypes.IsValid(normalized) ? normalized : null;
    }
}
