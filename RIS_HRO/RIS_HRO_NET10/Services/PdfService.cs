using PdfSharp.Drawing;
using PdfSharp.Pdf;
using RIS_HRO.Models;

namespace RIS_HRO.Services;

public sealed class PdfService
{
    private readonly XFont _title = new("Arial", 16, XFontStyleEx.Bold);
    private readonly XFont _subtitle = new("Arial", 11, XFontStyleEx.Bold);
    private readonly XFont _body = new("Arial", 9, XFontStyleEx.Regular);
    private readonly XFont _bodyBold = new("Arial", 9, XFontStyleEx.Bold);
    private readonly XFont _small = new("Arial", 7.5, XFontStyleEx.Regular);

    public byte[] AppointmentReceipt(AppointmentDetail cita)
    {
        using var doc = new PdfDocument();
        var page = doc.AddPage();
        page.Size = PdfSharp.PageSize.Letter;
        using var gfx = XGraphics.FromPdfPage(page);

        var blue = XColor.FromArgb(0, 64, 130);
        var teal = XColor.FromArgb(16, 184, 200);
        var gray = XColor.FromArgb(95, 110, 130);

        gfx.DrawString("RIS HRO", _title, new XSolidBrush(blue), new XPoint(45, 55));
        gfx.DrawString("Constancia de cita - Departamento de Radiología", _subtitle,
            new XSolidBrush(blue), new XPoint(45, 76));
        gfx.DrawLine(new XPen(teal, 2), 45, 86, 565, 86);

        var y = 112d;
        DrawPair(gfx, "Número de cita", cita.NumeroCita, 45, ref y);
        DrawPair(gfx, "Paciente", $"{cita.IdPaciente} - {cita.Paciente}", 45, ref y);
        DrawPair(gfx, "Médico solicitante", cita.Medico, 45, ref y);
        DrawPair(gfx, "Servicio hospitalario", cita.Servicio, 45, ref y);
        DrawPair(gfx, "Fecha", cita.FechaCita.ToString("dd/MM/yyyy"), 45, ref y);
        DrawPair(gfx, "Hora", DateTime.Today.Add(cita.HoraCita).ToString("HH:mm"), 45, ref y);
        DrawPair(gfx, "Estado", cita.Estado, 45, ref y);

        y += 10;
        gfx.DrawString("Estudios solicitados", _subtitle, new XSolidBrush(blue), new XPoint(45, y));
        y += 18;

        foreach (var estudio in cita.Estudios)
        {
            gfx.DrawEllipse(new XSolidBrush(teal), 48, y - 6, 5, 5);
            gfx.DrawString($"{estudio.IdPrueba} - {estudio.NombrePrueba}",
                _body, XBrushes.Black, new XPoint(62, y));
            y += 16;
        }

        if (!string.IsNullOrWhiteSpace(cita.Observaciones))
        {
            y += 8;
            gfx.DrawString("Observaciones", _subtitle, new XSolidBrush(blue), new XPoint(45, y));
            y += 16;
            y = DrawWrapped(gfx, cita.Observaciones!, _body, XBrushes.Black, 45, y, 510, 13);
        }

        y += 20;
        gfx.DrawRectangle(new XPen(XColor.FromArgb(210, 220, 232)), new XRect(45, y, 520, 50));
        gfx.DrawString("Preséntese en la fecha y hora indicadas.",
            _bodyBold, new XSolidBrush(gray), new XPoint(60, y + 20));
        gfx.DrawString("Conserve esta constancia para referencia de su programación.",
            _small, new XSolidBrush(gray), new XPoint(60, y + 37));

        gfx.DrawString("Hospital Regional de Occidente", _small,
            new XSolidBrush(gray), new XPoint(45, 750));

        return Save(doc);
    }

    public byte[] StudyReport(
        IReadOnlyList<StudyReportRow> rows,
        DateTime from,
        DateTime to)
    {
        using var doc = new PdfDocument();
        var page = doc.AddPage();
        page.Size = PdfSharp.PageSize.Letter;
        using var gfx = XGraphics.FromPdfPage(page);

        DrawReportHeader(gfx, "Reporte de estudios realizados", from, to, 565);

        double y = 115;
        DrawTableHeader(gfx, ref y, 45,
            ("Código", 70), ("Estudio", 240), ("Categoría", 140), ("Cantidad", 70));

        foreach (var row in rows.Take(25))
        {
            var x = 45d;
            DrawCell(gfx, row.IdPrueba, x, y, 70); x += 70;
            DrawCell(gfx, row.NombrePrueba, x, y, 240); x += 240;
            DrawCell(gfx, row.Categoria, x, y, 140); x += 140;
            DrawCell(gfx, row.Cantidad.ToString(), x, y, 70, true);
            y += 22;
        }

        y += 12;
        gfx.DrawString($"Total de estudios: {rows.Sum(x => x.Cantidad)}",
            _bodyBold, XBrushes.Black, new XPoint(45, y));

        if (rows.Count > 25)
            gfx.DrawString($"Se muestran los primeros 25 de {rows.Count} estudios.",
                _small, XBrushes.Gray, new XPoint(45, y + 16));

        return Save(doc);
    }

    public byte[] AppointmentReport(
        IReadOnlyList<AppointmentReportRow> rows,
        DateTime from,
        DateTime to)
    {
        using var doc = new PdfDocument();
        var page = doc.AddPage();
        page.Size = PdfSharp.PageSize.Letter;
        page.Orientation = PdfSharp.PageOrientation.Landscape;
        using var gfx = XGraphics.FromPdfPage(page);

        DrawReportHeader(gfx, "Reporte de citas", from, to, 747);

        double y = 110;
        var columns = new (string Text, double Width)[]
        {
            ("Cita", 95), ("Fecha/Hora", 105), ("Paciente", 175),
            ("Servicio", 120), ("Estudios", 225), ("Estado", 85)
        };
        DrawTableHeader(gfx, ref y, 35, columns);

        foreach (var row in rows.Take(22))
        {
            var x = 35d;
            DrawCell(gfx, row.NumeroCita, x, y, 95); x += 95;
            DrawCell(gfx, $"{row.FechaCita:dd/MM/yyyy} {DateTime.Today.Add(row.HoraCita):HH:mm}", x, y, 105); x += 105;
            DrawCell(gfx, row.Paciente, x, y, 175); x += 175;
            DrawCell(gfx, row.Servicio, x, y, 120); x += 120;
            DrawCell(gfx, row.Estudios, x, y, 225); x += 225;
            DrawCell(gfx, row.Estado, x, y, 85);
            y += 22;
        }

        if (rows.Count > 22)
            gfx.DrawString($"Se muestran las primeras 22 de {rows.Count} citas. Consulte el listado en pantalla para el detalle completo.",
                _small, XBrushes.Gray, new XPoint(35, y + 15));

        return Save(doc);
    }

    private void DrawReportHeader(XGraphics gfx, string title, DateTime from, DateTime to, double rightX)
    {
        var blue = new XSolidBrush(XColor.FromArgb(0, 64, 130));
        var teal = new XPen(XColor.FromArgb(16, 184, 200), 2);

        gfx.DrawString("RIS HRO", _title, blue, new XPoint(45, 48));
        gfx.DrawString(title, _subtitle, blue, new XPoint(45, 69));
        gfx.DrawString($"Período: {from:dd/MM/yyyy} al {to:dd/MM/yyyy}",
            _small, XBrushes.Gray, new XPoint(45, 86));
        gfx.DrawLine(teal, 45, 94, rightX, 94);
    }

    private void DrawTableHeader(XGraphics gfx, ref double y, double startX, params (string Text, double Width)[] cols)
    {
        var x = startX;
        var brush = new XSolidBrush(XColor.FromArgb(235, 243, 252));

        foreach (var col in cols)
        {
            gfx.DrawRectangle(brush, x, y - 14, col.Width, 20);
            gfx.DrawString(col.Text, _bodyBold, new XSolidBrush(XColor.FromArgb(0, 64, 130)),
                new XRect(x + 4, y - 13, col.Width - 8, 18),
                new XStringFormat { Alignment = XStringAlignment.Near, LineAlignment = XLineAlignment.Center });
            x += col.Width;
        }

        y += 14;
    }

    private void DrawCell(XGraphics gfx, string? text, double x, double y, double width, bool center = false)
    {
        var value = text ?? "";
        if (value.Length > Math.Max(8, (int)(width / 6.2)))
            value = value[..Math.Max(5, (int)(width / 6.2) - 3)] + "...";

        gfx.DrawString(value, _small, XBrushes.Black,
            new XRect(x + 4, y - 12, width - 8, 18),
            center
                ? XStringFormats.Center
                : new XStringFormat { Alignment = XStringAlignment.Near, LineAlignment = XLineAlignment.Center });
        gfx.DrawLine(new XPen(XColor.FromArgb(230, 235, 242)), x, y + 7, x + width, y + 7);
    }

    private void DrawPair(XGraphics gfx, string label, string value, double x, ref double y)
    {
        gfx.DrawString(label + ":", _bodyBold, new XSolidBrush(XColor.FromArgb(0, 64, 130)), new XPoint(x, y));
        gfx.DrawString(value, _body, XBrushes.Black, new XPoint(x + 125, y));
        y += 20;
    }

    private double DrawWrapped(XGraphics gfx, string text, XFont font, XBrush brush,
        double x, double y, double width, double lineHeight)
    {
        var words = text.Split(' ');
        var line = "";

        foreach (var word in words)
        {
            var test = string.IsNullOrEmpty(line) ? word : $"{line} {word}";
            if (gfx.MeasureString(test, font).Width > width && !string.IsNullOrEmpty(line))
            {
                gfx.DrawString(line, font, brush, new XPoint(x, y));
                y += lineHeight;
                line = word;
            }
            else line = test;
        }

        if (!string.IsNullOrWhiteSpace(line))
        {
            gfx.DrawString(line, font, brush, new XPoint(x, y));
            y += lineHeight;
        }

        return y;
    }

    private static byte[] Save(PdfDocument doc)
    {
        using var ms = new MemoryStream();
        doc.Save(ms, false);
        return ms.ToArray();
    }
}
