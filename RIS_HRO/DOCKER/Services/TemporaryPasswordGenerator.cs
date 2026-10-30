using System.Security.Cryptography;

namespace RIS_HRO.Services;

public sealed class TemporaryPasswordGenerator
{
    private const string Upper = "ABCDEFGHJKLMNPQRSTUVWXYZ";
    private const string Lower = "abcdefghijkmnopqrstuvwxyz";
    private const string Digits = "23456789";
    private const string Symbols = "@#$%!*";

    public string Generate(int length = 12)
    {
        if (length < 10)
            length = 10;

        var chars = new List<char>
        {
            RandomFrom(Upper),
            RandomFrom(Lower),
            RandomFrom(Digits),
            RandomFrom(Symbols)
        };

        var all = Upper + Lower + Digits + Symbols;

        while (chars.Count < length)
            chars.Add(RandomFrom(all));

        // Fisher-Yates con RNG criptográfico.
        for (var i = chars.Count - 1; i > 0; i--)
        {
            var j = RandomNumberGenerator.GetInt32(i + 1);
            (chars[i], chars[j]) = (chars[j], chars[i]);
        }

        return new string(chars.ToArray());
    }

    private static char RandomFrom(string source) =>
        source[RandomNumberGenerator.GetInt32(source.Length)];
}
