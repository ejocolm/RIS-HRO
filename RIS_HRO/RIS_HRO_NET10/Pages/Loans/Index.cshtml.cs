using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

using RIS_HRO.Models;
using RIS_HRO.Repositories;


namespace RIS_HRO.Pages.Loans;


[Authorize(
    Roles = "ADMINISTRADOR,USUARIO_BODEGA"
)]
public sealed class IndexModel : PageModel
{
    private readonly LoanRepository _loans;


    public IndexModel(
        LoanRepository loans)
    {
        _loans = loans;
    }


    /* ========================================================================
       FILTROS
       ======================================================================== */

    [BindProperty(SupportsGet = true)]
    public DateTime? From { get; set; }


    [BindProperty(SupportsGet = true)]
    public DateTime? To { get; set; }


    [BindProperty(SupportsGet = true)]
    public string? PatientId { get; set; }


    [BindProperty(SupportsGet = true)]
    public string? InternalId { get; set; }


    [BindProperty(SupportsGet = true)]
    public string? Status { get; set; }



    /* ========================================================================
       RESULTADOS
       ======================================================================== */

    public List<LoanHistoryRow> Rows { get; private set; } = [];


    public int Prestados =>
        Rows.Count(
            x => x.EstaPrestado
        );


    public int Devueltos =>
        Rows.Count(
            x => !x.EstaPrestado
        );



    /* ========================================================================
       GET
       ======================================================================== */

    public async Task OnGetAsync(
        CancellationToken ct)
    {
        Normalize();


        if
        (
            From.HasValue
            &&
            To.HasValue
            &&
            From.Value.Date >
            To.Value.Date
        )
        {
            ModelState.AddModelError(
                "",
                "La fecha inicial no puede ser posterior a la fecha final."
            );

            return;
        }


        try
        {
            Rows =
                await _loans.ListLoansAsync(
                    From,
                    To,
                    PatientId,
                    InternalId,
                    Status,
                    ct
                );
        }
        catch (InvalidOperationException ex)
        {
            ModelState.AddModelError(
                "",
                ex.Message
            );
        }
    }



    /* ========================================================================
       HELPERS
       ======================================================================== */

    private void Normalize()
    {
        PatientId =
            NullIfWhite(
                PatientId
            );


        InternalId =
            NullIfWhite(
                InternalId
            );


        Status =
            NullIfWhite(
                Status
            )
            ?.ToUpperInvariant();
    }


    private static string? NullIfWhite(
        string? value)
    {
        return string.IsNullOrWhiteSpace(value)
            ? null
            : value.Trim();
    }
}