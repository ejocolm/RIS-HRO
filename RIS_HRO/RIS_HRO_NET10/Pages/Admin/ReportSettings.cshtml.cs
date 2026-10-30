using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using RIS_HRO.Repositories;

namespace RIS_HRO.Pages.Admin;

[Authorize(Roles = "ADMINISTRADOR")]
public sealed class ReportSettingsModel : PageModel
{
    private const long MaxFileSize = 5 * 1024 * 1024;

    private readonly AppointmentRepository _appointments;

    public ReportSettingsModel(AppointmentRepository appointments)
    {
        _appointments = appointments;
    }

    [BindProperty]
    public IFormFile? HeaderFile { get; set; }

    public bool HasHeader { get; private set; }
    public string? FileName { get; private set; }
    public string? MimeType { get; private set; }
    public string? ModifiedBy { get; private set; }
    public DateTime? ModifiedAt { get; private set; }

    public async Task OnGetAsync(CancellationToken ct)
    {
        await LoadAsync(ct);
    }

    public async Task<IActionResult> OnGetHeaderAsync(CancellationToken ct)
    {
        var config =
            await _appointments.GetReportHeaderConfigurationAsync(ct);

        if (config is null || !config.TieneEncabezado)
            return NotFound();

        return File(
            config.EncabezadoImagen!,
            config.EncabezadoTipoMime!);
    }

    public async Task<IActionResult> OnPostSaveAsync(CancellationToken ct)
    {
        if (HeaderFile is null || HeaderFile.Length == 0)
        {
            TempData["Error"] = "Seleccione una imagen PNG, JPG o JPEG.";
            return RedirectToPage();
        }

        if (HeaderFile.Length > MaxFileSize)
        {
            TempData["Error"] =
                "La imagen supera el tamaño máximo permitido de 5 MB.";
            return RedirectToPage();
        }

        var mime = HeaderFile.ContentType?.ToLowerInvariant();

        if (mime is not ("image/png" or "image/jpeg"))
        {
            TempData["Error"] =
                "El encabezado debe ser una imagen PNG, JPG o JPEG.";
            return RedirectToPage();
        }

        byte[] bytes;

        await using (var ms = new MemoryStream())
        {
            await HeaderFile.CopyToAsync(ms, ct);
            bytes = ms.ToArray();
        }

        if (!MatchesSignature(bytes, mime))
        {
            TempData["Error"] =
                "El contenido del archivo no corresponde a una imagen PNG/JPG/JPEG válida.";
            return RedirectToPage();
        }

        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);

        if (string.IsNullOrWhiteSpace(userId))
            return Challenge();

        try
        {
            await _appointments.SaveReportHeaderAsync(
                bytes,
                Path.GetFileName(HeaderFile.FileName),
                mime,
                userId,
                ct);

            TempData["Success"] =
                "El encabezado de los informes se actualizó correctamente.";
        }
        catch (InvalidOperationException ex)
        {
            TempData["Error"] = ex.Message;
        }

        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostDeleteAsync(CancellationToken ct)
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);

        if (string.IsNullOrWhiteSpace(userId))
            return Challenge();

        try
        {
            await _appointments.DeleteReportHeaderAsync(userId, ct);
            TempData["Success"] = "El encabezado fue eliminado.";
        }
        catch (InvalidOperationException ex)
        {
            TempData["Error"] = ex.Message;
        }

        return RedirectToPage();
    }

    private async Task LoadAsync(CancellationToken ct)
    {
        var config =
            await _appointments.GetReportHeaderConfigurationAsync(ct);

        if (config is null)
            return;

        HasHeader = config.TieneEncabezado;
        FileName = config.EncabezadoNombreArchivo;
        MimeType = config.EncabezadoTipoMime;
        ModifiedBy = config.IdUsuarioModificacion;
        ModifiedAt = config.FechaModificacion;
    }

    private static bool MatchesSignature(byte[] data, string mime)
    {
        if (mime == "image/png")
        {
            return data.Length >= 8 &&
                   data[0] == 0x89 &&
                   data[1] == 0x50 &&
                   data[2] == 0x4E &&
                   data[3] == 0x47 &&
                   data[4] == 0x0D &&
                   data[5] == 0x0A &&
                   data[6] == 0x1A &&
                   data[7] == 0x0A;
        }

        if (mime == "image/jpeg")
        {
            return data.Length >= 3 &&
                   data[0] == 0xFF &&
                   data[1] == 0xD8 &&
                   data[2] == 0xFF;
        }

        return false;
    }
}
