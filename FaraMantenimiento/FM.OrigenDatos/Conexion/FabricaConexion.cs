using System.Data;
using System.Text.RegularExpressions;
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
    private readonly string _zonaHoraria;

    public FabricaConexion(IConfiguration config)
    {
        _cs = config.GetConnectionString("FaraMantenimiento")
            ?? throw new InvalidOperationException("Falta ConnectionStrings:FaraMantenimiento (User Secrets o variable de entorno).");

        // El servidor MariaDB puede estar en UTC; NOW() de los SP debe dar la hora de Honduras.
        // BaseDatos:ZonaHoraria acepta un desfase "+HH:MM"/"-HH:MM" (Honduras = -06:00, sin horario de verano).
        var zona = (config["BaseDatos:ZonaHoraria"] ?? "-06:00").Trim();
        _zonaHoraria = Regex.IsMatch(zona, "^[+-](0\\d|1[0-4]):[0-5]\\d$") ? zona : "-06:00";
    }

    public IDbConnection Crear()
    {
        var cn = new MySqlConnection(_cs);
        cn.StateChange += (s, e) =>
        {
            if (e.CurrentState != ConnectionState.Open || s is not MySqlConnection abierta) return;
            using var cmd = abierta.CreateCommand();
            cmd.CommandText = $"SET time_zone = '{_zonaHoraria}'"; // valor validado con regex arriba
            cmd.ExecuteNonQuery();
        };
        return cn;
    }
}
