using System.Net;
using System.Text.RegularExpressions;

namespace RIS_HRO.Services;

public static class RichTextSanitizer
{
    private static readonly HashSet<string> AllowedTags = new(StringComparer.OrdinalIgnoreCase)
    {
        "p", "div", "span", "br", "b", "strong", "i", "em", "u", "ul", "ol", "li"
    };

    private static readonly Regex CommentRegex =
        new("<!--.*?-->", RegexOptions.Singleline | RegexOptions.Compiled);

    private static readonly Regex DangerousBlockRegex =
        new("<(script|style|iframe|object|embed|form|input|button|link|meta)[^>]*>.*?</\\1\\s*>",
            RegexOptions.IgnoreCase | RegexOptions.Singleline | RegexOptions.Compiled);

    private static readonly Regex DangerousSingleRegex =
        new("<(script|style|iframe|object|embed|form|input|button|link|meta)[^>]*/?>",
            RegexOptions.IgnoreCase | RegexOptions.Singleline | RegexOptions.Compiled);

    private static readonly Regex TagRegex =
        new("<\\s*(/?)\\s*([a-zA-Z0-9]+)([^>]*)>", RegexOptions.Singleline | RegexOptions.Compiled);

    private static readonly Regex TextAlignStyleRegex =
        new("text-align\\s*:\\s*(left|center|right|justify)", RegexOptions.IgnoreCase | RegexOptions.Compiled);

    private static readonly Regex AlignAttributeRegex =
        new("align\\s*=\\s*[\\\"']?(left|center|right|justify)[\\\"']?", RegexOptions.IgnoreCase | RegexOptions.Compiled);

    private static readonly Regex AnyTagRegex =
        new("<[^>]+>", RegexOptions.Singleline | RegexOptions.Compiled);

    public static string? Sanitize(string? html)
    {
        if (string.IsNullOrWhiteSpace(html))
            return null;

        var value = CommentRegex.Replace(html, string.Empty);
        value = DangerousBlockRegex.Replace(value, string.Empty);
        value = DangerousSingleRegex.Replace(value, string.Empty);

        value = TagRegex.Replace(value, match =>
        {
            var closing = match.Groups[1].Value == "/";
            var tag = match.Groups[2].Value.ToLowerInvariant();
            var attrs = match.Groups[3].Value;

            if (!AllowedTags.Contains(tag))
                return string.Empty;

            if (closing)
                return tag == "br" ? string.Empty : $"</{tag}>";

            if (tag == "br")
                return "<br>";

            if (tag is "p" or "div" or "span")
            {
                var alignment = TextAlignStyleRegex.Match(attrs);
                if (!alignment.Success)
                    alignment = AlignAttributeRegex.Match(attrs);

                if (alignment.Success)
                {
                    var align = alignment.Groups[1].Value.ToLowerInvariant();
                    return $"<{tag} style=\"text-align:{align}\">";
                }
            }

            return $"<{tag}>";
        });

        return HasVisibleText(value) ? value.Trim() : null;
    }

    public static bool HasVisibleText(string? html)
    {
        if (string.IsNullOrWhiteSpace(html))
            return false;

        var text = AnyTagRegex.Replace(html, " ");
        text = WebUtility.HtmlDecode(text)
            .Replace("\u00A0", " ")
            .Trim();

        return !string.IsNullOrWhiteSpace(text);
    }
}
