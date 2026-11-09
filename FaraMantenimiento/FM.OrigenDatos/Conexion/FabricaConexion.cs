using System.Data;
using Microsoft.Extensions.Configuration;
using MySqlConnector;

namespace FM.OrigenDatos.Conexion;

public interface IFabricaConexion
{
    IDbConnection Crear();
}

public sealed class FabricaConexion : IFabricaConexion
{
    private readonly string _cs;

    public FabricaConexion(IConfiguration config)
    {
        _cs = config.GetConnectionString("FaraMantenimiento")
            ?? throw new InvalidOperationException("Falta ConnectionStrings:FaraMantenimiento (User Secrets o variable de entorno).");
    }

    public IDbConnection Crear() => new MySqlConnection(_cs);
}
