using RIS_HRO.Models;
using RIS_HRO.Repositories;

namespace RIS_HRO.Services;

public sealed class PatientLookupResult
{
    public bool Found { get; init; }
    public string Source { get; init; } = "";
    public Patient? Patient { get; init; }
    public string Message { get; init; } = "";
}

public sealed class PatientLookupService
{
    private readonly IHospitalPatientService _hospitalService;
    private readonly PatientRepository _patientRepository;

    public PatientLookupService(
        IHospitalPatientService hospitalService,
        PatientRepository patientRepository)
    {
        _hospitalService = hospitalService;
        _patientRepository = patientRepository;
    }

    public async Task<PatientLookupResult> FindAsync(
        string idPaciente,
        CancellationToken cancellationToken = default)
    {
        var hospital = await _hospitalService.FindAsync(idPaciente, cancellationToken);

        if (hospital.Success && hospital.Found && hospital.Patient is not null)
        {
            // Se mantiene copia local para poder cumplir las FK de CITA.
            await _patientRepository.SaveAsync(hospital.Patient, cancellationToken);

            return new PatientLookupResult
            {
                Found = true,
                Source = "HOSPITAL",
                Patient = hospital.Patient,
                Message = hospital.Message
            };
        }

        var local = await _patientRepository.GetAsync(idPaciente, cancellationToken);
        if (local is not null)
        {
            return new PatientLookupResult
            {
                Found = true,
                Source = "LOCAL",
                Patient = local,
                Message = hospital.Success
                    ? "Paciente no encontrado externamente; se utilizó la base local."
                    : "Sin respuesta externa; paciente encontrado en la base local."
            };
        }

        return new PatientLookupResult
        {
            Found = false,
            Source = "MANUAL",
            Message = "Paciente no encontrado. Ingrese sus datos manualmente."
        };
    }
}
