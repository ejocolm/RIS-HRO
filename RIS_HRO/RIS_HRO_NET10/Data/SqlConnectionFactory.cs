using Microsoft.Data.SqlClient;

namespace RIS_HRO.Data;

public sealed class SqlConnectionFactory
{
    private readonly string _connectionString;

    public SqlConnectionFactory(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("No se configuró ConnectionStrings:DefaultConnection.");
    }

    public SqlConnection Create() => new(_connectionString);
}
