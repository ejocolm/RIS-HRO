using PdfSharp.Fonts;

namespace RIS_HRO.Services;

/// <summary>
/// Resolver de fuentes para PDFsharp Core cuando RIS HRO corre en Linux/Docker.
/// PdfService solicita la familia "Arial"; en Linux se sustituye por
/// Liberation Sans, instalada por el Dockerfile mediante fonts-liberation2.
/// </summary>
public sealed class LinuxFontResolver : IFontResolver
{
    private const string Regular = "LiberationSans-Regular";
    private const string Bold = "LiberationSans-Bold";
    private const string Italic = "LiberationSans-Italic";
    private const string BoldItalic = "LiberationSans-BoldItalic";

    private const string FontDirectory = "/usr/share/fonts/truetype/liberation2";

    public FontResolverInfo? ResolveTypeface(
        string familyName,
        bool bold,
        bool italic)
    {
        // RIS HRO usa Arial en PdfService. Para mantener compatibilidad,
        // también resolvemos Liberation Sans si se solicita directamente.
        if (!familyName.Equals("Arial", StringComparison.OrdinalIgnoreCase) &&
            !familyName.Equals("Liberation Sans", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        var faceName = (bold, italic) switch
        {
            (true, true) => BoldItalic,
            (true, false) => Bold,
            (false, true) => Italic,
            _ => Regular
        };

        return new FontResolverInfo(faceName);
    }

    public byte[]? GetFont(string faceName)
    {
        var fileName = faceName switch
        {
            Regular => "LiberationSans-Regular.ttf",
            Bold => "LiberationSans-Bold.ttf",
            Italic => "LiberationSans-Italic.ttf",
            BoldItalic => "LiberationSans-BoldItalic.ttf",
            _ => null
        };

        if (fileName is null)
            return null;

        var fullPath = Path.Combine(FontDirectory, fileName);

        if (!File.Exists(fullPath))
        {
            throw new FileNotFoundException(
                $"No se encontró la fuente requerida por PDFsharp: {fullPath}");
        }

        return File.ReadAllBytes(fullPath);
    }
}
