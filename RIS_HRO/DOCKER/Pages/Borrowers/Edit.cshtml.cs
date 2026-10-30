using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using RIS_HRO.Models;
using RIS_HRO.Repositories;

namespace RIS_HRO.Pages.Borrowers;

[Authorize(Roles = "ADMINISTRADOR,USUARIO_BODEGA")]
public sealed class EditModel : PageModel
{
    private const long MaxImageBytes = 1536 * 1024; // 1.5 MB máximo en servidor
    private const int MaxImageDimension = 1600;      // lado mayor máximo
    private readonly LoanRepository _loans;

    public EditModel(LoanRepository loans)
    {
        _loans = loans;
    }

    [BindProperty]
    public string IdPrestatario { get; set; } = "";

    [BindProperty]
    public string NombreCompleto { get; set; } = "";

    [BindProperty]
    public string? Telefono { get; set; }

    [BindProperty]
    public string? Correo { get; set; }

    [BindProperty]
    public string? Direccion { get; set; }

    [BindProperty]
    public bool Activo { get; set; } = true;

    [BindProperty]
    public IFormFile? Documento1 { get; set; }

    [BindProperty]
    public IFormFile? Documento2 { get; set; }

    [BindProperty]
    public bool EliminarDocumento2 { get; set; }

    [BindProperty]
    public int? ReturnDetailId { get; set; }

    public bool IsExisting { get; private set; }
    public bool TieneDocumento1 { get; private set; }
    public bool TieneDocumento2 { get; private set; }

    public async Task<IActionResult> OnGetAsync(
        string? id,
        int? returnDetailId,
        CancellationToken ct)
    {
        ReturnDetailId = returnDetailId;

        if (string.IsNullOrWhiteSpace(id))
            return Page();

        var borrower = await _loans.GetBorrowerAsync(id.Trim(), ct);

        if (borrower is null)
        {
            IdPrestatario = id.Trim();
            return Page();
        }

        LoadBorrower(borrower);
        return Page();
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        Normalize();

        var existing = string.IsNullOrWhiteSpace(IdPrestatario)
            ? null
            : await _loans.GetBorrowerAsync(IdPrestatario, ct);

        IsExisting = existing is not null;
        TieneDocumento1 = existing?.TieneDocumento1 ?? false;
        TieneDocumento2 = existing?.TieneDocumento2 ?? false;

        if (string.IsNullOrWhiteSpace(IdPrestatario))
            ModelState.AddModelError(nameof(IdPrestatario), "El ID es obligatorio.");

        if (string.IsNullOrWhiteSpace(NombreCompleto))
            ModelState.AddModelError(nameof(NombreCompleto), "El nombre completo es obligatorio.");

        if (existing is null && Documento1 is null)
            ModelState.AddModelError(
                nameof(Documento1),
                "La primera imagen del documento es obligatoria.");

        if (!ModelState.IsValid)
            return Page();

        try
        {
            var doc1 = Documento1 is null
                ? null
                : await ReadImageAsync(Documento1, ct);

            var doc2 = Documento2 is null
                ? null
                : await ReadImageAsync(Documento2, ct);

            await _loans.SaveBorrowerAsync(
                new BorrowerSaveCommand
                {
                    IdPrestatario = IdPrestatario,
                    NombreCompleto = NombreCompleto,
                    Telefono = Telefono,
                    Correo = Correo,
                    Direccion = Direccion,

                    Documento1NombreArchivo = doc1?.FileName,
                    Documento1TipoMime = doc1?.Mime,
                    Documento1Imagen = doc1?.Bytes,

                    Documento2NombreArchivo = doc2?.FileName,
                    Documento2TipoMime = doc2?.Mime,
                    Documento2Imagen = doc2?.Bytes,

                    EliminarDocumento2 = EliminarDocumento2,
                    Activo = Activo
                },
                ct);

            if (ReturnDetailId.HasValue)
            {
                return RedirectToPage(
                    "/Loans/Create",
                    new
                    {
                        detailId = ReturnDetailId.Value,
                        borrowerId = IdPrestatario
                    });
            }

            TempData["Success"] = "Prestatario guardado correctamente.";
            return RedirectToPage("/Borrowers/Index");
        }
        catch (InvalidOperationException ex)
        {
            ModelState.AddModelError("", ex.Message);
            return Page();
        }
        catch (ArgumentException ex)
        {
            ModelState.AddModelError("", ex.Message);
            return Page();
        }
    }

    public async Task<IActionResult> OnGetDocumentAsync(
        string id,
        int number,
        CancellationToken ct)
    {
        try
        {
            var doc = await _loans.GetBorrowerDocumentAsync(id, number, ct);

            if (doc is null)
                return NotFound();

            return File(doc.Imagen, doc.TipoMime);
        }
        catch (InvalidOperationException)
        {
            return NotFound();
        }
    }

    private void LoadBorrower(BorrowerRow borrower)
    {
        IsExisting = true;
        IdPrestatario = borrower.IdPrestatario;
        NombreCompleto = borrower.NombreCompleto;
        Telefono = borrower.Telefono;
        Correo = borrower.Correo;
        Direccion = borrower.Direccion;
        Activo = borrower.Activo;
        TieneDocumento1 = borrower.TieneDocumento1;
        TieneDocumento2 = borrower.TieneDocumento2;
    }

    private void Normalize()
    {
        IdPrestatario = IdPrestatario?.Trim() ?? "";
        NombreCompleto = NombreCompleto?.Trim() ?? "";
        Telefono = NullIfWhite(Telefono);
        Correo = NullIfWhite(Correo);
        Direccion = NullIfWhite(Direccion);
    }

    private static string? NullIfWhite(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static async Task<ImageUpload> ReadImageAsync(
        IFormFile file,
        CancellationToken ct)
    {
        if (file.Length <= 0)
            throw new ArgumentException("La imagen seleccionada está vacía.");

        if (file.Length > MaxImageBytes)
            throw new ArgumentException(
                "La imagen supera 1.5 MB. Selecciónela nuevamente para que el navegador la optimice antes de guardar.");

        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();

        if (ext is not ".png" and not ".jpg" and not ".jpeg")
            throw new ArgumentException(
                "Solo se permiten imágenes PNG, JPG o JPEG.");

        await using var ms = new MemoryStream();
        await file.CopyToAsync(ms, ct);
        var bytes = ms.ToArray();

        var isPng =
            bytes.Length >= 8 &&
            bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4E &&
            bytes[3] == 0x47 &&
            bytes[4] == 0x0D &&
            bytes[5] == 0x0A &&
            bytes[6] == 0x1A &&
            bytes[7] == 0x0A;

        var isJpeg =
            bytes.Length >= 3 &&
            bytes[0] == 0xFF &&
            bytes[1] == 0xD8 &&
            bytes[2] == 0xFF;

        if (!isPng && !isJpeg)
            throw new ArgumentException(
                "El archivo no contiene una imagen PNG/JPG válida.");

        var dimensions = GetImageDimensions(bytes, isPng);

        if (dimensions.Width <= 0 || dimensions.Height <= 0)
            throw new ArgumentException(
                "No fue posible validar las dimensiones de la imagen.");

        if (dimensions.Width > MaxImageDimension ||
            dimensions.Height > MaxImageDimension)
        {
            throw new ArgumentException(
                $"La imagen excede {MaxImageDimension}px en uno de sus lados. Selecciónela nuevamente para que el navegador la optimice.");
        }

        return new ImageUpload
        {
            FileName = Path.GetFileName(file.FileName),
            Mime = isPng ? "image/png" : "image/jpeg",
            Bytes = bytes
        };
    }

    private static (int Width, int Height) GetImageDimensions(
        byte[] bytes,
        bool isPng)
    {
        if (isPng)
        {
            if (bytes.Length < 24)
                return (0, 0);

            var width =
                (bytes[16] << 24) |
                (bytes[17] << 16) |
                (bytes[18] << 8) |
                bytes[19];

            var height =
                (bytes[20] << 24) |
                (bytes[21] << 16) |
                (bytes[22] << 8) |
                bytes[23];

            return (width, height);
        }

        // JPEG: leer los segmentos SOF sin decodificar toda la imagen.
        var offset = 2;

        while (offset + 8 < bytes.Length)
        {
            if (bytes[offset] != 0xFF)
            {
                offset++;
                continue;
            }

            while (offset < bytes.Length && bytes[offset] == 0xFF)
                offset++;

            if (offset >= bytes.Length)
                break;

            var marker = bytes[offset++];

            // Marcadores sin longitud de segmento.
            if (marker is 0xD8 or 0xD9)
                continue;

            if (offset + 1 >= bytes.Length)
                break;

            var segmentLength =
                (bytes[offset] << 8) | bytes[offset + 1];

            if (segmentLength < 2 ||
                offset + segmentLength > bytes.Length)
                break;

            var isStartOfFrame =
                marker is 0xC0 or 0xC1 or 0xC2 or 0xC3
                    or 0xC5 or 0xC6 or 0xC7
                    or 0xC9 or 0xCA or 0xCB
                    or 0xCD or 0xCE or 0xCF;

            if (isStartOfFrame && segmentLength >= 7)
            {
                var height =
                    (bytes[offset + 3] << 8) |
                    bytes[offset + 4];

                var width =
                    (bytes[offset + 5] << 8) |
                    bytes[offset + 6];

                return (width, height);
            }

            offset += segmentLength;
        }

        return (0, 0);
    }

    private sealed class ImageUpload
    {
        public string FileName { get; set; } = "";
        public string Mime { get; set; } = "";
        public byte[] Bytes { get; set; } = [];
    }
}
