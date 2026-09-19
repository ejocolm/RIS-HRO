namespace RIS_HRO.Services
{
    public static class PasswordPolicy
    {
        public const int MinLength = 5;

        public static bool IsValid(
            string? password,
            out string errorMessage)
        {
            if (string.IsNullOrWhiteSpace(password))
            {
                errorMessage = "La contraseña es obligatoria.";
                return false;
            }

            if (password.Length < MinLength)
            {
                errorMessage =
                    $"La contraseña debe contener al menos {MinLength} caracteres.";
                return false;
            }

            if (!password.Any(char.IsUpper))
            {
                errorMessage =
                    "La contraseña debe contener al menos una letra mayúscula.";
                return false;
            }

            if (!password.Any(char.IsDigit))
            {
                errorMessage =
                    "La contraseña debe contener al menos un número.";
                return false;
            }

            errorMessage = "";
            return true;
        }
    }
}
