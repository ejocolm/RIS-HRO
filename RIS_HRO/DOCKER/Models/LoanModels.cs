namespace RIS_HRO.Models;


public sealed class BorrowerRow
{
    public string IdPrestatario { get; set; } = "";

    public string NombreCompleto { get; set; } = "";

    public string? Telefono { get; set; }

    public string? Correo { get; set; }

    public string? Direccion { get; set; }

    public bool Activo { get; set; }

    public DateTime FechaCreacion { get; set; }

    public DateTime? FechaModificacion { get; set; }

    public bool TieneDocumento1 { get; set; }

    public bool TieneDocumento2 { get; set; }
}


public sealed class BorrowerSaveCommand
{
    public string IdPrestatario { get; set; } = "";

    public string NombreCompleto { get; set; } = "";

    public string? Telefono { get; set; }

    public string? Correo { get; set; }

    public string? Direccion { get; set; }


    public string? Documento1NombreArchivo { get; set; }

    public string? Documento1TipoMime { get; set; }

    public byte[]? Documento1Imagen { get; set; }


    public string? Documento2NombreArchivo { get; set; }

    public string? Documento2TipoMime { get; set; }

    public byte[]? Documento2Imagen { get; set; }


    public bool EliminarDocumento2 { get; set; }

    public bool Activo { get; set; } = true;
}


public sealed class BorrowerDocumentData
{
    public string NombreArchivo { get; set; } = "";

    public string TipoMime { get; set; } = "";

    public byte[] Imagen { get; set; } = [];
}


public sealed class LoanStudyContext
{
    public int IdDetalleCita { get; set; }

    public int IdCita { get; set; }

    public string NumeroCita { get; set; } = "";

    public string IdPaciente { get; set; } = "";

    public string Paciente { get; set; } = "";

    public string IdPrueba { get; set; } = "";

    public string NombrePrueba { get; set; } = "";

    public string NombreCategoria { get; set; } = "";

    public string PartesCuerpo { get; set; } = "";

    public string? IdInternoRadiologia { get; set; }


    public int? IdPrestamoActivo { get; set; }

    public DateTime? FechaHoraPrestamo { get; set; }

    public string? IdPrestatarioActivo { get; set; }

    public string? PrestatarioActivo { get; set; }


    public bool EstaPrestado =>
        IdPrestamoActivo.HasValue;
}


public sealed class ActiveLoanRow
{
    public int IdPrestamo { get; set; }

    public int IdDetalleCita { get; set; }

    public DateTime FechaHoraPrestamo { get; set; }

    public int DiasPrestado { get; set; }


    public string? IdInternoRadiologia { get; set; }


    public string IdPaciente { get; set; } = "";

    public string Paciente { get; set; } = "";


    public string IdPrueba { get; set; } = "";

    public string NombrePrueba { get; set; } = "";

    public string PartesCuerpo { get; set; } = "";


    public string IdPrestatario { get; set; } = "";

    public string Prestatario { get; set; } = "";

    public string? TelefonoPrestatario { get; set; }


    public string MotivoPrestamo { get; set; } = "";

    public string? Observaciones { get; set; }

    public string UsuarioPrestamo { get; set; } = "";
}


public sealed class LoanDetail
{
    public int IdPrestamo { get; set; }

    public int IdDetalleCita { get; set; }

    public DateTime FechaHoraPrestamo { get; set; }

    public string MotivoPrestamo { get; set; } = "";

    public string? Observaciones { get; set; }

    public string Estado { get; set; } = "";

    public string UsuarioPrestamo { get; set; } = "";


    public string? DocumentoIdentificacionDevuelve { get; set; }

    public string? NombrePersonaDevuelve { get; set; }

    public DateTime? FechaHoraDevolucion { get; set; }

    public string? UsuarioDevolucion { get; set; }

    public string? ObservacionesDevolucion { get; set; }


    public string? IdInternoRadiologia { get; set; }


    public string IdPaciente { get; set; } = "";

    public string Paciente { get; set; } = "";


    public string IdPrueba { get; set; } = "";

    public string NombrePrueba { get; set; } = "";

    public string NombreCategoria { get; set; } = "";

    public string PartesCuerpo { get; set; } = "";


    public string IdPrestatario { get; set; } = "";

    public string Prestatario { get; set; } = "";

    public string? TelefonoPrestatario { get; set; }

    public string? CorreoPrestatario { get; set; }

    public string? DireccionPrestatario { get; set; }

    public bool TieneDocumento1 { get; set; }

    public bool TieneDocumento2 { get; set; }


    public bool EstaActivo =>
        string.Equals
        (
            Estado,
            "ACTIVO",
            StringComparison.OrdinalIgnoreCase
        );
}


/* ============================================================================
   FASE 2 - HISTORIAL DE PRÉSTAMOS
   ============================================================================ */

public sealed class LoanHistoryRow
{
    public int IdPrestamo { get; set; }

    public int IdDetalleCita { get; set; }


    public DateTime FechaHoraPrestamo { get; set; }

    public DateTime? FechaHoraDevolucion { get; set; }

    public int DiasPrestamo { get; set; }


    public string EstadoPrestamo { get; set; } = "PRESTADO";


    public bool EstaPrestado =>
        string.Equals
        (
            EstadoPrestamo,
            "PRESTADO",
            StringComparison.OrdinalIgnoreCase
        );


    public string? IdInternoRadiologia { get; set; }


    public string IdPaciente { get; set; } = "";

    public string Paciente { get; set; } = "";


    public string IdPrueba { get; set; } = "";

    public string NombrePrueba { get; set; } = "";

    public string PartesCuerpo { get; set; } = "";


    public string IdPrestatario { get; set; } = "";

    public string Prestatario { get; set; } = "";

    public string? TelefonoPrestatario { get; set; }


    public string MotivoPrestamo { get; set; } = "";

    public string? Observaciones { get; set; }


    public string UsuarioPrestamo { get; set; } = "";

    public string? UsuarioDevolucion { get; set; }
}