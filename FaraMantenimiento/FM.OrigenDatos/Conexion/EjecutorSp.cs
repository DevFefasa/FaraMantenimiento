using System.Data;
using Dapper;
using MySqlConnector;

namespace FM.OrigenDatos.Conexion;

public interface IEjecutorSp
{
    Task<RespuestaSp> EjecutarAsync(string sp, object? param = null, CancellationToken ct = default);
    Task<RespuestaSp<T>> EjecutarAsync<T>(string sp, object? param = null, CancellationToken ct = default);
    Task<(RespuestaSp Cabecera, List<T1> Datos1, List<T2> Datos2)> EjecutarDosAsync<T1, T2>(string sp, object? param = null, CancellationToken ct = default);
    Task<(RespuestaSp Cabecera, List<T1> Datos1, List<T2> Datos2, List<T3> Datos3)> EjecutarTresAsync<T1, T2, T3>(string sp, object? param = null, CancellationToken ct = default);
}

public sealed class EjecutorSp : IEjecutorSp
{
    private readonly IFabricaConexion _fabrica;
    public EjecutorSp(IFabricaConexion fabrica) => _fabrica = fabrica;

    public async Task<RespuestaSp> EjecutarAsync(string sp, object? param = null, CancellationToken ct = default)
    {
        await using var cn = (MySqlConnection)_fabrica.Crear();
        await cn.OpenAsync(ct);
        await using var multi = await cn.QueryMultipleAsync(new CommandDefinition(sp, param, commandType: CommandType.StoredProcedure, cancellationToken: ct));
        return await multi.ReadSingleAsync<RespuestaSp>();
    }

    public async Task<RespuestaSp<T>> EjecutarAsync<T>(string sp, object? param = null, CancellationToken ct = default)
    {
        await using var cn = (MySqlConnection)_fabrica.Crear();
        await cn.OpenAsync(ct);
        await using var multi = await cn.QueryMultipleAsync(new CommandDefinition(sp, param, commandType: CommandType.StoredProcedure, cancellationToken: ct));
        var cab = await multi.ReadSingleAsync<RespuestaSp>();
        var datos = new List<T>();
        if (cab.FbSucces && !multi.IsConsumed)
            datos = (await multi.ReadAsync<T>()).AsList();
        return new RespuestaSp<T> { FiCodigo = cab.FiCodigo, FcMensaje = cab.FcMensaje, FbSucces = cab.FbSucces, FjData = cab.FjData, Datos = datos };
    }

    public async Task<(RespuestaSp Cabecera, List<T1> Datos1, List<T2> Datos2)> EjecutarDosAsync<T1, T2>(string sp, object? param = null, CancellationToken ct = default)
    {
        await using var cn = (MySqlConnection)_fabrica.Crear();
        await cn.OpenAsync(ct);
        await using var multi = await cn.QueryMultipleAsync(new CommandDefinition(sp, param, commandType: CommandType.StoredProcedure, cancellationToken: ct));
        var cab = await multi.ReadSingleAsync<RespuestaSp>();
        var d1 = new List<T1>();
        var d2 = new List<T2>();
        if (cab.FbSucces && !multi.IsConsumed) d1 = (await multi.ReadAsync<T1>()).AsList();
        if (cab.FbSucces && !multi.IsConsumed) d2 = (await multi.ReadAsync<T2>()).AsList();
        return (cab, d1, d2);
    }

    public async Task<(RespuestaSp Cabecera, List<T1> Datos1, List<T2> Datos2, List<T3> Datos3)> EjecutarTresAsync<T1, T2, T3>(string sp, object? param = null, CancellationToken ct = default)
    {
        await using var cn = (MySqlConnection)_fabrica.Crear();
        await cn.OpenAsync(ct);
        await using var multi = await cn.QueryMultipleAsync(new CommandDefinition(sp, param, commandType: CommandType.StoredProcedure, cancellationToken: ct));
        var cab = await multi.ReadSingleAsync<RespuestaSp>();
        var d1 = new List<T1>();
        var d2 = new List<T2>();
        var d3 = new List<T3>();
        if (cab.FbSucces && !multi.IsConsumed) d1 = (await multi.ReadAsync<T1>()).AsList();
        if (cab.FbSucces && !multi.IsConsumed) d2 = (await multi.ReadAsync<T2>()).AsList();
        if (cab.FbSucces && !multi.IsConsumed) d3 = (await multi.ReadAsync<T3>()).AsList();
        return (cab, d1, d2, d3);
    }
}
