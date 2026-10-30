using System.Net;
using System.Text.RegularExpressions;
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
        gfx.DrawString("Constancia de solicitud - Departamento de Radiología", _subtitle,
            new XSolidBrush(blue), new XPoint(45, 76));
        gfx.DrawLine(new XPen(teal, 2), 45, 86, 565, 86);

        var y = 112d;
        DrawPair(gfx, "Número de solicitud", cita.NumeroCita, 45, ref y);
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

        DrawReportHeader(gfx, "Reporte de solicitudes", from, to, 747);

        double y = 110;
        var columns = new (string Text, double Width)[]
        {
            ("Solicitud", 95), ("Fecha/Hora", 105), ("Paciente", 175),
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
            gfx.DrawString($"Se muestran las primeras 22 de {rows.Count} solicitudes. Consulte el listado en pantalla para el detalle completo.",
                _small, XBrushes.Gray, new XPoint(35, y + 15));

        return Save(doc);
    }


    public byte[] RadiologyStudyReport(
        StudyReportPrintData report,
        byte[]? headerImage = null)
    {
        using var doc = new PdfDocument();

        using (var ctx = new ReportPageContext(doc))
        {
            var black = XBrushes.Black;
            var bodyFont = new XFont("Arial", 10.5, XFontStyleEx.Regular);
            var labelFont = new XFont("Arial", 10.5, XFontStyleEx.Bold);
            var titleFont = new XFont(
                "Arial",
                11.5,
                XFontStyleEx.Bold | XFontStyleEx.Underline);
            var signatureFont = new XFont("Arial", 10.5, XFontStyleEx.Bold);

            /* Encabezado institucional opcional.
               El resto del formato es idéntico con o sin imagen. */
            if (headerImage is { Length: > 0 })
            {
                using var ms = new MemoryStream(
                    headerImage,
                    0,
                    headerImage.Length,
                    false,
                    true);

                using var image = XImage.FromStream(ms);

                const double maxWidth = 520;
                const double maxHeight = 80;

                var sourceWidth = Math.Max(1, image.PixelWidth);
                var sourceHeight = Math.Max(1, image.PixelHeight);
                var scale = Math.Min(
                    maxWidth / sourceWidth,
                    maxHeight / sourceHeight);

                var drawWidth = sourceWidth * scale;
                var drawHeight = sourceHeight * scale;
                var imageX = 45 + ((maxWidth - drawWidth) / 2);

                ctx.Gfx.DrawImage(
                    image,
                    imageX,
                    ctx.Y,
                    drawWidth,
                    drawHeight);

                ctx.Y += drawHeight + 14;
            }
            else
            {
                ctx.Y += 24;
            }

            /* Fecha y referencia institucional, alineadas a la derecha. */
            var fechaTexto =
                $"Quetzaltenango, {FormatSpanishLongDate(report.FechaHoraInforme)}";

            ctx.Gfx.DrawString(
                fechaTexto,
                labelFont,
                black,
                new XRect(255, ctx.Y, 310, 18),
                XStringFormats.TopRight);

            ctx.Y += 18;

            ctx.Gfx.DrawString(
                "REF. VR/BH",
                new XFont("Arial", 9, XFontStyleEx.Bold),
                black,
                new XRect(255, ctx.Y, 310, 16),
                XStringFormats.TopRight);

            ctx.Y += 50;

            /* Identificación del paciente. */
            ctx.Gfx.DrawString(
                "Informe del (a) paciente:",
                labelFont,
                black,
                new XPoint(75, ctx.Y));

            var patientLabelWidth =
                ctx.Gfx.MeasureString("Informe del (a) paciente: ", labelFont).Width;

            ctx.Gfx.DrawString(
                report.Paciente,
                bodyFont,
                black,
                new XPoint(75 + patientLabelWidth, ctx.Y));

            ctx.Y += 19;

            ctx.Gfx.DrawString(
                "Código:",
                labelFont,
                black,
                new XPoint(145, ctx.Y));

            ctx.Gfx.DrawString(
                report.IdPaciente,
                bodyFont,
                black,
                new XPoint(195, ctx.Y));

            ctx.Y += 42;

            /* Título del estudio. */
            var studyTitle =
                (report.NombrePrueba ?? "")
                    .Trim()
                    .ToUpperInvariant();

            if (!studyTitle.EndsWith(":"))
                studyTitle += ":";

            ctx.Gfx.DrawString(
                studyTitle,
                titleFont,
                black,
                new XPoint(80, ctx.Y));

            ctx.Y += 28;

            /* Hallazgos: el formato institucional no lleva el rótulo
               "Hallazgos"; se imprime directamente la redacción. */
            DrawRichHtml(
                ctx,
                report.Hallazgos,
                80,
                455);

            ctx.Y += 12;

            EnsureReportSpace(ctx, 45);

            ctx.Gfx.DrawString(
                "CONCLUSIONES:",
                titleFont,
                black,
                new XPoint(80, ctx.Y));

            ctx.Y += 25;

            DrawRichHtml(
                ctx,
                report.Conclusiones,
                90,
                445);

            ctx.Y += 30;

            /* Firma institucional. */
            EnsureReportSpace(ctx, 105);

            ctx.Gfx.DrawString(
                "Atentamente,",
                labelFont,
                black,
                new XRect(170, ctx.Y, 275, 18),
                XStringFormats.TopCenter);

            ctx.Y += 42;

            ctx.Gfx.DrawString(
                $"DR. {report.MedicoInformante}".ToUpperInvariant(),
                signatureFont,
                black,
                new XRect(150, ctx.Y, 315, 18),
                XStringFormats.TopCenter);

            ctx.Y += 18;

            if (!string.IsNullOrWhiteSpace(report.PuestoMedicoInformante))
            {
                ctx.Gfx.DrawString(
                    report.PuestoMedicoInformante!.ToUpperInvariant(),
                    signatureFont,
                    black,
                    new XRect(150, ctx.Y, 315, 18),
                    XStringFormats.TopCenter);

                ctx.Y += 18;
            }

            ctx.Gfx.DrawString(
                "RADIOLOGÍA",
                signatureFont,
                black,
                new XRect(150, ctx.Y, 315, 18),
                XStringFormats.TopCenter);
        }

        return Save(doc);
    }

    private static string FormatSpanishLongDate(DateTime date)
    {
        string[] months =
        [
            "enero",
            "febrero",
            "marzo",
            "abril",
            "mayo",
            "junio",
            "julio",
            "agosto",
            "septiembre",
            "octubre",
            "noviembre",
            "diciembre"
        ];

        return $"{date.Day:00} de {months[date.Month - 1]} de {date.Year}";
    }

    private void DrawInfoGrid(ReportPageContext ctx, StudyReportPrintData report)
    {
        EnsureReportSpace(ctx, 140);

        var blueBrush = new XSolidBrush(XColor.FromArgb(0, 64, 130));
        var border = new XPen(XColor.FromArgb(220, 228, 238));

        var rows = new (string L1, string V1, string L2, string V2)[]
        {
            ("Cita", report.NumeroCita,
             "ID interno", report.IdInternoRadiologia),

            ("Paciente", $"{report.IdPaciente} - {report.Paciente}",
             "Fecha cita", report.FechaCita.ToString("dd/MM/yyyy")),

            ("Estudio", $"{report.IdPrueba} - {report.NombrePrueba}",
             "Categoría", report.NombreCategoria),

            ("Parte(s) del cuerpo",
             string.IsNullOrWhiteSpace(report.PartesCuerpo) ? "Sin especificar" : report.PartesCuerpo,
             "Servicio", report.Servicio),

            ("Médico solicitante", report.MedicoSolicitante,
             "Versión", report.NumeroVersion.ToString()),

            ("Técnico que realizó", report.TecnicoRealiza,
             "Técnico que posicionó", report.TecnicoPosiciona)
        };

        foreach (var row in rows)
        {
            EnsureReportSpace(ctx, 28);

            ctx.Gfx.DrawRectangle(
                border,
                new XRect(45, ctx.Y, 520, 25));

            DrawInfoCell(ctx.Gfx, row.L1, row.V1, 50, ctx.Y + 5, 250, blueBrush);
            DrawInfoCell(ctx.Gfx, row.L2, row.V2, 310, ctx.Y + 5, 250, blueBrush);

            ctx.Y += 25;
        }
    }

    private void DrawInfoCell(
        XGraphics gfx,
        string label,
        string? value,
        double x,
        double y,
        double width,
        XBrush labelBrush)
    {
        gfx.DrawString(
            label + ":",
            _small,
            labelBrush,
            new XPoint(x, y + 7));

        var labelWidth = Math.Min(90, gfx.MeasureString(label + ": ", _small).Width + 4);

        var display = value ?? "";
        if (display.Length > 47)
            display = display[..44] + "...";

        gfx.DrawString(
            display,
            _small,
            XBrushes.Black,
            new XRect(x + labelWidth, y, width - labelWidth, 18),
            new XStringFormat
            {
                Alignment = XStringAlignment.Near,
                LineAlignment = XLineAlignment.Center
            });
    }

    private void DrawSectionTitle(ReportPageContext ctx, string title, XColor color)
    {
        EnsureReportSpace(ctx, 30);
        ctx.Gfx.DrawString(
            title,
            _subtitle,
            new XSolidBrush(color),
            new XPoint(45, ctx.Y + 11));
        ctx.Y += 20;
    }

    private void DrawResourceTable(
        ReportPageContext ctx,
        IReadOnlyList<StudyReportResource> resources)
    {
        EnsureReportSpace(ctx, 100);

        var cols = new (string Text, double Width)[]
        {
            ("Tamaño", 95),
            ("Películas entregadas", 125),
            ("Imágenes digitales", 125),
            ("Sistema de adquisición CD/DR", 175)
        };

        var x = 45d;
        var headerBrush = new XSolidBrush(XColor.FromArgb(235, 243, 252));
        var headerText = new XSolidBrush(XColor.FromArgb(0, 64, 130));

        foreach (var col in cols)
        {
            ctx.Gfx.DrawRectangle(headerBrush, x, ctx.Y, col.Width, 24);
            ctx.Gfx.DrawString(
                col.Text,
                _small,
                headerText,
                new XRect(x + 4, ctx.Y + 2, col.Width - 8, 20),
                XStringFormats.Center);
            x += col.Width;
        }

        ctx.Y += 24;

        foreach (var size in new[] { "8x10", "10x14", "14x17" })
        {
            var row = resources.FirstOrDefault(x =>
                string.Equals(x.TamanoPelicula, size, StringComparison.OrdinalIgnoreCase))
                ?? new StudyReportResource { TamanoPelicula = size };

            x = 45;
            var values = new[]
            {
                row.TamanoPelicula,
                row.PeliculasEntregadas.ToString(),
                row.ImagenesDigitales.ToString(),
                row.SistemaAdquisicionCDDR ?? ""
            };

            for (var i = 0; i < cols.Length; i++)
            {
                ctx.Gfx.DrawRectangle(
                    new XPen(XColor.FromArgb(225, 232, 240)),
                    new XRect(x, ctx.Y, cols[i].Width, 22));

                ctx.Gfx.DrawString(
                    values[i],
                    _small,
                    XBrushes.Black,
                    new XRect(x + 4, ctx.Y + 2, cols[i].Width - 8, 18),
                    XStringFormats.Center);

                x += cols[i].Width;
            }

            ctx.Y += 22;
        }
    }

    private void DrawRichHtml(
        ReportPageContext ctx,
        string? html,
        double x,
        double width)
    {
        var paragraphs = ParseRichHtml(html);

        if (paragraphs.Count == 0)
        {
            ctx.Gfx.DrawString(
                "-",
                _body,
                XBrushes.Black,
                new XPoint(x, ctx.Y + 10));
            ctx.Y += 16;
            return;
        }

        foreach (var paragraph in paragraphs)
        {
            DrawRichParagraph(ctx, paragraph, x, width);
            ctx.Y += 4;
        }
    }

    private void DrawRichParagraph(
        ReportPageContext ctx,
        RichParagraph paragraph,
        double x,
        double width)
    {
        var runs = new List<RichRun>();

        if (!string.IsNullOrWhiteSpace(paragraph.Prefix))
        {
            runs.Add(new RichRun
            {
                Text = paragraph.Prefix!,
                Bold = false,
                Italic = false,
                Underline = false
            });
        }

        runs.AddRange(paragraph.Runs);

        var lines = new List<List<RichRun>>();
        var currentLine = new List<RichRun>();
        var currentWidth = 0d;

        foreach (var run in runs)
        {
            var parts = Regex.Split(run.Text, @"(\s+)")
                .Where(p => p.Length > 0);

            foreach (var part in parts)
            {
                if (part.Contains('\n'))
                {
                    foreach (var piece in part.Split('\n'))
                    {
                        if (!string.IsNullOrEmpty(piece))
                            AddRichToken(piece);

                        FlushLine();
                    }
                    continue;
                }

                AddRichToken(part);
            }

            void AddRichToken(string token)
            {
                var font = GetRichFont(run);
                var tokenWidth = ctx.Gfx.MeasureString(token, font).Width;

                if (currentLine.Count > 0 &&
                    currentWidth + tokenWidth > width &&
                    !string.IsNullOrWhiteSpace(token))
                {
                    FlushLine();
                }

                if (currentLine.Count == 0 && string.IsNullOrWhiteSpace(token))
                    return;

                currentLine.Add(new RichRun
                {
                    Text = token,
                    Bold = run.Bold,
                    Italic = run.Italic,
                    Underline = run.Underline
                });

                currentWidth += tokenWidth;
            }

            void FlushLine()
            {
                if (currentLine.Count > 0)
                {
                    lines.Add(currentLine);
                    currentLine = new List<RichRun>();
                    currentWidth = 0;
                }
            }
        }

        if (currentLine.Count > 0)
            lines.Add(currentLine);

        foreach (var line in lines)
        {
            EnsureReportSpace(ctx, 16);

            var totalWidth = line.Sum(r =>
                ctx.Gfx.MeasureString(r.Text, GetRichFont(r)).Width);

            var lineX = paragraph.Alignment switch
            {
                "center" => x + Math.Max(0, (width - totalWidth) / 2),
                "right" => x + Math.Max(0, width - totalWidth),
                _ => x
            };

            foreach (var run in line)
            {
                var font = GetRichFont(run);
                ctx.Gfx.DrawString(
                    run.Text,
                    font,
                    XBrushes.Black,
                    new XPoint(lineX, ctx.Y + 10));

                lineX += ctx.Gfx.MeasureString(run.Text, font).Width;
            }

            ctx.Y += 14;
        }
    }

    private XFont GetRichFont(RichRun run)
    {
        var style = XFontStyleEx.Regular;

        if (run.Bold)
            style |= XFontStyleEx.Bold;
        if (run.Italic)
            style |= XFontStyleEx.Italic;
        if (run.Underline)
            style |= XFontStyleEx.Underline;

        return new XFont("Arial", 10.5, style);
    }

    private static List<RichParagraph> ParseRichHtml(string? html)
    {
        var result = new List<RichParagraph>();

        if (string.IsNullOrWhiteSpace(html))
            return result;

        var tokens = Regex.Split(html, "(<[^>]+>)");
        var current = new RichParagraph();

        var bold = 0;
        var italic = 0;
        var underline = 0;

        var listStack = new Stack<string>();
        var orderedCounters = new Stack<int>();

        foreach (var raw in tokens)
        {
            if (string.IsNullOrEmpty(raw))
                continue;

            if (!raw.StartsWith("<", StringComparison.Ordinal))
            {
                var decoded = WebUtility.HtmlDecode(raw)
                    .Replace("\u00A0", " ");

                if (!string.IsNullOrEmpty(decoded))
                {
                    current.Runs.Add(new RichRun
                    {
                        Text = decoded,
                        Bold = bold > 0,
                        Italic = italic > 0,
                        Underline = underline > 0
                    });
                }

                continue;
            }

            var tag = raw.Trim().ToLowerInvariant();
            var closing = tag.StartsWith("</", StringComparison.Ordinal);

            if (tag.StartsWith("<strong") || tag.StartsWith("<b>"))
            {
                if (!closing) bold++;
                continue;
            }
            if (tag.StartsWith("</strong") || tag.StartsWith("</b"))
            {
                bold = Math.Max(0, bold - 1);
                continue;
            }

            if (tag.StartsWith("<em") || tag.StartsWith("<i>"))
            {
                if (!closing) italic++;
                continue;
            }
            if (tag.StartsWith("</em") || tag.StartsWith("</i"))
            {
                italic = Math.Max(0, italic - 1);
                continue;
            }

            if (tag.StartsWith("<u>"))
            {
                underline++;
                continue;
            }
            if (tag.StartsWith("</u"))
            {
                underline = Math.Max(0, underline - 1);
                continue;
            }

            if (tag.StartsWith("<ul"))
            {
                Flush();
                listStack.Push("ul");
                orderedCounters.Push(0);
                continue;
            }
            if (tag.StartsWith("</ul"))
            {
                Flush();
                if (listStack.Count > 0) listStack.Pop();
                if (orderedCounters.Count > 0) orderedCounters.Pop();
                continue;
            }

            if (tag.StartsWith("<ol"))
            {
                Flush();
                listStack.Push("ol");
                orderedCounters.Push(0);
                continue;
            }
            if (tag.StartsWith("</ol"))
            {
                Flush();
                if (listStack.Count > 0) listStack.Pop();
                if (orderedCounters.Count > 0) orderedCounters.Pop();
                continue;
            }

            if (tag.StartsWith("<li"))
            {
                Flush();

                if (listStack.Count > 0 && listStack.Peek() == "ol")
                {
                    var next = orderedCounters.Pop() + 1;
                    orderedCounters.Push(next);
                    current.Prefix = $"{next}. ";
                }
                else
                {
                    current.Prefix = "• ";
                }

                continue;
            }

            if (tag.StartsWith("</li"))
            {
                Flush();
                continue;
            }

            if (tag.StartsWith("<br"))
            {
                Flush();
                continue;
            }

            if (tag.StartsWith("<p") || tag.StartsWith("<div"))
            {
                Flush();
                current.Alignment = ExtractAlignment(tag);
                continue;
            }

            if (tag.StartsWith("</p") || tag.StartsWith("</div"))
            {
                Flush();
            }
        }

        Flush();

        return result;

        void Flush()
        {
            if (current.Runs.Any(r => !string.IsNullOrWhiteSpace(r.Text)) ||
                !string.IsNullOrWhiteSpace(current.Prefix))
            {
                result.Add(current);
            }

            current = new RichParagraph();
        }
    }

    private static string ExtractAlignment(string tag)
    {
        var match = Regex.Match(
            tag,
            @"text-align\s*:\s*(left|center|right|justify)",
            RegexOptions.IgnoreCase);

        return match.Success
            ? match.Groups[1].Value.ToLowerInvariant()
            : "left";
    }

    private static void EnsureReportSpace(ReportPageContext ctx, double needed)
    {
        if (ctx.Y + needed <= 735)
            return;

        ctx.NewPage();
    }

    private sealed class RichRun
    {
        public string Text { get; set; } = "";
        public bool Bold { get; set; }
        public bool Italic { get; set; }
        public bool Underline { get; set; }
    }

    private sealed class RichParagraph
    {
        public string Alignment { get; set; } = "left";
        public string? Prefix { get; set; }
        public List<RichRun> Runs { get; } = [];
    }

    private sealed class ReportPageContext : IDisposable
    {
        private readonly PdfDocument _document;
        public PdfPage Page { get; private set; }
        public XGraphics Gfx { get; private set; }
        public double Y { get; set; }

        public ReportPageContext(PdfDocument document)
        {
            _document = document;
            Page = null!;
            Gfx = null!;
            NewPage();
        }

        public void NewPage()
        {
            if (Gfx is not null)
            {
                Gfx.Dispose();
            }

            Page = _document.AddPage();
            Page.Size = PdfSharp.PageSize.Letter;
            Gfx = XGraphics.FromPdfPage(Page);
            Y = 42;
        }

        public void DrawFooter()
        {
            if (Gfx is null)
                return;

            var font = new XFont("Arial", 7, XFontStyleEx.Regular);
            var brush = new XSolidBrush(XColor.FromArgb(105, 115, 130));

            Gfx.DrawLine(
                new XPen(XColor.FromArgb(225, 230, 238)),
                45, 752, 565, 752);

            Gfx.DrawString(
                "Hospital Regional de Occidente - Departamento de Imágenes",
                font,
                brush,
                new XPoint(45, 766));
        }

        public void Dispose()
        {
            if (Gfx is not null)
            {
                Gfx.Dispose();
            }
        }
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
